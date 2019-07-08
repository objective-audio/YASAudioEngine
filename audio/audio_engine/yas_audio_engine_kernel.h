//
//  yas_audio_engine_kernel.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include "yas_audio_engine_kernel_protocol.h"

namespace yas::audio::engine {
struct kernel final : base {
    kernel();
    kernel(std::nullptr_t);

    virtual ~kernel();

    audio::engine::connection_smap input_connections() const;
    audio::engine::connection_smap output_connections() const;
    audio::engine::connection input_connection(uint32_t const bus_idx) const;
    audio::engine::connection output_connection(uint32_t const bus_idx) const;

    void set_decorator(base);
    base const &decorator() const;
    base &decorator();

    manageable_kernel &manageable();

   private:
    struct impl;

    manageable_kernel _manageable = nullptr;
};
}  // namespace yas::audio::engine
