//
//  yas_audio_graph_io_protocol.h
//

#pragma once

#include "yas_audio_ptr.h"

namespace yas::audio {
struct manageable_graph_io {
    virtual ~manageable_graph_io() = default;

    virtual audio::io_ptr const &raw_io() = 0;

    static manageable_graph_io_ptr cast(manageable_graph_io_ptr const &io) {
        return io;
    }
};
}  // namespace yas::audio