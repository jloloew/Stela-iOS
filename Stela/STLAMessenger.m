//
//  STLAMessenger.m
//  Stela
//
//  Created by Justin Loew on 1/30/15.
//  Copyright (c) 2015-2019 Justin Loew. All rights reserved.
//

#import <PebbleKit/NSDictionary+Pebble.h>
#import <PebbleKit/NSNumber+stdint.h>

#import "STLAConstants.h"
#import "STLAWordManager.h"
#import "STLAMessenger.h"


@interface STLAMessenger () <PBPebbleCentralDelegate, PBWatchDelegate>

/// Whether the watch contains any text to read.
@property BOOL watchIsEmpty;

/// The version of Stela running on the currently connected watch.
@property Version watchVersion;

/// Perform initialization specific to the Pebble watch.
- (void)configurePebbleCentral;

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
			  completion:(void (^)(BOOL success))handler;

/// Send a dictionary to the watch. The keys should be AppMessageKeys.
/// It is the caller's responsibility to use the correct value types with each key.
///
/// @param message The key-value pair or pairs to send.
/// @param handler The callback to run when the message is done sending.
- (void)sendMessage:(NSDictionary *)message
		 completion:(void (^)(PBWatch *watch, NSDictionary *update, NSError *error))handler;

/// Send the iOS app's current version to the watch.
///
/// @param handler The callback to run when the message is done sending.
- (void)sendVersionWithCompletion:(void (^)(PBWatch *watch, NSDictionary *update, NSError *error))handler;

/// Send the given version to the watch.
///
/// @param version The version to send.
/// @param handler The callback to run when the message is done sending.
- (void)sendVersion:(Version)version
		 completion:(void (^)(PBWatch *watch, NSDictionary *update, NSError *error))handler;

/// Handle a new message from the watch. This method is a sort of router for messages.
/// This method passes the message on to one of several helper methods.
///
/// @param message The received key-value pairs.
- (void)receiveMessage:(NSDictionary *)message;

/// Handle a received query for the total number of blocks in the text.
///
/// @param blockCount The total number of blocks.
- (void)receiveBlockCount:(NSNumber *)blockCount;

/// Handle a received request for a block. This method starts sending the block
/// at the requested index over to the watch.
///
/// @param requestedBlockIndex The index of the block that the phone should send to the watch.
- (void)receiveBlockRequest:(NSNumber *)requestedBlockIndex;

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
/// @param major The major component of the version.
/// @param minor The minor component of the version.
/// @param patch The patch component of the version.
- (void)receiveVersionNumberMajor:(NSNumber *)major
							minor:(NSNumber *)minor
							patch:(NSNumber *)patch;

#pragma mark Pebble Central delegate

// Called when a Pebble connects.
- (void)pebbleCentral:(PBPebbleCentral *)central
	  watchDidConnect:(PBWatch *)watch
				isNew:(BOOL)isNew;

// Called when a Pebble disconnects.
- (void)pebbleCentral:(PBPebbleCentral *)central
   watchDidDisconnect:(PBWatch *)watch;

@end


#pragma mark - Implementation
@implementation STLAMessenger

+ (STLAMessenger *)defaultMessenger {
	static STLAMessenger *_defaultMessenger = nil;
	if (!_defaultMessenger) {
		_defaultMessenger = [[STLAMessenger alloc] init];
	}
	return _defaultMessenger;
}

- (instancetype)init {
	if (self = [super init]) {
		self.connectedWatch = nil;
		[self configurePebbleCentral];
	}
	return self;
}

- (void)configurePebbleCentral {
	PBPebbleCentral *pebbleCentral = [PBPebbleCentral defaultCentral];
	
	pebbleCentral.delegate = self;
	
	// Set the UUID of the app.
	uuid_t stelaUUIDBytes;
	NSUUID *stelaUUID = [[NSUUID alloc] initWithUUIDString:stelaUUIDString];
	[stelaUUID getUUIDBytes:stelaUUIDBytes];
	NSData *UUIDData = [NSData dataWithBytes:stelaUUIDBytes length:sizeof(uuid_t)];
	[pebbleCentral setAppUUID:UUIDData];
	if (![pebbleCentral hasValidAppUUID]) {  // Safety check.
		NSLog(@"%s:%d: Our app UDID is invalid!", __PRETTY_FUNCTION__, __LINE__);
	}
	
	// Set our connected watch.
	if (pebbleCentral.lastConnectedWatch.isConnected) {
		self.connectedWatch = pebbleCentral.lastConnectedWatch;
	} else {
		self.connectedWatch = nil;
	}
	
	#if DEBUG
		NSLog(@"%s:%d: Last connected watch: %@",
			  __PRETTY_FUNCTION__, __LINE__, self.connectedWatch);
	#endif
	
	// Set the callback for incoming messages.
	[self.connectedWatch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch,
																  NSDictionary *update)
	{
		[self receiveMessage:update];
		return YES;
	}];
}

