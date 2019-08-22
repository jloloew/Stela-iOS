//
//  STLAWordManager.m
//  Stela
//
//  Created by Justin Loew on 1/30/15.
//  Copyright (c) 2015-2019 Justin Loew. All rights reserved.
//

#import "STLAMessenger.h"
#import "STLAWordManager.h"


/// The default block size (measured in words, not bytes).
static NSUInteger const kDefaultBlockSize = 200;  // In words, not bytes.
static NSString * const kSharedWordsFileName = @"sharedWords";


@implementation STLAWordManager

+ (STLAWordManager *)defaultManager
{
	static STLAWordManager *_defaultManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultManager = [[STLAWordManager alloc] init];
    });
	return _defaultManager;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		self.blockSize = kDefaultBlockSize;  // In words, not bytes.
	}
	return self;
}

- (void)setTextBlocks:(NSMutableArray *)textBlocks {
	NSAssert(self.blockSize != 0, @"%s:%d: The size of a block of text should not be zero.",
			 __PRETTY_FUNCTION__, __LINE__);
	
	// Check whether textBlocks is an array of arrays of words,
	// or whether it's an array of words that needs to be blockified.
	if (!textBlocks || textBlocks.count == 0) {
		_textBlocks = nil;
		// Delete current text blocks from the watch.
		[[STLAMessenger defaultMessenger] resetWatch];
		return;
	}
	
	NSMutableArray *allWords = [NSMutableArray array];  // This will be a 1-D array of all the words.
	
	if ([textBlocks[0] isKindOfClass:[NSArray class]]) {
		// textBlocks is a 2-D array of words that must be reordered.
		// ObjC fast enumeration doesn't guarantee order, must use old school for loop.
		for (NSUInteger i = 0; i < textBlocks.count; i++) {
			NSArray *textBlock = textBlocks[i];
			[allWords addObjectsFromArray:textBlock];
		}
	} else if ([textBlocks[0] isKindOfClass:[NSString class]]) {
		// textBlocks is a 1-D array of words.
		for (NSUInteger i = 0; i < textBlocks.count; i++) {
			// Make sure each "word" in allWords is actually a valid word.
			if ([textBlocks[i] isKindOfClass:[NSString class]]) {
				if (![textBlocks[i] isEqualToString:@""]) {
					[allWords addObject:textBlocks[i]];
				}
			}
		}
	} else {
		NSLog(@"%s:%d: Parameter contains neither blocks nor words. (Actual class is %@)",
			  __PRETTY_FUNCTION__, __LINE__, [textBlocks[0] class]);
		return;
	}
	
	// allWords is now a 1-D array of all the words to be put into blocks.
	NSUInteger numBlocks = ((allWords.count - 1) / self.blockSize) + 1;
	_textBlocks = [NSMutableArray arrayWithCapacity:numBlocks];
	_textBlocks[0] = [NSMutableArray arrayWithCapacity:self.blockSize];
	// Fill the blocks.
	NSUInteger wordNum = 0, blockNum = 0, i = 0;
	while (wordNum < allWords.count) {
		// Create new blocks as needed.
		if (i >= self.blockSize) {
			i = 0;
			blockNum++;
			_textBlocks[blockNum] = [NSMutableArray arrayWithCapacity:self.blockSize];
		}
		// Add the next word to the current block and increment the counters.
		_textBlocks[blockNum][i++] = allWords[wordNum++];
	}
	
	#if DEBUG
		NSLog(@"%s:%d: Added %lu words, resulting in %lu blocks holding %lu words each.",
			  __PRETTY_FUNCTION__, __LINE__, (unsigned long)allWords.count,
			  (unsigned long)_textBlocks.count, (unsigned long)self.blockSize);
	#endif
}

- (NSArray *)getWordsOfSize:(NSUInteger)numBytes
		   fromBlockAtIndex:(NSUInteger)blockIndex
			fromWordAtIndex:(NSUInteger)wordIndex
{
	NSMutableArray *words = nil;  ///< Holds the words to get.
	
	if (blockIndex < self.textBlocks.count) {
		NSArray *textBlock = self.textBlocks[blockIndex];
		if (wordIndex < textBlock.count) {
			words = [NSMutableArray array];
			NSUInteger currentSize = 0;  ///< The size of all the words in @c words, in bytes.
			NSUInteger wIndex = wordIndex;
			do {
				NSString *word = textBlock[wIndex];
				NSUInteger wordSize = [word lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
				if (wordSize == 0) {
					break;
				} else {
					wordSize += 1;  // Account for the string's NULL-terminator.
				}
				if (currentSize + wordSize > numBytes) {
					// Stop before the array gets too big.
					break;
				}
				// Add the word to the array.
				[words addObject:word];
				currentSize += wordSize;
			} while (++wIndex < textBlock.count);
		}
	}
	
	// Return nil instead of an empty array.
	if (words.count == 0) {
		words = nil;
	}
	
	return words;
}

@end
