//
//  BrowserViewController.h
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface BrowserViewController : UIViewController <PebbleConnectionNoticeDelegate>

- (IBAction)sendToPebble:(id)sender;

@end
