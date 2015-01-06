//
//  VTextView.m
//  VEmotionText
//
//  Created by Vic Zhou on 12/31/14.
//  Copyright (c) 2014 everycode. All rights reserved.
//

#import "VTextView.h"
#import "UIColor+VTextView.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import <UIKit/UITextChecker.h>
#include <objc/runtime.h>
#import "VContentView.h"
#import "VTextAttachment.h"
#import "VCaretView.h"
#import "VTextPostion.h"
#import "VTextRange.h"

static NSString *const vLeftDelimiter = @"\\[";
static NSString *const vRightDelimiter = @"\\]";
static NSString *const vTextAttachmentAttributeName = @"com.everycode.vTextAttachmentAttribute";
static NSString *const vTextAttachmentPlaceholderString = @"\ufffc";
static NSString *const vTextAttachmentOriginStringKey = @"com.everycode.vTextAttachmentOriginString";

static void AttachmentRunDelegateDealloc(void *refCon) {
    CFBridgingRelease(refCon);
}

static CGSize AttachmentRunDelegateGetSize(void *refCon) {
    id <VTextAttachment> attachment = (__bridge id<VTextAttachment>)(refCon);
    if ([attachment respondsToSelector: @selector(attachmentSize)]) {
        return [attachment attachmentSize];
    } else {
        return [[attachment attachmentView] frame].size;
    }
}

static CGFloat AttachmentRunDelegateGetAscent(void *refCon) {
    return AttachmentRunDelegateGetSize(refCon).height;
}

static CGFloat AttachmentRunDelegateGetDescent(void *refCon) {
    return 0;
}

static CGFloat AttachmentRunDelegateGetWidth(void *refCon) {
    return AttachmentRunDelegateGetSize(refCon).width;
}

@interface VTextView () <
    ContentViewDelegate>

@property (nonatomic, assign) BOOL editing;
@property (nonatomic, strong) NSDictionary *defaultAttributes;
@property (nonatomic, strong) NSMutableDictionary *currentAttributes;
@property (nonatomic, strong) NSDictionary *correctionAttributes;
@property (nonatomic, strong) NSMutableDictionary *menuItemActions;
@property (nonatomic, assign) NSRange correctionRange;
@property (nonatomic, assign) NSRange linkRange;

@property (nonatomic, strong) NSMutableArray *attachmentViewArray;
@property (nonatomic, strong) NSMutableAttributedString *mutableAttributeString;

@property (nonatomic, assign) CTFramesetterRef framesetterRef;
@property (nonatomic, assign) CTFrameRef frameRef;
@property (nonatomic, strong) UITextInputStringTokenizer *tokenizer;
@property (nonatomic, strong) UITextChecker *textChecker;

@property (nonatomic, strong) VContentView *contentView;
@property (nonatomic, strong) VCaretView *caretView;

- (void)common;
- (void)textChanged;

- (CGFloat)boundingHeightForWidth:(CGFloat)width;
- (CGRect)caretRectForIndex:(NSInteger)index;
- (CGRect)vFirstRectForRange:(NSRange)range;
- (NSInteger)closestIndexToPoint:(CGPoint)point;
- (NSRange)vCharacterRangeAtPoint:(CGPoint)point;
- (NSRange)characterRangeAtIndex:(NSInteger)index;
- (void)checkSpellingForRange:(NSRange)range;
- (void)removeCorrectionAttributesForRange:(NSRange)range;
- (void)insertCorrectionAttributesForRange:(NSRange)range;
- (void)showCorrectionMenuForRange:(NSRange)range;
- (void)showMenu;
- (CGRect)menuPresentationRect;

//Layout
- (void)drawContentInRect:(CGRect)rect;
- (void)drawBoundingRangeAsSelection:(NSRange)selectionRange cornerRadius:(CGFloat)cornerRadius;
- (void)drawPathFromRects:(NSArray*)array cornerRadius:(CGFloat)cornerRadius;

//Layout get range
- (NSRange)rangeIntersection:(NSRange)first withSecond:(NSRange)second;

//Layout selection


//Data Detectors
- (void)scanAttachments;
- (void)checkLinksForRange:(NSRange)range;

//NSAttributedstring <-> NSString
- (NSAttributedString*)converStringToAttributedString:(NSString*)string;
- (NSString*)converAttributedStringToString:(NSAttributedString*)attributedString;


@end

@implementation VTextView

#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self common];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self common];
    }
    return self;
}

#pragma mark - Getter

- (NSDictionary*)defaultAttributes {
    if (!_defaultAttributes) {
        UIFont *font = [UIFont systemFontOfSize:17.f];
        UIColor *color = [UIColor blackColor];
        CTFontRef fontRef = CTFontCreateWithName((CFStringRef)font.fontName, font.pointSize, NULL);
        CGColorRef colorRef = color.CGColor;
        _defaultAttributes = @{
                               (id)kCTFontAttributeName: (__bridge id)fontRef,
                               (id)kCTForegroundColorAttributeName: (__bridge id)colorRef
                               };
        CFRelease(fontRef);
        CFRelease(colorRef);
    }
    return _defaultAttributes;
}

