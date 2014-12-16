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
//const static int sPebbleStorageCapacity = 50000;	// 50KB

static NSString * SAVED_URL_KEY = @"savedURL";


@interface AppDelegate () <PBPebbleCentralDelegate>

- (BOOL)isValidStelaURL:(NSURL *)url;

+ (NSArray *)chunkifyString:(NSString *)text;		// Break down the text into chunks small enough to send to the Pebble.
+ (NSString *)formatString:(NSString *)chunk;		// Take a chunk and insert "- " if it's too long to fit on the screen of the Pebble.

- (void)handleUpdateFromWatch:(PBWatch *)watch withUpdate:(NSDictionary *)update;

- (void)pebbleCentral:(PBPebbleCentral *)central watchDidConnect:(PBWatch *)watch isNew:(BOOL)isNew;
- (void)pebbleCentral:(PBPebbleCentral *)central watchDidDisconnect:(PBWatch *)watch;

- (void)setUpPebble;

@end



@implementation AppDelegate

// always keep the current URL saved in case of a crash
- (void)setCurrentURL:(NSString *)currentURL {
	_currentURL = currentURL;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:currentURL forKey:SAVED_URL_KEY];
}


#pragma mark - App lifecycle


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window.tintColor = [UIColor blackColor];
	
	[self setUpPebble];
	
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


#pragma mark URL stuff


- (BOOL)isValidStelaURL:(NSURL *)url {
	if ([url isFileURL]) {
		return NO;
	}
	if ([[url scheme] isEqualToString:@"stela"] || [[url scheme] isEqualToString:@"stelas"]) {
		if ([[url host] isEqualToString:@""]) { // not a valid webpage
			return NO;
		}
		
		return YES;
	}
	
	return NO;
}


// make sure we can open the URL passed in, if any.
- (BOOL)application:(UIApplication *)application
willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	NSURL *url = [launchOptions valueForKey:UIApplicationLaunchOptionsURLKey];
	if (url) {
		if (![self isValidStelaURL:url]) {
			return NO;
		}
	}
	
	return YES;
}

// Actually go and open the URL passed in.
- (BOOL)application:(UIApplication *)application
			openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
		 annotation:(id)annotation
{
	if (![self isValidStelaURL:url]) {
		return NO;
	}
	
	// replace stela:// with http://
	NSString *urlString = [url absoluteString];
	if ([[url scheme] isEqualToString:@"stelas"]) { // https
		NSRange stelaRange = NSMakeRange(0, @"stelas".length);
		urlString = [urlString stringByReplacingCharactersInRange:stelaRange withString:@"https"];
	} else if ([[url scheme] isEqualToString:@"stela"]) { // http
		NSRange stelaRange = NSMakeRange(0, @"stela".length);
		urlString = [urlString stringByReplacingCharactersInRange:stelaRange withString:@"http"];
	} else { // unreachable
		NSLog(@"Unreachable code path reached! %s %d %s", __FILE__, __LINE__, __PRETTY_FUNCTION__);
		exit(EXIT_FAILURE);
	}
	
	self.currentURL = urlString;
	
	return YES;
}


#pragma mark String Stuff


/** Takes a string and splits it into words
 */
+ (NSArray *)chunkifyString:(NSString *)text {
	if ([text length] == 0) {
		return nil;
	}
	NSArray *_chunks = [text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSMutableArray *chunks = [NSMutableArray arrayWithArray:_chunks];
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
#if DEBUG
			NSLog(@"Successfully launched app.");
#endif
		} else {
			NSLog(@"Error launching app - error: %@", error);
		}
	}];
}

- (void)killPebbleApp {
	[self.connectedWatch appMessagesKill:^(PBWatch *watch, NSError *error) {
		if (!error) {
#if DEBUG
			NSLog(@"Successfully killed app.");
#endif
		} else {
			NSLog(@"Error killing app - error: %@", error);
		}
	}];
}


- (void)sendStringsToPebble:(NSArray *)words
				 completion:(void(^)(BOOL success))handler
{
	// safety check
	if (!words || words.count == 0) {
		if (handler) {
			handler(YES);
		}
		return;
	}
	
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
					return;
				}
				
				// send the strings to the watch
				// how many errors we've encountered in the course of sending messages so far
				__block NSUInteger errorCount = 0;
				__block NSUInteger wordNum = 0;
				__block NSDictionary *dict = @{ @(wordNum): words[wordNum] };
				// the code to execute after each word is delivered
				void (^sendNextWord)(PBWatch *watch, NSDictionary *update, NSError *error);
				__block __weak void (^weakBlock)(PBWatch *watch, NSDictionary *update, NSError *error);
				weakBlock = sendNextWord = ^void(PBWatch *watch, NSDictionary *update, NSError *error) {
					if (wordNum >= words.count || wordNum == NSUIntegerMax) {
						return;
					}
					
					// check if we're receiving nothing but errors
					if (errorCount >= 10 && 1.0 * errorCount / wordNum >= 0.50) {
						NSLog(@"Too many errors! Aborting send.");
						success = NO;
						return;
					}
					
					if (error) {
						NSLog(@"Error while sending word: %@", error);
						errorCount++;
						if (wordNum > 0)
							wordNum--; // retry sending this message
					}
					
					// send the next word
					NSString *word = [words objectAtIndex:wordNum];
					if (!word) {
						NSLog(@"Encountered nil word while sending words.");
						success = NO;
						return;
					}
					dict = @{ @(wordNum++): word };
					
					[self.connectedWatch appMessagesPushUpdate:dict onSent:weakBlock];
				};
				
				// actually run the block
				[self.connectedWatch appMessagesPushUpdate:dict onSent:sendNextWord];
			}];
		}];
	}
	
	if (handler) {
		handler(success);
	}
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


#pragma mark - Misc. setup

- (void)setUpPebble {
	[[PBPebbleCentral defaultCentral] setDelegate:self];
	
	// Set the UUID of the app
	uuid_t stelaUUIDBytes;
	NSUUID *stelaUUID = [[NSUUID alloc] initWithUUIDString:[NSString stringWithString:stelaUUIDString]];
	[stelaUUID getUUIDBytes:stelaUUIDBytes];
	[[PBPebbleCentral defaultCentral] setAppUUID:[NSData dataWithBytes:stelaUUIDBytes length:sizeof(uuid_t)]];
	
	self.connectedWatch = [[PBPebbleCentral defaultCentral] lastConnectedWatch];
#if DEBUG
	NSLog(@"Last connected watch: %@", self.connectedWatch);
#endif
	
	[self.connectedWatch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {
		[self handleUpdateFromWatch:watch withUpdate:update];
		return YES;
	}];
}


@end
