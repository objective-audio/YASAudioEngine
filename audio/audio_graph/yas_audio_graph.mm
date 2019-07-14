//
//  yas_audio_graph.mm
//

#include "yas_audio_graph.h"
#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_unit.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <cpp_utils/yas_objc_ptr.h>
#endif

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device_io.h"
#endif

using namespace yas;

namespace yas::audio {
static std::recursive_mutex global_mutex;
static bool global_interrupting;
static std::map<uint8_t, base::weak<graph>> global_graphs;
#if TARGET_OS_IPHONE
static objc_ptr<> global_did_become_active_observer;
static objc_ptr<> global_interruption_observer;
#endif
}

#pragma mark - impl

struct audio::graph::impl : base::impl {
   public:
    impl(uint8_t const key) : _key(key){};

    ~impl() {
        this->stop_all_ios();
        this->remove_graph_for_key(key());
        this->remove_all_units();
    }

    static std::shared_ptr<impl> make_shared() {
        std::lock_guard<std::recursive_mutex> lock(global_mutex);
        auto key = min_empty_key(global_graphs);
        if (key && global_graphs.count(*key) == 0) {
            return std::make_shared<impl>(*key);
        }
        return nullptr;
    }

#if TARGET_OS_IPHONE
    static void setup_notifications() {
        if (!global_did_become_active_observer) {
            auto const lambda = [](NSNotification *note) { start_all_graphs(); };
            id observer =
                [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                  object:nil
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:std::move(lambda)];
            global_did_become_active_observer.set_object(observer);
        }

        if (!global_interruption_observer) {
            auto const lambda = [](NSNotification *note) {
                NSDictionary *info = note.userInfo;
                NSNumber *typeNum = [info valueForKey:AVAudioSessionInterruptionTypeKey];
                AVAudioSessionInterruptionType interruptionType =
                    static_cast<AVAudioSessionInterruptionType>([typeNum unsignedIntegerValue]);

                if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
                    global_interrupting = true;
                    stop_all_graphs();
                } else if (interruptionType == AVAudioSessionInterruptionTypeEnded) {
                    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                        start_all_graphs();
                        global_interrupting = false;
                    }
                }
            };
            id observer =
                [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification
                                                                  object:nil
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:std::move(lambda)];
            global_interruption_observer.set_object(observer);
        }
    }
#endif

    static bool const is_interrupting() {
        return global_interrupting;
    }

    static void start_all_graphs() {
#if TARGET_OS_IPHONE
        NSError *error = nil;
        if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
            NSLog(@"%@", error);
            return;
        }
