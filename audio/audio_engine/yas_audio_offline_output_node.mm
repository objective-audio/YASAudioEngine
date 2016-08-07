//
//  yas_audio_offline_output_node.cpp
//

#include "yas_audio_node.h"
#include "yas_audio_offline_output_node.h"
#include "yas_audio_time.h"
#include "yas_operation.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - audio::offline_output_node::impl

struct audio::offline_output_node::impl : base::impl, manageable_offline_output_unit::impl {
    operation_queue _queue = nullptr;
    audio::node _node = {{.input_bus_count = 1, .output_bus_count = 0}};
    audio::node::observer_t _reset_observer;

    impl() : _core(std::make_unique<audio::offline_output_node::impl::core>()) {
    }

    ~impl() = default;

    void prepare(offline_output_node const &node) {
        _reset_observer =
            _node.subject().make_observer(audio::node::method::will_reset, [weak_node = to_weak(node)](auto const &) {
                if (auto node = weak_node.lock()) {
                    node.impl_ptr<audio::offline_output_node::impl>()->stop();
                }
            });
    }

    audio::offline_start_result_t start(offline_render_f &&render_func,
                                        offline_completion_f &&completion_func) override {
        if (_queue) {
            return offline_start_result_t(offline_start_error_t::already_running);
        } else if (auto connection = _node.input_connection(0)) {
            std::experimental::optional<uint8_t> key;
            if (completion_func) {
                key = _core->push_completion_function(std::move(completion_func));
                if (!key) {
                    return offline_start_result_t(offline_start_error_t::prepare_failure);
                }
            }

            audio::pcm_buffer render_buffer(connection.format(), 1024);

            auto weak_node = to_weak(cast<offline_output_node>());
            auto operation_lambda =
                [weak_node, render_buffer, render_func = std::move(render_func), key](operation const &op) mutable {
                bool cancelled = false;
                uint32_t current_sample_time = 0;
                bool stop = false;

                while (!stop) {
                    audio::time when(current_sample_time, render_buffer.format().sample_rate());
                    auto offline_node = weak_node.lock();
                    if (!offline_node) {
                        cancelled = true;
                        break;
                    }

                    auto kernel = offline_node.node().kernel();
                    if (!kernel) {
                        cancelled = true;
                        break;
                    }

                    auto connection_on_block = kernel.input_connection(0);
                    if (!connection_on_block) {
                        cancelled = true;
                        break;
                    }

                    auto format = connection_on_block.format();
                    if (format != render_buffer.format()) {
                        cancelled = true;
                        break;
                    }

                    render_buffer.reset();

                    if (auto source_node = connection_on_block.source_node()) {
                        source_node.render(render_buffer, connection_on_block.source_bus(), when);
                    }

                    if (render_func) {
                        render_func({.buffer = render_buffer, .when = when, .out_stop = stop});
                    }

                    if (op.is_canceled()) {
                        cancelled = true;
                        break;
                    }

                    current_sample_time += 1024;
                }

                auto completion_lambda = [weak_node, cancelled, key]() {
                    if (auto offline_node = weak_node.lock()) {
                        std::experimental::optional<offline_completion_f> node_completion_func;
                        if (key) {
                            node_completion_func = offline_node.impl_ptr<impl>()->_core->pull_completion_function(*key);
                        }

                        offline_node.impl_ptr<impl>()->_queue = nullptr;

                        if (node_completion_func) {
                            (*node_completion_func)(cancelled);
                        }
                    }
                };

                dispatch_async(dispatch_get_main_queue(), completion_lambda);
            };

            operation operation{std::move(operation_lambda)};
            _queue = operation_queue{1};
            _queue.push_back(operation);
        } else {
            return offline_start_result_t(offline_start_error_t::connection_not_found);
        }
        return offline_start_result_t(nullptr);
    }

    void stop() override {
        auto completion_functions = _core->pull_completion_handlers();

        if (auto &queue = _queue) {
            queue.cancel();
            queue.wait_until_all_operations_are_finished();
            _queue = nullptr;
        }

        for (auto &pair : completion_functions) {
            auto &func = pair.second;
            if (func) {
                func(true);
            }
        }
    }

    bool is_running() {
        return _queue != nullptr;
    }

    audio::node &node() {
        return _node;
    }

   private:
    struct core {
        using completion_function_map_t = std::map<uint8_t, offline_completion_f>;

        std::experimental::optional<uint8_t> const push_completion_function(offline_completion_f &&function) {
            if (!function) {
                return nullopt;
            }

            auto key = min_empty_key(_completion_handlers);
            if (key) {
                _completion_handlers.insert(std::make_pair(*key, std::move(function)));
            }
            return key;
        }

        std::experimental::optional<offline_completion_f> const pull_completion_function(uint8_t key) {
            if (_completion_handlers.count(key) > 0) {
                auto func = _completion_handlers.at(key);
                _completion_handlers.erase(key);
                return std::move(func);
            } else {
                return nullopt;
            }
        }

        completion_function_map_t pull_completion_handlers() {
            auto map = _completion_handlers;
            _completion_handlers.clear();
            return map;
        }

       private:
        completion_function_map_t _completion_handlers;
    };

    std::unique_ptr<core> _core;
};

#pragma mark - audio::offline_output_node

audio::offline_output_node::offline_output_node() : base(std::make_unique<impl>()) {
    impl_ptr<impl>()->prepare(*this);
}

audio::offline_output_node::offline_output_node(std::nullptr_t) : base(nullptr) {
}

audio::offline_output_node::offline_output_node(std::shared_ptr<impl> const &imp) : base(imp) {
    impl_ptr<impl>()->prepare(*this);
}

audio::offline_output_node::~offline_output_node() = default;

bool audio::offline_output_node::is_running() const {
    return impl_ptr<impl>()->is_running();
}

audio::node const &audio::offline_output_node::node() const {
    return impl_ptr<impl>()->node();
}
audio::node &audio::offline_output_node::node() {
    return impl_ptr<impl>()->node();
}

audio::manageable_offline_output_unit &audio::offline_output_node::manageable() {
    if (!_manageable) {
        _manageable = audio::manageable_offline_output_unit{impl_ptr<manageable_offline_output_unit::impl>()};
    }
    return _manageable;
}

std::string yas::to_string(audio::offline_start_error_t const &error) {
    switch (error) {
        case audio::offline_start_error_t::already_running:
            return "already_running";
        case audio::offline_start_error_t::prepare_failure:
            return "prepare_failure";
        case audio::offline_start_error_t::connection_not_found:
            return "connection_not_found";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::offline_start_error_t const &value) {
    os << to_string(value);
    return os;
}
