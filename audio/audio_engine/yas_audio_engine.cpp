//
//  yas_audio_engine.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_engine.h"
#include "yas_audio_engine_impl.h"
#include "yas_audio_node.h"

using namespace yas;

audio::engine::engine() : super_class(std::make_shared<impl>()) {
    impl_ptr<impl>()->prepare(*this);
}

audio::engine::engine(std::nullptr_t) : super_class(nullptr) {
}

audio::engine::~engine() = default;

audio::engine &audio::engine::operator=(std::nullptr_t) {
    set_impl_ptr(nullptr);
    return *this;
}

audio::connection audio::engine::connect(node &source_node, node &destination_node, const audio::format &format) {
    if (!source_node || !destination_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    auto source_bus_result = source_node.next_available_output_bus();
    auto destination_bus_result = destination_node.next_available_input_bus();

    if (!source_bus_result || !destination_bus_result) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : bus is not available.");
    }

    return connect(source_node, destination_node, *source_bus_result, *destination_bus_result, format);
}

audio::connection audio::engine::connect(node &source_node, node &destination_node, const UInt32 src_bus_idx,
                                         const UInt32 dst_bus_idx, const audio::format &format) {
    return impl_ptr<impl>()->connect(source_node, destination_node, src_bus_idx, dst_bus_idx, format);
}

void audio::engine::disconnect(connection &connection) {
    impl_ptr<impl>()->disconnect(connection);
}

void audio::engine::disconnect(node &node) {
    impl_ptr<impl>()->disconnect(node);
}

void audio::engine::disconnect_input(const node &node) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate(
        [node](const connection &connection) { return (connection.destination_node() == node); });
}

void audio::engine::disconnect_input(const node &node, const UInt32 bus_idx) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate([node, bus_idx](const auto &connection) {
        return (connection.destination_node() == node && connection.destination_bus() == bus_idx);
    });
}

void audio::engine::disconnect_output(const node &node) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate(
        [node](const connection &connection) { return (connection.source_node() == node); });
}

void audio::engine::disconnect_output(const node &node, const UInt32 bus_idx) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate([node, bus_idx](const auto &connection) {
        return (connection.source_node() == node && connection.source_bus() == bus_idx);
    });
}

audio::engine::start_result_t audio::engine::start_render() {
    return impl_ptr<impl>()->start_render();
}

audio::engine::start_result_t audio::engine::start_offline_render(const offline_render_f &render_function,
                                                                  const offline_completion_f &completion_function) {
    return impl_ptr<impl>()->start_offline_render(render_function, completion_function);
}

void audio::engine::stop() {
    impl_ptr<impl>()->stop();
}

subject<audio::engine> &audio::engine::subject() const {
    return impl_ptr<impl>()->subject();
}

std::string yas::to_string(const audio::engine::start_error_t &error) {
    switch (error) {
        case audio::engine::start_error_t::already_running:
            return "already_running";
        case audio::engine::start_error_t::prepare_failure:
            return "prepare_failure";
        case audio::engine::start_error_t::connection_not_found:
            return "connection_not_found";
        case audio::engine::start_error_t::offline_output_not_found:
            return "offline_output_not_found";
        case audio::engine::start_error_t::offline_output_starting_failure:
            return "offline_output_starting_failure";
    }
}