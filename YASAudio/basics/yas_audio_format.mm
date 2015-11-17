//
//  yas_audio_format.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_format.h"
#include "yas_exception.h"
#include "yas_cf_utils.h"
#include <unordered_map>
#import <AVFoundation/AVFoundation.h>

using namespace yas;

#pragma mark - private

static std::string format_flags_string(const AudioStreamBasicDescription &asbd)
{
    const std::unordered_map<AudioFormatFlags, std::string> flags = {
        {kAudioFormatFlagIsFloat, "kAudioFormatFlagIsFloat"},
        {kAudioFormatFlagIsBigEndian, "kAudioFormatFlagIsBigEndian"},
        {kAudioFormatFlagIsSignedInteger, "kAudioFormatFlagIsSignedInteger"},
        {kAudioFormatFlagIsPacked, "kAudioFormatFlagIsPacked"},
        {kAudioFormatFlagIsAlignedHigh, "kAudioFormatFlagIsAlignedHigh"},
        {kAudioFormatFlagIsNonInterleaved, "kAudioFormatFlagIsNonInterleaved"},
        {kAudioFormatFlagIsNonMixable, "kAudioFormatFlagIsNonMixable"}};

    std::string string;
    for (auto &pair : flags) {
        if (asbd.mFormatFlags & pair.first) {
            if (string.size() != 0) {
                string += " | ";
            }
            string += pair.second;
        }
    }
    return string;
}

#pragma mark - impl

static const AudioStreamBasicDescription empty_asbd = {0};

class audio_format::impl
{
   public:
    AudioStreamBasicDescription asbd;
    yas::pcm_format pcm_format;
    bool standard;
};

#pragma mark - main

audio_format::audio_format(std::nullptr_t) : _impl(nullptr)
{
}

