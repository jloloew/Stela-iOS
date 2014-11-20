//
//  AppDelegate.m
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import "AppDelegate.h"

const static int sMaxTextChunkLength = 60;
const static int sMaxWordLength = 8;
const static int sPebbleStorageCapacity = 50000;	// 50KB


@interface AppDelegate () <PBPebbleCentralDelegate>

+ (NSArray *)chunkifyString:(NSString *)text;		// Break down the text into chunks small enough to send to the Pebble.
+ (NSString *)formatString:(NSString *)chunk;		// Take a chunk and insert "- " if it's too long to fit on the screen of the Pebble.

- (void)handleUpdateFromWatch:(PBWatch *)watch withUpdate:(NSDictionary *)update;

- (void)pebbleCentral:(PBPebbleCentral *)central watchDidConnect:(PBWatch *)watch isNew:(BOOL)isNew;
- (void)pebbleCentral:(PBPebbleCentral *)central watchDidDisconnect:(PBWatch *)watch;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// This makes it work on iOS 6
	BOOL systemVersioniOS6 = [[UIDevice currentDevice].systemVersion characterAtIndex:0] == '6';
	if (!systemVersioniOS6) {
		self.window.tintColor = [UIColor blackColor];
	}
	
	[[PBPebbleCentral defaultCentral] setDelegate:self];
	// Set the UUID of the app
	uuid_t stelaUUIDBytes;
	NSUUID *stelaUUID = [[NSUUID alloc] initWithUUIDString:[NSString stringWithString:stelaUUIDString]];
	[stelaUUID getUUIDBytes:stelaUUIDBytes];
	[[PBPebbleCentral defaultCentral] setAppUUID:[NSData dataWithBytes:stelaUUIDBytes length:sizeof(uuid_t)]];
	
    self.connectedWatch = [[PBPebbleCentral defaultCentral] lastConnectedWatch];
	NSLog(@"Last connected watch: %@", self.connectedWatch);
	
	[self.connectedWatch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {
		[self handleUpdateFromWatch:watch withUpdate:update];
		return YES;
	}];
	
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// close the session so other apps can use Pebble too
	[self.connectedWatch closeSession:^(void) {
#if DEBUG
		NSLog(@"Session closed.");
#endif
	}];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// save the current page to reload on next launch
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:self.currentURL forKey:@"savedURL"];
}

#pragma mark String Stuff

/** Takes a string and splits it into words
 */
+ (NSArray *)chunkifyString:(NSString *)text {
	if ([text length] == 0) {
		return nil;
	}
	NSMutableArray *chunks = [NSMutableArray arrayWithArray:[text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
	for (int i = 0; i < [chunks count]; i++) {
		chunks[i] = [AppDelegate formatString:chunks[i]];
		if ([chunks[i] length] > sMaxTextChunkLength) {
			[chunks insertObject:[chunks[i] substringFromIndex:sMaxTextChunkLength] atIndex:(i + 1)];
			chunks[i] = [chunks[i] substringToIndex:sMaxTextChunkLength];
		}
	}
	return chunks;
}

// Tested
+ (NSString *)formatString:(NSString *)string {
	NSString *text = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([text length] <= sMaxWordLength) {
		return text;
	}
	static NSString *delimiter_to_be_inserted = @"- ";
	NSString *result = [string substringToIndex:(sMaxWordLength - [delimiter_to_be_inserted length])];	// Cut it short so there's room for the "- "
	NSRange range;
	range.location = 0;
	range.length = [result length];
	while (range.location < [text length]) {
		range.location += range.length;
		range.length = MIN(sMaxWordLength - [delimiter_to_be_inserted length], [text length] - range.location - 1);
		result = [NSString stringWithFormat:@"%@%@%@", result, delimiter_to_be_inserted, [text substringWithRange:range]];
	}
	return result;
}

#pragma mark Watch Stuff

- (void)launchPebbleApp {
	[self.connectedWatch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
		if (!error) {
			NSLog(@"Successfully launched app.");
		} else {
			NSLog(@"Error launching app - error: %@", error);
		}
	}];
}

- (void)killPebbleApp {
	[self.connectedWatch appMessagesKill:^(PBWatch *watch, NSError *error) {
		if (!error) {
			NSLog(@"Successfully killed app.");
		} else {
			NSLog(@"Error killing app - error: %@", error);
		}
	}
	 ];
}

- (void)pushString:(NSString *)text toWatch:(PBWatch *)watch {
	if (![watch isConnected]) {
		NSLog(@"AppDelegate pushString toWatch: Error: watch not connected!");
		return;
	}
	
	[watch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
		if (isAppMessagesSupported) {
			NSLog(@"App messages is supported.");
			
			// Launch the watch app
			[self.connectedWatch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
				if (!error) {
					NSLog(@"Successfully launched app.");
				} else {
					NSLog(@"Error launching app - Error: %@", error);
				}
			}];
			// Get chunks small enough to send to Pebble
			NSArray *chunks = [AppDelegate chunkifyString:text];
			// Limit the amount of data that can be sent
			if (sMaxTextChunkLength * [chunks count] > sPebbleStorageCapacity) {
				NSLog(@"String is too long! Sending the first %d bytes.", sPebbleStorageCapacity);
				NSRange subarrayRange;
				subarrayRange.location = 0;
				subarrayRange.length = sPebbleStorageCapacity / sMaxTextChunkLength;
				chunks = [chunks subarrayWithRange:subarrayRange];
			}
			// Push each chunk to the watch
			for (NSString *chunkString in chunks) {
				NSDictionary *chunkDict = @{ @(0): chunkString };
				[self.connectedWatch appMessagesPushUpdate:chunkDict onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
					if (error) {
						NSLog(@"Error sending chunk: %@", error.localizedDescription);
					}
				}];
			}
			[self.connectedWatch closeSession:^(void) {
				NSLog(@"Session closed.");
			}];
		} else {
			NSLog(@"App messages not supported!");
		}
	}];
}

