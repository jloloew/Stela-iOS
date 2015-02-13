//
//  STLAMessenger.m
//  Stela
//
//  Created by Justin Loew on 1/30/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

#import <PebbleKit/NSDictionary+Pebble.h>
#import <PebbleKit/NSNumber+stdint.h>
#import "STLAConstants.h"
#import "STLAWordManager.h"
#import "STLAMessenger.h"


@interface STLAMessenger () <PBPebbleCentralDelegate>

/// The version of Stela running on the currently connected watch.
@property Version watchVersion;

/// Perform initialization specific to the Pebble watch.
- (void)setUpPebble;

/// Validate a dictionary in preparation for sending it via AppMessage.
/// Keys must be NSNumbers and values must be NSNumber, NSString, or NSData.
/// NSNumbers are converted to their Pebble-compatible NSNumber equivalents.
///
/// @param dictionary The dictionary to convert.
/// @return The converted dictionary, or @c nil on error.
- (NSDictionary *)prepareDictionaryForAppMessage:(NSDictionary *)dictionary;

/// This is a convenience method to send a text block to the watch.
/// This method starts sending the block in the background and returns immediately.
///
/// @param blockIndex The index of the block to send.
/// @param handler A block to be called on completion.
- (void)sendBlockAtIndex:(NSUInteger)blockIndex
			  completion:(void(^)(BOOL success))handler;

/// Send a dictionary to the watch. The keys should be AppMessageKeys.
/// It is the caller's responsibility to use the correct value types with each key.
///
/// @param message The key-value pair or pairs to send.
- (void)sendMessage:(NSDictionary *)message;

/// Handle a new message from the watch. This method is a sort of router for messages.
/// This method passes the message on to one of several helper methods.
///
/// @param message The received key-value pairs.
- (void)receiveMessage:(NSDictionary *)message;

/// Handle a received query for the total number of blocks in the text.
///
/// @param blockCount The total number of blocks.
- (void)receiveBlockCount:(NSNumber *)blockCount;

/// Handle a received block size query.
///
/// @param blockSize The block size received.
- (void)receiveBlockSize:(NSNumber *)blockSize;

/// Handle a received error message.
///
/// @param errorMessage The error message.
- (void)receiveError:(NSString *)errorMessage;

/// Handle a received version number.
///
/// @param version The version string.
- (void)receiveVersionNumber:(NSString *)version;

#pragma mark Pebble Central delegate

// Called when a Pebble connects.
- (void)pebbleCentral:(PBPebbleCentral *)central
	  watchDidConnect:(PBWatch *)watch
				isNew:(BOOL)isNew;

// Called when a Pebble disconnects.
- (void)pebbleCentral:(PBPebbleCentral *)central
   watchDidDisconnect:(PBWatch *)watch;

@end


#pragma mark -
@implementation STLAMessenger

+ (STLAMessenger *)defaultMessenger {
	static STLAMessenger *_defaultMessenger = nil;
	if (!_defaultMessenger) {
		_defaultMessenger = [[STLAMessenger alloc] init];
	}
	return _defaultMessenger;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		self.watchVersion = (Version) { 0, 255, 255 };
		[self setUpPebble];
	}
	return self;
}

- (void)setUpPebble {
	PBPebbleCentral *pebbleCentral = [PBPebbleCentral defaultCentral];
	
	[pebbleCentral setDelegate:self];
	
	// Set the UUID of the app
	uuid_t stelaUUIDBytes;
	NSUUID *stelaUUID = [[NSUUID alloc] initWithUUIDString:stelaUUIDString];
	[stelaUUID getUUIDBytes:stelaUUIDBytes];
	NSData *UUIDData = [NSData dataWithBytes:stelaUUIDBytes length:sizeof(uuid_t)];
	[pebbleCentral setAppUUID:UUIDData];
	
	self.connectedWatch = [pebbleCentral lastConnectedWatch];
	#if DEBUG
		NSLog(@"Last connected watch: %@", self.connectedWatch);
	#endif
	
	// set the callback for incoming messages
	[self.connectedWatch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {
		[self receiveMessage:update];
		return YES;
	}];
}

