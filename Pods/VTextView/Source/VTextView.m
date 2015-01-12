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
#import "VSelectionView.h"
#import "VTextWindow.h"

static NSString *const vLeftDelimiter = @"\\[";
static NSString *const vRightDelimiter = @"\\]";
static NSString *const vAtDelimiter = @"@";
static NSString *const vTopicDelimiter = @"#";
static NSString *const vTextAttachmentAttributeName = @"com.everycode.vTextAttachmentAttribute";
static NSString *const vTextAttachmentPlaceholderString = @"\ufffc";
static NSString *const vTextAttachmentOriginStringKey = @"com.everycode.vTextAttachmentOriginString";

static void AttachmentRunDelegateDealloc(void *refCon) {
//    CFBridgingRelease(refCon);
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
    return AttachmentRunDelegateGetSize(refCon).height-3.f;
}

static CGFloat AttachmentRunDelegateGetDescent(void *refCon) {
    return 3.f;
}

static CGFloat AttachmentRunDelegateGetWidth(void *refCon) {
    return AttachmentRunDelegateGetSize(refCon).width;
}

@interface VTextView () <
    ContentViewDelegate,
    UIGestureRecognizerDelegate>

@property (nonatomic, assign) BOOL editing;
@property (nonatomic, assign) BOOL ignoreSelectionMenu;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPress;
@property (nonatomic, strong) NSDictionary *defaultAttributes;
@property (nonatomic, strong) NSMutableDictionary *currentAttributes;
@property (nonatomic, strong) NSDictionary *correctionAttributes;
@property (nonatomic, strong) NSMutableDictionary *menuItemActions;
@property (nonatomic, assign) NSRange correctionRange;
@property (nonatomic, assign) NSRange linkRange;

@property (nonatomic, strong) NSMutableAttributedString *mutableAttributeString;

@property (nonatomic, assign) CTFramesetterRef framesetterRef;
@property (nonatomic, assign) CTFrameRef frameRef;
@property (nonatomic, strong) UITextInputStringTokenizer *tokenizer;
@property (nonatomic, strong) UITextChecker *textChecker;

@property (nonatomic, strong) VContentView *contentView;
@property (nonatomic, strong) VCaretView *caretView; //no getter
@property (nonatomic, strong) VSelectionView *selectionView; //no getter
@property (nonatomic, strong) VTextWindow *textWindow;

- (void)common;
- (void)textChanged;
- (void)clearFrameRef;

//Layout
- (void)drawContentInRect:(CGRect)rect;
- (void)drawBoundingRangeAsSelection:(NSRange)selectionRange cornerRadius:(CGFloat)cornerRadius;
- (void)drawPathFromRects:(NSArray*)array cornerRadius:(CGFloat)cornerRadius;

//Get Height
- (CGFloat)boundingHeightForWidth:(CGFloat)width;

//Get Index
- (NSInteger)closestIndexToPoint:(CGPoint)point;

//Get Range
- (NSRange)rangeIntersection:(NSRange)first withSecond:(NSRange)second;
- (NSRange)vCharacterRangeAtPoint:(CGPoint)point;
- (NSRange)characterRangeAtIndex:(NSInteger)index;

//Get Rect
- (CGRect)caretRectForIndex:(NSInteger)index;
- (CGRect)vFirstRectForRange:(NSRange)range;
- (CGRect)menuPresentationRect;

//Selection
- (void)selectionChanged;
- (void)setLinkRangeFromTextCheckerResults:(NSTextCheckingResult*)results;

//Data Detectors
- (void)scanAttachments;
- (NSAttributedString*)checkAtWithAttributedString:(NSAttributedString*)attributedStr;
- (NSAttributedString*)checkTopicWithAttributedStrig:(NSAttributedString*)attributedStr;
- (NSAttributedString*)checkLinkWithAttributedStrig:(NSAttributedString*)attributedStr;
- (void)checkLinksForRange:(NSRange)range;
- (NSTextCheckingResult*)linkAtIndex:(NSInteger)index;
- (BOOL)selectedLinkAtIndex:(NSInteger)index;


//NSAttributedstring <-> NSString
- (NSAttributedString*)converStringToAttributedString:(NSString*)string;
- (NSString*)converAttributedStringToString:(NSAttributedString*)attributedString;

//Input spell checking
- (void)checkSpellingForRange:(NSRange)range;
- (void)removeCorrectionAttributesForRange:(NSRange)range;
- (void)insertCorrectionAttributesForRange:(NSRange)range;

//Menu
- (void)showCorrectionMenuForRange:(NSRange)range;
- (void)showMenu;
- (void)spellingCorrection:(UIMenuController*)sender;
- (void)spellCheckMenuEmpty:(id)sender;


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

- (UILongPressGestureRecognizer*)longPress {
    if (!_longPress) {
        _longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
        _longPress.delegate = self;
    }
    return _longPress;
}

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
        fontRef = NULL;
        colorRef = NULL;
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
        colorRef = NULL;
    }
    return _correctionAttributes;
}

- (NSMutableDictionary*)menuItemActions {
    if (!_menuItemActions) {
        _menuItemActions = [[NSMutableDictionary alloc] init];
    }
    return _menuItemActions;
}

- (VContentView*)contentView {
    if (!_contentView) {
        _contentView = [[VContentView alloc] initWithFrame:self.bounds];
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _contentView.delegate = self;
    }
    return _contentView;
}

