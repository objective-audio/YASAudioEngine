//
//  yas_audio_time.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <cpp_utils/yas_base.h>
#include "yas_audio_types.h"

namespace yas::audio {
struct time final {
    class impl;

    time(AudioTimeStamp const &ts, double const sample_rate);
    explicit time(uint64_t const host_time);
    time(int64_t const sample_time, double const sample_rate);
    time(uint64_t const host_time, int64_t const sample_time, double const sample_rate);

    bool is_host_time_valid() const;
    uint64_t host_time() const;
    bool is_sample_time_valid() const;
    int64_t sample_time() const;
    double sample_rate() const;
    AudioTimeStamp audio_time_stamp() const;

    time extrapolate_time_from_anchor(time const &anchor_time);

    std::string description() const;

    bool operator==(time const &) const;
    bool operator!=(time const &) const;

   private:
    std::shared_ptr<impl> _impl;
};

uint64_t host_time_for_seconds(double seconds);
double seconds_for_host_time(uint64_t host_time);
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::time const &);
}
