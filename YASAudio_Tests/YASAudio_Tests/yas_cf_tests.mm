//
//  yas_cf_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_cf_utils.h"

@interface yas_cf_tests : XCTestCase

@end

@implementation yas_cf_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testRetaining
{
    CFMutableArrayRef _property_array = nullptr;
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 1, nullptr);

    XCTAssertEqual(CFGetRetainCount(array), 1);

    yas::set_cf_property(_property_array, array);

    XCTAssertEqual(_property_array, array);
    XCTAssertEqual(CFGetRetainCount(array), 2);

    CFRelease(array);

    XCTAssertEqual(CFGetRetainCount(array), 1);

    @autoreleasepool
    {
        CFMutableArrayRef array2 = yas::get_cf_property(_property_array);

        XCTAssertEqual(_property_array, array2);
        XCTAssertEqual(CFGetRetainCount(array), 2);
    }

    XCTAssertEqual(CFGetRetainCount(array), 1);

    CFRelease(array);
}

@end
