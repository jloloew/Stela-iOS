//
//  STLAMigrationEducationViewController.m
//  Stela
//
//  Created by Justin Loew on 8/22/19.
//  Copyright © 2019 Justin Loew. All rights reserved.
//

#import "STLAMigrationEducationViewController.h"


static NSString *const kAppStoreLinkForRebrandedApp = @"https://www.apple.com";  // FIXME: Fill in this link.


@interface STLAMigrationEducationViewController ()

@property (weak, nonatomic) IBOutlet UITextView *explanationTextView;

@end


@implementation STLAMigrationEducationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)doneButtonTapped:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES
                                                      completion:nil];
}

- (IBAction)viewOnAppStoreButtonTapped:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kAppStoreLinkForRebrandedApp]];
}

@end
