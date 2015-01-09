//
//  FirstViewController.m
//  VEmotionText
//
//  Created by Vic Zhou on 12/30/14.
//  Copyright (c) 2014 everycode. All rights reserved.
//

#import "CoretextController.h"
#import "VLoupeView.h"
#import "VTextView.h"

@interface CoretextController ()

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) VTextView *vTextView;

@end

@implementation CoretextController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.vTextView = [[VTextView alloc] initWithFrame:CGRectMake(10.f, 100.f, 300.f, 300.f)];
    self.vTextView.backgroundColor = [UIColor purpleColor];
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Emotion" ofType:@"plist"];
    NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
    self.vTextView.textImageMapping = dictionary;
    self.vTextView.editable = YES;
    self.vTextView.text = @"测试[高兴]并且也有点[生气],测试[高兴]并且也有点[生气]测试[高兴]并且也有点[生气],测试[高兴]并且也有点[生气]http://12345.com @住在这里 当时#大幅度发# 测试[高兴]并且也有点[生气],测试[高兴]并且也有点[生气]测试[高兴]并且也有点[生气],测试[高兴]并且也有点[生气]http://12345.com @住在这里 当时#大幅度发# ";

    [self.view addSubview:self.vTextView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
