//
//  vTextAttachment.h
//  VEmotionText
//
//  Created by Vic Zhou on 1/5/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol VTextAttachment <NSObject>

@optional

- (UIView*)attachmentView;

- (CGSize)attachmentSize;

- (void)attachmentDrawInRect:(CGRect)rect withContent:(CGContextRef)context;

@end
