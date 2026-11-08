/*
 * Copyright (c) 28/01/2013 Mario Negro (@emenegro)
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "UIAlertView+Blocks.h"

/*
 * UIAlertView 在基于 UIScene 的应用里不可用（iOS 26+ 会直接抛异常），
 * 这里保留原有 category 的调用方式，但内部改用 UIAlertController 实现。
 */

@interface HPAlertViewProxy : NSObject
@property (nonatomic, weak) UITextField *textField;
- (UITextField *)textFieldAtIndex:(NSInteger)index;
- (NSInteger)cancelButtonIndex;
@end

@implementation HPAlertViewProxy

- (UITextField *)textFieldAtIndex:(NSInteger)index {
    return self.textField;
}

- (NSInteger)cancelButtonIndex {
    return 0;
}

@end

@implementation HPAlert

+ (UIViewController *)hp_topViewController {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        if (scene.activationState != UISceneActivationStateForegroundActive) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *w in windowScene.windows) {
            if (w.isKeyWindow) {
                window = w;
                break;
            }
        }
        if (!window) {
            window = windowScene.windows.firstObject;
        }
        if (window) {
            break;
        }
    }
    if (!window) {
        window = [UIApplication sharedApplication].keyWindow;
    }
    
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    if ([vc isKindOfClass:[UINavigationController class]]) {
        vc = ((UINavigationController *)vc).topViewController;
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        vc = ((UITabBarController *)vc).selectedViewController;
    }
    return vc;
}

+ (void)hp_presentAlert:(UIAlertController *)alert {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = [self hp_topViewController];
        if (vc) {
            [vc presentViewController:alert animated:YES completion:nil];
        }
    });
}

+ (void)showWithTitle:(NSString *)title
              message:(NSString *)message
              handler:(UIAlertViewHandler)handler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        if (handler) {
            handler(nil, 0);
        }
    }]];
    [self hp_presentAlert:alert];
}

+ (void)showErrorWithMessage:(NSString *)message
                     handler:(UIAlertViewHandler)handler {
    [self showWithTitle:@"Error" message:message handler:handler];
}

+ (void)showWarningWithMessage:(NSString *)message
                       handler:(UIAlertViewHandler)handler {
    [self showWithTitle:@"Warning" message:message handler:handler];
}

+ (void)showConfirmationDialogWithTitle:(NSString *)title
                                message:(NSString *)message
                                handler:(UIAlertViewHandler)handler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"No"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
        if (handler) {
            handler(nil, 0);
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        if (handler) {
            handler(nil, 1);
        }
    }]];
    [self hp_presentAlert:alert];
}

+ (void)showSendMessageDialogWithTitle:(NSString *)title
                               handler:(UIAlertViewHandler)handler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:nil];
    
    HPAlertViewProxy *proxy = [HPAlertViewProxy new];
    proxy.textField = alert.textFields.firstObject;
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
        if (handler) {
            handler((UIAlertView *)(id)proxy, 0);
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"发送"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        if (handler) {
            handler((UIAlertView *)(id)proxy, 1);
        }
    }]];
    [self hp_presentAlert:alert];
}

@end
