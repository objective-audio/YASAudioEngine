//
//  yas_audio_node_protocol.h
//

#pragma once

#include "yas_audio_connection_protocol.h"

namespace yas {
namespace audio {
    struct connectable_node : protocol {
        struct impl : protocol::impl {
            virtual void add_connection(audio::connection const &) = 0;
            virtual void remove_connection(audio::connection const &) = 0;
        };

        explicit connectable_node(std::shared_ptr<impl>);

        void add_connection(audio::connection const &);
        void remove_connection(audio::connection const &);
    };

    class engine;

    struct manageable_node : connectable_node {
        struct impl : connectable_node::impl {
            virtual audio::connection input_connection(uint32_t const bus_idx) const = 0;
            virtual audio::connection output_connection(uint32_t const bus_idx) const = 0;
            virtual audio::connection_wmap const &input_connections() const = 0;
            virtual audio::connection_wmap const &output_connections() const = 0;
            virtual void set_engine(audio::engine const &engine) = 0;
            virtual audio::engine engine() const = 0;
            virtual void update_kernel() = 0;
            virtual void update_connections() = 0;
        };

        explicit manageable_node(std::shared_ptr<impl>);

        audio::connection input_connection(uint32_t const bus_idx) const;
        audio::connection output_connection(uint32_t const bus_idx) const;
        audio::connection_wmap const &input_connections() const;
        audio::connection_wmap const &output_connections() const;

        void set_engine(audio::engine const &);
        audio::engine engine() const;

        void update_kernel();
        void update_connections();
    };
}
}