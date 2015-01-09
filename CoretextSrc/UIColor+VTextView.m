//
//  UIColor+VTextView.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "UIColor+VTextView.h"

@implementation UIColor (VTextView)

+ (UIColor*)vCaretColor {
    return [UIColor colorWithRed:0.259f green:0.420f blue:0.949f alpha:1.0f];
}

+ (UIColor*)vSelectionColor {
    return [UIColor colorWithRed:0.800f green:0.867f blue:0.929f alpha:1.0f];
}

+ (UIColor*)vMarkColor {
    return [UIColor colorWithRed:0.800f green:0.867f blue:0.929f alpha:1.0f];
}

+ (UIColor*)vSpellingSelectionColor {
    return [UIColor colorWithRed:1.000f green:0.851f blue:0.851f alpha:1.0f];
}

+ (UIColor*)vLinkColor {
    return [UIColor colorWithRed:0.f/255.f green:102.f/255.f blue:204.f/255.f alpha:1.f];
}

@end