- (VTextWindow*)textWindow {
    if (!_textWindow) {
        VTextWindow *window;
        for (VTextWindow *aWindow in [[UIApplication sharedApplication] windows]){
            if ([aWindow isKindOfClass:[VTextWindow class]]) {
                window = aWindow;
                window.frame = [[UIScreen mainScreen] bounds];
                break;
            }
        }
        if (!window) {
            window = [[VTextWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        }
        window.windowLevel = UIWindowLevelStatusBar;
        window.hidden = NO;
        _textWindow=window;

    }
    return _textWindow;
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

#pragma mark - #Getter

#pragma mark - Setter
#pragma mark - Text Style

- (void)setFont:(UIFont *)font {
    _font = font;
    CTFontRef fontRef = CTFontCreateWithName((CFStringRef)font.fontName, font.pointSize, NULL);
    [self.currentAttributes setObject:(__bridge id)fontRef
                               forKey:(id)kCTFontAttributeName];
    CFRelease(fontRef);
    fontRef = NULL;

    [self textChanged];
}

- (void)setText:(NSString *)text {
    if ([self.inputDelegate respondsToSelector:@selector(textWillChange:)]) {
        [self.inputDelegate textWillChange:self];
    }
    NSAttributedString *attributedString = [self converStringToAttributedString:text];
    self.attributedString = attributedString;
    if ([self.inputDelegate respondsToSelector:@selector(textDidChange:)]) {
        [self.inputDelegate textDidChange:self];
    }
}

- (void)setAttributedString:(NSAttributedString *)attributedString {
    _attributedString = attributedString;
    if(!_mutableAttributeString) {
        _mutableAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedString];
    }
    [self textChanged];
    if ([self.delegate respondsToSelector:@selector(vTextViewDidChange:)]) {
        [self.delegate vTextViewDidChange:self];
    }
}

- (void)setEditable:(BOOL)editable {
    _editable = editable;
    if (editable) {
        self.inputView = nil;
        if (!self.caretView) {
            self.caretView = [[VCaretView alloc] initWithFrame:CGRectZero];
        }
    }else {
        self.inputView = [[UIView alloc] init];
        [self.caretView removeFromSuperview];
        self.caretView = nil;
    }
    self.tokenizer = nil;
    self.textChecker = nil;
    self.mutableAttributeString = nil;
    self.correctionAttributes = nil;
}

#pragma mark - Range

- (void)setSelectedRange:(NSRange)selectedRange {
    _selectedRange = NSMakeRange(selectedRange.location == NSNotFound ? NSNotFound : MAX(0, selectedRange.location), selectedRange.length);
    [self selectionChanged];
}

- (void)setCorrectionRange:(NSRange)correctionRange {
    if (NSEqualRanges(correctionRange, _correctionRange) && correctionRange.location == NSNotFound && correctionRange.length == 0) {
        _correctionRange = correctionRange;
        return;
    }

    _correctionRange = correctionRange;
    if (correctionRange.location != NSNotFound && correctionRange.length > 0) {
        if (self.caretView.superview) {
            [self.caretView removeFromSuperview];
        }
        [self removeCorrectionAttributesForRange:_correctionRange];
        [self showCorrectionMenuForRange:_correctionRange];
    } else {
        if (!self.caretView.superview) {
            [self.contentView addSubview:self.caretView];
            [self.caretView animatedCaret];
        }
    }
    [self.contentView setNeedsDisplay];
}

- (void)setLinkRange:(NSRange)linkRange {
    _linkRange = linkRange;
    if (_linkRange.length>0) {
        if (self.caretView.superview) {
            [self.caretView removeFromSuperview];
        }
    } else {
        if (!self.caretView.superview) {
            [self.contentView addSubview:self.caretView];
            self.caretView.frame = [self caretRectForIndex:self.selectedRange.location];
            [self.caretView animatedCaret];
        }
    }
    [self.contentView setNeedsDisplay];
}

#pragma mark - #Setter

#pragma mark - View
#pragma mark - Layout

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
    CGPoint origins[lineCount];
    CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, 0), origins);

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
            BOOL respondDraw = [attachment respondsToSelector:@selector(attachmentDrawInRect:withContent:)];
            if (attachment && respondSize && respondDraw) {
                CGPoint position;
                CTRunGetPositions(run, CFRangeMake(0, 1), &position);
                CGFloat ascent, descent, leading;
                CTRunGetTypographicBounds(run, CFRangeMake(0, 1), &ascent, &descent, &leading);
                CGSize size = [attachment attachmentSize];
                CGRect rect = {{origins[i].x+position.x, origins[i].y+position.y-descent}, size};
                CGContextSaveGState(contextRef);
                [attachment attachmentDrawInRect:rect withContent:contextRef];
                CGContextRestoreGState(contextRef);
            }
        }
    }
}

- (void)drawBoundingRangeAsSelection:(NSRange)selectionRange cornerRadius:(CGFloat)cornerRadius {
    if (selectionRange.length == 0 || selectionRange.location == NSNotFound) {
        return;
    }

    NSMutableArray *pathRects = [[NSMutableArray alloc] init];
    CFArrayRef lines = CTFrameGetLines(self.frameRef);
    NSInteger lineCount = CFArrayGetCount(lines);
    CGPoint origins[lineCount];
    CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, 0), origins);
    for (int i = 0; i < lineCount; i++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
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
    path = NULL;
}

#pragma mark - #View

#pragma mark - Actions Private
#pragma mark - Common & TextChanged

- (void)common {
    _editable = YES;
    _editing = NO;
    _font = [UIFont systemFontOfSize:17];
    _autocorrectionType = UITextAutocorrectionTypeNo;
    _dataDetectorTypes = UIDataDetectorTypeLink;
//    self.alwaysBounceVertical = YES;
    self.backgroundColor = [UIColor whiteColor];
    self.clipsToBounds = YES;
    [self addSubview:self.contentView];
    self.text = @"";
    [self addGestures];
}

