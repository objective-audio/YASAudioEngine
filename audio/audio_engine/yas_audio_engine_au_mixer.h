//
//  yas_audio_au_mixer.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>

namespace yas::audio::engine {
class au;

struct au_mixer : std::enable_shared_from_this<au_mixer> {
    virtual ~au_mixer();

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

    audio::engine::au const &au() const;
    audio::engine::au &au();

   private:
    std::shared_ptr<audio::engine::au> _au;
    chaining::any_observer_ptr _connections_observer = nullptr;

    au_mixer(au_mixer const &) = delete;
    au_mixer(au_mixer &&) = delete;
    au_mixer &operator=(au_mixer const &) = delete;
    au_mixer &operator=(au_mixer &&) = delete;

    au_mixer();

    void prepare();

    void _update_unit_mixer_connections();

    friend std::shared_ptr<au_mixer> make_au_mixer();
};

std::shared_ptr<au_mixer> make_au_mixer();
}  // namespace yas::audio::engine
