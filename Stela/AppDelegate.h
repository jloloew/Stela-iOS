//
//  AppDelegate.h
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PebbleKit/PebbleKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) PBWatch *connectedWatch;

- (void)launchPebbleApp;
- (void)killPebbleApp;
- (void)pushString:(NSString*)text toWatch:(PBWatch*)watch;

@end
