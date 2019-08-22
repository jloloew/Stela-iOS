//
//  STLAWatch.h
//  Stela
//
//  Created by Justin Loew on 4/10/15.
//  Copyright (c) 2015-2019 Justin Loew. All rights reserved.
//

@import Foundation;

#import "STLAConstants.h"


#pragma mark - STLAWatch Protocol

/// An abstract smartwatch device.
@protocol STLAWatch <NSObject>

/// Whether the watch is currently connected to this iOS device.
///
/// @return The current connection status.
@required
- (STLAConnectionStatus)connectionStatus;

/// Start the process of processing and sending words to the watch.
///
/// @param wordsToSend The words to be sent.
/// @return @c YES if successful, @c NO on error.
- (BOOL)setReadingMaterial:(NSArray *)wordsToSend;

@end
