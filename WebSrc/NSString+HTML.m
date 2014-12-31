//
//  NSString+HTML.m
//  Sina_emoji
//
//  Created by cxjwin on 13-10-30.
//
//

#import "NSString+HTML.h"
#import <RegexKitLite.h>

@implementation NSString (HTML)

- (NSString*)html {
    NSString *html = [self atLink];
    html = [html topicLink];
    html = [html urlLink];
    html = [html emotion];
    return html;
}

/* @ */
- (NSString*)atLink {
    NSString *atDone = self;
    NSString *regex = @"@[a-zA-Z0-9\\u4e00-\\u9fa5\\w\\-]+";
    NSArray *array = [self componentsMatchedByRegex:regex];
    for (NSString *match in array) {
        NSString *link = [NSString stringWithFormat:@"<a href='vlink:%@'>%@</a>",match, match];
        atDone = [atDone stringByReplacingOccurrencesOfString:match withString:link];
    }
    return atDone;
}

/* #....# */
- (NSString*)topicLink {
    NSString *topicDone = self;
    NSString *regex = @"#([^\\#|.]+)#";
    NSArray *array = [self componentsMatchedByRegex:regex];
    for (NSString *match in array) {
        NSString *link = [NSString stringWithFormat:@"<a href='vlink:%@'>%@</a>",match, match];
        topicDone = [topicDone stringByReplacingOccurrencesOfString:match withString:link];
    }
    return topicDone;
}

/* 短链接 */
- (NSString*)urlLink {
    NSString *urlDone = self;
    NSString *regex = @"[http]+://[a-zA-Z].[a-zA-Z]*/[a-zA-Z]*";
    NSArray *array = [self componentsMatchedByRegex:regex];
    for (NSString *match in array) {
        NSString *link = [NSString stringWithFormat:@"<a href='vlink:%@'>V链接</a>",match];
        urlDone = [urlDone stringByReplacingOccurrencesOfString:match withString:link];
    }
    return urlDone;
}

/* 表情 */
- (NSString*)emotion {
    NSString *emotionDone = self;
    NSString *regex = @"\\[[a-zA-Z0-9\\u4e00-\\u9fa5]+\\]";
    NSArray *array = [self componentsMatchedByRegex:regex];
    for (NSString *match in array) {
        NSString *matchPath = [[self class] emotionUrl:match];
        NSString *link = [NSString stringWithFormat:@"<img src = 'file://%@' width='16' height='16'>", matchPath];
        emotionDone = [emotionDone stringByReplacingOccurrencesOfString:match withString:link];
    }
    return emotionDone;
}

/* 获取表情图片名 */

+ (NSString*)emotionUrl:(NSString*)emotion {
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Emotion" ofType:@"plist"];
    NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
    NSString *picTitle = [dictionary objectForKey:emotion];
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *picPath = [NSString stringWithFormat:@"%@/%@@2x.png", bundlePath, picTitle];
    return picPath;
}

@end