- (NSMutableDictionary*)currentAttributes {
    if (!_currentAttributes) {
        _currentAttributes = [NSMutableDictionary dictionaryWithDictionary:self.defaultAttributes];
    }
    return _currentAttributes;
}

- (NSDictionary*)correctionAttributes {
    if (!_correctionAttributes) {
        UIColor *color = [UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:1.0f];
        CGColorRef colorRef = color.CGColor;
        _correctionAttributes = @{
                                  (id)kCTUnderlineStyleAttributeName:[NSNumber numberWithInt:(int)(kCTUnderlineStyleThick|kCTUnderlinePatternDot)],
                                  (id)kCTUnderlineColorAttributeName:(__bridge id)colorRef
                                  };
        CFRelease(colorRef);
    }
    return _correctionAttributes;
}

- (NSMutableDictionary*)menuItemActions {
    if (!_menuItemActions) {
        _menuItemActions = [[NSMutableDictionary alloc] init];
    }
    return _menuItemActions;
}

- (NSMutableArray*)attachmentViewArray {
    if (!_attachmentViewArray) {
        _attachmentViewArray = [[NSMutableArray alloc] init];
    }
    return _attachmentViewArray;
}

- (VContentView*)contentView {
    if (!_contentView) {
        _contentView = [[VContentView alloc] initWithFrame:self.bounds];
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _contentView.delegate = self;
    }
    return _contentView;
}

- (VCaretView*)caretView {
    if (!_caretView) {
        _caretView = [[VCaretView alloc] initWithFrame:CGRectZero];
    }
    return _caretView;
}

- (UITextInputStringTokenizer*)tokenizer {
    if (!_tokenizer) {
        _tokenizer = [[UITextInputStringTokenizer alloc] initWithTextInput:self];
    }
    return _tokenizer;
}

- (UITextChecker*)textChecker {
    if (!_textChecker) {
        _textChecker = [[UITextChecker alloc] init];
    }
    return _textChecker;
}

- (NSMutableAttributedString*)mutableAttributeString {
    if (!_mutableAttributeString) {
        _mutableAttributeString = [[NSMutableAttributedString alloc] init];
    }
    return _mutableAttributeString;
}

- (NSString*)text {
    return [self converAttributedStringToString:self.attributedString];
}

#pragma mark - Setter

- (void)setFont:(UIFont *)font {
    _font = font;
    CTFontRef fontRef = CTFontCreateWithName((CFStringRef)font.fontName, font.pointSize, NULL);
    [self.currentAttributes setObject:(__bridge id)fontRef
                               forKey:(id)kCTFontAttributeName];
    CFRelease(fontRef);

    [self textChanged];
}

- (void)setText:(NSString *)text {
    [self.inputDelegate textWillChange:self];
    NSAttributedString *attributedString = [self converStringToAttributedString:text];
//    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:text
//                                                                 attributes:self.currentAttributes];
    self.attributedString = attributedString;
    [self.inputDelegate textDidChange:self];
}

- (void)setAttributedString:(NSAttributedString *)attributedString {
    _attributedString = attributedString;
    NSRange stringRange = NSMakeRange(0, attributedString.length);
    if (!_editing && !_editable) {
        [self checkLinksForRange:stringRange];
    }

    [self textChanged];
    if ([self.delegate respondsToSelector:@selector(vTextViewDidChange:)]) {
        [self.delegate vTextViewDidChange:self];
    }
}

- (void)setEditable:(BOOL)editable {
    _editable = editable;
    if (!editable) {
        [self.caretView removeFromSuperview];
        self.caretView=nil;
    }
    self.tokenizer = nil;
    self.textChecker = nil;
    self.mutableAttributeString = nil;
    self.correctionAttributes = nil;
}

#pragma mark - View
#pragma mark Layout

