//
//  yas_audio_graph_io.h
//

#pragma once

#include <audio/yas_audio_graph_io_protocol.h>
#include <audio/yas_audio_graph_node.h>
#include <audio/yas_audio_io_device.h>
#include <audio/yas_audio_ptr.h>
#include <chaining/yas_chaining_umbrella.h>

namespace yas::audio {
class graph_input_context;

struct graph_io : manageable_graph_io {
    virtual ~graph_io();

    audio::graph_node_ptr const &output_node() const;
    audio::graph_node_ptr const &input_node() const;

    audio::io_ptr const &raw_io() override;

    static graph_io_ptr make_shared(audio::io_ptr const &);

   private:
    audio::graph_node_ptr const _output_node;
    audio::graph_node_ptr const _input_node;
    audio::io_ptr const _raw_io;
    std::shared_ptr<graph_input_context> _input_context = nullptr;

    graph_io(audio::io_ptr const &);

    graph_io(graph_io &&) = delete;
    graph_io &operator=(graph_io &&) = delete;
    graph_io(graph_io const &) = delete;
    graph_io &operator=(graph_io const &) = delete;

    void _prepare(graph_io_ptr const &);
    bool _validate_connections();

    void update_rendering() override;
    void clear_rendering() override;
};
}  // namespace yas::audio
