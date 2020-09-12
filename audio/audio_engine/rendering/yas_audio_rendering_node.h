//
//  yas_audio_rendering_node.h
//

#pragma once

#include <audio/yas_audio_pcm_buffer.h>
#include <audio/yas_audio_time.h>

#include <unordered_map>
#include <unordered_set>

namespace yas::audio {
class rendering_connection;

struct rendering_node {
    struct render_args {
        audio::pcm_buffer *const buffer;
        uint32_t const bus_idx;
        audio::time const &time;

        std::unordered_map<uint32_t, rendering_connection *> const &input_connections;
    };

    std::unordered_map<uint32_t, rendering_connection *> const input_connections;

    void render(render_args const &);
};

using rendering_node_set = std::unordered_set<rendering_node>;
}  // namespace yas::audio
