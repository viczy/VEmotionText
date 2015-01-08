//
//  VSelectionView.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "VSelectionView.h"
#import "UIColor+VTextView.h"

@interface VSelectionView ()

@property (nonatomic, strong) UIImageView *leftDot;
@property (nonatomic, strong) UIView *leftCaret;
@property (nonatomic, strong) UIImageView *rightDot;
@property (nonatomic, strong) UIView *rightCaret;

@end

@implementation VSelectionView

#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.layer.geometryFlipped = YES;
    }
    return self;
}

#pragma mark - Getter

- (UIImageView *)leftDot {
    if (!_leftDot) {
        UIImage *dot = [UIImage imageNamed:@"drag_dot"];
        _leftDot = [[UIImageView alloc] initWithFrame:CGRectMake(0.f, 0.f, dot.size.width, dot.size.height)];
        _leftDot.image = dot;
    }
    return _leftDot;
}

- (UIView*)leftCaret {
    if (!_leftCaret) {
        _leftCaret = [[UIView alloc]initWithFrame:CGRectZero];
        _leftCaret.backgroundColor = [UIColor vCaretColor];
    }
    return _leftCaret;
}

- (UIImageView*)rightDot {
    if (!_rightDot) {
        UIImage *dot = [UIImage imageNamed:@"drag_dot"];
        _rightDot = [[UIImageView alloc] initWithFrame:CGRectMake(0.f, 0.f, dot.size.width, dot.size.height)];
        _rightDot.image = dot;
    }
    return _rightDot;
}

- (UIView*)rightCaret {
    if (!_rightCaret) {
        _rightCaret = [[UIView alloc] initWithFrame:CGRectZero];
        _rightCaret.backgroundColor = [UIColor vCaretColor];
    }
    return _rightCaret;
}

#pragma mark - Actions Public

- (void)setBeginCaret:(CGRect)begin andEndCaret:(CGRect)end {
    if (!self.superview) {
        return;
    }

    CGFloat x = begin.origin.x;
    CGFloat y = begin.origin.y+begin.size.height;
    CGFloat w = end.origin.x-begin.origin.x;
    CGFloat h = end.origin.y-end.size.height-begin.origin.y;
    self.frame = CGRectMake(x, y, w, h);

    begin = [self.superview convertRect:begin toView:self];
    end = [self.superview convertRect:end toView:self];

    CGRect leftDotRect = self.leftDot.frame;
    leftDotRect.origin.x = floorf(CGRectGetMidX(begin)-leftDotRect.size.width/2);
    leftDotRect.origin.y = CGRectGetMidY(begin)-leftDotRect.size.height-self.leftDot.bounds.size.height/2;
    CGRect rightDotRect = self.rightDot.frame;
    rightDotRect.origin.x = floorf(CGRectGetMidX(end)-rightDotRect.size.width/2);
    rightDotRect.origin.y = CGRectGetMidY(end)+rightDotRect.size.height-self.rightDot.bounds.size.height/2;

    self.leftCaret.frame = begin;
    self.rightCaret.frame = end;
    self.leftDot.frame = leftDotRect;
    self.rightDot.frame = rightDotRect;

    [self addSubview:self.leftCaret];
    [self addSubview:self.leftDot];
    [self addSubview:self.rightCaret];
    [self addSubview:self.rightDot];
}

@end