- (void)disconnectFromPebble {
	[self.connectedWatch closeSession:^{
		#if DEBUG
			NSLog(@"AppMessages session closed.");
		#endif
	}];
}

- (void)resetWatch {
	NSDictionary *resetCommand = @{@(RESET_KEY): @(0)};
	[self sendMessage:resetCommand];
}

- (void)sendStringsToWatch:(NSArray *)words
				completion:(void (^)(BOOL success))handler
{
	// safety check
	if (!words || words.count == 0) {
		if (handler) {
			handler(YES);
		}
		return;
	}
	
	STLAWordManager *wordManager = [STLAWordManager defaultManager];
	
	// divide up the words into blocks
	[wordManager setTextBlocks:(NSMutableArray *)words];
	
	// reset the watch
	NSDictionary *message = @{[NSNumber numberWithUint32:RESET_KEY]: [NSNumber numberWithUint32:0]};
	[self sendMessage:message];
	// tell the watch the total number of blocks
	message = @{[NSNumber numberWithUint32:TOTAL_NUMBER_OF_BLOCKS_KEY]:
					[NSNumber numberWithUint32:(uint32_t)wordManager.textBlocks.count]};
	[self sendMessage:message];
	// tell the watch the block size
	message = @{[NSNumber numberWithUint32:TEXT_BLOCK_SIZE_KEY]:
					[NSNumber numberWithUint32:(uint32_t)wordManager.blockSize]};
	[self sendMessage:message];
	
	// send the first block to the watch
	[self sendBlockAtIndex:0 completion:^(BOOL success) {
		if (!success) {
			NSLog(@"%s:%d: Failed to send the first block to the watch.",
				  __PRETTY_FUNCTION__, __LINE__);
		}
		#if DEBUG
		else {
			NSLog(@"%s:%d: Successfully sent first block to the watch.",
				  __PRETTY_FUNCTION__, __LINE__);
		}
		#endif
		
		// call our caller's handler
		if (handler) {
			handler(success);
		}
	}];
}

#pragma mark Sending messages

- (NSDictionary *)prepareDictionaryForAppMessage:(NSDictionary *)dictionary
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary]; ///< output dictionary
	for (id key in dictionary) {
		if ([key isKindOfClass:[NSNumber class]]) {
			// convert the key
			NSInteger intKey = [key integerValue];
			NSNumber *keyForPebble = [NSNumber numberWithInt32:(int32_t)intKey];
			// convert the value
			id value = dictionary[key];
			if ([value isKindOfClass:[NSNumber class]]) {
				NSNumber *newValue = [NSNumber numberWithInt32:(int32_t)[value integerValue]];
				dict[keyForPebble] = newValue;
			} else if ([value isKindOfClass:[NSString class]] ||
					   [value isKindOfClass:[NSData class]]) {
				dict[keyForPebble] = value;
			} else {
				NSLog(@"%s:%d: Value is not an NSNumber, NSString, or NSData (it's a %@).",
					  __PRETTY_FUNCTION__, __LINE__, [value class]);
				return nil;
			}
		} else {
			NSLog(@"%s:%d: Key is not an NSNumber (it's a %@)",
				  __PRETTY_FUNCTION__, __LINE__, [key class]);
			return nil;
		}
	}
	return dict;
}

- (void)sendMessage:(NSDictionary *)message
{
	if (!self.connectedWatch) {
		NSLog(@"%s:%d: Trying to send message with no watch connected.",
			  __PRETTY_FUNCTION__, __LINE__);
		return;
	}
	
	// validate the message before sending it
	message = [self prepareDictionaryForAppMessage:message];
	if (message) {
		[self.connectedWatch appMessagesPushUpdate:message onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
			if (error) {
				NSLog(@"%s:%d: Error sending message to watch: %@",
					  __PRETTY_FUNCTION__, __LINE__, error);
			}
			#if DEBUG
			else {
				NSLog(@"%s:%d: Successfully sent message to watch: %@",
					  __PRETTY_FUNCTION__, __LINE__, update);
			}
			#endif
		}];
	}
}

