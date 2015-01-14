//
//  AppDelegate.m
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import "Constants.h"
#import "AppDelegate.h"

const static int sMaxTextChunkLength = 60;
const static int sMaxWordLength = 8;
//const static int sPebbleStorageCapacity = 50000;	// 50KB

static NSString * SAVED_URL_KEY = @"savedURL";


@interface AppDelegate () <PBPebbleCentralDelegate>

/// Array of arrays of a given size
@property (nonatomic) NSMutableArray *textBlocks;
@property (nonatomic) NSInteger lastSentTextBlockIndex;
/// Maximum number of words in each of the text blocks
@property (nonatomic) NSUInteger blockSize; // 300 by default

- (BOOL)isValidStelaURL:(NSURL *)url;

+ (NSArray *)chunkifyString:(NSString *)text;		// Break down the text into chunks small enough to send to the Pebble.
+ (NSString *)formatString:(NSString *)chunk;		// Take a chunk and insert "- " if it's too long to fit on the screen of the Pebble.

- (void)sendTextBlockAtIndex:(NSUInteger)blockIndex completion:(void(^)(BOOL success))handler;

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
	
	// default block size
	self.blockSize = 300; // in words
	self.lastSentTextBlockIndex = -1;
	
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
				 completion:(void (^)(BOOL success))handler
{
	// safety check
	if (!words || words.count == 0) {
		if (handler) {
			handler(YES);
		}
		return;
	}
	
	// divide up the words into blocks
	[self setTextBlocks:(NSMutableArray *)words];
	
	// send the first block to the watch
	[self sendTextBlockAtIndex:0 completion:^(BOOL success) {
		if (!success) {
			NSLog(@"Failed to send the first block to the watch.");
		}
		#if DEBUG
		else {
			NSLog(@"Successfully sent first block to the watch.");
		}
		#endif
		
		// call our caller's handler
		handler(success);
	}];
}

- (void)sendTextBlockAtIndex:(NSUInteger)blockIndex
				  completion:(void (^)(BOOL success))handler
{
	NSAssert(blockIndex < self.textBlocks.count, @"block index out of range");
	__block NSUInteger _blockBlockIndex = blockIndex; // block-safe index of the block to send
	
	__block NSArray *textBlock = self.textBlocks[blockIndex];
	
	__block BOOL success = YES;
	
	// check whether we're connected to a watch
	if (!self.connectedWatch) {
		NSLog(@"%s: No connected watch.", __PRETTY_FUNCTION__);
		success = NO;
	} else if (!textBlock) {
		#if DEBUG
			NSLog(@"No block to send. Reporting success.");
		#endif
		success = YES;
	} else {
		// a watch is connected
		[self.connectedWatch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
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
				__block NSUInteger wordNum = 1;
				__block NSDictionary *dict = @{ @(blockIndex): textBlock[0] };
				// the code to execute after each word is delivered
				void (^sendNextWord)(PBWatch *watch, NSDictionary *update, NSError *error);
				__block __weak void (^weakBlock)(PBWatch *watch, NSDictionary *update, NSError *error);
				weakBlock = sendNextWord = ^void(PBWatch *watch, NSDictionary *update, NSError *error) {
					if (wordNum >= textBlock.count) {
						return;
					}
					
					// check if we're receiving nothing but errors
					if (errorCount >= 10 && 1.0 * errorCount / wordNum >= 0.50) {
						NSLog(@"Too many errors! Aborting send.");
						success = NO;
						return;
					}
					
					// check for an error while sending the previous word
					if (error) {
						NSLog(@"Error while sending word: %@", error);
						errorCount++;
						wordNum--; // retry sending this message
					}
					
					// send the next word
					NSString *word = textBlock[wordNum];
					if (!word) {
						NSLog(@"Encountered nil word while sending words.");
						success = NO;
						return;
					}
					dict = @{ @(_blockBlockIndex): word };
					wordNum++;
					
					[self.connectedWatch appMessagesPushUpdate:dict onSent:weakBlock];
				};
				
				// actually run the block
				[self.connectedWatch appMessagesPushUpdate:dict onSent:sendNextWord];
			}];
		}];
	}
	
	if (success) {
		// update the record of the last block sent successfully
		self.lastSentTextBlockIndex = blockIndex;
	}
	
	if (handler) {
		handler(success);
	}
}