- (void)addGestures {
    [self addGestureRecognizer:self.longPress];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    [doubleTap setNumberOfTapsRequired:2];
    [self addGestureRecognizer:doubleTap];

    UITapGestureRecognizer *singleTap =  [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self addGestureRecognizer:singleTap];
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
//    [self clearFrameRef];
    [self clearFramesetterRef];
    _framesetterRef = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.attributedString);
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.contentView.bounds];
    
    [self clearFrameRef];
    _frameRef = CTFramesetterCreateFrame(self.framesetterRef,CFRangeMake(0, 0), [path CGPath], NULL);
    
    [self.contentView setNeedsDisplay];
}

- (void)clearFrameRef {
    if (_frameRef) {
        CFRelease(_frameRef);
        _frameRef = NULL;
    }
}

- (void)clearFramesetterRef {
    if (_framesetterRef) {
        CFRelease(_framesetterRef);
        _framesetterRef = NULL;
    }
}

#pragma mark - Height
- (CGFloat)boundingHeightForWidth:(CGFloat)width {
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(self.framesetterRef, CFRangeMake(0, 0), NULL, CGSizeMake(width, CGFLOAT_MAX), NULL);
    return suggestedSize.height;
}

#pragma mark - Index

- (NSInteger)closestIndexToPoint:(CGPoint)point {
    point = [self convertPoint:point toView:self.contentView];
    CFArrayRef lines = CTFrameGetLines(self.frameRef);
    NSInteger count = CFArrayGetCount(lines);
    CGPoint origins[count];
    CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, 0), origins);
    CFIndex index = kCFNotFound;
    for (int i = 0; i < count; i++) {
        if (point.y > origins[i].y) {
            CTLineRef lineRef = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
            CGPoint convertedPoint = CGPointMake(point.x - origins[i].x, point.y - origins[i].y);
            index = CTLineGetStringIndexForPosition(lineRef, convertedPoint);
            break;
        }
    }
    if (index == kCFNotFound) {
        index = [self.attributedString length];
    }

    return index;
}

#pragma mark - Range

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

- (NSRange)vCharacterRangeAtPoint:(CGPoint)point {
    CFArrayRef lines = CTFrameGetLines(self.frameRef);
    NSInteger lineCount = CFArrayGetCount(lines);
    CGPoint origins[lineCount];
    CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, 0), origins);
    __block NSRange returnRange = NSMakeRange(NSNotFound, 0);
    for (int i = 0; i < lineCount; i++) {
        if (point.y > origins[i].y) {
            CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
            CGPoint convertedPoint = CGPointMake(point.x - origins[i].x, point.y - origins[i].y);
            NSInteger index = CTLineGetStringIndexForPosition(line, convertedPoint);
            CFRange cfRange = CTLineGetStringRange(line);
            NSRange range = NSMakeRange(cfRange.location == kCFNotFound ? NSNotFound : cfRange.location, cfRange.length);

            [self.attributedString.string enumerateSubstringsInRange:range options:NSStringEnumerationByWords usingBlock:^(NSString *subString, NSRange subStringRange, NSRange enclosingRange, BOOL *stop){
                if (index - subStringRange.location <= subStringRange.length) {
                    returnRange = subStringRange;
                    *stop = YES;
                }
            }];
            break;
        }
    }
    return  returnRange;
}

- (NSRange)characterRangeAtIndex:(NSInteger)index {
    CFArrayRef lines = CTFrameGetLines(self.frameRef);
    NSInteger count = CFArrayGetCount(lines);
    __block NSRange returnRange = NSMakeRange(NSNotFound, 0);
    for (int i=0; i < count; i++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
        CFRange cfRange = CTLineGetStringRange(line);
        NSRange range = NSMakeRange(cfRange.location == kCFNotFound ? NSNotFound : cfRange.location, cfRange.length == kCFNotFound ? 0 : cfRange.length);
        if (index >= range.location && index <= range.location+range.length) {
            if (range.length > 1) {
                [self.attributedString.string enumerateSubstringsInRange:range options:NSStringEnumerationByWords usingBlock:^(NSString *subString, NSRange subStringRange, NSRange enclosingRange, BOOL *stop){
                    if (index - subStringRange.location <= subStringRange.length) {
                        returnRange = subStringRange;
                        *stop = YES;
                    }
                }];
            }
        }
    }

    return returnRange;
}

#pragma mark - Selection

- (void)selectionChanged {
    if (_editable && !_editing) {
        [self.caretView removeFromSuperview];
    }
    _ignoreSelectionMenu = NO;

    if (self.selectedRange.length == 0) {
        if (self.selectionView) {//so selection no getter
            [self.selectionView removeFromSuperview];
            self.selectionView=nil;
        }

        if (_editable && !self.caretView.superview) {
            if (!self.caretView) {
                self.caretView = [[VCaretView alloc] initWithFrame:CGRectZero];
            }
            [self.contentView addSubview:self.caretView];
            [self.contentView setNeedsDisplay];
        }

        self.caretView.frame = [self caretRectForIndex:self.selectedRange.location];
        [self.caretView animatedCaret];

        CGRect frame = self.caretView.frame;
        frame.origin.y -= (self.font.lineHeight*2);
        [self scrollRectToVisible:[self.contentView convertRect:frame toView:self] animated:YES];
        [self.contentView setNeedsDisplay];

        self.longPress.minimumPressDuration = 0.5f;
    } else {
        self.longPress.minimumPressDuration = 0.0f;

        if (self.caretView.superview) {
            [self.caretView removeFromSuperview];
        }

        if (self.selectionView==nil) {
            self.selectionView = [[VSelectionView alloc] initWithFrame:self.contentView.bounds];
            [self.contentView addSubview:self.selectionView];
        }

        CGRect begin = [self caretRectForIndex:self.selectedRange.location];
        CGRect end = [self caretRectForIndex:self.selectedRange.location+self.selectedRange.length];
        [self.selectionView setBeginCaret:begin andEndCaret:end];
        [self.contentView setNeedsDisplay];
    }

    if (self.markedRange.location != NSNotFound) {
        [self.contentView setNeedsDisplay];
    }
}

