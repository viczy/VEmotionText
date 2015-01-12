//
//  VIndexedPostion.h
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VTextPostion : UITextPosition

@property (nonatomic, assign) NSUInteger index;

+ (VTextPostion*)instanceWithIndex:(NSUInteger)index;

@end
