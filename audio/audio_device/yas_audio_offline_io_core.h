//
//  yas_audio_offline_io_core.h
//

#pragma once

#include <cpp_utils/yas_task.h>
#include "yas_audio_io_core.h"

namespace yas::audio {
struct offline_io_core : io_core {
    void initialize() override;
    void uninitialize() override;

    void set_render_handler(std::optional<io_render_f>) override;
    void set_maximum_frames_per_slice(uint32_t const) override;

    bool start() override;
    void stop() override;

    [[nodiscard]] std::optional<pcm_buffer_ptr> const &input_buffer_on_render() const override;
    [[nodiscard]] std::optional<time_ptr> const &input_time_on_render() const override;

    static offline_io_core_ptr make_shared(offline_device_ptr const &);

   private:
    std::weak_ptr<offline_io_core> _weak_io_core;
    offline_device_ptr const _device;
    std::optional<task_queue> _queue = std::nullopt;

    mutable std::recursive_mutex _mutex;
    std::optional<io_render_f> __render_handler = std::nullopt;
    uint32_t __maximum_frames = 4096;
    std::optional<io_kernel_ptr> __kernel = std::nullopt;

    offline_io_core(offline_device_ptr const &);

    void _prepare(offline_io_core_ptr const &);
    std::optional<io_render_f> _render_handler() const;
    void _set_kernel(std::optional<io_kernel_ptr> const &);
    std::optional<io_kernel_ptr> _kernel() const;
    void _update_kernel();
};
}  // namespace yas::audio