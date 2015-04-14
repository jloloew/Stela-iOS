//
//  STLAWatch.h
//  Stela
//
//  Created by Justin Loew on 4/10/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

#import "STLAConstants.h"
@import Foundation;


#pragma mark - STLAWatch Protocol

/// An abstract smartwatch device.
@protocol STLAWatch <NSObject>

/// Whether the watch is currently connected to this iOS device.
///
/// @return the current connection status.
@required
- (STLAConnectionStatus)connectionStatus;

/// Start the process of processing and sending words to the watch.
///
/// @param wordsToSend the words to be sent.
/// @return @c YES if successful, @c NO on error.
- (BOOL)setReadingMaterial:(NSArray *)wordsToSend;

@end
