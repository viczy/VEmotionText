//
//  SecondViewController.m
//  VEmotionText
//
//  Created by Vic Zhou on 12/30/14.
//  Copyright (c) 2014 everycode. All rights reserved.
//

#import "WebController.h"
#import "NSString+HTML.h"

@interface WebController ()

@property (nonatomic, weak) IBOutlet UIWebView *webView;

@end

@implementation WebController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadHtml];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark Actions Private

- (void)loadHtml {
    NSString *str =
    @"这是测试字符串 测试字[高兴]符串@对象 测试字[生气]符串#话题#测试字符串 http://t.cn/zWZraspD";
    NSString *html = [str html];
    self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
    [self.webView loadHTMLString:html baseURL:nil];
}

#pragma mark -
#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString *scheme = request.URL.scheme;
    if ([scheme caseInsensitiveCompare:@"vlink"] == NSOrderedSame) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"跳转"
                                                        message:scheme
                                                       delegate:nil
                                              cancelButtonTitle:@"确定"
                                              otherButtonTitles:nil];
        [alert show];
        return NO;
    }

    return YES;
}


@end
