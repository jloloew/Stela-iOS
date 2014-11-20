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
//static NSString * const stelaUUIDString = @"5bee74a1-b87d-4c62-adcf-8e4eec7a8d69";	// Stela_chessgecko
//static NSString * const stelaUUIDString = @"0b96289a-fed1-4970-9732-3f8425e616cb";	// Stela_revamped
//static NSString * const stelaUUIDString = @"70580e72-b262-4971-992d-9f89053fad11";		// original Stela
static NSString * const stelaUUIDString = @"6db75b90-8dad-4490-94ca-0fef4296c78e";		// Stela-Linked


@protocol PebbleConnectionNoticeDelegate <NSObject>

- (void)watch:(PBWatch *)watch didChangeConnectionStateToConnected:(BOOL)isConnected;

@end



@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) PBWatch *connectedWatch;
@property (weak, nonatomic) id<PebbleConnectionNoticeDelegate> delegate;
@property (nonatomic) NSString* currentURL;

- (void)launchPebbleApp;
- (void)killPebbleApp;
- (void)sendStringsToPebble:(NSArray*)words completion:(void(^)(BOOL success))handler;

@end
