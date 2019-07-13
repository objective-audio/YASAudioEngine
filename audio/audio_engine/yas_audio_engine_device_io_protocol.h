//
//  yas_audio_engine_device_io_protocol.h
//

#pragma once

#include <cpp_utils/yas_protocol.h>

namespace yas::audio {
class device_io;
}

namespace yas::audio::engine {
struct manageable_device_io : protocol {
    struct impl : protocol::impl {
        virtual void add_device_io() = 0;
        virtual void remove_device_io() = 0;
        virtual std::shared_ptr<audio::device_io> &device_io() = 0;
    };

    explicit manageable_device_io(std::shared_ptr<impl>);
    manageable_device_io(std::nullptr_t);

    void add_device_io();
    void remove_device_io();
    std::shared_ptr<audio::device_io> &device_io() const;
};
}  // namespace yas::audio::engine