- (void)handleUpdateFromWatch:(PBWatch *)watch withUpdate:(NSDictionary *)update {
	#if DEBUG
		NSLog(@"Received update: %@", update);
	#endif
	
	// process requests for additional blocks
	if (update[@((unsigned)PEB_TEXT_BLOCK_NUMBER_KEY)]) {
		// turns out, the update contains NSData.
//		if (![update[@(PEB_TEXT_BLOCK_NUMBER_KEY)] isKindOfClass:[NSNumber class]]) {
//			NSLog(@"Error: received request for block from watch, but requested block is not a number.");
//			return;
//		}
		NSUInteger blockIndex = *(uint32_t *)[update[@((unsigned)PEB_TEXT_BLOCK_NUMBER_KEY)] bytes];
		[self sendTextBlockAtIndex:blockIndex completion:^(BOOL success) {
			#if DEBUG
				NSLog(@"Successfully sent a new block (block number %lu).", (unsigned long)blockIndex);
			#endif
		}];
	}
	
	// process requests to get and set the text block size
	if (update[@((unsigned)PEB_TEXT_BLOCK_SIZE_KEY)]) {
		if (![update[@((unsigned)PEB_TEXT_BLOCK_SIZE_KEY)] isKindOfClass:[NSNumber class]]) {
			NSLog(@"Error: received request for block size from watch, but requested block size is not a number");
			return;
		}
		NSInteger blockSize = [update[@((unsigned)PEB_TEXT_BLOCK_SIZE_KEY)] integerValue];
		// if the new number is a valid value, set the max block size.
		if (blockSize > 0 && blockSize < 0x80000000 && blockSize != self.blockSize) {
			// re-blockify the existing blocks
			self.blockSize = blockSize;
			[self setTextBlocks:self.textBlocks];
		}
		
		// send a message containing the max block size to the watch
		NSDictionary *blockSizeUpdate = @{ @((unsigned)PEB_TEXT_BLOCK_SIZE_KEY): @(-self.blockSize) };
		[watch appMessagesPushUpdate:blockSizeUpdate onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
			if (error) {
				NSLog(@"Error while replying to block size query: %@", error);
			}
			#if DEBUG
			else {
				NSLog(@"Successfully replied to block size query.");
			}
			#endif
		}];
	}
}

/// A nil parameter will delete the existing blocks.
- (void)setTextBlocks:(NSMutableArray *)textBlocks {
	NSAssert(self.blockSize != 0, @"The size of a block of text is zero.");
	// check whether textBlocks is an array of arrays of words, or whether it's an array of words that needs to be blockified
	if (!textBlocks || textBlocks.count == 0) {
		_textBlocks = nil;
		// delete current text blocks from the watch
		if (self.lastSentTextBlockIndex >= 0) {
			[self sendTextBlockAtIndex:(NSUInteger)self.lastSentTextBlockIndex completion:nil];
		}
		[self sendTextBlockAtIndex:0 completion:nil];
		return;
	}
	
	NSMutableArray *allWords; // this will be a 1-D array of all the words to be put into blocks
	
	if ([textBlocks[0] isKindOfClass:[NSArray class]]) {
		// textBlocks is a 2-D array of words that must be reordered
		allWords = [NSMutableArray array];
		for (NSArray *textBlock in textBlocks) {
			[allWords addObjectsFromArray:textBlock];
		}
	} else {
		allWords = textBlocks;
	}
	
	// allWords is now a 1-D array of all the words to be put into blocks
	NSUInteger numBlocks = ((allWords.count - 1) / self.blockSize) + 1;
	_textBlocks = [NSMutableArray arrayWithCapacity:numBlocks];
	_textBlocks[0] = [NSMutableArray arrayWithCapacity:self.blockSize];
	// fill the blocks
	NSUInteger wordNum = 0, blockNum = 0, i = 0;
	while (wordNum < allWords.count) {
		// create new blocks as needed
		if (i >= self.blockSize) {
			i = 0;
			blockNum++;
			_textBlocks[blockNum] = [NSMutableArray arrayWithCapacity:self.blockSize];
		}
		// add the next word to the current block and increment the counters
		_textBlocks[blockNum][i++] = allWords[wordNum++];
	}
	
	#if DEBUG
		NSLog(@"%s: Added %lu words, resulting in %lu blocks holding %lu words each.", __PRETTY_FUNCTION__, (unsigned long)allWords.count, (unsigned long)_textBlocks.count, (unsigned long)self.blockSize);
	#endif
}

#pragma mark PBPebbleCentralDelegate methods

- (void)pebbleCentral:(PBPebbleCentral *)central watchDidConnect:(PBWatch *)watch isNew:(BOOL)isNew {
	#if DEBUG
		NSLog(@"Pebble connected: %@", [watch name]);
	#endif
	self.connectedWatch = watch;
	// Update the UI to reflect the connected watch
	[self.delegate watch:watch didChangeConnectionStateToConnected:YES];
}

- (void)pebbleCentral:(PBPebbleCentral *)central watchDidDisconnect:(PBWatch *)watch {
	#if DEBUG
		NSLog(@"Pebble disconnected: %@", [watch name]);
	#endif
	if (self.connectedWatch == watch || [watch isEqual:self.connectedWatch]) {
		self.connectedWatch = nil;
		[self.delegate watch:watch didChangeConnectionStateToConnected:NO];
	}
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
