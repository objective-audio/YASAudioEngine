//
//  yas_audio_tap_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"

namespace yas
{
    class audio_tap_node : public audio_node
    {
       public:
        static audio_tap_node_sptr create();

        virtual ~audio_tap_node();

        using render_f = std::function<void(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)>;

        void set_render_function(const render_f &);

        virtual UInt32 input_bus_count() const override;
        virtual UInt32 output_bus_count() const override;

        // render thread
        virtual void render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when) override;

        audio_connection input_connection_on_render(const UInt32 bus_idx) const;
        audio_connection output_connection_on_render(const UInt32 bus_idx) const;
        audio_connection_smap input_connections_on_render() const;
        audio_connection_smap output_connections_on_render() const;
        void render_source(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when);

       protected:
        audio_tap_node();

        virtual kernel_sptr make_kernel() override;
        virtual void prepare_kernel(const kernel_sptr &) override;

       private:
        using super_class = audio_node;
        class kernel;
        class impl;

        std::shared_ptr<kernel> _kernel() const;
        impl *_impl_ptr() const;
    };

    class audio_input_tap_node : public audio_tap_node
    {
       public:
        static audio_input_tap_node_sptr create();

        virtual UInt32 input_bus_count() const override;
        virtual UInt32 output_bus_count() const override;
    };
}