- (void)drawContentInRect:(CGRect)rect {
    UIColor *fillColor = [UIColor whiteColor];
    [fillColor setFill];
    [self drawBoundingRangeAsSelection:self.linkRange cornerRadius:2.f];
    [[UIColor vSelectionColor] setFill];
    [self drawBoundingRangeAsSelection:self.selectedRange cornerRadius:0];
    [[UIColor vSpellingSelectionColor] setFill];
    [self drawBoundingRangeAsSelection:self.correctionRange cornerRadius:2.f];

    CGPathRef frameRefPath = CTFrameGetPath(self.frameRef);
    CGRect frameRefRect = CGPathGetBoundingBox(frameRefPath);
    CFArrayRef lines = CTFrameGetLines(self.frameRef);
    NSInteger lineCount = CFArrayGetCount(lines);
    CGPoint *origins = (CGPoint*)malloc(lineCount*sizeof(CGPoint));
    CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, lineCount), origins);

    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    for (int i = 0; i <  lineCount; i++) {
        CTLineRef lineRef = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
        CGContextSetTextPosition(contextRef, frameRefRect.origin.x+origins[i].x, frameRefRect.origin.y+origins[i].y);
        CTLineDraw(lineRef, contextRef);
        CFArrayRef runs = CTLineGetGlyphRuns(lineRef);
        CFIndex runCount = CFArrayGetCount(runs);
        for (CFIndex index = 0; index < runCount; index++) {
            CTRunRef run = CFArrayGetValueAtIndex(runs, index);
            CFDictionaryRef attributes = CTRunGetAttributes(run);
            id <VTextAttachment>attachment = [(__bridge id)attributes objectForKey:vTextAttachmentAttributeName];
            BOOL respondSize = [attachment respondsToSelector:@selector(attachmentSize)];
            BOOL respondDraw = [attachment respondsToSelector:@selector(attachmentDrawInRect:)];
            if (attachment && respondSize && respondDraw) {
                CGPoint position;
                CTRunGetPositions(run, CFRangeMake(0, 1), &position);
                CGFloat ascent, descent, leading;
                CTRunGetTypographicBounds(run, CFRangeMake(0, 1), &ascent, &descent, &leading);
                CGSize size = [attachment attachmentSize];
                CGRect rect = {{origins[i].x+position.x, origins[i].y+position.y-descent}, size};
                CGContextSaveGState(UIGraphicsGetCurrentContext());
                [attachment attachmentDrawInRect:rect];
                CGContextSaveGState(UIGraphicsGetCurrentContext());
            }
        }
    }
    free(origins);
}

- (void)drawBoundingRangeAsSelection:(NSRange)selectionRange cornerRadius:(CGFloat)cornerRadius {
    if (selectionRange.length == 0 || selectionRange.location == NSNotFound) {
        return;
    }

    NSMutableArray *pathRects = [[NSMutableArray alloc] init];
    NSArray *lines = (NSArray*)CTFrameGetLines(self.frameRef);
    CGPoint *origins = (CGPoint*)malloc([lines count] * sizeof(CGPoint));
    CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, [lines count]), origins);
    NSInteger count = [lines count];

    for (int i = 0; i < count; i++) {
        CTLineRef line = (__bridge CTLineRef) [lines objectAtIndex:i];
        CFRange lineRange = CTLineGetStringRange(line);
        NSRange range = NSMakeRange(lineRange.location==kCFNotFound ? NSNotFound : lineRange.location, lineRange.length);
        NSRange intersection = [self rangeIntersection:range withSecond:selectionRange];
        if (intersection.location != NSNotFound && intersection.length > 0) {
            CGFloat xStart = CTLineGetOffsetForStringIndex(line, intersection.location, NULL);
            CGFloat xEnd = CTLineGetOffsetForStringIndex(line, intersection.location + intersection.length, NULL);
            CGPoint origin = origins[i];
            CGFloat ascent, descent;
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            CGRect selectionRect = CGRectMake(origin.x + xStart, origin.y - descent, xEnd - xStart, ascent + descent);
            if (range.length==1) {
                selectionRect.size.width = self.contentView.bounds.size.width;
            }
            [pathRects addObject:NSStringFromCGRect(selectionRect)];
        }
    }

    [self drawPathFromRects:pathRects cornerRadius:cornerRadius];
    free(origins);
}

- (void)drawPathFromRects:(NSArray*)array cornerRadius:(CGFloat)cornerRadius {
    if (array.count == 0) {
        return;
    }

    CGMutablePathRef path = CGPathCreateMutable();
    CGRect firstRect = CGRectFromString([array lastObject]);
    CGRect lastRect = CGRectFromString([array objectAtIndex:0]);
    if ([array count]>1) {
        lastRect.size.width = self.contentView.bounds.size.width-lastRect.origin.x;
    }
    if (cornerRadius>0) {
        CGPathAddPath(path, NULL, [UIBezierPath bezierPathWithRoundedRect:firstRect cornerRadius:cornerRadius].CGPath);
        CGPathAddPath(path, NULL, [UIBezierPath bezierPathWithRoundedRect:lastRect cornerRadius:cornerRadius].CGPath);
    } else {
        CGPathAddRect(path, NULL, firstRect);
        CGPathAddRect(path, NULL, lastRect);
    }
    if ([array count] > 1) {
        CGRect fillRect = CGRectZero;
        CGFloat originX = ([array count]==2) ? MIN(CGRectGetMinX(firstRect), CGRectGetMinX(lastRect)) : 0.0f;
        CGFloat originY = firstRect.origin.y + firstRect.size.height;
        CGFloat width = ([array count]==2) ? originX+MIN(CGRectGetMaxX(firstRect), CGRectGetMaxX(lastRect)) : self.contentView.bounds.size.width;
        CGFloat height =  MAX(0.0f, lastRect.origin.y-originY);
        fillRect = CGRectMake(originX, originY, width, height);
        if (cornerRadius>0) {
            CGPathAddPath(path, NULL, [UIBezierPath bezierPathWithRoundedRect:fillRect cornerRadius:cornerRadius].CGPath);
        } else {
            CGPathAddRect(path, NULL, fillRect);
        }
    }
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextAddPath(ctx, path);
    CGContextFillPath(ctx);
    CGPathRelease(path);
}

