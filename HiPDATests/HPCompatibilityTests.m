//
//  HPCompatibilityTests.m
//  HiPDATests
//
//  解析层兼容性回归：直接对抓下来的论坛 HTML fixture 调用 Model 解析方法。
//  fixture 来自 4d4y.com 的公开页面（版块列表 / 打印版 / viewthread）。
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>

#import "HPThread.h"
#import "HPNewPost.h"
#import "HPUser.h"
#import "HPReadViewController.h"
#import "HPSetting.h"

@interface HPThread (CompatibilityTesting)
+ (NSArray *)extractThreads:(NSString *)string;
@end

@interface HPNewPost (CompatibilityTesting)
+ (NSArray *)extractPosts:(NSString *)string;
+ (NSArray *)extractFuckPosts:(NSString *)string;
@end

@interface HPCompatibilityTests : XCTestCase

@end

@implementation HPCompatibilityTests

- (NSString *)HTMLFixtureNamed:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:name ofType:@"html" inDirectory:@"Fixtures"];
    if (!path) {
        NSString *fallback = [[[@(__FILE__) stringByDeletingLastPathComponent]
                               stringByAppendingPathComponent:@"Fixtures"]
                              stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"html"]];
        path = fallback;
    }
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:path], @"missing fixture: %@", path);
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

- (void)testForumListParser {
    NSString *html = [self HTMLFixtureNamed:@"forumdisplay"];
    XCTAssertNotNil(html);
    
    NSArray *threads = [HPThread extractThreads:html];
    XCTAssertGreaterThan(threads.count, 0, @"版块列表解析结果为空");
    
    NSDictionary *first = threads.firstObject;
    XCTAssertGreaterThan([first[@"tid"] integerValue], 0);
    XCTAssertGreaterThan([first[@"title"] length], 0);
    XCTAssertGreaterThan([first[@"user"][@"username"] length], 0);
    XCTAssertGreaterThan([first[@"replyCount"] integerValue], -1);
}

- (void)testPrintableThreadParser {
    NSString *html = [self HTMLFixtureNamed:@"printable"];
    XCTAssertNotNil(html);
    
    NSArray *posts = [HPNewPost extractPosts:html];
    XCTAssertGreaterThan(posts.count, 0, @"打印版帖子解析结果为空");
    
    HPNewPost *first = posts.firstObject;
    XCTAssertEqualObjects(first.user.username, @"fbscell");
    XCTAssertGreaterThan([first.body_html length], 0);
    XCTAssertNotNil(first.date);
    // 防止正则跨楼层：首楼正文应包含 OP 的标题文字，而不是第二楼正文
    XCTAssertTrue([first.body_html containsString:@"迟到的爱"]);
    XCTAssertFalse([first.body_html containsString:@"由于本人使用的是"]);
    
    HPNewPost *second = posts[1];
    XCTAssertTrue([second.body_html containsString:@"由于本人使用的是"]);
}

- (void)testDesktopThreadParser {
    NSString *html = [self HTMLFixtureNamed:@"viewthread"];
    XCTAssertNotNil(html);
    
    NSArray *posts = [HPNewPost extractFuckPosts:html];
    XCTAssertGreaterThan(posts.count, 0, @"桌面版帖子解析结果为空");
    
    HPNewPost *first = posts.firstObject;
    XCTAssertGreaterThan(first.pid, 0);
    XCTAssertEqualObjects(first.user.username, @"fbscell");
    XCTAssertGreaterThan([first.body_html length], 0);
    XCTAssertNotNil(first.date);
    XCTAssertTrue([first.body_html containsString:@"迟到的爱"]);
}

- (void)testReadViewInitialFrameIsFinite {
    // 回归：iOS 27 的 UIScreen.applicationFrame 可能返回 NaN 高度，
    // UIWebView initWithFrame: 会触发 CALayerInvalidGeometry。
    HPThread *thread = [HPThread new];
    HPReadViewController *vc = [[HPReadViewController alloc] initWithThread:thread];
    XCTAssertNoThrow([vc loadView]);
    
    CGRect frame = vc.view.frame;
    XCTAssertFalse(isnan(frame.size.width));
    XCTAssertFalse(isnan(frame.size.height));
    XCTAssertGreaterThan(frame.size.width, 0);
    XCTAssertGreaterThan(frame.size.height, 0);
}

- (void)testSettingsSaveAfterLoading {
    // 回归：UserDefaults 取出的设置字典是不可变的，loadSetting 必须 mutableCopy。
    HPSetting *setting = [HPSetting sharedSetting];
    [setting loadSetting];
    XCTAssertNoThrow([setting saveInteger:[setting integerForKey:@"HPPMCount"] forKey:@"HPPMCount"]);
}

- (void)testMalformedHTMLDoesNotCrash {
    XCTAssertNoThrow([HPThread extractThreads:@""]);
    XCTAssertNoThrow([HPThread extractThreads:@"<html><body>loginform</body></html>"]);
    XCTAssertNoThrow([HPNewPost extractPosts:@"<html></html>"]);
    XCTAssertNoThrow([HPNewPost extractFuckPosts:@"<html></html>"]);
    
    XCTAssertEqual([HPThread extractThreads:@""].count, 0);
    XCTAssertEqual([HPNewPost extractPosts:@"<html></html>"].count, 0);
    XCTAssertEqual([HPNewPost extractFuckPosts:@"<html></html>"].count, 0);
}

@end