- (void)disconnectFromPebble {
	[self.connectedWatch closeSession:^{
		#if DEBUG
			NSLog(@"%s:%d: AppMessages session closed.", __PRETTY_FUNCTION__, __LINE__);
		#endif
		
		self.watchIsEmpty = YES;
		self.watchVersion = stla_unknown_version_number;
		
		// Push out a notification to reflect the new connection status.
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:STLAWatchConnectionStateChangeNotification
						  object:self.connectedWatch
						userInfo:@{ kWatchConnectionStateChangeNotificationBoolKey: @(NO) }];
		
		self.connectedWatch = nil;
	}];
}

- (void)resetWatch {
	// Don't send simultaneous reset commands.
	static BOOL _resetInProgress = NO;
	BOOL *resetInProgress = &_resetInProgress; // Needed for the block.
	
	if (!_resetInProgress) {
		_resetInProgress = YES;
		NSDictionary *resetCommand = @{@(RESET_KEY): @(0)};
		[self sendMessage:resetCommand
			   completion:^(PBWatch *watch __unused,
							NSDictionary *update __unused,
							NSError *error __unused)
		{
			*resetInProgress = NO;
			self.watchIsEmpty = YES;
			
			#if DEBUG
				NSLog(@"%s:%d: Reset command sent to watch.", __PRETTY_FUNCTION__, __LINE__);
			#endif
		}];
	}
}

- (void)sendStringsToWatch:(NSArray *)words
				completion:(void (^)(BOOL success))handler
{
	// Safety check.
	if (!words || words.count == 0) {
		if (handler) {
			handler(YES);
		}
		return;
	}
	
	// Check for a connected Pebble.
	if (self.connectedWatch) {
		// Pebble is connected.
		#if DEBUG
			NSLog(@"Sending to Pebble (%@)", self.connectedWatch);
		#endif
		
		STLAWordManager *wordManager = [STLAWordManager defaultManager];
		
		// Divide up the words into blocks.
		[wordManager setTextBlocks:(NSMutableArray *)words];
		
		[self resetWatch];
		
		// Tell the watch the total number of blocks and the block size.
		NSDictionary *message = @{@(TOTAL_NUMBER_OF_BLOCKS_KEY): @(wordManager.textBlocks.count),
								  @(TEXT_BLOCK_SIZE_KEY): @(wordManager.blockSize)};
		[self sendMessage:message completion:nil];
		
		// Send the first block to the watch.
		[self sendBlockAtIndex:0 completion:^(BOOL success) {
			if (success) {
				#if DEBUG
					NSLog(@"%s:%d: Successfully sent first block to the watch.",
						  __PRETTY_FUNCTION__, __LINE__);
				#endif
				
				self.watchIsEmpty = NO;
			} else {
				NSLog(@"%s:%d: Failed to send the first block to the watch.",
					  __PRETTY_FUNCTION__, __LINE__);
			}
			
			// Call our caller's handler.
			if (handler) {
				handler(success);
			}
		}];
	} else {
		// No Pebble connected.
		handler(NO);
	}
}

#pragma mark Sending messages

- (NSDictionary *)prepareDictionaryForAppMessage:(NSDictionary *)dictionary
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];  ///< Output dictionary
	for (id key in dictionary) {
		if ([key isKindOfClass:[NSNumber class]]) {
			// Convert the key.
			NSInteger intKey = [key integerValue];
			NSNumber *keyForPebble = [NSNumber numberWithInt32:(int32_t)intKey];
			// Convert the value.
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
		 completion:(void (^)(PBWatch *watch, NSDictionary *update, NSError *error))handler
{
	if (!self.connectedWatch) {
		NSLog(@"%s:%d: Trying to send message with no watch connected.",
			  __PRETTY_FUNCTION__, __LINE__);
	}
	
	// Validate the message before sending it.
//	message = [self prepareDictionaryForAppMessage:message];
	
	// Communication with the watch must be done on the main thread.
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.connectedWatch appMessagesPushUpdate:message onSent:handler];
	});
}

