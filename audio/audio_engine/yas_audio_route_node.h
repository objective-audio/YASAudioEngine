//
//  yas_audio_route_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"

namespace yas {
namespace audio {
    class route_node : public node {
        using super_class = node;
        class kernel;
        class impl;

       public:
        route_node();
        route_node(std::nullptr_t);

        const audio::route_set_t &routes() const;
        void add_route(const audio::route &);
        void add_route(audio::route &&);
        void remove_route(const audio::route &);
        void remove_route_for_source(const audio::route::point &);
        void remove_route_for_destination(const audio::route::point &);
        void set_routes(const audio::route_set_t &routes);
        void set_routes(audio::route_set_t &&routes);
        void clear_routes();
    };
}
}