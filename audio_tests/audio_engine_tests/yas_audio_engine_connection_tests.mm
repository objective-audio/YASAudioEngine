//
//  yas_audio_connection_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_connection_tests : XCTestCase

@end

@implementation yas_audio_connection_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_connention_success {
    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node_object src_obj;
    test::audio_test_node_object dst_obj;
    uint32_t const src_bus = 0;
    uint32_t const dst_bus = 1;

    auto connection = test::connection(*src_obj.node(), src_bus, *dst_obj.node(), dst_bus, format);

    XCTAssertTrue(connection.source_node() == src_obj.node());
    XCTAssertTrue(connection.source_bus() == src_bus);
    XCTAssertTrue(connection.destination_node() == dst_obj.node());
    XCTAssertTrue(connection.destination_bus() == dst_bus);
    XCTAssertTrue(connection.format() == format);

    XCTAssertTrue(src_obj.node()->manageable().output_connection(src_bus) == connection);
    XCTAssertTrue(dst_obj.node()->manageable().input_connection(dst_bus) == connection);
}

- (void)test_create_null {
    audio::engine::connection connection{nullptr};

    XCTAssertFalse(connection);
}

- (void)test_remove_nodes {
    auto format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    test::audio_test_node_object src_obj;
    test::audio_test_node_object dst_obj;
    uint32_t const src_bus = 0;
    uint32_t const dst_bus = 1;

    auto connection = test::connection(*src_obj.node(), src_bus, *dst_obj.node(), dst_bus, format);

    connection.remove_nodes();

    XCTAssertFalse(connection.source_node());
    XCTAssertFalse(connection.destination_node());
}

- (void)test_remove_nodes_separately {
    auto format = audio::format({.sample_rate = 8000.0, .channel_count = 2});
    test::audio_test_node_object src_obj;
    test::audio_test_node_object dst_obj;
    uint32_t const src_bus = 0;
    uint32_t const dst_bus = 1;

    auto connection = test::connection(*src_obj.node(), src_bus, *dst_obj.node(), dst_bus, format);

    connection.remove_source_node();

    XCTAssertFalse(connection.source_node());
    XCTAssertTrue(connection.destination_node());

    connection.remove_destination_node();

    XCTAssertFalse(connection.destination_node());
}

- (void)test_empty_connection {
    audio::engine::connection connection(nullptr);

    XCTAssertFalse(connection.source_node());
    XCTAssertFalse(connection.destination_node());
}

@end