- (void)sendBlockAtIndex:(NSUInteger)_blockIndex
			  completion:(void (^)(BOOL success))handler
{
	STLAWordManager *wordManager = [STLAWordManager defaultManager];
	NSAssert(_blockIndex < wordManager.textBlocks.count, @"%s:%d: Block index out of range (max %lu, actual %lu)",
			 __PRETTY_FUNCTION__, __LINE__, (unsigned long)wordManager.textBlocks.count, (unsigned long)_blockIndex);
	
	// Create copies of the parameters with block scope storage.
	NSUInteger const blockIndex = _blockIndex;  // (ObjC block syntax)-safe index of the (text block) to send.
	NSArray *__weak textBlock = wordManager.textBlocks[blockIndex];
	
	// Create blocks to send to Pebble methods as callbacks.
	// Declare the blocks up front. This is kind of like a file within a file, huh?
	
	// Silence warnings about @params on blocks.
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdocumentation"
	
	/// The code to execute after each word is delivered.
	///
	/// @param watch The Pebble to which the words are being sent.
	/// @param update The dictionary that was just sent to the Pebble.
	/// @param error Contains details of the error that occurred, or @c nil if there was no error.
	__block void (^sendNextWords)(PBWatch *__strong watch, NSDictionary *update, NSError *error);
	
	/// Keeps a strong pointer to @c sendNextWords just long enough to send it to the Pebble method.
	void (^strongBlock)(PBWatch *watch, NSDictionary *update, NSError *error);
	
	/// Called after the phone finishes launching the watch app.
	void (^watchAppLaunchedCallback)(PBWatch *watch, NSError *error);
	
	/// Called after the phone checks whether AppMessage is supported by the Pebble.
	void (^appMessagesSupportedCallback)(PBWatch *watch, BOOL appMessagesIsSupported);
	
	#pragma clang diagnostic pop
	
	
	__block NSUInteger messagesSent = 0;  ///< How many messages we've sent successfully.
	__block NSUInteger errorCount = 0;  ///< How many errors we've encountered in the course of sending messages so far.
	__block NSUInteger wordNum = 0;  ///< The index of the last sent word in the block.
	__block NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	sendNextWords = strongBlock = ^void(PBWatch *watch,
										NSDictionary *update,
										NSError *error)
	{
		if (wordNum >= textBlock.count) {
			// No words left to send.
			if (handler) {
				handler(YES);
			}
			return;
		}
		
		// Check if we're receiving nothing but errors.
		NSUInteger const minErrorsBeforeFailure = 10;
		double const maxErrorRate = 0.25;
		if (errorCount >= minErrorsBeforeFailure && (1.0 * errorCount / messagesSent) > maxErrorRate) {
			NSLog(@"%s:%d: Too many errors! Aborting send.", __PRETTY_FUNCTION__, __LINE__);
			if (handler) {
				handler(NO);
			}
			return;
		}
		
		// Check for an error while sending the previous words.
		if (error) {
			// An error occurred, retry sending the same dict.
			NSLog(@"%s:%d: Error while sending words: %@. Retrying send.",
				  __PRETTY_FUNCTION__, __LINE__, error);
			errorCount++;
			[self sendMessage:dict completion:sendNextWords];
		} else {
			// No error found, send a new dictionary.
			messagesSent++;
			// Create the dictionary of words to send.
			NSArray *words = [[STLAWordManager defaultManager] getWordsOfSize:kPebbleMaxMessageSize
															 fromBlockAtIndex:blockIndex
															  fromWordAtIndex:wordNum];
			if (!words) {  // Safety check.
				#if DEBUG
					NSLog(@"%s:%d: An error occurred while retrieving the next words to send.",
						  __PRETTY_FUNCTION__, __LINE__);
				#endif
				if (handler) {
					handler(NO);
				}
				return;
			}
			
			// Base dictionary.
			dict = [NSMutableDictionary dictionaryWithDictionary:@{@(APPMESG_BLOCK_NUMBER_KEY):		@(blockIndex),
																   @(APPMESG_WORD_START_INDEX_KEY):	@(wordNum),
																   @(APPMESG_NUM_WORDS_KEY):		@(words.count),
																   @(APPMESG_FIRST_WORD_KEY):		@(APPMESG_FIRST_WORD)}];
			// Add the words to the dictionary.
			for (NSUInteger i = 0; i < words.count; i++) {
				dict[@(APPMESG_FIRST_WORD + i)] = words[i];
			}
			
			#if DEBUG
				// Log the size of the dictionary we're trying to send.
				NSData *data = [dict pebbleDictionaryData:nil];
				NSLog(@"%s:%d: sending message %lu containing a dictionary with size %lu and contents: %@",
					  __PRETTY_FUNCTION__, __LINE__, (unsigned long)messagesSent, (unsigned long)data.length, dict);
			#endif
			
			// Send the dictionary.
			[self sendMessage:dict completion:sendNextWords];
			
			// Update wordNum.
			wordNum += words.count;
		}
	};
	
	watchAppLaunchedCallback = ^void(PBWatch *watch, NSError *error)
	{
		if (error) {
			NSLog(@"%s:%d: Error launching watch app: %@", __PRETTY_FUNCTION__, __LINE__, error);
			if (handler) {
				handler(NO);
			}
			return;
		}
		
		// Send the strings to the watch.
		sendNextWords(watch, dict, nil);
	};
	
	appMessagesSupportedCallback = ^void(PBWatch *watch, BOOL isAppMessagesSupported)
	{
		if (!isAppMessagesSupported) {
			NSLog(@"%s:%d: App messages not supported!", __PRETTY_FUNCTION__, __LINE__);
			if (handler) {
				handler(NO);
			}
			return;
		}
		
		// Launch the watch app.
		[watch appMessagesLaunch:watchAppLaunchedCallback];
	};
	
	
	// Enough blocks, let's actually run some code.
	
	// Check whether we're connected to a watch.
	if (!self.connectedWatch) {
		NSLog(@"%s:%d: No connected watch.", __PRETTY_FUNCTION__, __LINE__);
		if (handler) {
			handler(NO);
		}
		return;
	}
	if (!textBlock) {
		#if DEBUG
			NSLog(@"%s:%d: Error: no block to send.", __PRETTY_FUNCTION__, __LINE__);
		#endif
		if (handler) {
			handler(NO);
		}
		return;
	}
	// A watch is connected.
	[self.connectedWatch appMessagesGetIsSupported:appMessagesSupportedCallback];
}