audio_format::audio_format(const AudioStreamBasicDescription &asbd) : _impl(std::make_shared<impl>())
{
    _impl->asbd = asbd;
    _impl->asbd.mReserved = 0;
    _impl->pcm_format = yas::pcm_format::other;
    _impl->standard = false;
    if (asbd.mFormatID == kAudioFormatLinearPCM) {
        if ((asbd.mFormatFlags & kAudioFormatFlagIsFloat) &&
            ((asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagsNativeEndian) &&
            (asbd.mFormatFlags & kAudioFormatFlagIsPacked)) {
            if (asbd.mBitsPerChannel == 64) {
                _impl->pcm_format = yas::pcm_format::float64;
            } else if (asbd.mBitsPerChannel == 32) {
                _impl->pcm_format = yas::pcm_format::float32;
                if (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
                    _impl->standard = true;
                }
            }
        } else if ((asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) &&
                   ((asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagsNativeEndian) &&
                   (asbd.mFormatFlags & kAudioFormatFlagIsPacked)) {
            UInt32 fraction = (asbd.mFormatFlags & kLinearPCMFormatFlagsSampleFractionMask) >>
                              kLinearPCMFormatFlagsSampleFractionShift;
            if (asbd.mBitsPerChannel == 32 && fraction == 24) {
                _impl->pcm_format = yas::pcm_format::fixed824;
            } else if (asbd.mBitsPerChannel == 16) {
                _impl->pcm_format = yas::pcm_format::int16;
            }
        }
    }
}

audio_format::audio_format(const CFDictionaryRef &settings) : audio_format(to_stream_description(settings))
{
}

audio_format::audio_format(const Float64 sample_rate, const UInt32 channel_count, const yas::pcm_format pcm_format,
                           const bool interleaved)
    : audio_format(to_stream_description(sample_rate, channel_count, pcm_format, interleaved))
{
}

bool audio_format::operator==(const audio_format &format) const
{
    return is_equal(stream_description(), format.stream_description());
}

bool audio_format::operator!=(const audio_format &format) const
{
    return !is_equal(stream_description(), format.stream_description());
}

audio_format::operator bool() const
{
    return _impl != nullptr;
}

bool audio_format::is_empty() const
{
    if (_impl) {
        return memcmp(&_impl->asbd, &empty_asbd, sizeof(AudioStreamBasicDescription)) == 0;
    } else {
        return true;
    }
}

bool audio_format::is_standard() const
{
    if (_impl) {
        return _impl->standard;
    } else {
        return false;
    }
}

yas::pcm_format audio_format::pcm_format() const
{
    if (_impl) {
        return _impl->pcm_format;
    } else {
        return pcm_format::other;
    }
}

UInt32 audio_format::channel_count() const
{
    if (_impl) {
        return _impl->asbd.mChannelsPerFrame;
    } else {
        return 0;
    }
}

UInt32 audio_format::buffer_count() const
{
    if (_impl) {
        return is_interleaved() ? 1 : _impl->asbd.mChannelsPerFrame;
    } else {
        return 0;
    }
}

UInt32 audio_format::stride() const
{
    if (_impl) {
        return is_interleaved() ? _impl->asbd.mChannelsPerFrame : 1;
    } else {
        return 0;
    }
}

Float64 audio_format::sample_rate() const
{
    if (_impl) {
        return _impl->asbd.mSampleRate;
    } else {
        return 0.0;
    }
}

bool audio_format::is_interleaved() const
{
    if (_impl) {
        return !(_impl->asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
    } else {
        return false;
    }
}

const AudioStreamBasicDescription &audio_format::stream_description() const
{
    if (_impl) {
        return _impl->asbd;
    } else {
        return empty_asbd;
    }
}

UInt32 audio_format::sample_byte_count() const
{
    if (_impl) {
        switch (_impl->pcm_format) {
            case yas::pcm_format::float32:
            case yas::pcm_format::fixed824:
                return 4;
            case yas::pcm_format::int16:
                return 2;
            case yas::pcm_format::float64:
                return 8;
            default:
                return 0;
        }
    } else {
        return 0;
    }
}

UInt32 audio_format::buffer_frame_byte_count() const
{
    return sample_byte_count() * stride();
}

CFStringRef audio_format::description() const
{
    std::string string;
    const AudioStreamBasicDescription &asbd = stream_description();
    string += "{\n";
    string += "    pcmFormat = " + to_string(pcm_format()) + ";\n";
    string += "    sampleRate = " + std::to_string(asbd.mSampleRate) + ";\n";
    string += "    bitsPerChannel = " + std::to_string(asbd.mBitsPerChannel) + ";\n";
    string += "    bytesPerFrame = " + std::to_string(asbd.mBytesPerFrame) + ";\n";
    string += "    bytesPerPacket = " + std::to_string(asbd.mBytesPerPacket) + ";\n";
    string += "    channelsPerFrame = " + std::to_string(asbd.mChannelsPerFrame) + ";\n";
    string += "    formatFlags = " + format_flags_string(stream_description()) + ";\n";
    string += "    formatID = " + to_string(yas::file_type_for_hfs_type_code(asbd.mFormatID)) + ";\n";
    string += "    framesPerPacket = " + std::to_string(asbd.mFramesPerPacket) + ";\n";
    string += "}\n";
    return yas::to_cf_object(string);
}

const audio_format &audio_format::null_format()
{
    static const audio_format _format;
    return _format;
}

#pragma mark - utility

std::string yas::to_string(const yas::pcm_format &pcm_format)
{
    switch (pcm_format) {
        case yas::pcm_format::float32:
            return "Float32";
        case yas::pcm_format::float64:
            return "Float64";
        case yas::pcm_format::int16:
            return "Int16";
        case yas::pcm_format::fixed824:
            return "Fixed8.24";
        case yas::pcm_format::other:
            return "Other";
    }
    return "";
}

AudioStreamBasicDescription yas::to_stream_description(const CFDictionaryRef &settings)
{
    AudioStreamBasicDescription asbd = {0};

    const CFNumberRef formatIDNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVFormatIDKey));
    if (formatIDNumber) {
        SInt64 value = 0;
        CFNumberGetValue(formatIDNumber, kCFNumberSInt64Type, &value);
        asbd.mFormatID = static_cast<UInt32>(value);
    }

    const CFNumberRef sampleRateNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVSampleRateKey));
    if (sampleRateNumber) {
        CFNumberGetValue(sampleRateNumber, kCFNumberDoubleType, &asbd.mSampleRate);
    }

    const CFNumberRef channelsNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVNumberOfChannelsKey));
    if (channelsNumber) {
        SInt64 value = 0;
        CFNumberGetValue(channelsNumber, kCFNumberSInt64Type, &value);
        asbd.mChannelsPerFrame = static_cast<UInt32>(value);
    }

    const CFNumberRef bitNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVLinearPCMBitDepthKey));
    if (bitNumber) {
        SInt64 value = 0;
        CFNumberGetValue(bitNumber, kCFNumberSInt64Type, &value);
        asbd.mBitsPerChannel = static_cast<UInt32>(value);
    }

    if (asbd.mFormatID == kAudioFormatLinearPCM) {
        asbd.mFormatFlags = kAudioFormatFlagIsPacked;

        const CFNumberRef isBigEndianNumber =
            (CFNumberRef)CFDictionaryGetValue(settings, (const void *)AVLinearPCMIsBigEndianKey);
        if (isBigEndianNumber) {
            SInt8 value = 0;
            CFNumberGetValue(isBigEndianNumber, kCFNumberSInt8Type, &value);
            if (value) {
                asbd.mFormatFlags |= kAudioFormatFlagIsBigEndian;
            }
        }

        const CFNumberRef isFloatNumber =
            static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVLinearPCMIsFloatKey));
        if (isFloatNumber) {
            SInt8 value = 0;
            CFNumberGetValue(isFloatNumber, kCFNumberSInt8Type, &value);
            if (value) {
                asbd.mFormatFlags |= kAudioFormatFlagIsFloat;
            } else {
                asbd.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
            }
        }

        const CFNumberRef isNonInterleavedNumber =
            static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVLinearPCMIsNonInterleaved));
        if (isNonInterleavedNumber) {
            SInt8 value = 0;
            CFNumberGetValue(isNonInterleavedNumber, kCFNumberSInt8Type, &value);
            if (value) {
                asbd.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
            }
        }
    }

    UInt32 size = sizeof(AudioStreamBasicDescription);
    yas_raise_if_au_error(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &asbd));

    return asbd;
}

