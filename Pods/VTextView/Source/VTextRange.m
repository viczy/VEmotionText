//
//  VTextRange.m
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import "VTextRange.h"

@implementation VTextRange

+ (VTextRange*)instanceWithRange:(NSRange)range {
    if (range.location != NSNotFound) {
        VTextRange *textRange = [[VTextRange alloc] init];
        textRange.range = range;
        return textRange;
    }
    return nil;
}



@end
