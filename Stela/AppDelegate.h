//
//  AppDelegate.h
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PebbleKit/PebbleKit.h>

#define URL_STRING_DICTIONARY_KEY 1

const static BOOL debug = YES;
static NSString * const stelaUUIDString = @"70580e72-b262-4971-992d-9f89053fad11";

@protocol PebbleConnectionNoticeDelegate;


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) PBWatch *connectedWatch;
@property (weak, nonatomic) id<PebbleConnectionNoticeDelegate> delegate;

- (void)launchPebbleApp;
- (void)killPebbleApp;
- (void)pushString:(NSString*)text toWatch:(PBWatch*)watch;
//TODO: Remove before release
- (void)testAppMessageWithURLString:(NSString*)urlString;

@end


@protocol PebbleConnectionNoticeDelegate <NSObject>

- (void)watch:(PBWatch*)watch didChangeConnectionStateToConnected:(BOOL)isConnected;

@end
