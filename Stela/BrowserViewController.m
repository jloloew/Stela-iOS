//
//  BrowserViewController.m
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import "BrowserViewController.h"
@import UIKit;
@import WebKit;
#import "TargetConditionals.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import <AFNetworking.h>

//static const CGFloat kNavBarHeight = 52.0f;
static const CGFloat kLabelHeight = 14.0f;
static const CGFloat kMargin = 10.0f;
static const CGFloat kSpacer = 2.0f;
static const CGFloat kLabelFontSize = 12.0f;
static const CGFloat kAddressHeight = 24.0f;


@interface BrowserViewController () <UIGestureRecognizerDelegate, WKNavigationDelegate, PebbleConnectionNoticeDelegate>

@property (nonatomic) WKWebView *webView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *back;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *stop;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *refresh;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *sendToPebble;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *forward;

@property (strong, nonatomic) UILabel *pageTitle;
@property (strong, nonatomic) UITextField *addressField;

@property (strong, nonatomic) MBProgressHUD *progressHUD;

- (void)browseForward:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)browseBack:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)loadRequestFromString:(NSString *)urlString;
- (void)updateButtons;
- (void)loadRequestFromAddressField:(id)addressField;
- (void)updateAddress:(NSString *)newAddress;
- (void)updateTitle:(NSString *)newTitle;

@end

@implementation BrowserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds];
	self.webView.navigationDelegate = self;
	self.webView.allowsBackForwardNavigationGestures = YES;
	
	// update the title and URL automatically
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
	
	/* Create the page title label */
	UINavigationBar *navBar = self.navigationController.navigationBar;
	CGRect labelFrame = CGRectMake(kMargin, kSpacer, navBar.bounds.size.width - 2*kMargin, kLabelHeight);
	UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont systemFontOfSize:kLabelFontSize];
	label.textAlignment = NSTextAlignmentCenter;
	[navBar addSubview:label];
	self.pageTitle = label;
	
	/* load the saved URL, if any */
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *savedURL = [defaults stringForKey:@"savedURL"];
	if (!savedURL || [savedURL isEqualToString:@""]) {
		savedURL = @"https://en.wikipedia.org/wiki/Pebble_watch";
#if DEBUG
		NSLog(@"Used default URL.");
	} else {
		NSLog(@"Used saved URL (%@).", savedURL);
#endif
	}
	
	/* Create the address bar */
	CGRect addressFrame = CGRectMake(kMargin, kSpacer * 2.0 + kLabelHeight, labelFrame.size.width, kAddressHeight);
	UITextField *address = [[UITextField alloc] initWithFrame:addressFrame];
	address.text = savedURL;
	[address setAutocapitalizationType:UITextAutocapitalizationTypeNone];
	[address setAutocorrectionType:UITextAutocorrectionTypeNo];
	address.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	address.borderStyle = UITextBorderStyleRoundedRect;
	address.font = [UIFont systemFontOfSize:17];
	address.keyboardType = UIKeyboardTypeURL;
	address.clearButtonMode = UITextFieldViewModeWhileEditing;
	[address addTarget:self
				action:@selector(loadRequestFromAddressField:)
	  forControlEvents:UIControlEventEditingDidEndOnExit];
	[navBar addSubview:address];
	self.addressField = address;
	
	// spins when we send data to the Pebble
	self.progressHUD = nil;
	
	// For Pebble
	((AppDelegate *)([UIApplication sharedApplication].delegate)).delegate = self;
	
	// Start up by loading the Pebble Wikipedia page
    [self loadRequestFromString:self.addressField.text];
}

- (void)dealloc {
	[self.webView removeObserver:self forKeyPath:NSStringFromSelector(@selector(title))];
	[self.webView removeObserver:self forKeyPath:NSStringFromSelector(@selector(URL))];
	[self.webView removeObserver:self forKeyPath:@"loading"];
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
	if (!url.scheme) {
		NSString *modifiedURLString = [NSString stringWithFormat:@"http://%@", url];
		url = [NSURL URLWithString:modifiedURLString];
	}
	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
	[self.webView loadRequest:urlRequest];
}

- (void)updateAddress:(NSString *)newAddress {
	self.addressField.text = newAddress;
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	appDelegate.currentURL = newAddress;
}

- (void)updateButtons {
	self.forward.enabled = self.webView.canGoForward;
	self.back.enabled = self.webView.canGoBack;
	self.stop.enabled = self.webView.loading;
#if TARGET_IPHONE_SIMULATOR
	self.sendToPebble.enabled = YES;
#else // TARGET_IPHONE_SIMULATOR
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	self.sendToPebble.enabled = [appDelegate.connectedWatch isConnected];
#endif // TARGET_IPHONE_SIMULATOR
}

- (void)updateTitle:(NSString *)newTitle {
	self.pageTitle.text = newTitle;
}

#pragma mark Watch Stuff

- (IBAction)sendToPebble:(id)sender {
	// Start a spinner so the user knows something's happening
	self.progressHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	self.progressHUD.labelText = @"Sending...";
	self.progressHUD.minShowTime = 3;
	self.progressHUD.dimBackground = YES;
	
	// turn the webpage into an array of words
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
	NSDictionary *requestParameters = @{@"url": self.addressField.text,
										@"apikey": @"f6687a0711a74306ac45cb89c08b026fe0cd03d6",
										@"outputMode": @"json"
										};
	[manager GET:@"http://access.alchemyapi.com/calls/url/URLGetText" parameters:requestParameters
		 success:^(AFHTTPRequestOperation *operation, id responseObject) {
			 
			 // turn the responseObject into useful text
			 if (![responseObject isKindOfClass:[NSDictionary class]]) {
				 NSLog(@"Error: responseObject is not a dictionary.");
				 // hide the HUD
				 [self.progressHUD hide:YES];
				 return;
			 }
			 NSDictionary *responseDict = responseObject;
			 NSString *blockText = [responseDict objectForKey:@"text"];
			 if (!blockText) {
				 NSLog(@"Error: couldn't get text from JSON response.");
				 // hide the HUD
				 [self.progressHUD hide:YES];
				 return;
			 }
			 NSArray *words = [blockText componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			 // send the words to the Pebble
			 AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
			 [appDelegate sendStringsToPebble:words completion:^(BOOL success) {
				 if (success) {
					 NSLog(@"Successfully sent words to Pebble.");
					 // hide the HUD
					 [self.progressHUD hide:YES];
				 } else {
					 NSLog(@"ERROR. Failed to send words to Pebble.");
					 
					 [[[UIAlertView alloc] initWithTitle:@"Error"
												 message:@"Unable to send words to Pebble."
												delegate:nil
									   cancelButtonTitle:@"Ok"
									   otherButtonTitles:nil] show];
					 
					 // hide the HUD
					 [self.progressHUD hide:YES];
				 }
			 }];
		 }
		 failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			 NSLog(@"Failed to get text from current website: %@", error);
			 // hide the HUD
			 [self.progressHUD hide:YES];
		 }];
}

- (void)watch:(PBWatch *)watch didChangeConnectionStateToConnected:(BOOL)isConnected {
	self.sendToPebble.enabled = isConnected;
}

#pragma mark WKNavigationDelegate

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	[self updateButtons];
	
	// save the new URL
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
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
