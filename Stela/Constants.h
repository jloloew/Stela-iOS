//
//  Constants.h
//  Stela
//
//  Created by Justin Loew on 1/5/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

#ifndef Stela_Constants_h
#define Stela_Constants_h

#define API_KEY						@"f6687a0711a74306ac45cb89c08b026fe0cd03d6"

// When sending values for these keys, an invalid (negative) value represents a query for the current value, and a valid (positive) value represents a command to set the value.
/* Example blocks:
 0: @["The", "quick", "brown"],
 1: @["fox", "jumps", "over"],
 2: @["the", "lazy", "black"],
 3: @["dog."]
 
 Each row is a block, starting with row 0. This example contains 3 blocks. PEB_TEXT_BLOCK_NUMBER_KEY is the key for transmitting/receiving the block numbers.
 Each row contains the same number of words (except possibly the last block/row), in this case 3. PEB_TEXT_BLOCK_SIZE_KEY is the key for transmitting/receiving this number.
 */
#define PEB_TEXT_BLOCK_NUMBER_KEY	-1//((unsigned)-1)//0xFFFFFFFF // -1
#define PEB_TEXT_BLOCK_SIZE_KEY		-2//((unsigned)-2)//0xFFFFFFFE // -2

#endif
