//
//  yas_audio_graph_tap.h
//

#pragma once

#include <audio/yas_audio_graph_node.h>

namespace yas::audio {
struct graph_tap final {
    struct args {
        bool is_input = false;
    };

    void set_render_handler(audio::node_render_f);

    audio::graph_node_ptr const &node() const;

    static graph_tap_ptr make_shared();
    static graph_tap_ptr make_shared(graph_tap::args);

   private:
    class kernel;

    graph_node_ptr _node;
    std::optional<audio::node_render_f> _render_handler;
    std::optional<chaining::any_observer_ptr> _reset_observer = std::nullopt;
    std::optional<graph_kernel_ptr> _kernel_on_render = std::nullopt;

    explicit graph_tap(args &&);

    void _prepare(graph_tap_ptr const &);

    graph_tap(graph_tap const &) = delete;
    graph_tap(graph_tap &&) = delete;
    graph_tap &operator=(graph_tap const &) = delete;
    graph_tap &operator=(graph_tap &&) = delete;

    using kernel_ptr = std::shared_ptr<kernel>;
};
}  // namespace yas::audio
