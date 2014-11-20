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

- (NSString *)getParsedText;	// Injects JavaScript
- (void)browseForward:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)browseBack:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)loadRequestFromString:(NSString *)urlString;
- (void)updateButtons;
- (void)loadRequestFromAddressField:(id)addressField;
- (void)updateAddress:(NSString*)newAddress;
- (void)updateTitle:(NSString*)newTitle;

@end

@implementation BrowserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.webView.navigationDelegate = self;
	
	NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"ArticlePull" ofType:@"js"];
	NSError *__autoreleasing *error = NULL;
	NSString *js = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:error];
	if (error) {
		NSLog(@"Error loading JavaScript from file to parse article.");
		[[[UIAlertView alloc] initWithTitle:@"Error"
									message:@"Error loading JavaScript from file to parse article."
								   delegate:self
						  cancelButtonTitle:@"OK"
						  otherButtonTitles:nil] show];
	}
#if DEBUG
	NSLog(@"Loaded js successfully");
#endif
	
	WKUserScript *script = [[WKUserScript alloc] initWithSource:js
												  injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
											   forMainFrameOnly:YES];
	WKUserContentController *contentController = [[WKUserContentController alloc] init];
	[contentController addUserScript:script];
	WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
	config.userContentController = contentController;
	self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds
									  configuration:config];
	self.webView.allowsBackForwardNavigationGestures = YES;
	
	self.view = self.webView;
	NSString *sysver = [UIDevice currentDevice].systemVersion;
	NSInteger systemVersion = [[sysver componentsSeparatedByString:@"."][0] integerValue];
	if (systemVersion >= 7) {
		self.webView.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
	}
	
	/* Enable swipe to go forward/back */
	UIScreenEdgePanGestureRecognizer *bezelForwardSwipeGestureRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(browseForward:)];
	UIScreenEdgePanGestureRecognizer *bezelBackSwipeGestureRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(browseBack:)];
	bezelForwardSwipeGestureRecognizer.edges = UIRectEdgeRight;
	bezelBackSwipeGestureRecognizer.edges = UIRectEdgeLeft;
	bezelForwardSwipeGestureRecognizer.delegate = self;
	bezelBackSwipeGestureRecognizer.delegate = self;
	[self.view addGestureRecognizer:bezelForwardSwipeGestureRecognizer];
	[self.view addGestureRecognizer:bezelBackSwipeGestureRecognizer];
	// hack to avoid scrolling the web view instead of doing the back/forward action
	UIView *invisibleForwardScrollPreventer = [UIView new];
	UIView *invisibleBackScrollPreventer = [UIView new];
	invisibleForwardScrollPreventer.frame = CGRectMake(0, 0, 10, self.view.frame.size.height);
	invisibleBackScrollPreventer.frame = CGRectMake(self.view.frame.size.width - 10, 0, 10, self.view.frame.size.height);
	[self.view addSubview:invisibleForwardScrollPreventer];
	[self.view addSubview:invisibleBackScrollPreventer];
	
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
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSString* savedURL = [defaults stringForKey:@"savedURL"];
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

#pragma mark Browser Stuff

- (void)browseForward:(UIScreenEdgePanGestureRecognizer *)recognizer {
	if (recognizer.state == UIGestureRecognizerStateEnded) {
		if (self.webView.canGoForward) {
			[self.webView goForward];
		}
	}
}

- (void)browseBack:(UIScreenEdgePanGestureRecognizer *)recognizer {
	if (recognizer.state == UIGestureRecognizerStateEnded) {
		if (self.webView.canGoBack) {
			[self.webView goBack];
		}
	}
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

- (void)updateAddress:(NSString*)newAddress {
	self.addressField.text = newAddress;
	AppDelegate* appDelegate = [UIApplication sharedApplication].delegate;
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

- (void)updateTitle:(NSString*)newTitle {
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
					 NSLog(@"Successfully send words to Pebble.");
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

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	[self updateButtons];
	
	// save the new URL
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	appDelegate.currentURL = [webView.URL absoluteString];
	//TODO: Use KVO to update the address bar
	self.addressField.text = appDelegate.currentURL;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateButtons];
	[self updateTitle:webView.title];
	[self updateAddress:webView.URL.absoluteString];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateButtons];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateButtons];
}

@end
