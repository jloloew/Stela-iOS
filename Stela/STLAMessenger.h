//
//  STLAMessenger.h
//  Stela
//
//  Created by Justin Loew on 1/30/15.
//  Copyright (c) 2015-2019 Justin Loew. All rights reserved.
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

/// Send a reset command to the watch to delete the text on the watch.
- (void)resetWatch;

/// Take an array of words and enable them to be read on the watch.
///
/// @param words The words to be sent.
/// @param handler The code to be run when the words are finished sending.
- (void)sendStringsToWatch:(NSArray *)words
				completion:(void (^)(BOOL success))handler;

@end
