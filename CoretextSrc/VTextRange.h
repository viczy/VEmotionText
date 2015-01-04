//
//  VTextRange.h
//  VEmotionText
//
//  Created by Vic Zhou on 1/4/15.
//  Copyright (c) 2015 everycode. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VTextRange : UITextRange

@property (nonatomic, assign) NSRange range;

+ (VTextRange*)instanceWithRange:(NSRange)range;

@end