#pragma mark - View
#pragma mark Layout Range

- (NSRange)rangeIntersection:(NSRange)first withSecond:(NSRange)second {
    NSRange result = NSMakeRange(NSNotFound, 0);
    if (first.location > second.location) {
        NSRange tmp = first;
        first = second;
        second = tmp;
    }
    if (second.location < first.location + first.length) {
        result.location = second.location;
        NSUInteger end = MIN(first.location + first.length, second.location + second.length);
        result.length = end - result.location;
    }
    return result;
}

#pragma mark - Actions Private

- (void)common {
    _editable = NO;
    _editing = NO;
    _font = [UIFont systemFontOfSize:17];
    _autocorrectionType = UITextAutocorrectionTypeNo;
    _dataDetectorTypes = UIDataDetectorTypeLink;
    self.alwaysBounceVertical = YES;
    self.backgroundColor = [UIColor whiteColor];
    self.clipsToBounds = YES;
    [self addSubview:self.contentView];
    self.text = @"";
}
- (void)textChanged {
    if ([[UIMenuController sharedMenuController] isMenuVisible]) {
        [[UIMenuController sharedMenuController] setMenuVisible:NO];
    }
    //content frame
    CGRect contentRect = self.contentView.frame;
    CGFloat height = [self boundingHeightForWidth:contentRect.size.width];
    contentRect.size.height = height+self.font.lineHeight;
    self.contentView.frame = contentRect;

    //contentsize
    self.contentSize = CGSizeMake(self.frame.size.width, contentRect.size.height+self.font.lineHeight*2);

    //frameRef(nsattributedstring的绘画需要通过ctframeref,而ctframesetterref是ctframeref的创建工厂)
    self.framesetterRef = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.attributedString);
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.contentView.bounds];
    self.frameRef = CTFramesetterCreateFrame(self.framesetterRef,CFRangeMake(0, 0), [path CGPath], NULL);

    //
    for (UIView *view in self.attachmentViewArray) {
        [view removeFromSuperview];
    }
    NSRange stringRange = NSMakeRange(0, self.attributedString.length);
    [self.attributedString enumerateAttribute:vTextAttachmentAttributeName
                                      inRange:stringRange
                                      options:0
                                   usingBlock:^(id value, NSRange range, BOOL *stop) {
                                       if ([value respondsToSelector:@selector(attachmentView)]) {
                                           UIView *view = [value attachmentView];
                                           [self.attachmentViewArray addObject:view];
                                           CGRect rect = [self vFirstRectForRange:range];
                                           rect.size = view.frame.size;
                                           view.frame = rect;
                                           [self addSubview:view];
                                       }
                                   }];
    [self.contentView setNeedsDisplay];
}

- (CGFloat)boundingHeightForWidth:(CGFloat)width {
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(self.framesetterRef, CFRangeMake(0, 0), NULL, CGSizeMake(width, CGFLOAT_MAX), NULL);
    return suggestedSize.height;
}

#pragma mark - Actions Private
#pragma mark NSString<->NSAttributedString

