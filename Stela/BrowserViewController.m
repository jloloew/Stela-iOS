//
//  BrowserViewController.m
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import "BrowserViewController.h"
#ifdef __APPLE__
	#import "TargetConditionals.h"
#endif // __APPLE__
#import <MBProgressHUD/MBProgressHUD.h>

//static const CGFloat kNavBarHeight = 52.0f;
static const CGFloat kLabelHeight = 14.0f;
static const CGFloat kMargin = 10.0f;
static const CGFloat kSpacer = 2.0f;
static const CGFloat kLabelFontSize = 12.0f;
static const CGFloat kAddressHeight = 24.0f;


@interface BrowserViewController () <UIWebViewDelegate, UIGestureRecognizerDelegate, PebbleConnectionNoticeDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
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
- (void)updateAddress:(NSURLRequest *)request;
- (void)updateTitle:(UIWebView *)aWebView;

@end

@implementation BrowserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// web view
	self.webView.delegate = self;
	self.webView.scalesPageToFit = YES;
	// This makes it work on iOS 6
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
	
	/* Create the address bar */
	CGRect addressFrame = CGRectMake(kMargin, kSpacer * 2.0 + kLabelHeight, labelFrame.size.width, kAddressHeight);
	UITextField *address = [[UITextField alloc] initWithFrame:addressFrame];
	address.text = @"https://en.wikipedia.org/wiki/Pebble_watch";
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

/**	Return the result of running Dave's JavaScript, which supposedly pulls the currently loaded article from the page.
 */
- (NSString *)getParsedText {
	NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"ArticlePull" ofType:@"js"];
	NSError *__autoreleasing *error = NULL;
	NSString *js = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:error];
	if (error) {
		NSLog(@"Error loading JavaScript from file to parse article.");
		[[[UIAlertView alloc] initWithTitle:@"Error" message:@"Error loading JavaScript from file to parse article." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
		return @"Error";
	}
	
#if DEBUG
	NSLog(@"Loaded js successfully");
#endif
/*	// This is unnecessary because I just need to send the URL
	// Wait until the page is done loading before trying to do anything
	while ([self.webView isLoading]) {
#if DEBUG
		NSLog(@"getParsedText is waiting for the WebView to finish loading");
#endif
		sleep(1);
	}
*/
	
//	js = [NSString stringWithFormat:js, [NSString stringWithFormat:@"\"%@\"", self.addressField.text]];
	[self.webView stringByEvaluatingJavaScriptFromString:js];
	NSString *jsCall = [NSString stringWithFormat:@"getText(%@)", self.addressField.text];
	NSString *parsedText = [self.webView stringByEvaluatingJavaScriptFromString:jsCall];
//	NSString *parsedText = [self.webView stringByEvaluatingJavaScriptFromString:js];
#if DEBUG
	NSLog(@"BrowserViewController getParsedText (line %d): Text returned by call to the JS parser: %@", __LINE__, parsedText);
#endif
	// Work around Dave's incompetence. Haha, Dave's incontinent. Wait...
	return parsedText;
}

- (void)displayLoadingSpinner {
//	UIActivityIndicatorView
}

- (void)hideLoadingSpinner {
	
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

- (void)updateAddress:(NSURLRequest *)request {
	NSURL *url = [request mainDocumentURL];
	NSString *absoluteString = [url absoluteString];
	self.addressField.text = absoluteString;
}

- (void)updateButtons {
	self.forward.enabled = self.webView.canGoForward;
	self.back.enabled = self.webView.canGoBack;
	self.stop.enabled = self.webView.loading;
#if TARGET_IPHONE_SIMULATOR
	self.sendToPebble.enabled = YES;
#else // TARGET_IPHONE_SIMULATOR
	self.sendToPebble.enabled = [((AppDelegate *)[[UIApplication sharedApplication] delegate]).connectedWatch isConnected];
#endif // TARGET_IPHONE_SIMULATOR
}

- (void)updateTitle:(UIWebView *)aWebView {
	NSString *pageTitle = [aWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
	self.pageTitle.text = pageTitle;
}

#pragma mark Watch Stuff

- (IBAction)sendToPebble:(id)sender {
	//TODO: fix all this, see what works.
	
	/*
	// Instead of a spinner, show an alert.
	[[[UIAlertView alloc] initWithTitle:@"Success"
								message:@"Article now sending to Pebble."
							   delegate:nil
					  cancelButtonTitle:@"Gee, thanks!"
					  otherButtonTitles:nil]
	 show];
	*/
	
	// Start a spinner so the user knows something's happening
	self.progressHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	self.progressHUD.labelText = @"Sending...";
	self.progressHUD.minShowTime = 3;
	self.progressHUD.dimBackground = YES;
	
	// create a new WebView to run our JS
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	UIWebView *aWebView = [[UIWebView alloc] init];
	aWebView.hidden = YES;
	[aWebView loadHTMLString:@"<script src=\"ArticlePull.js\"></script>" baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
//	NSString *function = [[NSString alloc] initWithFormat: @"getText(%@)", self.addressField.text];
//	NSString *result = [awebView stringByEvaluatingJavaScriptFromString:function];
//	[appDelegate pushString:result toWatch:appDelegate.connectedWatch];
//	UIColor *original = self.sendToPebble.tintColor;
//	self.sendToPebble.tintColor = [UIColor greenColor];
//	sleep(2);
//	self.sendToPebble.tintColor = original;
//	return;
	
	[appDelegate sendURL:self.addressField.text toWatch:appDelegate.connectedWatch];	// send the URL to the Pebble
	
	// hide the HUD
	[self.progressHUD hide:YES];
}

- (void)watch:(PBWatch *)watch didChangeConnectionStateToConnected:(BOOL)isConnected {
	self.sendToPebble.enabled = isConnected;
}


#pragma mark UIWebViewDelegate methods

- (void)webViewDidStartLoad:(UIWebView *)webView {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	[self updateButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateButtons];
	[self updateTitle:webView];
	[self updateAddress:[webView request]];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateButtons];
	[[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
#if DEBUG
	NSLog(@"%@", error.localizedDescription);
#endif
}

@end
