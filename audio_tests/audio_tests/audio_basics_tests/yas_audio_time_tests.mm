//
//  yas_audio_time_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

static NSInteger testCount = 8;

@interface yas_audio_time_tests : XCTestCase

@end

@implementation yas_audio_time_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testCreateAudioTimeWithHostTime {
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime];
        auto yas_time = audio::time(hostTime);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(avTime.sampleRate == yas_time.sample_rate(), @"");
    }
}

- (void)testCreateAudioTimeSampleTime {
    for (NSInteger i = 0; i < testCount; i++) {
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithSampleTime:sampleTime atRate:rate];
        auto yas_time = audio::time(sampleTime, rate);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(test::is_equal(avTime.sampleRate, yas_time.sample_rate(), 0.00001), @"");
    }
}

- (void)testCreateAudioTimeWithHostTimeAndSampleTime {
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        auto yas_time = audio::time(hostTime, sampleTime, rate);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(test::is_equal(avTime.sampleRate, yas_time.sample_rate(), 0.00001), @"");
    }
}

- (void)testConvert {
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();

        NSTimeInterval avSec = [AVAudioTime secondsForHostTime:hostTime];
        NSTimeInterval yasSec = audio::seconds_for_host_time(hostTime);
        XCTAssertTrue(avSec == yasSec, @"");
        uint64_t avHostTime = [AVAudioTime hostTimeForSeconds:avSec];
        uint64_t yasHostTime = audio::host_time_for_seconds(yasSec);
        XCTAssertTrue(avHostTime == yasHostTime, @"");
    }
}

- (void)testExtrapolateTime {
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        auto yas_time = audio::time(hostTime, sampleTime, rate);
        int64_t sampleTime2 = sampleTime + arc4random();
        AVAudioTime *avTime2 = [AVAudioTime timeWithSampleTime:sampleTime2 atRate:rate];
        auto yas_time2 = audio::time(sampleTime2, rate);
        AVAudioTime *avExtraplateTime = [avTime2 extrapolateTimeFromAnchor:avTime];
        auto yas_extraplate_time = yas_time2.extrapolate_time_from_anchor(yas_time);

        XCTAssertTrue([self compareAudioTimeStamp:avExtraplateTime to:yas_extraplate_time]);
        XCTAssertTrue(avTime2.sampleRate == yas_time2.sample_rate());
    }
}

- (void)test_compare_objc_to_cpp {
    for (NSInteger i = 0; i < testCount; i++) {
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithSampleTime:sampleTime atRate:rate];
        auto yas_time = to_time(avTime);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(test::is_equal(avTime.sampleRate, yas_time.sample_rate(), 0.00001), @"");
    }
}

- (void)test_compare_cpp_to_objc {
    for (NSInteger i = 0; i < testCount; i++) {
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        auto yas_time = audio::time(sampleTime, rate);
        AVAudioTime *avTime = to_objc_object(yas_time);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(test::is_equal(avTime.sampleRate, yas_time.sample_rate(), 0.00001), @"");
    }
}

- (void)test_bool {
    audio::time time{100};

    XCTAssertTrue(time);

    audio::time null_time{nullptr};

    XCTAssertFalse(null_time);
}

- (void)test_host_time {
    const uint64_t host_time = 1000;
    audio::time time{host_time};

    XCTAssertTrue(time.is_host_time_valid());
    XCTAssertTrue(time.host_time() == 1000);
}

- (void)test_sample_time {
    const int64_t sample_time = 2000;
    const double sample_rate = 48000.0;
    audio::time time{sample_time, sample_rate};

    XCTAssertTrue(time.is_sample_time_valid());
    XCTAssertTrue(time.sample_time() == 2000);
}

- (void)test_equal {
    audio::time const time1{4000, 48000.0};
    audio::time const time3{8000, 48000.0};

    XCTAssertTrue(time1 == time1);
    XCTAssertFalse(time1 == time3);
}

- (void)test_equal_null_false {
    const audio::time time1{4000, 48000.0};
    const audio::time time2{nullptr};
    const audio::time time3{nullptr};

    XCTAssertFalse(time1 == time2);
    XCTAssertFalse(time2 == time1);
    XCTAssertFalse(time2 == time2);
}

#pragma mark -

- (BOOL)compareAudioTimeStamp:(AVAudioTime *)avTime to:(audio::time &)yasTime {
    AudioTimeStamp avTimeStamp = avTime.audioTimeStamp;
    const AudioTimeStamp &yasTimeStamp = yasTime.audio_time_stamp();
    return test::is_equal(&avTimeStamp, &yasTimeStamp);
}

@end
