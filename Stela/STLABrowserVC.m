//
//  BrowserViewController.m
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014-2019 Justin Loew. All rights reserved.
//

#import "TargetConditionals.h"
@import UIKit;
@import WebKit;

#import <AFNetworking.h>
#import <MBProgressHUD/MBProgressHUD.h>

#import "AppDelegate.h"
#import "JLUtils.h"
#import "STLAConstants.h"
#import "STLAMessenger.h"
#import "STLABrowserVC.h"


__unused static const CGFloat kNavBarHeight = 52.0f;
static const CGFloat kLabelHeight = 14.0f;
static const CGFloat kMargin = 10.0f;
static const CGFloat kSpacer = 2.0f;
static const CGFloat kLabelFontSize = 12.0f;
static const CGFloat kAddressHeight = 24.0f;

typedef NSUInteger AppUpdateVersionNumber;
__unused static const AppUpdateVersionNumber kNullAppVersion = 0;
static const AppUpdateVersionNumber kCurrentAppVersion = 1;
static const AppUpdateVersionNumber kReplacementAppVersion = 2;
static NSString *const kMostRecentIgnoredUpdateVersionNumberKey = @"most recently ignored update version number";


@interface STLABrowserViewController () <UIGestureRecognizerDelegate, WKNavigationDelegate>

@property (nonatomic) WKWebView *webView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *back;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *stop;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *refresh;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *sendToPebble;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *forward;

@property (strong, nonatomic) UILabel *pageTitle;
@property (strong, nonatomic) UITextField *addressField;

@property (strong, nonatomic) MBProgressHUD *progressHUD;

@property (strong, nonatomic) id<NSObject> watchConnectionObserver;

@property (nonatomic) BOOL hasPresentedAppListingMigrationPromptSinceAppLaunch;

- (BOOL)shouldPresentAppListingMigrationPromptForUpdateVersion:(AppUpdateVersionNumber)updateVersion;
- (void)presentAppListingMigrationPromptForUpdateVersion:(AppUpdateVersionNumber)updateVersion;

- (void)browseForward:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)browseBack:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)loadRequestFromString:(NSString *)urlString;
- (void)updateButtons;
- (void)loadRequestFromAddressField:(id)addressField;
- (void)updateAddress:(NSString *)newAddress;
- (void)updateTitle:(NSString *)newTitle;

@end

