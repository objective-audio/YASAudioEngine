//
//  yas_audio_device_io.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_types.h"
#include "yas_pcm_buffer.h"
#include "yas_audio_device.h"
#include <functional>
#include <memory>

namespace yas
{
    class audio_device_io
    {
       public:
        using render_function = std::function<void(const pcm_buffer_ptr &output_buffer, const audio_time_ptr &when)>;

        static audio_device_io_ptr create();
        static audio_device_io_ptr create(const audio_device_ptr &audio_device);

        ~audio_device_io();

        void set_device(const audio_device_ptr device);
        audio_device_ptr device() const;
        bool is_running() const;
        void set_render_callback(const render_function &callback);
        void set_maximum_frames_per_slice(const UInt32 frames);
        UInt32 maximum_frames_per_slice() const;

        void start();
        void stop();

        const pcm_buffer_ptr input_buffer_on_render() const;
        const audio_time_ptr input_time_on_render() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        audio_device_io();

        audio_device_io(const audio_device_io &) = delete;
        audio_device_io(audio_device_io &&) = delete;
        audio_device_io &operator=(const audio_device_io &) = delete;
        audio_device_io &operator=(audio_device_io &&) = delete;

        void _initialize();
        void _uninitialize();
    };
}

#endif
