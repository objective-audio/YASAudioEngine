//
//  yas_audio_node.cpp
//

#include <iostream>
#include "yas_audio_connection.h"
#include "yas_audio_engine.h"
#include "yas_audio_node.h"
#include "yas_audio_time.h"
#include "yas_result.h"

using namespace yas;

audio::node::node(std::nullptr_t) : base(nullptr) {
}

audio::node::node(std::shared_ptr<impl> const &impl) : base(impl) {
}

audio::node::~node() = default;

void audio::node::reset() {
    if (!impl_ptr()) {
        std::cout << "_impl is null" << std::endl;
    }
    impl_ptr<impl>()->reset();
}

audio::format audio::node::input_format(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_format(bus_idx);
}

audio::format audio::node::output_format(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_format(bus_idx);
}

audio::bus_result_t audio::node::next_available_input_bus() const {
    return impl_ptr<impl>()->next_available_input_bus();
}

audio::bus_result_t audio::node::next_available_output_bus() const {
    return impl_ptr<impl>()->next_available_output_bus();
}

bool audio::node::is_available_input_bus(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->is_available_input_bus(bus_idx);
}

bool audio::node::is_available_output_bus(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->is_available_output_bus(bus_idx);
}

audio::engine audio::node::engine() const {
    return impl_ptr<impl>()->engine();
}

audio::time audio::node::last_render_time() const {
    return impl_ptr<impl>()->render_time();
}

uint32_t audio::node::input_bus_count() const {
    return impl_ptr<impl>()->input_bus_count();
}

uint32_t audio::node::output_bus_count() const {
    return impl_ptr<impl>()->output_bus_count();
}

#pragma mark render thread

void audio::node::render(pcm_buffer &buffer, uint32_t const bus_idx, const time &when) {
    impl_ptr<impl>()->render(buffer, bus_idx, when);
}

void audio::node::set_render_time_on_render(const time &time) {
    impl_ptr<impl>()->set_render_time_on_render(time);
}

audio::connectable_node audio::node::connectable() {
    return audio::connectable_node{impl_ptr<connectable_node::impl>()};
}

audio::manageable_node const audio::node::manageable_node() const {
    return audio::manageable_node{impl_ptr<manageable_node::impl>()};
}

audio::manageable_node audio::node::manageable_node() {
    return audio::manageable_node{impl_ptr<manageable_node::impl>()};
}
