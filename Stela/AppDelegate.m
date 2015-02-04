//
//  AppDelegate.m
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import "STLAConstants.h"
#import "STLAMessenger.h"
#import "AppDelegate.h"

const static int sMaxTextChunkLength = 60;
const static int sMaxWordLength = 8;
//const static int sPebbleStorageCapacity = 50000;	// 50KB

static NSString *SAVED_URL_KEY = @"savedURL";


@interface AppDelegate ()

/// Check whether a given URL is a link to open a page in Stela.
///
/// @param url The URL to validate.
/// @return YES if the URL is a valid URL, NO otherwise.
- (BOOL)isValidStelaURL:(NSURL *)url;

/// Takes a string and splits it into words.
///
/// @param text The string to split.
/// @return An array of all the words in @c text.
+ (NSArray *)chunkifyString:(NSString *)text;

/// Clean up a string for sending it to the watch.
/// It takes a word and inserts "- " if it's too long to fit on the screen of the watch.
///
/// @param chunk The word to clean up
/// @return The clean word.
+ (NSString *)formatString:(NSString *)chunk;

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
	
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// close the session so other apps can use Pebble too
	[[STLAMessenger defaultMessenger] disconnectFromPebble];
}


#pragma mark URL stuff


- (BOOL)isValidStelaURL:(NSURL *)url {
	if ([url isFileURL]) {
		return NO;
	}
	// check if the URL starts with "stela://" (or "stelas://" for HTTPS)
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
		urlString = [urlString stringByReplacingCharactersInRange:stelaRange
													   withString:@"https"];
	} else if ([[url scheme] isEqualToString:@"stela"]) { // http
		NSRange stelaRange = NSMakeRange(0, @"stela".length);
		urlString = [urlString stringByReplacingCharactersInRange:stelaRange
													   withString:@"http"];
	} else { // unreachable
		NSLog(@"%s:%d: %s: Unreachable code path reached!",
			  __FILE__, __LINE__, __PRETTY_FUNCTION__);
		exit(EXIT_FAILURE);
	}
	
	self.currentURL = urlString;
	
	return YES;
}


#pragma mark String Stuff

+ (NSArray *)chunkifyString:(NSString *)text {
	if ([text length] == 0) {
		return nil;
	}
	NSArray *_chunks = [text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSMutableArray *chunks = [NSMutableArray arrayWithArray:_chunks];
	for (NSInteger i = 0; i < chunks.count; i++) {
		chunks[i] = [AppDelegate formatString:chunks[i]];
		if ([chunks[i] length] > sMaxTextChunkLength) {
			[chunks insertObject:[chunks[i] substringFromIndex:sMaxTextChunkLength]
						 atIndex:(i + 1)];
			chunks[i] = [chunks[i] substringToIndex:sMaxTextChunkLength];
			i++;
		}
	}
	return chunks;
}


+ (NSString *)formatString:(NSString *)string {
	NSString *text = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([text length] <= sMaxWordLength) {
		return text;
	}
	static NSString *delimiterToBeInserted = @"- ";
	NSString *result = [string substringToIndex:(sMaxWordLength - [delimiterToBeInserted length])];	// Cut it short so there's room for the "- "
	NSRange range;
	range.location = 0;
	range.length = [result length];
	while (range.location < [text length]) {
		range.location += range.length;
		range.length = MIN(sMaxWordLength - [delimiterToBeInserted length],
						   [text length] - range.location - 1);
		result = [NSString stringWithFormat:@"%@%@%@",
				  result, delimiterToBeInserted, [text substringWithRange:range]];
	}
	return result;
}

@end
