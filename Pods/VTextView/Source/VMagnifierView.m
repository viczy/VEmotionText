//
//  VMagnifierView.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/5/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "VMagnifierView.h"

@implementation VMagnifierView

#pragma mark - Setter

- (void)setImage:(UIImage *)image {
    _image = image;
    [self setNeedsDisplay];
}

@end