#pragma mark -
@implementation STLABrowserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds];
	self.webView.navigationDelegate = self;
	self.webView.allowsBackForwardNavigationGestures = YES;
	
	// Update the title and URL automatically.
	[self.webView addObserver:self
				   forKeyPath:NSStringFromSelector(@selector(title))
					  options:0
					  context:nil];
	[self.webView addObserver:self
				   forKeyPath:NSStringFromSelector(@selector(URL))
					  options:0
					  context:nil];
	[self.webView addObserver:self
				   forKeyPath:@"loading"
					  options:0
					  context:nil];
	
	[self.view addSubview:self.webView];
	NSString *sysver = [UIDevice currentDevice].systemVersion;
	NSInteger systemVersion = [[[sysver componentsSeparatedByString:@"."] firstObject] integerValue];
	if (systemVersion >= 7) {
		self.webView.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
	}
	
	// Create the page title label.
	UINavigationBar *navBar = self.navigationController.navigationBar;
	CGRect labelFrame = CGRectMake(kMargin, kSpacer, navBar.bounds.size.width - 2*kMargin, kLabelHeight);
	UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont systemFontOfSize:kLabelFontSize];
	label.textAlignment = NSTextAlignmentCenter;
	[navBar addSubview:label];
	self.pageTitle = label;
	
	// Load the saved URL, if any.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *savedURL = [defaults stringForKey:@"savedURL"];
	if (!savedURL || [savedURL isEqualToString:@""]) {
		savedURL = kDefaultPebbleURL;
	#if DEBUG
	} else {
		NSLog(@"Used saved URL (%@).", savedURL);
	#endif
	}
	
	// Create the address bar.
	CGRect addressFrame = CGRectMake(kMargin, kSpacer * 2.0 + kLabelHeight, labelFrame.size.width, kAddressHeight);
	UITextField *address = [[UITextField alloc] initWithFrame:addressFrame];
	address.text = savedURL;
	[address setAutocapitalizationType:UITextAutocapitalizationTypeNone];
	[address setAutocorrectionType:UITextAutocorrectionTypeNo];
	address.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	address.borderStyle = UITextBorderStyleRoundedRect;
	address.font = [UIFont systemFontOfSize:17];
	address.enablesReturnKeyAutomatically = YES;
	//*
	address.keyboardType = UIKeyboardTypeURL;
	address.returnKeyType = UIReturnKeyGo;
	/*/
	address.keyboardType = UIKeyboardTypeWebSearch;
	//*/
	address.clearButtonMode = UITextFieldViewModeWhileEditing;
	[address addTarget:self
				action:@selector(loadRequestFromAddressField:)
	  forControlEvents:UIControlEventEditingDidEndOnExit];
	[navBar addSubview:address];
	self.addressField = address;
	
	// Spins when we send data to the watch.
	self.progressHUD = nil;
    
    // This will be set up later in -viewDidAppear:.
    self.watchConnectionObserver = nil;
    
    self.hasPresentedAppListingMigrationPromptSinceAppLaunch = NO;
	
	// Start up by loading the Pebble Wikipedia page.
    [self loadRequestFromString:self.addressField.text];
    
    
    #ifdef DEBUG
    // [defaults removeObjectForKey:kMostRecentIgnoredUpdateVersionNumberKey];
    #endif
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Register for notifications to update the UI when the watch connects or disconnects.
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    self.watchConnectionObserver = [nc addObserverForName:STLAWatchConnectionStateChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSNumber *connected = note.userInfo[kWatchConnectionStateChangeNotificationBoolKey];
        self.sendToPebble.enabled = [connected boolValue];
    }];
    
    // Prompt to update to a newer version of this app, if necessary.
    if ([self shouldPresentAppListingMigrationPromptForUpdateVersion:kReplacementAppVersion]) {
        [self presentAppListingMigrationPromptForUpdateVersion:kReplacementAppVersion];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    // Notification center.
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self.watchConnectionObserver];
    self.watchConnectionObserver = nil;
    
    [super viewWillDisappear:animated];
}

- (void)dealloc {
	// KVO.
	[self.webView removeObserver:self forKeyPath:NSStringFromSelector(@selector(title))];
	[self.webView removeObserver:self forKeyPath:NSStringFromSelector(@selector(URL))];
	[self.webView removeObserver:self forKeyPath:@"loading"];
}

#pragma mark App Migration Stuff

