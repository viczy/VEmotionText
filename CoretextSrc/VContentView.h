//
//  VContentView.h
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import <UIKit/UIKit.h>


@protocol ContentViewDelegate <NSObject>

- (void)didLayoutSubviews;

- (void)didDrawRect:(CGRect)rect;

@end

@interface VContentView : UIView

@property (nonatomic, weak) id <ContentViewDelegate> delegate;

@end
