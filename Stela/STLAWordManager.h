//
//  STLAWordManager.h
//  Stela
//
//  Created by Justin Loew on 1/30/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

@import Foundation;


@interface STLAWordManager : NSObject

/// The singleton word manager.
///
/// @return The singleton word manager.
+ (STLAWordManager *)defaultManager;


/// The blocks of text that make up an article.
/// This is an array of arrays, with each array containing up to @c blockSize words.
@property (nonatomic) NSMutableArray *textBlocks;

/// Organizes the contents of the given array before storing it. A @c nil parameter
/// deletes the existing blocks.
///
/// @discussion
/// This method takes either an array of arrays that need their dimensions changed, or
/// it takes an array of words that need to be placed into the 2-D array. A good example
/// of the first use case would be to reorganize the current value of @c textBlocks into
/// a new 2-D array when the block size is changed. An example of the other use case
/// would be to pass in an entire article as a 1-D array of words.
///
/// @param textBlocks The strings or blocks to be organized.
- (void)setTextBlocks:(NSMutableArray *)textBlocks;

/// The maximum number of words in each of the text blocks.
@property (nonatomic) NSUInteger blockSize;


/// Create an array of words of a given size.
///
/// @param numBytes The desired maximum size of the array, in bytes.
/// @param blockIndex The index of the block to take words from.
/// @param wordIndex The index of the first word to add to the array.
/// @return An array containing one or more @c NSString@/cs, one for each word, whose total size is as close to @c numBytes as possible without going over. If there are no words left in the block, a parameter is invalid, or the first word is larger than @c numBytes bytes, returns @c nil;
- (NSArray *)getWordsOfSize:(NSUInteger)numBytes
		   fromBlockAtIndex:(NSUInteger)blockIndex
			fromWordAtIndex:(NSUInteger)wordIndex;

@end