- (void)sendVersionWithCompletion:(void (^)(PBWatch *watch, NSDictionary *update, NSError *error))handler
{
	Version const ver = stla_get_iOS_Stela_version();
	[self sendVersion:ver completion:handler];
}

- (void)sendVersion:(Version)version
		 completion:(void (^)(PBWatch *watch, NSDictionary *update, NSError *error))handler
{
	NSDictionary *message = @{@(VERSION_MAJOR_KEY): [NSNumber numberWithUint8:version.major],
							  @(VERSION_MINOR_KEY): [NSNumber numberWithUint8:version.minor],
							  @(VERSION_PATCH_KEY): [NSNumber numberWithUint8:version.patch]};
	[self sendMessage:message completion:handler];
}

#pragma mark Receiving messages

- (void)receiveMessage:(NSDictionary *)message {
	#if DEBUG
		NSLog(@"%s:%d: Received message: %@", __PRETTY_FUNCTION__, __LINE__, message);
	#endif
	
	id value;
	
	// Check for an error.
	value = message[@(ERROR_KEY)];
	if (value) {
		if ([value isKindOfClass:[NSString class]]) {
			NSString *errorMessage = (NSString *)value;
			[self receiveError:errorMessage];
		} else {
			NSLog(@"%s:%d: Received non-string error.", __PRETTY_FUNCTION__, __LINE__);
		}
		return;
	}
	
	// Check for a version number.
	value = message[@(VERSION_MAJOR_KEY)];
	if (value) {
		if ([message[@(VERSION_MAJOR_KEY)] isKindOfClass:[NSNumber class]] &&
			[message[@(VERSION_MINOR_KEY)] isKindOfClass:[NSNumber class]] &&
			[message[@(VERSION_PATCH_KEY)] isKindOfClass:[NSNumber class]]) {
			NSNumber *major = (NSNumber *)message[@(VERSION_MAJOR_KEY)];
			NSNumber *minor = (NSNumber *)message[@(VERSION_MINOR_KEY)];
			NSNumber *patch = (NSNumber *)message[@(VERSION_PATCH_KEY)];
			[self receiveVersionNumberMajor:major minor:minor patch:patch];
		} else {
			NSLog(@"%s:%d: Received invalid version number.", __PRETTY_FUNCTION__, __LINE__);
		}
		return;
	}
	
	// Check for a message with the watch's block size.
	value = message[@(TEXT_BLOCK_SIZE_KEY)];
	if (value) {
		if ([value isKindOfClass:[NSNumber class]]) {
			NSNumber *blockSize = (NSNumber *)value;
			[self receiveBlockSize:blockSize];
		} else {
			NSLog(@"%s:%d: Received block size update of type %@ (expected NSNumber).",
				  __PRETTY_FUNCTION__, __LINE__, [value class]);
		}
		return;
	}
	
	// Check for a request for the total number of blocks.
	value = message[@(TOTAL_NUMBER_OF_BLOCKS_KEY)];
	if (value) {
		if ([value isKindOfClass:[NSNumber class]]) {
			NSNumber *numBlocks = (NSNumber *)value;
			[self receiveBlockCount:numBlocks];
		} else {
			NSLog(@"%s:%d: Received query (for the total number of blocks) of type %@ (expected NSNumber).",
				  __PRETTY_FUNCTION__, __LINE__, [value class]);
		}
		return;
	}
	
	// Check for a request for another block to be sent over.
	value = message[@(APPMESG_BLOCK_NUMBER_KEY)];
	if (value) {
		if ([value isKindOfClass:[NSNumber class]]) {
			NSNumber *requestedBlock = (NSNumber *)value;
			[self receiveBlockRequest:requestedBlock];
		} else {
			NSLog(@"%s:%d: Received request (to send a block) of type %@ (expected NSNumber).",
				  __PRETTY_FUNCTION__, __LINE__, [value class]);
		}
		return;
	}
	
	// No valid keys found, now we just get info for debugging
	NSLog(@"%s:%d: No valid keys found! All received keys: %@",
		  __PRETTY_FUNCTION__, __LINE__, message.allKeys);
}

