//
//  VTextViewDelegate.h
//  VEmotionText
//
//  Created by Vic Zhou on 1/5/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//
#import <UIKit/UIKit.h>
@class VTextView;

@protocol VTextViewDelegate <NSObject, UIScrollViewDelegate>

@optional

- (BOOL)vTextviewShouldBeginEditing:(VTextView*)textView;

- (BOOL)vTextviewShouldEndEditing:(VTextView*)textView;

- (void)vTextviewDidBeginEditing:(VTextView*)textView;

- (void)vTextviewDidEndEditing:(VTextView*)textView;

- (void)vTextViewDidChange:(VTextView*)textView;

- (void)vTextViewDidChangeSelection:(VTextView*)textView;

- (void)vTextView:(VTextView*)textView didSelectURL:(NSURL*)URL;

@end
