//
//  yas_audio_file.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_pcm_buffer.h"
#include <memory>
#include <CoreFoundation/CoreFoundation.h>

namespace yas
{
    class audio_file
    {
       public:
        enum class open_error_t : UInt32 {
            opened,
            invalid_argument,
            open_failed,
        };

        enum class read_error_t : UInt32 {
            closed,
            invalid_argument,
            invalid_format,
            read_failed,
            tell_failed,
        };

        enum class create_error_t : UInt32 {
            created,
            invalid_argument,
            create_failed,
        };

        enum class write_error_t : UInt32 {
            closed,
            invalid_argument,
            invalid_format,
            write_failed,
            tell_failed,
        };

        using open_result_t = result<std::nullptr_t, open_error_t>;
        using read_result_t = result<std::nullptr_t, read_error_t>;
        using create_result_t = result<std::nullptr_t, create_error_t>;
        using write_result_t = result<std::nullptr_t, write_error_t>;

        audio_file();
        virtual ~audio_file() = default;

        audio_file(const audio_file &) = default;
        audio_file(audio_file &&) = default;
        audio_file &operator=(const audio_file &) = default;
        audio_file &operator=(audio_file &&) = default;

        explicit operator bool() const;

        CFURLRef url() const;
        const audio_format &file_format() const;
        void set_processing_format(const audio_format &format);
        const audio_format &processing_format() const;
        SInt64 file_length() const;
        SInt64 processing_length() const;
        void set_file_frame_position(const UInt32 position);
        SInt64 file_frame_position() const;

        open_result_t open(const CFURLRef file_url, const pcm_format pcm_format = pcm_format::float32,
                           const bool interleaved = false);
        create_result_t create(const CFURLRef file_url, const CFStringRef file_type, const CFDictionaryRef settings,
                               const pcm_format pcm_format = pcm_format::float32, const bool interleaved = false);
        void close();

        read_result_t read_into_buffer(audio_pcm_buffer &buffer, const UInt32 frame_length = 0);
        write_result_t write_from_buffer(const audio_pcm_buffer &buffer, const bool async = false);

       protected:
        class impl;
        std::shared_ptr<impl> _impl;
    };

    std::string to_string(const audio_file::open_error_t &);
    std::string to_string(const audio_file::read_error_t &);
    std::string to_string(const audio_file::create_error_t &);
    std::string to_string(const audio_file::write_error_t &);
}