- (NSAttributedString*)converStringToAttributedString:(NSString *)string {
    NSError *error;
    NSString *pattern = [NSString stringWithFormat:@"%@(.+?)%@",vLeftDelimiter, vRightDelimiter];
    NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                             options:0
                                                                               error:&error];
    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:string
                                                                                   attributes:self.currentAttributes];
    NSRange stringRange = NSMakeRange(0, string.length);
    [regular enumerateMatchesInString:string options:0 range:stringRange usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result.resultType == NSTextCheckingTypeRegularExpression) {
            NSRange subRange = [result rangeAtIndex:1];
            NSString *match = [string substringWithRange:subRange];
            NSString *fulltext = [string substringWithRange:[result rangeAtIndex:0]];
            if ([self.textImageMapping.allKeys containsObject:match]) {
                id img = [self.textImageMapping objectForKey:match];
                UIImage *image;
                if ([img isKindOfClass:[UIImage class]]) {
                    image = img;
                }
                else if ([img isKindOfClass:[NSURL class]]) {
                    NSURL *url = (NSURL*)img;
                    if (url.isFileURL) {
                        image = [UIImage imageWithContentsOfFile:url.absoluteString];
                    }
                    else {
                        //
                    }
                }
                else if ([img isKindOfClass:[NSString class]]) {
                    image = [UIImage imageNamed:img];
                    if (!image) {
                        image = [UIImage imageWithContentsOfFile:img];
                    }
                }
                CTRunDelegateCallbacks callbacks = {
                    .version = kCTRunDelegateVersion1,
                    .dealloc = AttachmentRunDelegateDealloc,
                    .getAscent = AttachmentRunDelegateGetAscent,
                    .getDescent = AttachmentRunDelegateGetDescent,
                    .getWidth = AttachmentRunDelegateGetWidth
                };

                CTRunDelegateRef Rundelegate = CTRunDelegateCreate(&callbacks, (__bridge void *)(image));

                NSMutableDictionary *attrDictionaryDelegate = [NSMutableDictionary dictionaryWithDictionary:self.currentAttributes];
                [attrDictionaryDelegate setObject:image
                                           forKey:vTextAttachmentAttributeName];
                [attrDictionaryDelegate setObject:(__bridge id)Rundelegate
                                           forKey:(NSString*)kCTRunDelegateAttributeName];
                [attrDictionaryDelegate setObject:fulltext
                                           forKey:vTextAttachmentOriginStringKey];
                NSAttributedString *newString = [[NSAttributedString alloc] initWithString:vTextAttachmentPlaceholderString
                                                                                attributes:attrDictionaryDelegate];

                [mutableAttributedString replaceCharactersInRange:[result resultByAdjustingRangesWithOffset:mutableAttributedString.length-string.length].range
                                withAttributedString:newString];
            }
        }
    }];
    return mutableAttributedString;
}

- (NSString*)converAttributedStringToString:(NSAttributedString *)attributedString {
    NSMutableString *mutableString = [NSMutableString stringWithString:attributedString.string];
    NSRange stringRange = NSMakeRange(0, attributedString.length);
    [attributedString enumerateAttribute:vTextAttachmentOriginStringKey
                                 inRange:stringRange
                                 options:0
                              usingBlock:^(id value, NSRange range, BOOL *stop) {
                                  if (value != nil) {
                                      NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:range.length];
                                      for (int i=0; i<range.length; ++i) {
                                          [mutableArray addObject:value];
                                      }
                                      [mutableString replaceCharactersInRange:NSMakeRange(range.location + mutableString.length - attributedString.length, range.length)
                                                                   withString:[mutableArray componentsJoinedByString:@""]];
                                  }
                              }];
    return [NSString stringWithString:mutableString];
}

#pragma mark - Actions Private
#pragma mark - Data Detectors

- (void)checkLinksForRange:(NSRange)range {
    NSMutableDictionary *linkAttributes = [NSMutableDictionary dictionaryWithDictionary:self.currentAttributes];
    [linkAttributes setObject:(id)[UIColor vLinkColor].CGColor
                       forKey:(NSString*)kCTForegroundColorAttributeName];
    [linkAttributes setObject:(id)[NSNumber numberWithInt:(int)kCTUnderlineStyleSingle]
                       forKey:(NSString*)kCTUnderlineStyleAttributeName];

    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedString];
    NSError *error = nil;
    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink
                                                                   error:&error];
    [linkDetector enumerateMatchesInString:[mutableAttributedString string]
                                   options:0
                                     range:range
                                usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {

                                    if ([result resultType] == NSTextCheckingTypeLink) {
                                        [mutableAttributedString addAttributes:linkAttributes range:[result range]];
                                    }

                                }];

    if (![self.attributedString isEqualToAttributedString:mutableAttributedString]) {
        self.attributedString = mutableAttributedString;
    }
}

- (void)scanAttachments
{
    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedString];
    NSRange stringRange = NSMakeRange(0, self.attributedString.length);
    [self.attributedString enumerateAttribute: vTextAttachmentAttributeName
                                      inRange: stringRange
                                      options: 0
                                   usingBlock: ^(id value, NSRange range, BOOL *stop) {
                                       if (value != nil) {
                                           CTRunDelegateCallbacks callbacks = {
                                               .version = kCTRunDelegateVersion1,
                                               .dealloc = AttachmentRunDelegateDealloc,
                                               .getAscent = AttachmentRunDelegateGetAscent,
                                               .getDescent = AttachmentRunDelegateGetDescent,
                                               .getWidth = AttachmentRunDelegateGetWidth
                                           };

                                           // the retain here is balanced by the release in the Dealloc function
                                           CTRunDelegateRef runDelegate = CTRunDelegateCreate(&callbacks, (__bridge void *)(value));
                                           [mutableAttributedString addAttribute: (NSString *)kCTRunDelegateAttributeName
                                                                           value: (id)CFBridgingRelease(runDelegate)
                                                                           range:range];
                                           CFRelease(runDelegate);
                                       }
                                   }];

    if (![self.attributedString isEqualToAttributedString:mutableAttributedString]) {
        self.attributedString = mutableAttributedString;
    }
}


