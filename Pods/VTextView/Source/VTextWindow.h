//
//  VTextWindow.h
//  VEmotionText
//
//  Created by Vic Zhou on 1/5/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    VWindowLoupe = 0,
    VWindowMagnify,
} VWindowType;

typedef enum {
    VSelectionTypeLeft = 0,
    VSelectionTypeRight,
} VSelectionType;

@interface VTextWindow : UIWindow

@property (nonatomic, assign) VWindowType type;
@property (nonatomic, assign) VSelectionType selectionType;
@property (nonatomic, assign) BOOL showing;

- (void)showFromView:(UIView*)view withRect:(CGRect)rect;

- (void)renderContentView:(UIView*)view fromRect:(CGRect)rect;

- (void)hide;

- (void)updateWindowTransform;

@end