- (void)setLinkRangeFromTextCheckerResults:(NSTextCheckingResult*)results {
    if (self.linkRange.length>0) {
        BOOL respondUrl = [self.delegate respondsToSelector:@selector(vTextView:didSelectURL:)];
        if (respondUrl) {
            [self.delegate respondsToSelector:@selector(vTextView:didSelectURL:)];
        }
    }
    self.linkRange = NSMakeRange(NSNotFound, 0);
}

#pragma mark - Rect

- (CGRect)caretRectForIndex:(NSInteger)index {
    CFArrayRef lines = CTFrameGetLines(self.frameRef);
    NSInteger count = CFArrayGetCount(lines);
    // no text / first index
    if (self.attributedString.length == 0 || index == 0) {
        CGPoint origin = CGPointMake(CGRectGetMinX(self.contentView.bounds), CGRectGetMaxY(self.contentView.bounds) - self.font.leading);
        return CGRectMake(origin.x, origin.y, 3, self.font.ascender + fabs(self.font.descender*2));
    }
    // last index is newline
    if (index == self.attributedString.length && [self.attributedString.string characterAtIndex:(index - 1)] == '\n' ) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, count-1);
        CFRange range = CTLineGetStringRange(line);
        CGFloat xPos = CTLineGetOffsetForStringIndex(line, range.location, NULL);
        CGFloat ascent, descent;
        CTLineGetTypographicBounds(line, &ascent, &descent, NULL);

        CGPoint origin;
        CGPoint origins[count];
        CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, 0), origins);
        origin = origins[0];
        origin.y -= self.font.leading;
        return CGRectMake(origin.x + xPos, floorf(origin.y - descent), 3, ceilf((descent*2) + ascent));
    }
    index = MAX(index, 0);
    index = MIN(self.attributedString.string.length, index);

    CGPoint origins[count];
    CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, 0), origins);
    CGRect returnRect = CGRectZero;
    for (int i = 0; i < count; i++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
        CFRange cfRange = CTLineGetStringRange(line);
        NSRange range;
        range = NSMakeRange(range.location == kCFNotFound ? NSNotFound : cfRange.location, cfRange.length);
        if (index >= range.location && index <= range.location+range.length) {
            CGFloat ascent, descent, xPos;
            xPos = CTLineGetOffsetForStringIndex(line, index, NULL);
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            CGPoint origin = origins[i];
            if (self.selectedRange.length>0 && index != self.selectedRange.location && range.length == 1) {
                xPos = self.contentView.bounds.size.width - 3.0f; // selection of entire line
            } else if ([self.attributedString.string characterAtIndex:index-1] == '\n' && range.length == 1) {
                xPos = 0.0f; // empty line
            }

            returnRect = CGRectMake(origin.x + xPos,  floorf(origin.y - descent)-2.f, 3, ceilf((descent*2) + ascent));
        }
    }

    return returnRect;
}

- (CGRect)vFirstRectForRange:(NSRange)range {
    NSInteger index = range.location;

    CFArrayRef lines = CTFrameGetLines(self.frameRef);
    NSInteger count = CFArrayGetCount(lines);
    CGPoint origins[count];
    CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, 0), origins);
    CGRect returnRect = CGRectNull;
    for (int i = 0; i < count; i++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
        CFRange lineRange = CTLineGetStringRange(line);
        NSInteger localIndex = index - lineRange.location;
        if (localIndex >= 0 && localIndex < lineRange.length) {
            NSInteger finalIndex = MIN(lineRange.location + lineRange.length, range.location + range.length);
            CGFloat xStart = CTLineGetOffsetForStringIndex(line, index, NULL);
            CGFloat xEnd = CTLineGetOffsetForStringIndex(line, finalIndex, NULL);
            CGPoint origin = origins[i];
            CGFloat ascent, descent;
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            returnRect = [self.contentView convertRect:CGRectMake(origin.x + xStart, origin.y - descent, xEnd - xStart, ascent + (descent*2)) toView:self];
            break;
        }
    }

    return returnRect;
}

- (CGRect)menuPresentationRect {
    CGRect rect = [self.contentView convertRect:self.caretView.frame toView:self];
    if (self.selectedRange.location != NSNotFound && self.selectedRange.length > 0) {
        if (self.selectionView) {
            rect = [self.contentView convertRect:self.selectionView.frame toView:self];
        } else {
            rect = [self vFirstRectForRange:self.selectedRange];
        }
    } else if (_editing && self.correctionRange.location != NSNotFound && self.correctionRange.length > 0) {
        rect = [self vFirstRectForRange:self.correctionRange];
    }

    return rect;
}

#pragma mark - Spell

- (void)insertCorrectionAttributesForRange:(NSRange)range {
    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedString];
    [mutableAttributedString addAttributes:self.correctionAttributes range:range];
    self.attributedString = mutableAttributedString;
}

- (void)removeCorrectionAttributesForRange:(NSRange)range {
    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedString];
    [mutableAttributedString removeAttribute:(NSString*)kCTUnderlineStyleAttributeName range:range];
    self.attributedString = mutableAttributedString;
}

- (void)checkSpellingForRange:(NSRange)range {
    self.mutableAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedString];
