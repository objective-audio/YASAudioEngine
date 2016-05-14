//
//  yas_audio_pcm_buffer.h
//

#pragma once

#include <memory>
#include <vector>
#include "yas_audio_types.h"
#include "yas_base.h"

namespace yas {
class flex_ptr;
template <typename T, typename U>
class result;

namespace audio {
    class format;

    class pcm_buffer : public base {
        class impl;

       public:
        enum class copy_error_t {
            invalid_argument,
            invalid_abl,
            invalid_format,
            out_of_range,
            buffer_is_null,
        };

        using copy_result = result<uint32_t, copy_error_t>;

        pcm_buffer(audio::format const &format, AudioBufferList *abl);
        pcm_buffer(audio::format const &format, uint32_t const frame_capacity);
        pcm_buffer(audio::format const &format, pcm_buffer const &from_buffer, const channel_map_t &channel_map);
        pcm_buffer(std::nullptr_t);

        audio::format const &format() const;
        AudioBufferList *audio_buffer_list();
        const AudioBufferList *audio_buffer_list() const;

        flex_ptr flex_ptr_at_index(uint32_t const buf_idx) const;
        flex_ptr flex_ptr_at_channel(uint32_t const ch_idx) const;

        template <typename T>
        T *data_ptr_at_index(uint32_t const buf_idx);
        template <typename T>
        T *data_ptr_at_channel(uint32_t const ch_idx);
        template <typename T>
        const T *data_ptr_at_index(uint32_t const buf_idx) const;
        template <typename T>
        const T *data_ptr_at_channel(uint32_t const ch_idx) const;

        uint32_t frame_capacity() const;
        uint32_t frame_length() const;
        void set_frame_length(uint32_t const length);

        void reset();
        void clear();
        void clear(uint32_t const start_frame, uint32_t const length);

        pcm_buffer::copy_result copy_from(pcm_buffer const &from_buffer, uint32_t const from_start_frame = 0,
                                          uint32_t const to_start_frame = 0, uint32_t const length = 0);
        pcm_buffer::copy_result copy_from(const AudioBufferList *const from_abl, uint32_t const from_start_frame = 0,
                                          uint32_t const to_start_frame = 0, uint32_t const length = 0);
        pcm_buffer::copy_result copy_to(AudioBufferList *const to_abl, uint32_t const from_start_frame = 0,
                                        uint32_t const to_start_frame = 0, uint32_t const length = 0);
    };

    void clear(AudioBufferList *abl);

    pcm_buffer::copy_result copy(const AudioBufferList *const from_abl, AudioBufferList *const to_abl,
                                 uint32_t const sample_byte_count, uint32_t const from_start_frame = 0,
                                 uint32_t const to_start_frame = 0, uint32_t const length = 0);

    uint32_t frame_length(const AudioBufferList *const abl, uint32_t const sample_byte_count);

    std::pair<abl_uptr, abl_data_uptr> allocate_audio_buffer_list(uint32_t const buffer_count,
                                                                  uint32_t const channel_count,
                                                                  uint32_t const size = 0);
    bool is_equal_structure(AudioBufferList const &abl1, AudioBufferList const &abl2);
}

std::string to_string(audio::pcm_buffer::copy_error_t const &error);
}
