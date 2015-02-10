//
//  STLAWordManager.m
//  Stela
//
//  Created by Justin Loew on 1/30/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

#import "STLAMessenger.h"
#import "STLAWordManager.h"


#define kDefaultBlockSize 300 // in words, not bytes


@implementation STLAWordManager

+ (STLAWordManager *)defaultManager
{
	static STLAWordManager *_defaultManager = nil;
	if (!_defaultManager) {
		_defaultManager = [[STLAWordManager alloc] init];
	}
	return _defaultManager;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		self.blockSize = kDefaultBlockSize; // in words, not bytes
	}
	return self;
}

- (void)setTextBlocks:(NSMutableArray *)textBlocks {
	NSAssert(self.blockSize != 0, @"The size of a block of text is zero.");
	// check whether textBlocks is an array of arrays of words,
	// or whether it's an array of words that needs to be blockified
	if (!textBlocks || textBlocks.count == 0) {
		_textBlocks = nil;
		// delete current text blocks from the watch
		[[STLAMessenger defaultMessenger] resetWatch];
		return;
	}
	
	NSMutableArray *allWords; // this will be a 1-D array of all the words
	
	if ([textBlocks[0] isKindOfClass:[NSArray class]]) {
		// textBlocks is a 2-D array of words that must be reordered
		allWords = [NSMutableArray array];
		// ObjC fast enumeration doesn't guarantee order, must use old school for loop
		for (NSUInteger i = 0; i < textBlocks.count; i++) {
			NSArray *textBlock = textBlocks[i];
			[allWords addObjectsFromArray:textBlock];
		}
	} else if ([textBlocks[0] isKindOfClass:[NSString class]]) {
		// textBlocks is a 1-D array of words
		allWords = textBlocks;
	} else {
		NSLog(@"%s: Parameter contains neither blocks nor words. (Actual class is %@)",
			  __PRETTY_FUNCTION__, [textBlocks[0] class]);
		return;
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
		NSLog(@"%s: Added %lu words, resulting in %lu blocks holding %lu words each.",
			  __PRETTY_FUNCTION__, (unsigned long)allWords.count,
			  (unsigned long)_textBlocks.count, (unsigned long)self.blockSize);
	#endif
}

- (NSArray *)getWordsOfSize:(NSUInteger)numBytes
		   fromBlockAtIndex:(NSUInteger)blockIndex
			fromWordAtIndex:(NSUInteger)wordIndex
{
	NSMutableArray *words = nil;
	
	if (blockIndex < self.textBlocks.count) {
		NSArray *wordArray = self.textBlocks[blockIndex];
		if (wordIndex < wordArray.count) {
			words = [NSMutableArray array];
			NSUInteger currentSize = 0;
			NSUInteger wIndex = wordIndex;
			do {
				NSString *word = wordArray[wIndex];
				NSUInteger wordSize = [word lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
				if (wordSize == 0) {
					break;
				}
				if (currentSize + wordSize > numBytes) {
					break;
				}
				// add the word to the array
				[words addObject:word];
				currentSize += wordSize;
			} while (++wIndex < wordArray.count);
		}
	}
	
	// return nil instead of an empty array
	if (words.count == 0) {
		words = nil;
	}
	return words;
}

@end
