//
//  UIImage+VTextView.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/5/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "UIImage+VTextView.h"

@implementation UIImage (VTextView)

- (void)attachmentDrawInRect:(CGRect)rect {
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(contextRef, rect.origin.x, rect.origin.y+self.size.height);
    CGContextScaleCTM(contextRef, 1, -1);
    CGContextTranslateCTM(contextRef, -rect.origin.x, -rect.origin.y);
    [self drawInRect:rect];
}

- (CGSize)attachmentSize {
    return self.size;
}

@end