- (BOOL)shouldPresentAppListingMigrationPromptForUpdateVersion:(AppUpdateVersionNumber)updateVersion {
    if (self.hasPresentedAppListingMigrationPromptSinceAppLaunch) {
        return NO;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *lastIgnoredUpdateVersion = [defaults objectForKey:kMostRecentIgnoredUpdateVersionNumberKey];
    AppUpdateVersionNumber lastVersionForWhichWeShouldNotPrompt = MAX([lastIgnoredUpdateVersion unsignedIntegerValue], kCurrentAppVersion);
    // Only present the prompt if we'd be prompting for a newer version than the most recent ignored version.
    return updateVersion > lastVersionForWhichWeShouldNotPrompt;
}

- (void)presentAppListingMigrationPromptForUpdateVersion:(AppUpdateVersionNumber)updateVersion {
    UIAlertController *__block alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Update Available", nil)
                                                                             message:NSLocalizedString(@"An update to this app is available in the App Store.", nil)
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    // Add a "Learn More" action.
    UIAlertAction *learnMoreAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Learn More", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
        // Show a sheet to explain the transition to the user and provide a link to the new version of the app.
        // The next time this app is launched, this prompt will appear again.
        [self performSegueWithIdentifier:@"showMigrationEducation" sender:self];
    }];
    [alertController addAction:learnMoreAction];
    
    // Add a "Remind Me Later" action.
    UIAlertAction *remindMeLaterAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Remind Me Later", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *_Nonnull action) {
        // If we've previously recorded that we should never prompt for a certain previous update, leave that record as-is. This means that the next time the app is launched, this prompt will appear again because this update is newer than the last ignored update.
        // Do nothing.
    }];
    [alertController addAction:remindMeLaterAction];
    // [alertController setPreferredAction:remindMeLaterAction];
    
    // Add a "Don't Show Again" action.
    UIAlertAction *dontShowAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Don't Show Again", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
        // Record that we shouldn't prompt for this update again, then dismiss the alert.
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:[NSNumber numberWithUnsignedInteger:updateVersion]
                     forKey:kMostRecentIgnoredUpdateVersionNumberKey];
    }];
    [alertController addAction:dontShowAgainAction];
    
    [self presentViewController:alertController animated:YES completion:^{}];
    self.hasPresentedAppListingMigrationPromptSinceAppLaunch = YES;
}

#pragma mark Browser Stuff

- (IBAction)browseForward:(id)sender {
	if (self.webView.canGoForward) {
		[self.webView goForward];
	}
}

- (IBAction)browseBack:(id)sender {
	if (self.webView.canGoBack) {
		[self.webView goBack];
	}
}

- (IBAction)refresh:(id)sender {
	[self.webView reloadFromOrigin];
}

- (IBAction)stopLoading:(id)sender {
	[self.webView stopLoading];
}

- (void)loadRequestFromAddressField:(id)addressField {
	NSString *urlString = [addressField text];
	[self loadRequestFromString:urlString];
}

- (void)loadRequestFromString:(NSString *)urlString {
	NSURL *url = [NSURL URLWithString:urlString];
	// Add http:// if necessary.
	if (!url.scheme) {
		NSString *modifiedURLString = [NSString stringWithFormat:@"http://%@", url];
		url = [NSURL URLWithString:modifiedURLString];
	}
//	// Make sure the URL is reachable to check if we should perform a web search instead.
//	if (url check) {
//		<#statements#>
//	}
//	// If it's not a valid URL, do a web search instead.
//	if (!url) {
//		NSString *escapedQuery = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//		NSString *searchURL = [NSString stringWithFormat:@"https://google.com/search?q=%@", escapedQuery];
//		url = [NSURL URLWithString:searchURL];
//	}
	// Load the URL.
	if (url) {
		NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
		[self.webView loadRequest:urlRequest];
	} else {
		JLERROR("Unable to create URL (attempt: %@) from original string: %@", url, urlString);
	}
}

- (void)updateAddress:(NSString *)newAddress {
	self.addressField.text = newAddress;
	AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
	appDelegate.currentURL = newAddress;
}

- (void)updateButtons {
	self.forward.enabled = self.webView.canGoForward;
	self.back.enabled = self.webView.canGoBack;
	self.stop.enabled = self.webView.loading;
#if TARGET_IPHONE_SIMULATOR
	self.sendToPebble.enabled = YES;
#endif
}

- (void)updateTitle:(NSString *)newTitle {
	self.pageTitle.text = newTitle;
}

#pragma mark Watch Stuff