- (void)sendBlockAtIndex:(NSUInteger)_blockIndex
			  completion:(void (^)(BOOL success))handler
{
	STLAWordManager *wordManager = [STLAWordManager defaultManager];
	NSAssert(_blockIndex < wordManager.textBlocks.count, @"block index out of range");
	
	// create copies of the parameters with block scope storage
	__block NSUInteger blockIndex = _blockIndex; // (ObjC block syntax)-safe index of the (text block) to send
//	__block void (^_handler)(BOOL success) = handler;
	NSArray *__weak textBlock = wordManager.textBlocks[blockIndex];
	
	// Create blocks to send to Pebble methods as callbacks.
	// Declare the blocks up front. This is kind of like a file within a file, huh?
	
	// silence warnings about @params on blocks
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdocumentation"
	
	/// The code to execute after each word is delivered.
	///
	/// @param watch The Pebble to which the words are being sent.
	/// @param update The dictionary that was just sent to the Pebble.
	/// @param error Contains details of the error that occurred, or @c nil if there was no error.
	__block void (^sendNextWords)(PBWatch *__strong watch, NSDictionary *update, NSError *error);
	
	/// Keeps a strong pointer to @c sendNextWords long enough to send it to the Pebble method.
	void (^strongBlock)(PBWatch *watch, NSDictionary *update, NSError *error);
	
	/// Called after the phone finishes launching the watch app.
	void (^watchAppLaunchedCallback)(PBWatch *watch, NSError *error);
	/// Called after the phone checks whether AppMessage is supported by the Pebble.
	void (^appMessagesSupportedCallback)(PBWatch *watch, BOOL appMessagesIsSupported);
	
	#pragma clang diagnostic pop
	
	
	__block NSUInteger errorCount = 0; ///< How many errors we've encountered in the course of sending messages so far
	__block NSUInteger wordNum = 0; ///< The index of the last sent word in the block.
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	sendNextWords = strongBlock = ^void(PBWatch *watch, NSDictionary *update, NSError *error) {
		if (wordNum >= textBlock.count) {
			// no words left to send
			if (handler) {
				handler(YES);
			}
			return;
		}
		
		// check if we're receiving nothing but errors
		NSUInteger const minErrorsBeforeFailure = 3;
		if (errorCount >= minErrorsBeforeFailure) {
			NSLog(@"%s:%d: Too many errors! Aborting send.",
				  __PRETTY_FUNCTION__, __LINE__);
			if (handler) {
				handler(NO);
			}
			return;
		}
		
		// check for an error while sending the previous words
		if (error) {
			// an error occurred, retry sending the same dict
			NSLog(@"%s:%d: Error while sending words: %@. Retrying send.",
				  __PRETTY_FUNCTION__, __LINE__, error);
			errorCount++;
			[self.connectedWatch appMessagesPushUpdate:dict
												onSent:sendNextWords];
		} else {
			// no error found, send a new dictionary
			// create the dictionary of words to send
			NSArray *words = [[STLAWordManager defaultManager] getWordsOfSize:kPebbleMaxMessageSize
															 fromBlockAtIndex:blockIndex
															  fromWordAtIndex:wordNum];
			if (!words) { // safety check
				#if DEBUG
					NSLog(@"%s:%d: Either no words left to send or an error occurred.",
						  __PRETTY_FUNCTION__, __LINE__);
				#endif
				if (handler) {
					handler(NO);
				}
				return;
			}
			NSNumber *dictKey = [NSNumber numberWithUint32:APPMESG_BLOCK_NUMBER_KEY];
			dict[dictKey] = [NSNumber numberWithUint32:(uint32_t)blockIndex];
			dictKey = [NSNumber numberWithUint32:APPMESG_WORD_START_INDEX_KEY];
			dict[dictKey] = [NSNumber numberWithUint32:(uint32_t)wordNum];
			dictKey = [NSNumber numberWithUint32:APPMESG_NUM_WORDS_KEY];
			dict[dictKey] = [NSNumber numberWithUint32:(uint32_t)words.count];
			dictKey = [NSNumber numberWithUint32:APPMESG_FIRST_WORD_KEY];
			dict[dictKey] = [NSNumber numberWithUint32:APPMESG_FIRST_WORD];
			
			// add the words to the dictionary
			for (uint32_t i = 0; i < words.count; i++) {
				dictKey = [NSNumber numberWithUint32:APPMESG_FIRST_WORD + i];
				dict[dictKey] = words[i];
			}
			
			#if DEBUG
				// log the size of the dictionary we're trying to send
				NSData *data = [dict pebbleDictionaryData:nil];
				NSLog(@"%s:%d: sending dictionary of size %lu",
					  __PRETTY_FUNCTION__, __LINE__, data.length);
			#endif
			
			// send the dictionary
			[self.connectedWatch appMessagesPushUpdate:dict
												onSent:sendNextWords];
			// update wordNum
			wordNum += words.count;
		}
	};
	
	watchAppLaunchedCallback = ^void(PBWatch *watch, NSError *error) {
		if (error) {
			NSLog(@"%s: Error launching watch app: %@",
				  __PRETTY_FUNCTION__, error);
			if (handler) {
				handler(NO);
			}
			return;
		}
		
		// wait for the watch app to finish launching
		usleep(1000); // 1 ms
		
		// send the strings to the watch
		
		
		// actually run the block
		[self.connectedWatch appMessagesPushUpdate:dict onSent:sendNextWords];
	};
	
	appMessagesSupportedCallback = ^void(PBWatch *watch, BOOL isAppMessagesSupported) {
		if (!isAppMessagesSupported) {
			NSLog(@"%s: App messages not supported!", __PRETTY_FUNCTION__);
			if (handler) {
				handler(NO);
			}
			return;
		}
		
		// launch the watch app
		[watch appMessagesLaunch:watchAppLaunchedCallback];
	};
	
	
	// Enough blocks, let's actually run some code.
	
	// check whether we're connected to a watch
	if (!self.connectedWatch) {
		NSLog(@"%s: No connected watch.", __PRETTY_FUNCTION__);
		if (handler) {
			handler(NO);
		}
		return;
	} else if (!textBlock) {
		#if DEBUG
			NSLog(@"%s: No block to send. Reporting success.", __PRETTY_FUNCTION__);
		#endif
		if (handler) {
			handler(YES);
		}
		return;
	} else {
		// a watch is connected
		[self.connectedWatch appMessagesGetIsSupported:appMessagesSupportedCallback];
	}
}

