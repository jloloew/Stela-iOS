//
//  BrowserViewController.m
//  Stela
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import "BrowserViewController.h"

//static const CGFloat kNavBarHeight = 52.0f;
static const CGFloat kLabelHeight = 14.0f;
static const CGFloat kMargin = 10.0f;
static const CGFloat kSpacer = 2.0f;
//static const CGFloat kLabelFontSize = 12.0f;
static const CGFloat kAddressHeight = 24.0f;


@interface BrowserViewController () <UIWebViewDelegate, PebbleConnectionNoticeDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *back;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *stop;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *refresh;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *sendToPebble;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *forward;

@property (strong, nonatomic) UILabel *pageTitle;
@property (strong, nonatomic) UITextField *addressField;

- (NSString*)getParsedText;	// Injects JavaScript
- (void)loadRequestFromString:(NSString*)urlString;
- (void)updateButtons;
- (void)loadRequestFromAddressField:(id)addressField;
- (void)updateAddress:(NSURLRequest*)request;
- (void)updateTitle:(UIWebView*)aWebView;
- (void)informError:(NSError*)error;

@end

@implementation BrowserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.webView.delegate = self;
	self.webView.scalesPageToFit = YES;
	/* Create the page title label */
	UINavigationBar *navBar = self.navigationController.navigationBar;
	CGRect labelFrame = CGRectMake(kMargin, kSpacer, navBar.bounds.size.width - 2*kMargin, kLabelHeight);
	UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont systemFontOfSize:12];
	label.textAlignment = NSTextAlignmentCenter;
	[navBar addSubview:label];
	self.pageTitle = label;
	/* Create the address bar */
	CGRect addressFrame = CGRectMake(kMargin, kSpacer*2.0 + kLabelHeight, labelFrame.size.width, kAddressHeight);
	UITextField *address = [[UITextField alloc] initWithFrame:addressFrame];
	address.text = @"https://en.m.wikipedia.org/wiki/Bubble_gum";
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
	
	((AppDelegate*)([UIApplication sharedApplication].delegate)).delegate = self;

    [self loadRequestFromString:self.addressField.text];
}

/**	Return the result of running Dave's JavaScript, which supposedly
 *	pulls the currently loaded article from the page.
 */

- (NSString*)getParsedText {
	//TODO: Remove before release
	[((AppDelegate*) [[UIApplication sharedApplication] delegate]) testAppMessageWithURLString:self.addressField.text];
	return @"";
	
	
	NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"ArticlePull" ofType:@"js"];
	NSError *__autoreleasing *error = NULL;
	NSString *js = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:NULL];
	if (error == NULL) {
		NSLog(@"Loaded js successfully");
		// Wait until the page is done loading before trying to do anything
		while ([self.webView isLoading]) {
			if(debug)
				NSLog(@"getParsedText is waiting for the WebView to finish loading");
			sleep(1);
		}
//		js = [NSString stringWithFormat:js, [NSString stringWithFormat:@"\"%@\"", self.addressField.text]];
		[self.webView stringByEvaluatingJavaScriptFromString:js];
		NSString *jsCall = [NSString stringWithFormat:@"getText(%@)", self.addressField.text];
		NSString *parsedText = [self.webView stringByEvaluatingJavaScriptFromString:jsCall];
//		NSString *parsedText = [self.webView stringByEvaluatingJavaScriptFromString:js];
		if (debug) {
			NSLog(@"Dave's next failed attempt: %@", parsedText);
		}
		// Work around Dave's incompetence. Haha, Dave's incontinent. Wait...
		if(debug && [parsedText isEqualToString:@""])
			return @"This is a test article. It's quite articulate. It's about the immaculate conception.";
		return parsedText;
	} else {
		NSLog(@"Error loading js");
		return @"";
	}
}

#pragma mark Browser Stuff

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
	self.sendToPebble.enabled = [((AppDelegate*)[[UIApplication sharedApplication] delegate]).connectedWatch isConnected];
}

- (void)updateTitle:(UIWebView *)aWebView {
	NSString *pageTitle = [aWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
	self.pageTitle.text = pageTitle;
}

- (void)informError:(NSError *)error {
	UIAlertView *alertView = [[UIAlertView alloc]
	 initWithTitle:NSLocalizedString(@"Error", @"Title for error alert.")
	 message:error.localizedDescription delegate:nil
	 cancelButtonTitle:NSLocalizedString(@"OK", @"OK button in error alert.")
	 otherButtonTitles:nil];
	[alertView show];
}

#pragma mark Watch Stuff

- (IBAction)sendToPebble:(id)sender {
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	[appDelegate pushString:[self getParsedText] toWatch:appDelegate.connectedWatch];
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
	[self informError:error];
}
@end