- (IBAction)sendToPebble:(id)sender {
	// Start a spinner so the user knows something's happening.
	self.progressHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	self.progressHUD.labelText = NSLocalizedString(@"Sending...", nil);
	self.progressHUD.minShowTime = 3;  // Keep the spinner onscreen for at least 3 seconds.
	self.progressHUD.dimBackground = YES;
	
	void (^requestFailed)(NSString *errorMessage) = ^void(NSString *errorMessage) {
		// Make my life just a little easier.
		NSLog(@"Failed to get text for article at URL: %@", self.addressField.text);
		
		// Hide the HUD.
		[self.progressHUD hide:YES];
		// Tell the user that retrieval failed.
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error Retrieving Webpage", nil)
																				 message:errorMessage ?: @""
																		  preferredStyle:UIAlertControllerStyleAlert];
		[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", nil)
															style:UIAlertActionStyleDefault
														  handler:nil]];
		[self presentViewController:alertController animated:YES completion:nil];
	};
	
	// Turn the webpage into an array of words.
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
	NSDictionary *requestParameters = @{ @"url": self.addressField.text,
										 @"apikey": API_KEY,
										 @"outputMode": @"json" };
	[manager GET:API_URL parameters:requestParameters
		 success:^(AFHTTPRequestOperation *operation, id responseObject) {
			 // Turn the responseObject into useful text.
			 if (![responseObject isKindOfClass:[NSDictionary class]]) {  // Safety check.
				 NSLog(@"Error: responseObject is not a dictionary.");
				 requestFailed(NSLocalizedString(@"Stela's servers aren't able to turn this page into text right now. Please try again later.", nil));
				 return;
			 }
			 
			 NSDictionary *responseDict = (NSDictionary *)responseObject;
			 NSString *blockText = responseDict[@"text"];
			 if (!blockText) {  // Safety check.
				 NSLog(@"Error: couldn't get text from JSON response.");
				 requestFailed(NSLocalizedString(@"Unable to get text from website. Stela doesn't work on PDFs, documents, or images.", nil));
				 return;
			 }
			 
			 // This is an array of all the words on the page.
			 NSArray *words = [blockText componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			 
			 // Send the words to the watch.
			 STLAMessenger *messenger = [STLAMessenger defaultMessenger];
			 [messenger sendStringsToWatch:words completion:^(BOOL success) {
				 if (success) {
					 NSLog(@"Successfully sent words to the watch.");
					 // Hide the HUD.
					 [self.progressHUD hide:YES];
				 } else {
					 NSLog(@"ERROR. Failed to send words to the watch.");
//					 requestFailed(NSLocalizedString(@"Something went wrong. Please wait a few moments, then try again.", nil));
				 }
			 }];
		 }
		 failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			 NSLog(@"Failed to get text from current website: %@", error);
			 requestFailed(NSLocalizedString(@"Unable to get text from website. Stela doesn't work on PDFs, documents, or images.", nil));
		 }];
}

#pragma mark WKNavigationDelegate

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	[self updateButtons];
	
	// Save the new URL.
	AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
	appDelegate.currentURL = [webView.URL absoluteString];
	self.addressField.text = appDelegate.currentURL;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateButtons];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation
	  withError:(NSError *)error
{
	#if DEBUG
		NSLog(@"%s Error: %@", __PRETTY_FUNCTION__, error);
	#endif
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateButtons];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation
	  withError:(NSError *)error
{
//	// Check if we were unable to load a web search as a URL.
//	if (error.code == -1003) {
//		// A server with the specified hostname could not be found.
//		NSURL *failingURL = error.userInfo[NSURLErrorFailingURLErrorKey];
//		
//		NSString *searchURL = [NSString stringWithFormat:@"https://google.com/search?q=%@", ]
//	}
	
	// It's a real error.
	#if DEBUG
		NSLog(@"%s Error: %@", __PRETTY_FUNCTION__, error);
	#endif
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateButtons];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	if (object == self.webView) {
		if ([keyPath isEqualToString:NSStringFromSelector(@selector(title))]) {
			[self updateTitle:self.webView.title];
		} else if ([keyPath isEqualToString:NSStringFromSelector(@selector(URL))]) {
			[self updateAddress:[self.webView.URL absoluteString]];
		} else if ([keyPath isEqualToString:@"loading"]) {
			[self updateButtons];
		}
	}
}

@end