//    [self.mutableAttributeString setAttributedString:self.attributedString];

    NSInteger location = range.location-1;
    NSInteger currentOffset = MAX(0, location);
    NSRange currentRange;
    NSString *string = self.attributedString.string;
    NSRange stringRange = NSMakeRange(0, string.length-1);
    NSArray *guesses;
    BOOL done = NO;

    NSString *language = [[UITextChecker availableLanguages] objectAtIndex:0];
    if (!language) {
        language = @"en_US";
    }

    while (!done) {
        currentRange = [self.textChecker rangeOfMisspelledWordInString:string
                                                                 range:stringRange
                                                            startingAt:currentOffset
                                                                  wrap:NO
                                                              language:language];
        if (currentRange.location == NSNotFound || currentRange.location > range.location) {
            done = YES;
            continue;
        }
        guesses = [self.textChecker guessesForWordRange:currentRange inString:string language:language];
        if (guesses) {
            [self.mutableAttributeString addAttributes:self.correctionAttributes range:currentRange];
        }
        currentOffset = currentOffset + (currentRange.length-1);
    }

    if (![self.attributedString isEqualToAttributedString:self.mutableAttributeString]) {
        self.attributedString = self.mutableAttributeString;
    }
}

#pragma mark - NSString<->NSAttributedString

- (NSAttributedString*)converStringToAttributedString:(NSString *)string {
    NSAttributedString *returnAttributedString;
    //emotion replace
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

                CFRelease(Rundelegate);
                Rundelegate = NULL;
            }
        }
    }];
    //@ check
    returnAttributedString = [self checkAtWithAttributedString:mutableAttributedString];

    //# check
    returnAttributedString = [self checkTopicWithAttributedStrig:returnAttributedString];

    //link check
    returnAttributedString = [self checkLinkWithAttributedStrig:returnAttributedString];

    return returnAttributedString;
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

#pragma mark - Data Detectors

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
                                           runDelegate = NULL;
                                       }
                                   }];

    if (![self.attributedString isEqualToAttributedString:mutableAttributedString]) {
        self.attributedString = mutableAttributedString;
    }
}

- (NSAttributedString*)checkAtWithAttributedString:(NSAttributedString*)attributedStr {
    NSMutableDictionary *linkAttributes = [NSMutableDictionary dictionaryWithDictionary:self.currentAttributes];
    [linkAttributes setObject:(id)[UIColor vLinkColor].CGColor
                       forKey:(NSString*)kCTForegroundColorAttributeName];
    NSError *error;
    NSString *pattern = [NSString stringWithFormat:@"%@(.+?)%@",vAtDelimiter, @":"];
    NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                             options:0
                                                                               error:&error];
    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedStr];
    NSRange stringRange = NSMakeRange(0, attributedStr.length);
    [regular enumerateMatchesInString:[attributedStr string] options:0 range:stringRange usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result.resultType == NSTextCheckingTypeRegularExpression) {
            NSRange subRange = [result rangeAtIndex:1];
            NSRange atRange = NSMakeRange(subRange.location-1, subRange.length+1);
            [mutableAttributedString addAttributes:linkAttributes range:atRange];
        }
    }];
    return mutableAttributedString;
}

- (NSAttributedString*)checkTopicWithAttributedStrig:(NSAttributedString*)attributedStr {
    NSMutableDictionary *linkAttributes = [NSMutableDictionary dictionaryWithDictionary:self.currentAttributes];
    [linkAttributes setObject:(id)[UIColor vLinkColor].CGColor
                       forKey:(NSString*)kCTForegroundColorAttributeName];
    NSError *error;
    NSString *pattern = [NSString stringWithFormat:@"%@(.+?)%@",vTopicDelimiter, vTopicDelimiter];
    NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                             options:0
                                                                               error:&error];
    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedStr];
    NSRange stringRange = NSMakeRange(0, attributedStr.length);
    [regular enumerateMatchesInString:[attributedStr string] options:0 range:stringRange usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result.resultType == NSTextCheckingTypeRegularExpression) {
            NSRange subRange = [result rangeAtIndex:1];
            NSRange topicRange = NSMakeRange(subRange.location-1, subRange.length+2);
            [mutableAttributedString addAttributes:linkAttributes range:topicRange];
        }
    }];
    return mutableAttributedString;
}

- (NSAttributedString*)checkLinkWithAttributedStrig:(NSAttributedString*)attributedStr {
    NSMutableDictionary *linkAttributes = [NSMutableDictionary dictionaryWithDictionary:self.currentAttributes];
    [linkAttributes setObject:(id)[UIColor vLinkColor].CGColor
                       forKey:(NSString*)kCTForegroundColorAttributeName];

    NSError *error;
    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink
                                                                   error:&error];

    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedStr];
    NSRange stringRange = NSMakeRange(0, attributedStr.length);
    [linkDetector enumerateMatchesInString:[attributedStr string]
                                   options:0
                                     range:stringRange
                                usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                    if ([result resultType] == NSTextCheckingTypeLink) {
                                        [mutableAttributedString addAttributes:linkAttributes range:[result range]];
                                    }
                                }];

    return mutableAttributedString;
}

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

}

- (NSTextCheckingResult*)linkAtIndex:(NSInteger)index {
    NSRange range = [self characterRangeAtIndex:index];
    if (range.location==NSNotFound || range.length == 0) {
        return nil;
    }

    __block NSTextCheckingResult *link = nil;
    NSError *error = nil;
    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
    [linkDetector enumerateMatchesInString:[self.attributedString string] options:0 range:range usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if ([result resultType] == NSTextCheckingTypeLink) {
            *stop = YES;
            link = link;
        }
    }];

    return link;
}

