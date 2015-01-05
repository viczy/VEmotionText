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
- (void)checkLinksForRange:(NSRange)range;
- (void)checkImageForRange:(NSRange)range;
- (void)scanAttachments;
- (void)showMenu;
- (CGRect)menuPresentationRect;


- (NSAttributedString*)converStringToAttributedString:(NSString*)string;
- (NSString*)converAttributedStringToString:(NSAttributedString*)attributedString;


//layout
- (void)drawContentInRect:(CGRect)rect;

@end

@implementation VTextView

#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        //
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        //
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

#pragma mark - Actions Private

- (void)common {
    self.text = @"";
    _editable = YES;
    _font = [UIFont systemFontOfSize:17];
    _autocorrectionType = UITextAutocorrectionTypeNo;
    _dataDetectorTypes = UIDataDetectorTypeLink;
    self.alwaysBounceVertical = YES;
    self.backgroundColor = [UIColor whiteColor];
    self.clipsToBounds = YES;
    [self addSubview:self.contentView];
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

    //frameRef
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
    return nil;
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

#pragma mark - Delegate
#pragma mark ContentViewDelegate

- (void)didLayoutSubviews {
    [self textChanged];
}

- (void)didDrawRect:(CGRect)rect {
    [self drawContentInRect:rect];
}



@end