AudioStreamBasicDescription yas::to_stream_description(const Float64 sample_rate, const UInt32 channel_count,
                                                       const yas::pcm_format pcm_format, const bool interleaved)
{
    if (pcm_format == yas::pcm_format::other || channel_count == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid argument. pcm_format(" +
                                    to_string(pcm_format) + ") channel_count(" + std::to_string(channel_count) + ")");
    }

    AudioStreamBasicDescription asbd = {
        .mSampleRate = sample_rate, .mFormatID = kAudioFormatLinearPCM,
    };

    asbd.mFormatFlags = kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;

    if (pcm_format == yas::pcm_format::float32 || pcm_format == yas::pcm_format::float64) {
        asbd.mFormatFlags |= kAudioFormatFlagIsFloat;
    } else if (pcm_format == yas::pcm_format::int16) {
        asbd.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
    } else if (pcm_format == yas::pcm_format::fixed824) {
        asbd.mFormatFlags |= kAudioFormatFlagIsSignedInteger | (24 << kLinearPCMFormatFlagsSampleFractionShift);
    }

    if (!interleaved) {
        asbd.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
    }

    if (pcm_format == yas::pcm_format::float64) {
        asbd.mBitsPerChannel = 64;
    } else if (pcm_format == yas::pcm_format::int16) {
        asbd.mBitsPerChannel = 16;
    } else {
        asbd.mBitsPerChannel = 32;
    }

    asbd.mChannelsPerFrame = channel_count;

    UInt32 size = sizeof(AudioStreamBasicDescription);
    yas_raise_if_au_error(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &asbd));

    return asbd;
}

bool yas::is_equal(const AudioStreamBasicDescription &asbd1, const AudioStreamBasicDescription &asbd2)
{
    return memcmp(&asbd1, &asbd2, sizeof(AudioStreamBasicDescription)) == 0;
}