#pragma mark - UITextInput
#pragma mark - Position & Range & Direction & Rect

- (UITextRange*)textRangeFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition {
    VTextPostion *from = (VTextPostion *)fromPosition;
    VTextPostion *to = (VTextPostion *)toPosition;
    NSRange range = NSMakeRange(MIN(from.index, to.index), ABS(to.index - from.index));
    return [VTextRange instanceWithRange:range];
}

- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction {
    VTextPostion *vPosition = (VTextPostion *)position;
    NSRange range = NSMakeRange(vPosition.index, 1);

    switch (direction) {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionLeft:
            range = NSMakeRange(vPosition.index - 1, 1);
            break;
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:
            range = NSMakeRange(vPosition.index, 1);
            break;
    }

    return [VTextRange instanceWithRange:range];
}

- (UITextRange*)characterRangeAtPoint:(CGPoint)point {
    VTextRange *range = [VTextRange instanceWithRange:[self vCharacterRangeAtPoint:point]];
    return range;
}

- (UITextPosition*)beginningOfDocument {
    return [VTextPostion instanceWithIndex:0];
}

- (UITextPosition*)endOfDocument {
    return [VTextPostion instanceWithIndex:self.attributedString.length];
}

- (UITextPosition*)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset {
    VTextPostion *vPosition = (VTextPostion *)position;
    NSInteger end = vPosition.index + offset;
    if (end > self.attributedString.length || end < 0) {
        return nil;
    }else {
        return [VTextPostion instanceWithIndex:end];
    }
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point {
    VTextPostion *position = [VTextPostion instanceWithIndex:[self closestIndexToPoint:point]];
    return position;
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range {
    VTextPostion *position = [VTextPostion instanceWithIndex:[self closestIndexToPoint:point]];
    return position;
}


- (UITextPosition*)positionFromPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset {
    VTextPostion *vPosition = (VTextPostion *)position;
    NSInteger vIndex = vPosition.index;
    switch (direction) {
        case UITextLayoutDirectionRight: {
            vIndex += offset;
            break;
        }

        case UITextLayoutDirectionLeft: {
            vIndex -= offset;
            break;
        }

        UITextLayoutDirectionUp:
        UITextLayoutDirectionDown:
        default:
            break;
    }

    vIndex = vIndex < 0 ? 0: vIndex;
    vIndex = vIndex > self.attributedString.length ? self.attributedString.length : vIndex;

    return [VTextPostion instanceWithIndex:vIndex];
}

- (UITextPosition *)positionWithinRange:(UITextRange *)range farthestInDirection:(UITextLayoutDirection)direction {
    VTextRange *vRange = (VTextRange *)range;
    NSInteger location = vRange.range.location;
    switch (direction) {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionLeft:
            location = vRange.range.location;
            break;
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:
            location = vRange.range.location + vRange.range.length;
            break;
    }
    return [VTextPostion instanceWithIndex:location];
}

- (NSComparisonResult)comparePosition:(UITextPosition *)position toPosition:(UITextPosition *)other {
    VTextPostion *vPosition = (VTextPostion *)position;
    VTextPostion *vOther = (VTextPostion *)other;
    if (vPosition.index == vOther.index) {
        return NSOrderedSame;
    }else if (vPosition.index < vOther.index) {
        return NSOrderedAscending;
    } else {
        return NSOrderedDescending;
    }
}

- (NSInteger)offsetFromPosition:(UITextPosition *)from toPosition:(UITextPosition *)toPosition {
    VTextPostion *vFrom = (VTextPostion *)from;
    VTextPostion *vTo = (VTextPostion *)toPosition;
    return (vTo.index - vFrom.index);
}

- (UITextWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction {
    return UITextWritingDirectionLeftToRight;
}

- (void)setBaseWritingDirection:(UITextWritingDirection)writingDirection forRange:(UITextRange *)range {
    //
}

- (CGRect)firstRectForRange:(UITextRange *)range {
    VTextRange *vRange = (VTextRange *)range;
    return [self vFirstRectForRange:vRange.range];
}

- (CGRect)caretRectForPosition:(UITextPosition *)position {
    VTextPostion *vPosition = (VTextPostion *)position;
    return [self caretRectForIndex:vPosition.index];
}

#pragma mark - UITextInput
#pragma mark - Marked & Selected

- (UITextRange *)selectedTextRange {
    return [VTextRange instanceWithRange:self.selectedRange];
}

- (UITextRange *)markedTextRange {
    return [VTextRange instanceWithRange:self.markedRange];
}

- (void)setSelectedTextRange:(UITextRange *)range {
    VTextRange *vRange = (VTextRange *)range;
    self.selectedRange = vRange.range;
}

- (NSArray *)selectionRectsForRange:(UITextRange *)range
{
    NSMutableArray *pathRects = [[NSMutableArray alloc] init];
    NSArray *lines = (NSArray*)CTFrameGetLines(self.frameRef);
    CGPoint *origins = (CGPoint*)malloc([lines count] * sizeof(CGPoint));
    CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, [lines count]), origins);
    NSInteger count = [lines count];

    for (int i = 0; i < count; i++) {
        CTLineRef line = (__bridge CTLineRef) [lines objectAtIndex:i];
        CFRange lineRange = CTLineGetStringRange(line);
        NSRange range1 = NSMakeRange(lineRange.location==kCFNotFound ? NSNotFound : lineRange.location, lineRange.length);
        NSRange intersection = [self rangeIntersection:range1 withSecond:((VTextRange*)range).range];
        if (intersection.location != NSNotFound && intersection.length > 0) {
            CGFloat xStart = CTLineGetOffsetForStringIndex(line, intersection.location, NULL);
            CGFloat xEnd = CTLineGetOffsetForStringIndex(line, intersection.location + intersection.length, NULL);
            CGPoint origin = origins[i];
            CGFloat ascent, descent;
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            CGRect selectionRect = CGRectMake(origin.x + xStart, origin.y - descent, xEnd - xStart, ascent + descent);
            if (((VTextRange*)range).range.length==1) {
                selectionRect.size.width = self.contentView.bounds.size.width;
            }
            [pathRects addObject:[NSValue valueWithCGRect:selectionRect]];

        }
    }
    free(origins);
    return pathRects;
}

- (void)setMarkedText:(NSString *)markedText
        selectedRange:(NSRange)selectedRange {

    NSRange selectedNSRange = self.selectedRange;
    NSRange markedTextRange = self.markedRange;
    if (markedTextRange.location != NSNotFound) {
        if (!markedText.length > 0) {
             markedText = @"";
        }
        [self.mutableAttributeString replaceCharactersInRange:markedTextRange withString:markedText];
        markedTextRange.length = markedText.length;
    } else if (selectedNSRange.length > 0) {
        [self.mutableAttributeString replaceCharactersInRange:selectedNSRange withString:markedText];
        markedTextRange.location = selectedNSRange.location;
        markedTextRange.length = markedText.length;
    } else {
        NSAttributedString *string = [[NSAttributedString alloc] initWithString:markedText
                                                                     attributes:self.currentAttributes];
        [self.mutableAttributeString insertAttributedString:string
                                                    atIndex:selectedNSRange.location];
        markedTextRange.location = selectedNSRange.location;
        markedTextRange.length = markedText.length;
    }
    selectedNSRange = NSMakeRange(selectedRange.location + markedTextRange.location, selectedRange.length);
    self.attributedString = self.mutableAttributeString;
    self.markedRange = markedTextRange;
    self.selectedRange = selectedNSRange;
}

- (void)unmarkText {
    NSRange markedTextRange = self.markedRange;
    if (markedTextRange.location == NSNotFound) {
        return;
    }
    markedTextRange.location = NSNotFound;
    self.markedRange = markedTextRange;
}

#pragma mark - UITextInput
#pragma mark - Replace & Return

- (void)replaceRange:(UITextRange *)range withText:(NSString *)text {
    VTextRange *vRange = (VTextRange*)range;
    NSRange selRange = self.selectedRange;
    if (vRange.range.location+vRange.range.length <= selRange.location) {
        selRange.location -= (vRange.range.length - text.length);
    }else {
        selRange = [self rangeIntersection:vRange.range withSecond:self.selectedRange];
    }
    [self.mutableAttributeString replaceCharactersInRange:vRange.range withString:text];
    self.attributedString = self.mutableAttributeString;
    self.selectedRange = selRange;
}

- (NSString*)textInRange:(UITextRange *)range {
    VTextRange *vRange = (VTextRange*)range;
    return [self.attributedString.string substringWithRange:vRange.range];
}

- (NSDictionary*)textStylingAtPosition:(UITextPosition *)position
                           inDirection:(UITextStorageDirection)direction {

    VTextPostion *vPosition = (VTextPostion*)position;
    NSInteger index = MAX(vPosition.index, 0);
    index = MIN(index, self.attributedString.length-1);

    NSDictionary *attribs = [self.attributedString attributesAtIndex:index effectiveRange:nil];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:1];

    CTFontRef ctFont = (__bridge CTFontRef)[attribs valueForKey:(NSString*)kCTFontAttributeName];
    UIFont *font = [UIFont fontWithName:(NSString*)CFBridgingRelease(CTFontCopyFamilyName(ctFont)) size:CTFontGetSize(ctFont)];

    double version = [[UIDevice currentDevice].systemVersion doubleValue];
    if(version>=8.0f){
        [dictionary setObject:font forKey:NSFontAttributeName];
    }else {
        [dictionary setObject:font forKey:UITextInputTextFontKey];
    }

    return dictionary;

}

