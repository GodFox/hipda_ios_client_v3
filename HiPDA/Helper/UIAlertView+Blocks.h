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

#import <UIKit/UIKit.h>

/*
 * Completion handler invoked when user taps a button.
 *
 * @param alertView The alert view being shown (兼容旧签名，实际传 nil 或占位对象).
 * @param buttonIndex The index of the button tapped.
 */
typedef void(^UIAlertViewHandler)(UIAlertView *alertView, NSInteger buttonIndex);

/*
 * UIAlertView 在 UIScene 应用里不可用，统一用这个类展示 UIAlertController。
 */
@interface HPAlert : NSObject

+ (void)showWithTitle:(NSString *)title
              message:(NSString *)message
              handler:(UIAlertViewHandler)handler;

+ (void)showErrorWithMessage:(NSString *)message
                     handler:(UIAlertViewHandler)handler;

+ (void)showWarningWithMessage:(NSString *)message
                       handler:(UIAlertViewHandler)handler;

+ (void)showConfirmationDialogWithTitle:(NSString *)title
                                message:(NSString *)message
                                handler:(UIAlertViewHandler)handler;

+ (void)showSendMessageDialogWithTitle:(NSString *)title
                               handler:(UIAlertViewHandler)handler;

@end
