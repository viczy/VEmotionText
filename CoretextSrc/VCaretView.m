//
//  VCaretView.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "VCaretView.h"
#import "UIColor+VTextView.h"

static NSTimeInterval const animationBeginTimeFactor = .6f;
static NSTimeInterval const animationDuration = 1.f;

@interface VCaretView ()

//@property (nonatomic, strong) NSTimer *timer;

@end

@implementation VCaretView

#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor vCaretColor];
    }
    return self;
}

#pragma mark - View

- (void)didMoveToSuperview {
    if (self.superview) {
        [self animatedCaret];
    }else {
        [self stopAnimation];
    }
}

#pragma mark - Actions Public

- (void)animatedCaret {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    animation.values = @[@(1.f), @(1.f), @(0.f), @(0.f)];
    animation.calculationMode = kCAAnimationCubic;
    animation.duration = animationDuration;
    animation.beginTime = CACurrentMediaTime() + animationBeginTimeFactor;
    animation.repeatCount = CGFLOAT_MAX;
    [self.layer addAnimation:animation forKey:@"caret"];
}

- (void)stopAnimation {
    [self.layer removeAllAnimations];
}

@end