- (UIView *)textInputView {
    return self.contentView;
}

- (BOOL)hasText {
    return self.attributedString.length != 0;
}


- (void)insertText:(NSString *)text {
    NSRange selectedNSRange = self.selectedRange;
    NSRange markedTextRange = self.markedRange;

    [self.mutableAttributeString setAttributedString:self.attributedString];
    NSAttributedString *newString = nil;
    if (text.length < 3) {
        newString = [[NSAttributedString alloc] initWithString:text
                                                    attributes:self.currentAttributes];
    }else {
        newString = [self converStringToAttributedString:text];
    }

    if (self.correctionRange.location != NSNotFound && self.correctionRange.length > 0){
        [self.mutableAttributeString replaceCharactersInRange:self.correctionRange
                                      withAttributedString:newString];
        selectedNSRange.length = 0;
        selectedNSRange.location = (self.correctionRange.location+text.length);
        self.correctionRange = NSMakeRange(NSNotFound, 0);

    } else if (markedTextRange.location != NSNotFound) {

        [self.mutableAttributeString replaceCharactersInRange:markedTextRange
                                      withAttributedString:newString];
        selectedNSRange.location = markedTextRange.location + newString.length;
        selectedNSRange.length = 0;
        markedTextRange = NSMakeRange(NSNotFound, 0);

    } else if (selectedNSRange.length > 0) {

        [self.mutableAttributeString replaceCharactersInRange:selectedNSRange
                                      withAttributedString:newString];
        selectedNSRange.length = 0;
        selectedNSRange.location = (selectedNSRange.location + newString.length);

    } else {

        [self.mutableAttributeString insertAttributedString:newString
                                                 atIndex:selectedNSRange.location];
        selectedNSRange.location += newString.length;
    }

    self.attributedString = self.mutableAttributeString;
    self.markedRange = markedTextRange;
    self.selectedRange = selectedNSRange;

    if ([text isEqualToString:@" "] || [text isEqualToString:@"\n"]) {
        [self checkSpellingForRange:[self characterRangeAtIndex:self.selectedRange.location-1]];
        if (self.dataDetectorTypes & UIDataDetectorTypeLink)
            [self checkLinksForRange:NSMakeRange(0, self.attributedString.length)];
    }
}

