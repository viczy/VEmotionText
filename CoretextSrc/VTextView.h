//
//  VTextView.h
//  VEmotionText
//
//  Created by Vic Zhou on 12/31/14.
//  Copyright (c) 2014 everycode. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VTextViewDelegate.h"

@interface VTextView : UIScrollView <
    UITextInputTraits, UITextInput>

@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSAttributedString *attributedString;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, assign) BOOL editable;

@property (nonatomic, assign) NSRange selectedRange;
@property (nonatomic, assign) NSRange markedRange;
@property (nonatomic, strong) NSDictionary *textImageMapping;


@property (nonatomic, assign) UIDataDetectorTypes dataDetectorTypes;
@property (nonatomic, assign) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic, assign) UITextAutocorrectionType autocorrectionType;
@property (nonatomic, assign) UIKeyboardType keyboardType;
@property (nonatomic, assign) UIKeyboardAppearance keyboardAppearance;
@property (nonatomic, assign) UIReturnKeyType returnKeyType;

@property (readwrite, strong) UIView *inputView;
@property (readwrite, strong) UIView *inputAccessoryView;

@property (nonatomic, weak) id <UITextInputDelegate> inputDelegate;
@property (nonatomic, weak) id <VTextViewDelegate> delegate;


@end
