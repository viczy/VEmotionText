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
- (BOOL)hasText;
- (void)textChanged;

- (CGFloat)boundingHeightForWidth:(CGFloat)width;
- (CGRect)caretRectForIndex:(NSInteger)index;
- (CGRect)vFirstRectForRange:(NSRange)range;
- (NSInteger)closestIndexToPoint:(CGPoint)point;
- (NSRange)vCharacterRangeAtPoint:(CGPoint)point;
- (void)checkSpellingForRange:(NSRange)range;
- (void)removeCorrectionAttributesForRange:(NSRange)range;
- (void)insertCorrectionAttributesForRange:(NSRange)range;
- (void)showCorrectionMenuForRange:(NSRange)range;
- (void)scanAttachments;
- (void)showMenu;
- (CGRect)menuPresentationRect;

//NSAttributedstring <-> NSString
- (NSAttributedString*)converStringToAttributedString:(NSString*)string;
- (NSString*)converAttributedStringToString:(NSAttributedString*)attributedString;


//Layout
- (void)drawContentInRect:(CGRect)rect;
- (void)drawBoundingRangeAsSelection:(NSRange)selectionRange cornerRadius:(CGFloat)cornerRadius;
- (void)drawPathFromRects:(NSArray*)array cornerRadius:(CGFloat)cornerRadius;

//Layout get range
- (NSRange)rangeIntersection:(NSRange)first withSecond:(NSRange)second;

//Layout selection


//Data Detectors
- (void)checkLinksForRange:(NSRange)range;



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
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:text
                                                                 attributes:self.currentAttributes];
    self.attributedString = attributedString;
    [self.inputDelegate textDidChange:self];
}

- (void)setEmotionText:(NSString *)emotionText {
    _emotionText = emotionText;
    NSAttributedString *attributedString = [self converStringToAttributedString:emotionText];
    self.attributedString = attributedString;
}

- (void)setAttributedString:(NSAttributedString *)attributedString {
    _attributedString = attributedString;
    NSRange stringRange = NSMakeRange(0, attributedString.length);
    if (!_editing && !_editable) {
        [self checkLinksForRange:stringRange];
        [self scanAttachments];
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
    UIColor *fillColor = [UIColor colorWithRed:.8f green:.8f blue:.8f alpha:1.f];
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
    _editable = YES;
    _font = [UIFont systemFontOfSize:17];
    _autocorrectionType = UITextAutocorrectionTypeNo;
    _dataDetectorTypes = UIDataDetectorTypeLink;
    self.alwaysBounceVertical = YES;
    self.backgroundColor = [UIColor whiteColor];
    self.clipsToBounds = YES;
    [self addSubview:self.contentView];
    self.text = @"";
}

- (BOOL)hasText {
    return self.attributedString.length != 0;
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
#pragma mark NSString-NSAttributedString


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
    [linkAttributes setObject:(id)[UIColor blueColor].CGColor
                       forKey:(NSString*)kCTForegroundColorAttributeName];
    [linkAttributes setObject:(id)[NSNumber numberWithInt:(int)kCTUnderlineStyleSingle]
                       forKey:(NSString*)kCTUnderlineStyleAttributeName];

    NSMutableAttributedString *string = [_attributedString mutableCopy];
    NSError *error = nil;
    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink
                                                                   error:&error];
    [linkDetector enumerateMatchesInString:[string string]
                                   options:0
                                     range:range
                                usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {

                                    if ([result resultType] == NSTextCheckingTypeLink) {
                                        [string addAttributes:linkAttributes range:[result range]];
                                    }

                                }];

    if (![self.attributedString isEqualToAttributedString:string]) {
        self.attributedString = string;
    }
}

- (void)scanAttachments
{
    __block NSMutableAttributedString *mutableAttributedString;
    NSRange stringRange = NSMakeRange(0, self.attributedString.length);
    [self.attributedString enumerateAttribute: vTextAttachmentAttributeName
                                  inRange: stringRange
                                  options: 0
                               usingBlock: ^(id value, NSRange range, BOOL *stop) {
                                   if (value != nil) {
                                       if (mutableAttributedString == nil)
                                           mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedString];
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

    self.attributedString = mutableAttributedString;
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