#pragma mark Helpers for receiving messages

- (void)receiveBlockCount:(NSNumber *)blockCount {
	#pragma unused(blockCount)
	STLAWordManager *wordManager = [STLAWordManager defaultManager];
	// Send a message containing the total number of blocks back to the watch.
	NSDictionary *blockCountMessage = @{@(TOTAL_NUMBER_OF_BLOCKS_KEY):
											@(-wordManager.textBlocks.count)};
	[self sendMessage:blockCountMessage completion:nil];
	
	#if DEBUG
		NSLog(@"%s:%d: Replied to block count query.", __PRETTY_FUNCTION__, __LINE__);
	#endif
}

- (void)receiveBlockRequest:(NSNumber *)requestedBlockIndex {
	NSUInteger blockIndex = [requestedBlockIndex unsignedIntegerValue];
	[self sendBlockAtIndex:blockIndex completion:nil];
	
	#if DEBUG
		NSLog(@"%s:%d: Received request for block %lu.",
			  __PRETTY_FUNCTION__, __LINE__, (unsigned long)blockIndex);
	#endif
}

- (void)receiveBlockSize:(NSNumber *)blockSize {
	NSInteger size = [blockSize integerValue];
	STLAWordManager *wordManager = [STLAWordManager defaultManager];
	// If the new number is positive, set the max block size.
	if (size > 0) {
		// Re-blockify the existing blocks.
		wordManager.blockSize = size;
		[wordManager setTextBlocks:wordManager.textBlocks];
	}
	
	// Send a message containing the max block size back to the watch.
	NSDictionary *blockSizeMessage = @{@(TEXT_BLOCK_SIZE_KEY):
										   @(-wordManager.blockSize)};
	[self sendMessage:blockSizeMessage completion:nil];
	
	#if DEBUG
		NSLog(@"%s:%d: Replied to block size query.", __PRETTY_FUNCTION__, __LINE__);
	#endif
}