- (void)sendURL:(NSString *)urlString toWatch:(PBWatch *)watch {
	if (![watch isConnected]) {
		NSLog(@"AppDelegate pushString toWatch: Error: watch not connected!");
		return;
	}
	
	[watch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
		if (!isAppMessagesSupported) {
			NSLog(@"App messages not supported!");
			return;
		}
		
		// Launch the watch app
		[watch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
			if (error) {
				NSLog(@"Error launching watch app: %@", error.localizedDescription);
			}
		}];
		NSDictionary *urlDict = @{ @(0): urlString };
		[watch appMessagesPushUpdate:urlDict onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
			if (error) {
				NSLog(@"Error sending URL: %@", error.localizedDescription);
			}
		}];
		
//		// close the session so other apps can use Pebble too
//		[watch closeSession:^(void) {
//#if DEBUG
//			NSLog(@"Session closed.");
//#endif
//		}];
	}];
}

- (void)sendStringsToPebble:(NSArray *)words
				 completion:(void(^)(BOOL success))handler
{
	__block BOOL success = YES;
	
	if (!self.connectedWatch) {
		NSLog(@"%s: No connected watch.", __PRETTY_FUNCTION__);
		success = NO;
	} else {
		[self.connectedWatch appMessagesGetIsSupported:^(PBWatch* watch, BOOL isAppMessagesSupported) {
			if (!isAppMessagesSupported) {
				NSLog(@"App messages not supported!");
				success = NO;
				return;
			}
			
			// launch the watch app
			[watch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
				if (error) {
					NSLog(@"Error launching watch app: %@", error);
					success = NO;
				}
			}];
			
			// quick error check
			if (!success)
				return;
			
			// send the strings to the watch
			/// how many errors we've encountered in the course of sending messages so far
			__block NSUInteger errorCount = 0;
			for (__block NSUInteger i = 0; i < words.count; i++) {
				// check if we're receiving all errors
				if (errorCount >= 10 && 1.0 * errorCount / i >= 0.50) {
					NSLog(@"Too many errors! Aborting send.");
					success = NO;
					break;
				}
				
				NSString* word = words[i];
				NSDictionary* dict = @{ [NSNumber numberWithUnsignedInteger:i]: word };
				
				[self.connectedWatch appMessagesPushUpdate:dict onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
					if (error) {
						NSLog(@"Error while sending word: %@", error);
						errorCount++;
						i--; // retry this message again
					}
				}];
				
				// quick error check
				if (!success)
					return;
			}
		}];
	}
	
	handler(success);
}

- (void)handleUpdateFromWatch:(PBWatch *)watch withUpdate:(NSDictionary *)update {
#if DEBUG
	NSLog(@"Received update: %@", update);
#endif
}

#pragma mark PBPebbleCentralDelegate methods

- (void)pebbleCentral:(PBPebbleCentral *)central watchDidConnect:(PBWatch *)watch isNew:(BOOL)isNew {
#if DEBUG
	NSLog(@"Pebble connected: %@", [watch name]);
#endif
	self.connectedWatch = watch;
	[self.delegate watch:watch didChangeConnectionStateToConnected:YES];
}

- (void)pebbleCentral:(PBPebbleCentral *)central watchDidDisconnect:(PBWatch *)watch {
#if DEBUG
	NSLog(@"Pebble disconnected: %@", [watch name]);
#endif
	if (self.connectedWatch == watch || [watch isEqual:self.connectedWatch]) {
		self.connectedWatch = nil;
	}
	[self.delegate watch:watch didChangeConnectionStateToConnected:NO];
}

@end