- (void)deleteBackward  {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(showCorrectionMenuWithoutSelection)
                                               object:nil];
    NSRange selectedNSRange = self.selectedRange;
    NSRange markedTextRange = self.markedRange;

    [self.mutableAttributeString setAttributedString:self.attributedString];

    if (self.correctionRange.location != NSNotFound && _correctionRange.length > 0) {
        [self.mutableAttributeString beginEditing];
        [self.mutableAttributeString deleteCharactersInRange:self.correctionRange];
        [self.mutableAttributeString endEditing];
        self.correctionRange = NSMakeRange(NSNotFound, 0);
        selectedNSRange.length = 0;
    } else if (markedTextRange.location != NSNotFound) {

        [self.mutableAttributeString beginEditing];
        [self.mutableAttributeString deleteCharactersInRange:selectedNSRange];
        [self.mutableAttributeString endEditing];
        selectedNSRange.location = markedTextRange.location;
        selectedNSRange.length = 0;
        markedTextRange = NSMakeRange(NSNotFound, 0);

    } else if (selectedNSRange.length > 0) {

        [self.mutableAttributeString beginEditing];
        [self.mutableAttributeString deleteCharactersInRange:selectedNSRange];
        [self.mutableAttributeString endEditing];
        selectedNSRange.length = 0;

    } else if (selectedNSRange.location > 0) {

        NSInteger index = MAX(0, selectedNSRange.location-1);
        index = MIN(_attributedString.length-1, index);
        if ([_attributedString.string characterAtIndex:index] == ' ') {
            [self performSelector:@selector(showCorrectionMenuWithoutSelection)
                       withObject:nil
                       afterDelay:0.2f];
        }

        selectedNSRange.location--;
        selectedNSRange.length = 1;
        [self.mutableAttributeString beginEditing];
        [self.mutableAttributeString deleteCharactersInRange:selectedNSRange];
        [self.mutableAttributeString endEditing];
        selectedNSRange.length = 0;

    }

    self.attributedString = self.mutableAttributeString;
    self.markedRange = markedTextRange;
    self.selectedRange = selectedNSRange;
}


#pragma mark - Delegate
#pragma mark ContentViewDelegate

- (void)didLayoutSubviews {
    [self textChanged];
}

- (void)didDrawRect:(CGRect)rect {
    [self drawContentInRect:rect];
}



@end
