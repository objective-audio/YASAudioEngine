//
//  yas_audio_file_utils_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_file_utils_tests : XCTestCase

@end

@implementation yas_audio_file_utils_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_wave_file_settings_int16 {
    double const sampleRate = 44100;
    uint32_t const channels = 2;
    uint32_t const bitDepth = 16;

    NSDictionary *settings = (__bridge NSDictionary *)audio::wave_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)test_wave_file_settings_float32 {
    double const sampleRate = 48000;
    uint32_t const channels = 4;
    uint32_t const bitDepth = 32;

    NSDictionary *settings = (__bridge NSDictionary *)audio::wave_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)test_aiff_settings_int16 {
    double const sampleRate = 32000;
    uint32_t const channels = 2;
    uint32_t const bitDepth = 16;

    NSDictionary *settings = (__bridge NSDictionary *)audio::aiff_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)test_aiff_settings_float32 {
    double const sampleRate = 96000;
    uint32_t const channels = 3;
    uint32_t const bitDepth = 32;

    NSDictionary *settings = (__bridge NSDictionary *)audio::aiff_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)test_aac_settings {
    double const sampleRate = 48000;
    uint32_t const channels = 2;
    uint32_t const bitDepth = 16;
    AVAudioQuality const encoderQuality = AVAudioQualityMedium;
    uint32_t const bitRate = 128000;
    uint32_t const bitDepthHint = 16;
    AVAudioQuality const converterQuality = AVAudioQualityMax;

    NSDictionary *settings = (__bridge NSDictionary *)audio::aac_settings(
        sampleRate, channels, bitDepth, encoderQuality, bitRate, bitDepthHint, converterQuality);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatMPEG4AAC));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));

    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVEncoderAudioQualityKey], @(encoderQuality));
    XCTAssertEqualObjects(settings[AVEncoderBitRateKey], @(bitRate));
    XCTAssertEqualObjects(settings[AVEncoderBitDepthHintKey], @(bitDepthHint));
    XCTAssertEqualObjects(settings[AVSampleRateConverterAudioQualityKey], @(converterQuality));
}

- (void)test_to_audio_file_type_id_from_file_type {
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::three_gpp), kAudioFile3GPType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::three_gpp2), kAudioFile3GP2Type);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::aifc), kAudioFileAIFCType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::aiff), kAudioFileAIFFType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::amr), kAudioFileAMRType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::ac3), kAudioFileAC3Type);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::mpeg_layer3), kAudioFileMP3Type);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::core_audio_format), kAudioFileCAFType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::mpeg4), kAudioFileMPEG4Type);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::apple_m4a), kAudioFileM4AType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type_cf_string::wave), kAudioFileWAVEType);
}

- (void)test_to_file_type_from_audio_file_type_id {
    XCTAssertEqual(audio::to_file_type(kAudioFile3GPType), audio::file_type::three_gpp);
    XCTAssertEqual(audio::to_file_type(kAudioFile3GP2Type), audio::file_type::three_gpp2);
    XCTAssertEqual(audio::to_file_type(kAudioFileAIFCType), audio::file_type::aifc);
    XCTAssertEqual(audio::to_file_type(kAudioFileAIFFType), audio::file_type::aiff);
    XCTAssertEqual(audio::to_file_type(kAudioFileAMRType), audio::file_type::amr);
    XCTAssertEqual(audio::to_file_type(kAudioFileAC3Type), audio::file_type::ac3);
    XCTAssertEqual(audio::to_file_type(kAudioFileMP3Type), audio::file_type::mpeg_layer3);
    XCTAssertEqual(audio::to_file_type(kAudioFileCAFType), audio::file_type::core_audio_format);
    XCTAssertEqual(audio::to_file_type(kAudioFileMPEG4Type), audio::file_type::mpeg4);
    XCTAssertEqual(audio::to_file_type(kAudioFileM4AType), audio::file_type::apple_m4a);
    XCTAssertEqual(audio::to_file_type(kAudioFileWAVEType), audio::file_type::wave);

    XCTAssertThrows(audio::to_file_type(0));
}

- (void)test_to_file_type_from_string {
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::three_gpp)), audio::file_type::three_gpp);
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::three_gpp2)), audio::file_type::three_gpp2);
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::aifc)), audio::file_type::aifc);
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::aiff)), audio::file_type::aiff);
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::amr)), audio::file_type::amr);
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::ac3)), audio::file_type::ac3);
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::mpeg_layer3)), audio::file_type::mpeg_layer3);
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::core_audio_format)),
                   audio::file_type::core_audio_format);
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::mpeg4)), audio::file_type::mpeg4);
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::apple_m4a)), audio::file_type::apple_m4a);
    XCTAssertEqual(audio::to_file_type(to_string(audio::file_type::wave)), audio::file_type::wave);

    XCTAssertThrows(audio::to_file_type(""));
}

- (void)test_to_string_from_file_type {
    XCTAssertEqual(to_string(audio::file_type::three_gpp), "public.3gpp");
    XCTAssertEqual(to_string(audio::file_type::three_gpp2), "public.3gpp2");
    XCTAssertEqual(to_string(audio::file_type::aifc), "public.aifc-audio");
    XCTAssertEqual(to_string(audio::file_type::aiff), "public.aiff-audio");
    XCTAssertEqual(to_string(audio::file_type::amr), "org.3gpp.adaptive-multi-rate-audio");
    XCTAssertEqual(to_string(audio::file_type::ac3), "public.ac3-audio");
    XCTAssertEqual(to_string(audio::file_type::mpeg_layer3), "public.mp3");
    XCTAssertEqual(to_string(audio::file_type::core_audio_format), "com.apple.coreaudio-format");
    XCTAssertEqual(to_string(audio::file_type::mpeg4), "public.mpeg-4");
    XCTAssertEqual(to_string(audio::file_type::apple_m4a), "com.apple.m4a-audio");
    XCTAssertEqual(to_string(audio::file_type::wave), "com.microsoft.waveform-audio");
}

@end