#pragma mark Receiving messages

- (void)receiveMessage:(NSDictionary *)message {
	#if DEBUG
		NSLog(@"Received message: %@", message);
	#endif
	
	id value;
	
	// check for an error
	value = message[@(ERROR_KEY)];
	if (value) {
		if ([value isKindOfClass:[NSString class]]) {
			NSString *errorMessage = (NSString *)value;
			[self receiveError:errorMessage];
		} else {
			NSLog(@"%s: Received non-string error.", __PRETTY_FUNCTION__);
		}
		return;
	}
	
	// check for a version number
	value = message[@(STELA_VERSION_KEY)];
	if (value) {
		if ([value isKindOfClass:[NSString class]]) {
			NSString *versionString = (NSString *)value;
			[self receiveVersionNumber:versionString];
		} else {
			NSLog(@"%s: Received non-string version number.", __PRETTY_FUNCTION__);
		}
		return;
	}
	
	// check for a message with the watch's block size
	value = message[@(TEXT_BLOCK_SIZE_KEY)];
	if (value) {
		if ([value isKindOfClass:[NSNumber class]]) {
			NSNumber *blockSize = (NSNumber *)value;
			[self receiveBlockSize:blockSize];
		} else {
			NSLog(@"%s: Received block size update of type %@ (expected NSNumber).",
				  __PRETTY_FUNCTION__, [value class]);
		}
		return;
	}
	
	// check for a request for the total number of blocks
	value = message[@(TOTAL_NUMBER_OF_BLOCKS_KEY)];
	if (value) {
		if ([value isKindOfClass:[NSNumber class]]) {
			NSNumber *numBlocks = (NSNumber *)value;
			[self receiveBlockCount:numBlocks];
		} else {
			NSLog(@"%s: Received block size update of type %@ (expected NSNumber).",
				  __PRETTY_FUNCTION__, [value class]);
		}
		return;
	}
	
	// no valid keys found, now we just get info for debugging
	NSLog(@"%s: No valid keys found! All received keys: %@",
		  __PRETTY_FUNCTION__, message.allKeys);
	return;
}

