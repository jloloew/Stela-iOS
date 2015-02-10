//
//  STLAConstants.c
//  Stela
//
//  Created by Justin Loew on 1/30/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

@import Foundation;
#import "STLAConstants.h"


NSUInteger const CURRENT_PATCH_VERSION = 1;

NSString * const API_KEY = @"f6687a0711a74306ac45cb89c08b026fe0cd03d6";
NSString * const API_URL = @"http://access.alchemyapi.com/calls/url/URLGetText";

NSString * const stelaUUIDString = @"6db75b90-8dad-4490-94ca-0fef4296c78e";
// Stela_chessgecko	@"5bee74a1-b87d-4c62-adcf-8e4eec7a8d69"
// Stela_revamped	@"0b96289a-fed1-4970-9732-3f8425e616cb"
// original Stela	@"70580e72-b262-4971-992d-9f89053fad11"
// Stela-Linked		@"6db75b90-8dad-4490-94ca-0fef4296c78e"

NSString * const kDefaultURL = @"https://en.wikipedia.org/wiki/Pebble_watch";

NSUInteger const kPebbleMaxMessageSize = 100;

NSString * const STLAWatchConnectionStateChangeNotification		= @"com.justinloew.stela.watchConnectionStateChange";
NSString * const kWatchConnectionStateChangeNotificationBoolKey	= @"com.justinloew.stela.watchConnectionStateChange.isConnected";

const Version stla_unknown_version_number = { 0, 255, 255 };


Version stla_get_iOS_Stela_version() {
	NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
	NSString *verStr = infoDict[@"CFBundleShortVersionString"];
	verStr = [NSString stringWithFormat:@"%@.%hhu", verStr, (unsigned char)CURRENT_PATCH_VERSION]; // max version is 255, only use 8 bits
	return stla_string_to_version(verStr);
}

BOOL stla_version_is_unknown(const Version versionNumber) {
	return versionNumber.major == stla_unknown_version_number.major
		&& versionNumber.minor == stla_unknown_version_number.minor
		&& versionNumber.patch == stla_unknown_version_number.patch;
}

Version stla_string_to_version(NSString *versionString) {
	Version ver = stla_unknown_version_number;
	NSScanner *scanner = [NSScanner scannerWithString:versionString];
	NSInteger digits[] = { -1, -1, -1 };
	NSUInteger sizeOfDigits = sizeof(digits) / sizeof(digits[0]);
	// scan in all the digits
	for (NSUInteger i = 0; i < sizeOfDigits; i++) {
		if (![scanner scanInteger:&digits[i]]) {
			return ver; // don't set the watch's version number without a valid value
		}
		[scanner scanString:@"." intoString:nil]; // skip past the '.'
	}
	// set the version number
	ver = (Version) { digits[0], digits[1], digits[2] };
	return ver;
}

NSString * stla_version_to_string(const Version versionNumber) {
	return [NSString stringWithFormat:@"%d.%d.%d",
			versionNumber.major, versionNumber.minor,
			versionNumber.patch];
}
