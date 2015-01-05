//
//  FirstViewController.m
//  VEmotionText
//
//  Created by Vic Zhou on 12/30/14.
//  Copyright (c) 2014 everycode. All rights reserved.
//

#import "CoretextController.h"
#import "VLoupeView.h"

@interface CoretextController ()

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) VLoupeView *lview;

@end

@implementation CoretextController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.lview = [VLoupeView instance];
    [self.view addSubview:self.lview];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(100.f, 100.f, 100.f, 100.f);
    [button setTitle:@"title" forState:UIControlStateNormal];
    button.backgroundColor = [UIColor blueColor];
    [button addTarget:self action:@selector(ti) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)ti {
    self.lview.image = [UIImage imageNamed:@"emotion1"];
}

@end
