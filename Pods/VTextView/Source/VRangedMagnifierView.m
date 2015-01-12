//
//  VRangedMagnifierView.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "VRangedMagnifierView.h"

@implementation VRangedMagnifierView

#pragma mark - NSObject

+ (VRangedMagnifierView*)instance {
    return [[self alloc] init];
}

-(id)init {
    //默认大小
    CGRect rect = CGRectMake(0.f, 0.f, 145.f, 59.f);
    self = [super initWithFrame:rect];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

#pragma mark - UIView

- (void)drawRect:(CGRect)rect {
    UIImage *loImage = [UIImage imageNamed:@"ranged_magnifier_lo"];
    UIImage *maskImage = [UIImage imageNamed:@"ranged_magnifier_mask"];
    UIImage *hiImage = [UIImage imageNamed:@"ranged_magnifier_hi"];

    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    [loImage drawInRect:rect];

    if (self.image) {
        CGContextSaveGState(contextRef);

        CGContextClipToMask(contextRef, rect, maskImage.CGImage);
        CGContextDrawImage(contextRef, rect, self.image.CGImage);

        CGContextRestoreGState(contextRef);
    }
    [hiImage drawInRect:rect];
}

@end