- (BOOL)selectedLinkAtIndex:(NSInteger)index {
    NSTextCheckingResult *link = [self linkAtIndex:index];
    if (link) {
        [self setLinkRange:[link range]];
        return YES;
    }else {
        return NO;
    }
}

#pragma mark - Menu

- (void)showCorrectionMenuForRange:(NSRange)range {
    if (range.location==NSNotFound || range.length==0) {
        return;
    }

    range.location = MAX(0, range.location);
    range.length = MIN(self.attributedString.string.length, range.length);
    [self removeCorrectionAttributesForRange:range];

    UIMenuController *menuController = [UIMenuController sharedMenuController];
    if ([menuController isMenuVisible]) {
        return;
    }
    _ignoreSelectionMenu = YES;

    NSString *language = [[UITextChecker availableLanguages] objectAtIndex:0];
    if (!language) {
        language = @"en_US";
    }

    NSArray *guesses = [self.textChecker guessesForWordRange:range inString:self.attributedString.string language:language];
    [menuController setTargetRect:[self menuPresentationRect] inView:self];
    if (guesses!=nil && [guesses count]>0) {
        NSMutableArray *items = [[NSMutableArray alloc] init];
        if (self.menuItemActions==nil) {
            self.menuItemActions = [NSMutableDictionary dictionary];
        }
        for (NSString *word in guesses){
            NSString *selString = [NSString stringWithFormat:@"spellCheckMenu_%lu:", (unsigned long)[word hash]];
            SEL sel = sel_registerName([selString UTF8String]);

            [self.menuItemActions setObject:word forKey:NSStringFromSelector(sel)];
            class_addMethod([self class], sel, [[self class] instanceMethodForSelector:@selector(spellingCorrection:)], "v@:@");

            UIMenuItem *item = [[UIMenuItem alloc] initWithTitle:word action:sel];
            [items addObject:item];
            if ([items count]>=4) {
                break;
            }
        }
        [menuController setMenuItems:items];
    } else {
        UIMenuItem *item = [[UIMenuItem alloc] initWithTitle:@"No Replacements Found" action:@selector(spellCheckMenuEmpty:)];
        [menuController setMenuItems:[NSArray arrayWithObject:item]];
    }

    [menuController setMenuVisible:YES animated:YES];
}

- (void)showMenu {
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    if ([menuController isMenuVisible]) {
        [menuController setMenuVisible:NO animated:NO];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [menuController setMenuItems:nil];
        [menuController setTargetRect:[self menuPresentationRect] inView:self];
        [menuController update];
        [menuController setMenuVisible:YES animated:YES];
    });
}

- (void)spellingCorrection:(UIMenuController*)sender {
    NSRange replacementRange = self.correctionRange;
    if (replacementRange.location==NSNotFound || replacementRange.length==0) {
        replacementRange = [self characterRangeAtIndex:self.selectedRange.location];
    }
    if (replacementRange.location!=NSNotFound && replacementRange.length!=0) {
        NSString *text = [self.menuItemActions objectForKey:NSStringFromSelector(_cmd)];
        if ([self.inputDelegate respondsToSelector:@selector(textWillChange:)]) {
            [self.inputDelegate textWillChange:self];
        }
        [self replaceRange:[VTextRange instanceWithRange:replacementRange] withText:text];
        if ([self.inputDelegate respondsToSelector:@selector(textDidChange:)]) {
            [self.inputDelegate textDidChange:self];
        }
        replacementRange.length = text.length;
        [self removeCorrectionAttributesForRange:replacementRange];
    }

    self.correctionRange = NSMakeRange(NSNotFound, 0);
    self.menuItemActions = nil;
    [sender setMenuItems:nil];
}

- (void)spellCheckMenuEmpty:(id)sender {
    self.correctionRange = NSMakeRange(NSNotFound, 0);
}

- (void)showCorrectionMenuWithoutSelection {

    if (_editing) {
        NSRange range = [self characterRangeAtIndex:self.selectedRange.location];
        [self showCorrectionMenuForRange:range];
    } else {
        [self showMenu];
    }
}

- (void)showCorrectionMenu {
    if (_editing) {
        NSRange range = [self characterRangeAtIndex:self.selectedRange.location];
        if (range.location!=NSNotFound && range.length>1) {
            NSString *language = [[UITextChecker availableLanguages] objectAtIndex:0];
            if (!language)
                language = @"en_US";
            self.correctionRange = [_textChecker rangeOfMisspelledWordInString:_attributedString.string range:range startingAt:0 wrap:YES language:language];
        }
    }
}

- (void)menuDidHide:(NSNotification*)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIMenuControllerDidHideMenuNotification object:nil];
    if (self.selectionView) {
        [self showMenu];
    }
}

#pragma mark - Gesture

