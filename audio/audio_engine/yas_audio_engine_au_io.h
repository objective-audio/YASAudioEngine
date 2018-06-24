//
//  yas_audio_au_io.h
//

#pragma once

#include "yas_audio_types.h"
#include "yas_base.h"
#include "yas_flow.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
namespace yas::audio {
class device;
}
#endif

namespace yas::audio::engine {
class au;

class au_io : public base {
   public:
    class impl;

    enum class method {
        did_update_connection,
    };

    using flow_pair_t = std::pair<method, au_io>;

    struct args {
        bool enable_input = true;
        bool enable_output = true;
    };

    au_io();
    au_io(args);
    au_io(std::nullptr_t);

    virtual ~au_io() final;

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void set_device(audio::device const &);
    audio::device device() const;
#endif

    void set_channel_map(channel_map_t const &, audio::direction const);
    channel_map_t const &channel_map(audio::direction const) const;

    double device_sample_rate() const;
    uint32_t output_device_channel_count() const;
    uint32_t input_device_channel_count() const;

    [[nodiscard]] flow::node_t<flow_pair_t, false> begin_flow() const;
    [[nodiscard]] flow::node<au_io, flow_pair_t, flow_pair_t, false> begin_flow(method const) const;

    audio::engine::au const &au() const;
    audio::engine::au &au();
};

class au_output : public base {
   public:
    class impl;

    au_output();
    au_output(std::nullptr_t);

    virtual ~au_output() final;

    void set_channel_map(channel_map_t const &);
    channel_map_t const &channel_map() const;

    audio::engine::au_io const &au_io() const;
    audio::engine::au_io &au_io();
};

class au_input : public base {
   public:
    class impl;

    au_input();
    au_input(std::nullptr_t);

    virtual ~au_input() final;

    void set_channel_map(channel_map_t const &);
    channel_map_t const &channel_map() const;

    audio::engine::au_io const &au_io() const;
    audio::engine::au_io &au_io();
};
}  // namespace yas::audio::engine