- (void)receiveError:(NSString *)errorMessage {
	NSLog(@"%s:%d: Received error message from watch: %@",
		  __PRETTY_FUNCTION__, __LINE__, errorMessage);
}

- (void)receiveVersionNumberMajor:(NSNumber *)major
							minor:(NSNumber *)minor
							patch:(NSNumber *)patch
{
	VERSION_MAJOR_KEY_t v_major = [major uint8Value];
	VERSION_MINOR_KEY_t v_minor = [minor uint8Value];
	VERSION_PATCH_KEY_t v_patch = [patch uint8Value];
	Version const ver = { .major = v_major, .minor = v_minor, .patch = v_patch };
	
	self.watchVersion = ver;
	
	#if DEBUG
		NSLog(@"%s:%d: Received version number %@ from watch.",
			  __PRETTY_FUNCTION__, __LINE__, stla_version_to_string(ver));
	#endif
}

#pragma mark - Pebble Central delegate

- (void)pebbleCentral:(PBPebbleCentral *)central
	  watchDidConnect:(PBWatch *)watch
				isNew:(BOOL)isNew
{
	#if DEBUG
		NSLog(@"%s:%d: Pebble connected: %@", __PRETTY_FUNCTION__, __LINE__, watch.name);
	#endif
	
	self.connectedWatch = watch;
	
	// Declare a block here to minimize nesting.
	void (^appMessagesSupportedCallback)(PBWatch *watch, BOOL isAppMessagesSupported);
	appMessagesSupportedCallback = ^(PBWatch *watch, BOOL isAppMessagesSupported) {
		if (isAppMessagesSupported) {
			// Send our version number to the watch.
			[self sendVersionWithCompletion:^(PBWatch *__unused watch,
											  NSDictionary *__unused update,
											  NSError *__unused error) {
				// Send a request to the watch to send its version number over.
				[self sendVersion:stla_unknown_version_number
					   completion:^(PBWatch *watch,
									NSDictionary *__unused update,
									NSError *__unused error)
				 {
					 // Push out a notification to reflect the new connection status.
					 NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
					 [nc postNotificationName:STLAWatchConnectionStateChangeNotification
									   object:watch
									 userInfo:@{kWatchConnectionStateChangeNotificationBoolKey: @(YES)}];
				 }];
			}];
		} else {
			NSLog(@"Newly connected Pebble doesn't support AppMessage!");
			[self disconnectFromPebble];
		}
	};
	
	// Query the watch for version and compatibility info.
	// These calls must be done on the main thread.
	dispatch_async(dispatch_get_main_queue(), ^{
		[watch appMessagesGetIsSupported:appMessagesSupportedCallback];
	});
}

- (void)pebbleCentral:(PBPebbleCentral *)central
   watchDidDisconnect:(PBWatch *)watch
{
	#if DEBUG
		NSLog(@"%s:%d: Pebble disconnected: %@", __PRETTY_FUNCTION__, __LINE__, watch.name);
	#endif
	
	if (self.connectedWatch == watch || [watch isEqual:self.connectedWatch]) {
		[self disconnectFromPebble];
		self.connectedWatch = nil;
	}
}

#pragma mark - Pebble watch delegate

- (void)watchDidDisconnect:(PBWatch *)watch {
	#if DEBUG
		NSLog(@"%s:%d: The Pebble disconnected.", __PRETTY_FUNCTION__, __LINE__);
	#endif
}

- (void)watch:(PBWatch *)watch handleError:(NSError *)error {
	NSLog(@"%s:%d: The Pebble caught an error: %@", __PRETTY_FUNCTION__, __LINE__, error);
}

- (void)watchWillResetSession:(PBWatch *)watch {
	#if DEBUG
		NSLog(@"%s:%d: The Pebble's internal EASession will be reset.", __PRETTY_FUNCTION__, __LINE__);
	#endif
}

- (void)watchDidOpenSession:(PBWatch *)watch {
	#if DEBUG
		NSLog(@"%s:%d: The Pebble's internal EASession was opened.", __PRETTY_FUNCTION__, __LINE__);
	#endif
}

- (void)watchDidCloseSession:(PBWatch *)watch {
	#if DEBUG
		NSLog(@"%s:%d: The Pebble's internal EASession was closed.", __PRETTY_FUNCTION__, __LINE__);
	#endif
}

@end
