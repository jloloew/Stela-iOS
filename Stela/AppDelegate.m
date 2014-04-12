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

+ (NSArray*)chunkifyString:(NSString*)text;		// Break down the text into chunks small enough to send to the Pebble.
+ (NSString*)formatString:(NSString*)chunk;		// Take a chunk and insert "- " if it's too long to fit on the screen of the Pebble.

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
	
	//TODO
//	[self test];
	
    return YES;
}

- (void)test {
	NSArray *testCases = @[ @"",
						@"testa",
						@"testa testa",
						@"supercalifredgelisticexpialidociouszzzzzzzzzzzzzzzzzzzzzzzzz+zzzzzzzzzzzzzzzzzzzzgfdsafffffff++++++++++++++++++++++++++++",
						@"0010012001001230010012001001234001001200100123001001200100123450010012001001230010012001001234001001200100123001001200100123456" ];
	NSArray *formatStringExpectedResults = @[ @"",
											  @"testa",
											  @"testa testa",
											  @"super...",
											  @"001001200100123" ];
	NSArray *chunkifyStringExpectedResults = @[ @[ @"" ],
								  @[ @"testa" ],
								  @[ @"testa testa" ],
								  @[ @"supercalifredgelisticexpialidociouszzzzzzzzzzzzzzzzzzzzzzzzz- ", @"+zzzzzzzzzzzzzzzzzzzgfdsafffffff++++++++++++++++++++++++++++" ],
								  @[ @"001001200100123001001200100123400100120010012300100120010012- ", @"345001001200100123001001200100123400100120010012300100120010- ", @"0123456" ] ];
	NSArray *testDescriptions = @[ @"empty string",
							   @"testa",
							   @"testa testa",
							   @"supercalifre...",
							   @"long string with two hyphens" ];
	for (int i = 0; i < MIN([testCases count], [chunkifyStringExpectedResults count]); i++) {
		NSString *testCase = testCases[i];
		NSString *formatStringResult = [AppDelegate formatString:testCase];
		NSArray *chunkifyStringResult = [AppDelegate chunkifyString:testCase];
		NSString *testDescription = (i < [testDescriptions count] && testDescriptions[i] != nil && [testDescriptions[i] length] > 0) ? testDescriptions[i] : testCases[i];
		NSLog(@"formatString: %@ %hhd", testDescription, [formatStringResult isEqualToString:formatStringExpectedResults[i]]);
		NSLog(@"chunkifyString: %@ %hhd", testDescription, [chunkifyStringResult isEqualToArray:chunkifyStringExpectedResults[i]]);
	}
}

#pragma mark String Stuff

/** Takes a string and splits it into words
 */
+ (NSArray*)chunkifyString:(NSString *)text {
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
+ (NSString*)formatString:(NSString *)string {
	NSString *text = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([text length] <= sMaxWordLength) {
		return text;
	}
	//TODO: Does this work?
	__strong static NSString *delimiter_to_be_inserted = @"- ";
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
						NSLog(@"Successfully sent chunk.");
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
