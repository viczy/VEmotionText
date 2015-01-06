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
//    CGContextRef contextRef = UIGraphicsGetCurrentContext();
//    CGContextTranslateCTM(contextRef, rect.origin.x, rect.origin.y+20.f/*self.size.height*/);
//    CGContextScaleCTM(contextRef, 1, -1);
//    CGContextTranslateCTM(contextRef, -rect.origin.x, -rect.origin.y);
    [self drawInRect:rect];
}

- (CGSize)attachmentSize {
    //return self.size;
    //表情固定大小
    return CGSizeMake(20.f, 20.f);
}

@end