#pragma mark Helpers for receiving messages

- (void)receiveBlockCount:(NSNumber *)blockCount {
	#pragma unused(blockCount)
	STLAWordManager *wordManager = [STLAWordManager defaultManager];
	// send a message containing the total number of blocks back to the watch
	NSDictionary *blockCountMessage = @{@(TOTAL_NUMBER_OF_BLOCKS_KEY):
											@(-wordManager.textBlocks.count)};
	[self sendMessage:blockCountMessage];
	
	#if DEBUG
		NSLog(@"Replied to block count query.");
	#endif
}

- (void)receiveBlockSize:(NSNumber *)blockSize {
	NSInteger size = [blockSize integerValue];
	STLAWordManager *wordManager = [STLAWordManager defaultManager];
	// if the new number is a valid value, set the max block size
	if (size > 0) {
		// re-blockify the existing blocks
		wordManager.blockSize = size;
		[wordManager setTextBlocks:wordManager.textBlocks];
	}
	
	// send a message containing the max block size back to the watch
	NSDictionary *blockSizeMessage = @{@(TEXT_BLOCK_SIZE_KEY):
										   @(-wordManager.blockSize)};
	[self sendMessage:blockSizeMessage];
	
	#if DEBUG
		NSLog(@"Replied to block size query.");
	#endif
}

- (void)receiveError:(NSString *)errorMessage {
	NSLog(@"Received error message from watch: %@", errorMessage);
}

- (void)receiveVersionNumber:(NSString *)version {
	Version ver = stla_string_to_version(version);
	if (!stla_version_is_unknown(ver)) { // don't set the watch's version number without a valid value
		self.watchVersion = ver;
	}
	
	#if DEBUG
		NSLog(@"Received version number %@ from watch.", version);
	#endif
}

#pragma mark - Pebble Central delegate

- (void)pebbleCentral:(PBPebbleCentral *)central
	  watchDidConnect:(PBWatch *)watch
				isNew:(BOOL)isNew
{
	#if DEBUG
		NSLog(@"Pebble connected: %@", watch.name);
	#endif
	self.connectedWatch = watch;
	// push out a notification to reflect the new connection status
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:STLAWatchConnectionStateChangeNotification
					  object:watch
					userInfo:@{kWatchConnectionStateChangeNotificationBoolKey: @(YES)}];
	
	// send a request to the watch to send its version number over
	NSString *verStr = stla_version_to_string(stla_unknown_version_number);
	NSDictionary *versionDict = @{@(STELA_VERSION_KEY): verStr};
	[self sendMessage:versionDict];
	
	// send our version number to the watch
	verStr = stla_version_to_string(stla_get_iOS_Stela_version());
	versionDict = @{@(STELA_VERSION_KEY): verStr};
	[self sendMessage:versionDict];
}

- (void)pebbleCentral:(PBPebbleCentral *)central
   watchDidDisconnect:(PBWatch *)watch
{
	#if DEBUG
		NSLog(@"Pebble disconnected: %@", watch.name);
	#endif
	if (self.connectedWatch == watch || [watch isEqual:self.connectedWatch]) {
		self.connectedWatch = nil;
		// push out a notification to reflect the new connection status
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:STLAWatchConnectionStateChangeNotification
						  object:watch
						userInfo:@{kWatchConnectionStateChangeNotificationBoolKey: @(NO)}];
	}
	
	// reset the version number we have on file for the watch
	self.watchVersion = stla_unknown_version_number;
}

@end