- (void)longPress:(UILongPressGestureRecognizer*)gesture {
    if (![self isFirstResponder]) {
        [self becomeFirstResponder];
    }

    if (gesture.state==UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {

//        if (self.linkRange.length>0 && gesture.state == UIGestureRecognizerStateBegan) {
//            NSTextCheckingResult *link = [self linkAtIndex:self.linkRange.location];
//            [self setLinkRangeFromTextCheckerResults:link];
//            gesture.enabled=NO;
//            gesture.enabled=YES;
//        }

        UIMenuController *menuController = [UIMenuController sharedMenuController];
        if ([menuController isMenuVisible]) {
            [menuController setMenuVisible:NO animated:NO];
        }

        CGPoint point = [gesture locationInView:self];
        BOOL hasSelection = (self.selectionView!=nil);

        if (!hasSelection && self.caretView) {
            [self.caretView stopAnimation];
        }

        [self.textWindow updateWindowTransform];
        self.textWindow.type =  hasSelection ? VWindowMagnify : VWindowLoupe;

        point.y -= 20.0f;
        NSInteger index = [self closestIndexToPoint:point];

        if (hasSelection) {
            if (gesture.state == UIGestureRecognizerStateBegan) {
                self.textWindow.selectionType = (index > (self.selectedRange.location+(self.selectedRange.length/2))) ? VSelectionTypeRight : VSelectionTypeLeft;
            }
            CGRect rect = CGRectZero;
            if (self.textWindow.selectionType==VSelectionTypeLeft) {
                NSInteger begin = MAX(0, index);
                begin = MIN(self.selectedRange.location+self.selectedRange.length-1, begin);

                NSInteger end = self.selectedRange.location + self.selectedRange.length;
                end = MIN(self.attributedString.string.length, end-begin);

                self.selectedRange = NSMakeRange(begin, end);
                index = self.selectedRange.location;
            } else {
                NSInteger length = MIN(index-self.selectedRange.location, self.attributedString.string.length-self.selectedRange.location);
                length = MAX(1, length);
                self.selectedRange = NSMakeRange(self.selectedRange.location, length);
                index = (self.selectedRange.location+_selectedRange.length);
            }
            rect = [self caretRectForIndex:index];

            if (gesture.state == UIGestureRecognizerStateBegan) {
                [self.textWindow showFromView:self.contentView withRect:[self.contentView convertRect:rect toView:self.textWindow]];
            } else {
                [self.textWindow renderContentView:self.contentView fromRect:[self.contentView convertRect:rect toView:self.textWindow]];
            }
        } else {
            NSInteger index = [self closestIndexToPoint:[gesture locationInView:self]];
            NSRange range;
            if (_editable) {
                range = NSMakeRange(index, 0);
            }else {
                range = [self characterRangeAtIndex:index];
            }
            if ([self.inputDelegate respondsToSelector:@selector(selectionWillChange:)]) {
                [self.inputDelegate selectionWillChange:self];
            }
            self.selectedRange = range;
            if ([self.inputDelegate respondsToSelector:@selector(selectionDidChange:)]) {
                [self.inputDelegate selectionDidChange:self];
            }

            CGPoint location = [gesture locationInView:self.textWindow];
            CGRect rect = CGRectMake(location.x, location.y, self.caretView.bounds.size.width, self.caretView.bounds.size.height);

            if (gesture.state == UIGestureRecognizerStateBegan) {
                [self.textWindow showFromView:self.contentView withRect:rect];
            } else {
                [self.textWindow renderContentView:self.contentView fromRect:rect];
            }
        }
    } else {
        if (self.caretView) {
            [self.caretView animatedCaret];
        }

        if (self.textWindow) {
            [self.textWindow hide];
            self.textWindow = nil;
        }

        if (gesture.state == UIGestureRecognizerStateEnded) {
            [self showMenu];
        }
    }
}

- (void)doubleTap:(UITapGestureRecognizer*)gesture {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showMenu) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCorrectionMenu) object:nil];
    NSInteger index = [self closestIndexToPoint:[gesture locationInView:self]];
    NSRange range = [self characterRangeAtIndex:index];
    if (range.location!=NSNotFound && range.length>0) {
        if ([self.inputDelegate respondsToSelector:@selector(selectionWillChange:)]) {
            [self.inputDelegate selectionWillChange:self];
        }
        self.selectedRange = range;
        if ([self.inputDelegate respondsToSelector:@selector(selectionDidChange:)]) {
            [self.inputDelegate selectionDidChange:self];
        }
        if (![[UIMenuController sharedMenuController] isMenuVisible]) {
            [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.1f];
        }
    }
}

- (void)tap:(UITapGestureRecognizer*)gesture {
    if (![self isFirstResponder]) {
        [self becomeFirstResponder];
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showMenu) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCorrectionMenu) object:nil];
    self.correctionRange = NSMakeRange(NSNotFound, 0);
    if (self.selectedRange.length>0) {
        self.selectedRange = NSMakeRange(self.selectedRange.location, 0);
    }

    NSInteger index = [self closestIndexToPoint:[gesture locationInView:self]];
    BOOL respondUrl = YES;// [self.delegate respondsToSelector:@selector(vTextView:didSelectURL:)];
    if (respondUrl && !_editing) {
        if ([self selectedLinkAtIndex:index]) {
            return;
        }
    }

    UIMenuController *menuController = [UIMenuController sharedMenuController];
    if ([menuController isMenuVisible]) {
        [menuController setMenuVisible:NO animated:NO];
    } else {
        if (index==self.selectedRange.location) {
            [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.35f];
        } else {
            if (_editing) {
                [self performSelector:@selector(showCorrectionMenu) withObject:nil afterDelay:0.35f];
            }
        }
    }

    if ([self.inputDelegate respondsToSelector:@selector(selectionWillChange:)]) {
        [self.inputDelegate selectionWillChange:self];
    }

    self.markedRange = NSMakeRange(NSNotFound, 0);
    self.selectedRange = NSMakeRange(index, 0);

    if ([self.inputDelegate respondsToSelector:@selector(selectionDidChange:)]) {
        [self.inputDelegate selectionDidChange:self];
    }
}

#pragma mark - #Actions Private

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

    self.mutableAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedString];
