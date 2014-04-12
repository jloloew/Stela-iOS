//
//  AppDelegate.m
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import "AppDelegate.h"

const static int sMaxTextChunkLength = 60;
const static int sPebbleStorageCapacity = 50000;	// 50KB

@interface AppDelegate () <PBPebbleCentralDelegate>

+ (NSArray*)chunkifyString:(NSString*)text;	// Break down the text into chunks small enough to send to the Pebble.
+ (NSString*)formatString:(NSString*)text;

- (void)handleUpdateFromWatch:(PBWatch*)watch withUpdate:(NSDictionary*)update;

- (void)pebbleCentral:(PBPebbleCentral *)central watchDidConnect:(PBWatch *)watch isNew:(BOOL)isNew;
- (void)pebbleCentral:(PBPebbleCentral *)central watchDidDisconnect:(PBWatch *)watch;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[[PBPebbleCentral defaultCentral] setDelegate:self];
	// Set the UUID of the app
	uuid_t stelaUUIDBytes;
	NSUUID *stelaUUID = [[NSUUID alloc] initWithUUIDString:@"70580e72-b262-4971-992d-9f89053fad11"];
	[stelaUUID getUUIDBytes:stelaUUIDBytes];
	[[PBPebbleCentral defaultCentral] setAppUUID:[NSData dataWithBytes:stelaUUIDBytes length:16]];
	
    self.connectedWatch = [[PBPebbleCentral defaultCentral] lastConnectedWatch];
	NSLog(@"Last connected watch: %@", self.connectedWatch);
	
	[self.connectedWatch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {
		[self handleUpdateFromWatch:watch withUpdate:update];
		return YES;
	}];
	
    return YES;
}

- (void)launchPebbleApp {
	[self.connectedWatch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
		if (!error) {
			NSLog(@"Successfully launched app.");
		} else {
			NSLog(@"Error launching app - error: %@", error);
		}
	}
	];
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
	[watch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
		if (isAppMessagesSupported) {
			NSLog(@"App messages is supported.");
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
					if (!error) {
						NSLog(@"Successfully send chunk.");
					} else {
						NSLog(@"Error sending chunk: %@", error);
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

- (void)handleUpdateFromWatch:(PBWatch *)watch withUpdate:(NSDictionary *)update {
	//TODO
	NSLog(@"Received update: %@", update);
}

+ (NSArray*)chunkifyString:(NSString *)text {
	if ([text length] == 0) {
		return nil;
	}
	NSMutableArray *chunks = [NSMutableArray array];
	for (int i = 0; i < [text lengthOfBytesUsingEncoding:NSUnicodeStringEncoding];) {
		NSRange range;
		range.location = i;
		range.length = MIN((i += sMaxTextChunkLength), [text length]);
		NSString *chunk = [text substringWithRange:range];
		[chunks addObject:chunk];
	}
	return chunks;
}

+ (NSString*)formatString:(NSString *)text {
	if ([text length] <= sMaxTextChunkLength) {
		return text;
	}
	NSRange range;
	range.location = 0;
	range.length = sMaxTextChunkLength;
	NSString *result = [text substringToIndex:range.length];
	while (range.location < [text length]) {
		range.location += range.length;
		range.length = MAX(sMaxTextChunkLength, [text length] - range.location);
		result = [NSString stringWithFormat:@"%@- %@", result, [text substringWithRange:range]];
	}
	return result;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark PBPebbleCentralDelegate methods
- (void)pebbleCentral:(PBPebbleCentral *)central watchDidConnect:(PBWatch *)watch isNew:(BOOL)isNew {
	NSLog(@"Pebble connected: %@", [watch name]);
	self.connectedWatch = watch;
}

- (void)pebbleCentral:(PBPebbleCentral *)central watchDidDisconnect:(PBWatch *)watch {
	NSLog(@"Pebble disconnected: %@", [watch name]);
	if (self.connectedWatch == watch || [watch isEqual:self.connectedWatch]) {
		self.connectedWatch = nil;
	}
}

@end
