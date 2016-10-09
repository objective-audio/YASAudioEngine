//
//  yas_audio_unit_mixer_node.h
//

#pragma once

#include "yas_base.h"

namespace yas {
namespace audio {
    namespace engine {
        class unit_node;

        class unit_mixer_node : public base {
           public:
            unit_mixer_node();
            unit_mixer_node(std::nullptr_t);

            virtual ~unit_mixer_node() final;

            void set_output_volume(float const volume, uint32_t const bus_idx);
            float output_volume(uint32_t const bus_idx) const;
            void set_output_pan(float const pan, uint32_t const bus_idx);
            float output_pan(uint32_t const bus_idx) const;

            void set_input_volume(float const volume, uint32_t const bus_idx);
            float input_volume(uint32_t const bus_idx) const;
            void set_input_pan(float const pan, uint32_t const bus_idx);
            float input_pan(uint32_t const bus_idx) const;

            void set_input_enabled(bool const enabled, uint32_t const bus_idx);
            bool input_enabled(uint32_t const bus_idx) const;

            audio::engine::unit_node const &unit_node() const;
            audio::engine::unit_node &unit_node();

           private:
            class impl;
        };
    }
}
}
