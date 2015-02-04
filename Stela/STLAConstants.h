//
//  Constants.h
//  Stela
//
//  Created by Justin Loew on 1/5/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

#ifndef Stela_Constants_h
#define Stela_Constants_h

extern NSUInteger const CURRENT_PATCH_VERSION;

/// The Alchemy API key that powers Stela's ability to parse webpages into text.
extern NSString * const API_KEY;
/// The URL of the Alchemy API that powers Stela's ability to parse webpages into text.
extern NSString * const API_URL;

/// The UUID of the Pebble app, given by its metadata. Used by PebbleKit to open the app.
extern NSString * const stelaUUIDString;

/// The URL to load on the app's first launch.
extern NSString * const kDefaultURL;

/// The maximum size of a message that a Pebble can send or receive, in bytes.
extern NSInteger const kPebbleMaxMessageSize; // actual max size is ~255, but I'll allow for overhead

/// The name of the notification that is fired each time a watch connects or
/// disconnects.
extern NSString * const STLAWatchConnectionStateChangeNotification;

/// The key for the @c userInfo dictionary of the notification. The value for this key
/// is a BOOL representing whether the watch is now connected, wrapped in a NSNumber.
extern NSString * const kWatchConnectionStateChangeNotificationBoolKey;


/// The keys used for sending messages between the watch and the phone.
typedef NS_ENUM(NSInteger, AppMessageKey) {
	/// For reporting an error, as a string.
	ERROR_KEY = -8,
	
	/// For sending the version of Stela as a string. E.g., "255.255.255"
	/// To query the value, send a version beginning with a zero ("0.x.x").
	STELA_VERSION_KEY,
	
	/// Reset command.
	/// Sent by the phone when a new article will be sent.
	/// Never sent by the watch.
	RESET_KEY,
	
	/// Sent by the phone to set the maximum number of words in each block.
	/// Sent by the watch to query the maximum block size.
	TEXT_BLOCK_SIZE_KEY,
	
	/// Sent by the phone to convey the number of blocks in the entire article.
	/// Sent by the watch to query the block count.
	TOTAL_NUMBER_OF_BLOCKS_KEY,
	
	/// The number of words contained in just the current message.
	/// Sent by the phone, in the same message as an array of strings.
	/// Never sent by the watch.
	APPMESG_NUM_WORDS_KEY,
	
	/// Used to send the index of the first word within the text block.
	/// In other words, it's where in the block to insert the words in this message.
	/// Sent by the phone, in the same message as an array of strings.
	/// Never sent by the watch.
	APPMESG_WORD_START_INDEX_KEY,
	
	/// Holds the index of the block that the words in the current message belong in.
	/// Sent by the phone, in the same message as an array of strings.
	/// Never sent by the watch.
	APPMESG_BLOCK_NUMBER_KEY
};

/// Used for sending version numbers to and from the watch. Ex.: "1.0.31"
typedef struct {
	/// The major version number.
	unsigned char major;
	/// The minor version number.
	unsigned char minor;
	/// The patch version number.
	unsigned char patch;
} Version;

extern const Version stla_unknown_version_number;

/// Gets the current version of the Stela iOS app.
///
/// @return The current version of the Stela iOS app.
Version stla_get_iOS_Stela_version();

/// Checks whether a version is equal to the unknown version number.
/// @remarks "@a Duuuuuuude. If the version number is, like, unknown, then how could we possibly know if our version is, like, the same, man?"
///
/// @param versionNumber The version number to check.
/// @return YES if the version is unknown, NO otherwise.
BOOL stla_version_is_unknown(const Version versionNumber);

/// Turns an NSString into a version number.
///
/// @param versionString The string form of the version number.
/// @return The Version form of the string, or 0.255.255 on error.
Version stla_string_to_version(NSString *versionString);

/// Turns a Version into a string.
///
/// @param versionNumber The version number to turn into an NSString.
/// @return The string form of the version.
NSString * stla_version_to_string(const Version versionNumber);

#endif
