//
//  HPAppDelegate.h
//  HiPDA
//
//  Created by wujichao on 13-11-6.
//  Copyright (c) 2013年 wujichao. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SWRevealViewController;
@interface HPAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) SWRevealViewController *viewController;

- (void)setupRootViewControllerWithWindow:(UIWindow *)window;

@end
