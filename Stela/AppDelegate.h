//
//  AppDelegate.h
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014-2019 Justin Loew. All rights reserved.
//

@import UIKit;


/// The key used to save the URL currently open in the browser to @c NSUserDefaults.
extern NSString *const kSTLASavedURLKey;


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic) NSString *currentURL;

/// Keep the current URL saved on disk at all times in case of a crash.
///
/// @param currentURL The URL to set.
- (void)setCurrentURL:(NSString *)currentURL;

@end
