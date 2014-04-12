//
//  AppDelegate.h
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PebbleKit/PebbleKit.h>

@protocol PebbleConnectionNoticeDelegate;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) PBWatch *connectedWatch;
@property (weak, nonatomic) id<PebbleConnectionNoticeDelegate> delegate;

- (void)launchPebbleApp;
- (void)killPebbleApp;
- (void)pushString:(NSString*)text toWatch:(PBWatch*)watch;

@end

@protocol PebbleConnectionNoticeDelegate <NSObject>

- (void)watch:(PBWatch*)watch didChangeConnectionStateToConnected:(BOOL)isConnected;

@end