//    [self.mutableAttributeString setAttributedString:self.attributedString];
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
    
    self.mutableAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedString];

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
        index = MIN(self.attributedString.length-1, index);
        if ([self.attributedString.string characterAtIndex:index] == ' ') {
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

#pragma mark - #UIInput

#pragma mark - UIResponder
#pragma mark - Become & Resign

- (BOOL)canBecomeFirstResponder {
    BOOL shouldBeginEditing = [self.delegate respondsToSelector:@selector(vTextviewShouldBeginEditing:)];
    if (_editable && shouldBeginEditing) {
        return [self.delegate vTextviewShouldBeginEditing:self];
    }else {
        return YES;
    }
}

- (BOOL)becomeFirstResponder {
    BOOL didBeginEditing = [self.delegate respondsToSelector:@selector(vTextviewDidBeginEditing:)];
    if (_editable) {
        _editing = YES;
        if (didBeginEditing) {
            [self.delegate vTextviewDidBeginEditing:self];
        }
        [self selectionChanged];
    }
    return [super becomeFirstResponder];
}

- (BOOL)canResignFirstResponder {
    BOOL shouldEndEditing = [self.delegate respondsToSelector:@selector(vTextviewShouldEndEditing:)];
    if (_editable && shouldEndEditing) {
        return [self.delegate vTextviewShouldEndEditing:self];
    }else {
        return YES;
    }
}

- (BOOL)resignFirstResponder {
    BOOL didEndEditing = [self.delegate respondsToSelector:@selector(vTextviewDidEndEditing:)];
    if (_editable) {
        _editing = NO;
        if (didEndEditing) {
            [self.delegate vTextviewDidEndEditing:self];
        }
        [self selectionChanged];
    }
    return [super resignFirstResponder];
}

#pragma mark - Menu Actions

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (self.correctionRange.length>0 || _ignoreSelectionMenu) {
        if ([NSStringFromSelector(action) hasPrefix:@"spellCheckMenu"]) {
            return YES;
        }
        return NO;
    }

    if (action==@selector(cut:)) {
        return (_editable && self.selectedRange.length>0 && _editing);
    } else if (action==@selector(copy:)) {
        return ((self.selectedRange.length>0));
    } else if ((action == @selector(select:) || action == @selector(selectAll:))) {
        return (self.selectedRange.length==0 && [self hasText]);
    } else if (action == @selector(paste:)) {
        return (_editable && _editing && [[UIPasteboard generalPasteboard] string].length > 0);
    } else if (action == @selector(delete:)) {
        return (_editable && self.selectedRange.length>0 && _editing);
    }

    return [super canPerformAction:action withSender:sender];
}

- (void)paste:(id)sender {
    NSString *pasteText = [[UIPasteboard generalPasteboard] string];
    if (pasteText!=nil) {
        [self insertText:pasteText];
    }
}

- (void)selectAll:(id)sender {
    NSString *string = [self.attributedString string];
    NSString *trimmedString = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.selectedRange = [self.attributedString.string rangeOfString:trimmedString];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHide:) name:UIMenuControllerDidHideMenuNotification object:nil];
}

- (void)select:(id)sender {
    NSRange range = [self vCharacterRangeAtPoint:self.caretView.center];
    self.selectedRange = range;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHide:) name:UIMenuControllerDidHideMenuNotification object:nil];
}

//TODO:textwillchange:与textdidchange的位置调整
- (void)cut:(id)sender {
    if ([self.inputDelegate respondsToSelector:@selector(textWillChange:)]) {
        [self.inputDelegate textWillChange:self];
    }

    NSString *string = [self converAttributedStringToString:[self.attributedString attributedSubstringFromRange:self.selectedRange]];
    [[UIPasteboard generalPasteboard] setString:string];
    self.mutableAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedString];
//    [self.mutableAttributeString setAttributedString:self.attributedString];

    if ([self.inputDelegate respondsToSelector:@selector(textDidChange:)]) {
        [self.inputDelegate textDidChange:self];
    }

    [self.mutableAttributeString deleteCharactersInRange:self.selectedRange];
    self.attributedString = self.mutableAttributeString;

    self.selectedRange = NSMakeRange(0, 0);
}

- (void)copy:(id)sender {
    NSString *string = [self converAttributedStringToString:[self.attributedString attributedSubstringFromRange:self.selectedRange]];
    [[UIPasteboard generalPasteboard] setString:string];
}

//TODO:textwillchange:与textdidchange的位置调整
- (void)delete:(id)sender {
    if ([self.inputDelegate respondsToSelector:@selector(textWillChange:)]) {
        [self.inputDelegate textWillChange:self];
    }
    
    self.mutableAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedString];
//    [self.mutableAttributeString setAttributedString:self.attributedString];

    if ([self.inputDelegate respondsToSelector:@selector(textDidChange:)]) {
        [self.inputDelegate textDidChange:self];
    }

    [self.mutableAttributeString deleteCharactersInRange:self.selectedRange];
    self.attributedString =self.mutableAttributeString;

    self.selectedRange = NSMakeRange(self.selectedRange.location, 0);
}

- (void)replace:(id)sender {
    //
}

#pragma mark - #UIResponder

#pragma mark - Delegate
#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    if (gestureRecognizer == self.longPress) {
        if (self.selectedRange.length>0 && self.selectionView) {
            return CGRectContainsPoint(CGRectInset([self.contentView convertRect:self.selectionView.frame
                                                                          toView:self], -20.0f, -20.0f) , [gestureRecognizer locationInView:self]);
        }
    }

    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    if ([gestureRecognizer isKindOfClass:NSClassFromString(@"UIScrollViewPanGestureRecognizer")]) {
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        if ([menuController isMenuVisible]) {
            [menuController setMenuVisible:NO animated:NO];
        }
    }

    return NO;
}

#pragma mark - ContentViewDelegate

- (void)didLayoutSubviews {
    [self textChanged];
}

- (void)didDrawRect:(CGRect)rect {
    [self drawContentInRect:rect];
}

#pragma mark - #Delegate

@end
