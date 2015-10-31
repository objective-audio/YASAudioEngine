//
//  yas_audio_engine.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_engine.h"
#include "yas_audio_engine_impl.h"

using namespace yas;

audio_engine::audio_engine() : super_class(std::make_shared<audio_engine::impl>())
{
    auto impl = _impl_ptr();
    impl->prepare(*this);
}

audio_engine::audio_engine(std::nullptr_t) : super_class(nullptr)
{
}

audio_engine::~audio_engine() = default;

audio_engine &audio_engine::operator=(std::nullptr_t)
{
    set_impl_ptr(nullptr);
    return *this;
}

std::shared_ptr<audio_engine::impl> audio_engine::_impl_ptr() const
{
    return impl_ptr<audio_engine::impl>();
}

audio_connection audio_engine::connect(audio_node &source_node, audio_node &destination_node,
                                       const audio_format &format)
{
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

audio_connection audio_engine::connect(audio_node &source_node, audio_node &destination_node, const UInt32 src_bus_idx,
                                       const UInt32 dst_bus_idx, const audio_format &format)
{
    return _impl_ptr()->connect(source_node, destination_node, src_bus_idx, dst_bus_idx, format);
}

void audio_engine::disconnect(audio_connection &connection)
{
    _impl_ptr()->disconnect(connection);
}

void audio_engine::disconnect(audio_node &node)
{
    _impl_ptr()->disconnect(node);
}

void audio_engine::disconnect_input(const audio_node &node)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl_ptr()->disconnect_node_with_predicate(
        [node](const audio_connection &connection) { return (connection.destination_node() == node); });
}

void audio_engine::disconnect_input(const audio_node &node, const UInt32 bus_idx)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl_ptr()->disconnect_node_with_predicate([node, bus_idx](const audio_connection &connection) {
        return (connection.destination_node() == node && connection.destination_bus() == bus_idx);
    });
}

void audio_engine::disconnect_output(const audio_node &node)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl_ptr()->disconnect_node_with_predicate(
        [node](const audio_connection &connection) { return (connection.source_node() == node); });
}

void audio_engine::disconnect_output(const audio_node &node, const UInt32 bus_idx)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl_ptr()->disconnect_node_with_predicate([node, bus_idx](const audio_connection &connection) {
        return (connection.source_node() == node && connection.source_bus() == bus_idx);
    });
}

audio_engine::start_result_t audio_engine::start_render()
{
    return _impl_ptr()->start_render();
}

audio_engine::start_result_t audio_engine::start_offline_render(const offline_render_f &render_function,
                                                                const offline_completion_f &completion_function)
{
    return _impl_ptr()->start_offline_render(render_function, completion_function);
}

void audio_engine::stop()
{
    _impl_ptr()->stop();
}

subject &audio_engine::subject() const
{
    return _impl_ptr()->subject();
}

std::unordered_map<uintptr_t, audio_node> &audio_engine::_nodes() const
{
    return _impl_ptr()->nodes();
}

audio_connection_map &audio_engine::_connections() const
{
    return _impl_ptr()->connections();
}

std::string yas::to_string(const audio_engine::start_error_t &error)
{
    switch (error) {
        case audio_engine::start_error_t::already_running:
            return "already_running";
        case audio_engine::start_error_t::prepare_failure:
            return "prepare_failure";
        case audio_engine::start_error_t::connection_not_found:
            return "connection_not_found";
        case audio_engine::start_error_t::offline_output_not_found:
            return "offline_output_not_found";
        case audio_engine::start_error_t::offline_output_starting_failure:
            return "offline_output_starting_failure";
    }
}