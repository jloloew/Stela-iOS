//
//  STLAMessenger.h
//  Stela
//
//  Created by Justin Loew on 1/30/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

@import Foundation;
#import <PebbleKit/PebbleKit.h>


@interface STLAMessenger : NSObject

/// The singleton messenger.
+ (STLAMessenger *)defaultMessenger;

/// The currently connected Pebble, or nil if no Pebble is connected.
@property (strong, nonatomic) PBWatch *connectedWatch;

/// Close the AppMessages connection to the Pebble so other apps can use the Pebble too.
- (void)disconnectFromPebble;

/// Delete the text on the watch.
- (void)resetWatch;

/// 
- (void)sendStringsToWatch:(NSArray *)words
				completion:(void (^)(BOOL success))handler;

@end