#endif

        {
            std::lock_guard<std::recursive_mutex> lock(global_mutex);
            for (auto &pair : global_graphs) {
                if (auto graph = pair.second.lock()) {
                    if (graph.is_running()) {
                        graph.impl_ptr<impl>()->start_all_ios();
                    }
                }
            }
        }

        global_interrupting = false;
    }

    static void stop_all_graphs() {
        std::lock_guard<std::recursive_mutex> lock(global_mutex);
        for (auto const &pair : global_graphs) {
            if (auto const graph = pair.second.lock()) {
                graph.impl_ptr<impl>()->stop_all_ios();
            }
        }
    }

    static void add_graph(graph const &graph) {
        std::lock_guard<std::recursive_mutex> lock(global_mutex);
        global_graphs.insert(std::make_pair(graph.impl_ptr<impl>()->key(), to_weak(graph)));
    }

    static void remove_graph_for_key(uint8_t const key) {
        std::lock_guard<std::recursive_mutex> lock(global_mutex);
        global_graphs.erase(key);
    }

    static graph graph_for_key(uint8_t const key) {
        std::lock_guard<std::recursive_mutex> lock(global_mutex);
        if (global_graphs.count(key) > 0) {
            auto weak_graph = global_graphs.at(key);
            return weak_graph.lock();
        }
        return nullptr;
    }

    std::optional<uint16_t> next_unit_key() {
        std::lock_guard<std::recursive_mutex> lock(global_mutex);
        return min_empty_key(this->_units);
    }

    std::shared_ptr<unit> unit_for_key(uint16_t const key) const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return this->_units.at(key);
    }

    void add_unit_to_units(std::shared_ptr<audio::unit> &unit) {
        if (!unit) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        if (unit->key()) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : unit.key is not null.");
        }

        std::lock_guard<std::recursive_mutex> lock(_mutex);

        auto unit_key = next_unit_key();
        if (unit_key) {
            unit->set_graph_key(key());
            unit->set_key(*unit_key);
            auto pair = std::make_pair(*unit_key, unit);
            this->_units.insert(pair);
            if (unit->is_output_unit()) {
                this->_io_units.insert(pair);
            }
        }
    }

    void remove_unit_from_units(audio::unit &unit) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        if (auto key = unit.key()) {
            this->_units.erase(*key);
            this->_io_units.erase(*key);
            unit.set_key(std::nullopt);
            unit.set_graph_key(std::nullopt);
        }
    }

    void add_unit(std::shared_ptr<audio::unit> &unit) {
        if (unit->key()) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : unit.key is already assigned.");
        }

        this->add_unit_to_units(unit);

        unit->initialize();

        if (unit->is_output_unit() && this->_running && !this->is_interrupting()) {
            unit->start();
        }
    }

    void remove_unit(audio::unit &unit) {
        unit.uninitialize();

        this->remove_unit_from_units(unit);
    }

    void remove_all_units() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        for_each(this->_units, [this](auto const &it) {
            auto unit = it->second;
            auto next = std::next(it);
            this->remove_unit(*unit);
            return next;
        });
    }

    void start_all_ios() {
#if TARGET_OS_IPHONE
        setup_notifications();
#endif

        for (auto &pair : this->_io_units) {
            auto &unit = pair.second;
            unit->start();
        }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        for (auto &device_io : this->_device_ios) {
            device_io->start();
        }
#endif
    }

    void stop_all_ios() {
        for (auto &pair : this->_io_units) {
            auto &unit = pair.second;
            unit->stop();
        }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        for (auto &device_io : this->_device_ios) {
            device_io->stop();
        }
#endif
    }

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void add_audio_device_io(std::shared_ptr<device_io> &device_io) {
        {
            std::lock_guard<std::recursive_mutex> lock(_mutex);
            this->_device_ios.insert(device_io);
        }
        if (this->_running && !this->is_interrupting()) {
            device_io->start();
        }
    }

    void remove_audio_device_io(std::shared_ptr<device_io> &device_io) {
        device_io->stop();
        {
            std::lock_guard<std::recursive_mutex> lock(_mutex);
            this->_device_ios.erase(device_io);
        }
    }
#endif

    void start() {
        if (!this->_running) {
            this->_running = true;
            this->start_all_ios();
        }
    }

    void stop() {
        if (this->_running) {
            this->_running = false;
            this->stop_all_ios();
        }
    }

    uint8_t key() const {
        return this->_key;
    }

    bool is_running() const {
        return this->_running;
    }

   private:
    uint8_t _key;
    bool _running = false;
    mutable std::recursive_mutex _mutex;
    std::map<uint16_t, std::shared_ptr<unit>> _units;
    std::map<uint16_t, std::shared_ptr<unit>> _io_units;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    std::unordered_set<std::shared_ptr<device_io>> _device_ios;
#endif
};

#pragma mark - main

audio::graph::graph() : base(impl::make_shared()) {
    if (impl_ptr()) {
        impl::add_graph(*this);
    }
}

audio::graph::graph(std::nullptr_t) : base(nullptr) {
}

audio::graph::~graph() = default;

void audio::graph::add_unit(std::shared_ptr<audio::unit> &unit) {
    impl_ptr<impl>()->add_unit(unit);
}

void audio::graph::remove_unit(audio::unit &unit) {
    impl_ptr<impl>()->remove_unit(unit);
}

void audio::graph::remove_all_units() {
    impl_ptr<impl>()->remove_all_units();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio::graph::add_audio_device_io(std::shared_ptr<device_io> &device_io) {
    impl_ptr<impl>()->add_audio_device_io(device_io);
}

void audio::graph::remove_audio_device_io(std::shared_ptr<device_io> &device_io) {
    impl_ptr<impl>()->remove_audio_device_io(device_io);
}

#endif

void audio::graph::start() {
    impl_ptr<impl>()->start();
}

void audio::graph::stop() {
    impl_ptr<impl>()->stop();
}

bool audio::graph::is_running() const {
    return impl_ptr<impl>()->is_running();
}

void audio::graph::unit_render(render_parameters &render_parameters) {
    raise_if_main_thread();

    if (auto graph = impl::graph_for_key(render_parameters.render_id.graph)) {
        if (auto unit = graph.impl_ptr<impl>()->unit_for_key(render_parameters.render_id.unit)) {
            unit->callback_render(render_parameters);
        }
    }
}
