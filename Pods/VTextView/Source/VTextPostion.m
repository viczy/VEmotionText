//
//  VIndexedPostion.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "VTextPostion.h"

@implementation VTextPostion

+ (VTextPostion*)instanceWithIndex:(NSUInteger)index {
    VTextPostion *postion = [[VTextPostion alloc] init];
    postion.index = index;
    return postion;
}

@end
