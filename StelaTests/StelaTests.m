//
//  StelaTests.m
//  StelaTests
//
//  Created by Justin Loew on 4/11/14.
//  Copyright (c) 2014 Justin Loew. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AppDelegate.h"

@interface StelaTests : XCTestCase

@end

@implementation StelaTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFormatString{
	NSString *test = @"";
	NSString *result = [AppDelegate formatString:test];
	XCTAssertEqualObjects(test, result, @"empty string broke");
	test = @"testa";
	result = [AppDelegate formatString:test];
	XCTAssertEqualObjects(test, result, @"testa broke");
	test = @"testa testa";
	result = [AppDelegate formatString:test];
	XCTAssertEqualObjects(test, result, @"testa testa broke");
	test = @"supercalifredgelisticexpialidociouszzzzzzzzzzzzzzzzzzzzzzzzz+zzzzzzzzzzzzzzzzzzzzgfdsafffffff++++++++++++++++++++++++++++";
	result = [AppDelegate formatString:test];
	XCTAssertEqualObjects(result, @"supercalifredgelisticexpialidociouszzzzzzzzzzzzzzzzzzzzzzzzz- +zzzzzzzzzzzzzzzzzzzgfdsafffffff++++++++++++++++++++++++++++", @"supercalifre... broke");
}

- (void)testExample
{
    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end
