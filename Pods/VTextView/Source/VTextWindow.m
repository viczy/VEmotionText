//
//  VTextWindow.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/5/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "VTextWindow.h"
#import "VSelectionView.h"
#import "VLoupeView.h"
#import "VRangedMagnifierView.h"
#import "VMagnifierView.h"

static NSTimeInterval const kAnimationDuration = 0.15f;
static float const rangedMgnifierOffsetY = 44.f;

@interface VTextWindow ()

@property (nonatomic, strong) VMagnifierView *magnifierView;//loupe or rangedmagnifier view;

@end

@implementation VTextWindow

#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _type = VWindowLoupe;
    }
    return self;
}

#pragma mark - Getter

- (VMagnifierView*)magnifierView {
    if (!_magnifierView) {
        if (self.type == VWindowLoupe) {
            _magnifierView = [VLoupeView instance];
        }else {
            _magnifierView = [VRangedMagnifierView instance];
        }
    }
    return _magnifierView;
}

#pragma mark - Setter {

- (void)setType:(VWindowType)type {
    if (_type != type) {
        _type = type;
        if (self.type == VWindowLoupe) {
            self.magnifierView = [VLoupeView instance];
        }else {
            self.magnifierView = [VRangedMagnifierView instance];
        }
    }
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateWindowTransform];
}

#pragma mark - Actions Public

- (void)showFromView:(UIView *)view withRect:(CGRect)rect {
    CGRect magnifierRect = [self getMagnifierViewRectWithRect:rect];
    CGRect originRect = magnifierRect;
    magnifierRect.origin.y += magnifierRect.size.height/2;
    self.magnifierView.frame = magnifierRect;
    self.magnifierView.transform = CGAffineTransformMakeScale(.01f, .01f);
    self.magnifierView.alpha = .01f;

    if (!_showing) {
        if (!self.magnifierView.superview) {
            [self addSubview:self.magnifierView];
        }
    }

    [UIView animateWithDuration:kAnimationDuration animations:^{
        self.magnifierView.alpha = 1.0f;
        self.magnifierView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
        self.magnifierView.frame = originRect;
    } completion:^(BOOL finished) {
        _showing=YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.0f*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self renderContentView:view fromRect:rect];
        });

    }];
}

- (void)renderContentView:(UIView *)view fromRect:(CGRect)rect {
    if (!_showing || !self.magnifierView) {
        return;
    }
    CGRect magnifierRect = [self getMagnifierViewRectWithRect:rect];
    self.magnifierView.frame = magnifierRect;

    UIImage *image = [self screenshotCaretRect:rect inView:view];
    self.magnifierView.image = image;
}

- (void)hide {
    if (self.magnifierView) {
        [UIView animateWithDuration:kAnimationDuration animations:^{
            CGRect rect = self.magnifierView.frame;
            CGPoint center = self.magnifierView.center;
            rect.origin.x = floorf(center.x-rect.size.width/2);
            rect.origin.y = center.y;
            self.magnifierView.frame = rect;
            self.magnifierView.transform = CGAffineTransformMakeScale(.01f, .01f);
        } completion:^(BOOL finished) {
            _showing = NO;
            [self.magnifierView removeFromSuperview];
            self.windowLevel = UIWindowLevelNormal;
            self.hidden = YES;
        }];
    }
}

- (void)updateWindowTransform {
    self.frame = [[UIScreen mainScreen] bounds];
    switch ([[UIApplication sharedApplication] statusBarOrientation]) {
        case UIInterfaceOrientationPortrait:
            self.layer.transform = CATransform3DIdentity;
            break;
        case UIInterfaceOrientationLandscapeRight:
            self.layer.transform = CATransform3DMakeRotation((M_PI/180)*90, 0, 0, 1);
            break;
        case UIInterfaceOrientationLandscapeLeft:
            self.layer.transform = CATransform3DMakeRotation((M_PI/180)*-90, 0, 0, 1);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            self.layer.transform = CATransform3DMakeRotation((M_PI/180)*180, 0, 0, 1);
            break;
        default:
            break;
    }
}

#pragma mark - Actions Private

- (CGRect)getMagnifierViewRectWithRect:(CGRect)rect {
    CGPoint point = CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGRect magnifierRect = self.magnifierView.frame;
    magnifierRect.origin.x = floorf(point.x-magnifierRect.size.width/2);
    magnifierRect.origin.y = floorf(point.y-magnifierRect.size.height);
    switch (self.type) {
        case VWindowLoupe: {
            magnifierRect.origin.y = MAX(magnifierRect.origin.y, -47.f);
            break;
        }

        case VWindowMagnify: {
            magnifierRect.origin.y = MAX(magnifierRect.origin.y, 0.f);
            break;
        }

        default:
            break;
    }

    return magnifierRect;
}

- (UIImage *)screenshotCaretRect:(CGRect)rect inView:(UIView*)view {
    CGRect offsetRect = [self convertRect:rect toView:view];
    CGFloat offsetX = offsetRect.origin.x;
    CGFloat offsetY = offsetRect.origin.y;
    offsetX -= self.magnifierView.bounds.size.width/2;
    offsetY -= self.magnifierView.bounds.size.width/2;
    if ([view.superview isKindOfClass:[UIScrollView class]]) {
        offsetY += ((UIScrollView*)view.superview).contentOffset.y;
    }
    if (self.type == VWindowMagnify) {
        offsetY += rangedMgnifierOffsetY;
    }

    UIView *selectionView;
    CGRect selectionRect = CGRectZero;
    for (UIView *subview in view.subviews){
        if ([subview isKindOfClass:[VSelectionView class]]) {
            selectionView = subview;
        }
    }
    if (selectionView) {
        selectionRect = selectionView.frame;
        CGRect newRect = selectionRect;
        newRect.origin.y = (selectionRect.size.height - view.bounds.size.height) - ((selectionRect.origin.y + selectionRect.size.height) - view.bounds.size.height);
        selectionView.frame = newRect;
    }

    UIGraphicsBeginImageContextWithOptions(self.magnifierView.bounds.size, YES, [[UIScreen mainScreen] scale]);
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(contextRef, [UIColor whiteColor].CGColor);
    UIRectFill(CGContextGetClipBoundingBox(contextRef));

    CGContextSaveGState(contextRef);
    CGContextConcatCTM(contextRef, CGAffineTransformMakeTranslation(-offsetX, -offsetY));

    [view.layer renderInContext:contextRef];

    CGContextRestoreGState(contextRef);

    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();


    if (selectionView) {
        selectionView.frame = selectionRect;
    }

    return screenshot;
}


@end
