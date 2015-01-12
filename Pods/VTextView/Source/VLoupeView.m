//
//  VLoupeView.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "VLoupeView.h"

static CGFloat const kScaleFactor = 1.2f;

@implementation VLoupeView

#pragma mark - NSObject

+ (VLoupeView*)instance {
    return [[self alloc] init];
}

-(id)init {
    //默认放大镜的大小
    CGRect rect = CGRectMake(0.f, 0.f, 114.f, 114.f);
    self = [super initWithFrame:rect];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

#pragma mark - UIView

- (void)drawRect:(CGRect)rect {
    UIImage *loImage = [UIImage imageNamed:@"loupe_lo"];
    UIImage *maskImage = [UIImage imageNamed:@"loupe_mask"];
    UIImage *hiImage = [UIImage imageNamed:@"loupe_hi"];

    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    [loImage drawInRect:rect];

    if (self.image) {
        CGContextSaveGState(contextRef);

        CGContextClipToMask(contextRef, rect, maskImage.CGImage);

        CGContextDrawImage(contextRef, [self imageRectWithSuperRect:rect], self.image.CGImage);
//        [self.image drawInRect:[self imageRectWithSuperRect:rect]];
        CGContextRestoreGState(contextRef);
    }
    [hiImage drawInRect:rect];
}

#pragma mark - Actions Private

- (CGRect)imageRectWithSuperRect:(CGRect)superRect {
    CGPoint center = {CGRectGetMidX(superRect), CGRectGetMidY(superRect)};
    CGFloat imageW = kScaleFactor*CGRectGetWidth(superRect);
    CGFloat imageH = kScaleFactor*CGRectGetHeight(superRect);
    CGFloat imageX = center.x-imageW/2;
    CGFloat imageY = center.y-imageH/2;
    CGRect imageRect = CGRectMake(imageX, imageY, imageW, imageH);
    return imageRect;
}


@end
