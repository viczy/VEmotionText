//
//  VContentView.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "VContentView.h"

@implementation VContentView

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

#pragma mark - View

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didLayoutSubviews)]) {
        [self.delegate didLayoutSubviews];
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    CGContextSaveGState(contextRef);
    if(self.delegate && [self.delegate respondsToSelector:@selector(didDrawRect:)]) {
        [self.delegate didDrawRect:rect];
    }
    CGContextRestoreGState(contextRef);
}


@end
