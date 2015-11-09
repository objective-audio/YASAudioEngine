//
//  yas_audio_graph.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_graph.h"
#include "yas_audio_unit.h"
#include "yas_exception.h"
#include "yas_stl_utils.h"
#include <mutex>
#include <list>
#include <string>
#include <exception>
#include <limits>

#if TARGET_OS_IPHONE
#include "yas_objc_container.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#include "yas_audio_device_io.h"
#endif

#include <iostream>

using namespace yas;

namespace yas
{
    static std::recursive_mutex _global_mutex;
    static bool _interrupting;
    static std::map<UInt8, weak<audio_graph>> _graphs;
#if TARGET_OS_IPHONE
    static yas::objc::container<> _did_become_active_observer;
    static yas::objc::container<> _interruption_observer;
#endif
}

#pragma mark - impl

class audio_graph::impl : public base::impl
{
   public:
    bool running;
    mutable std::recursive_mutex mutex;
    std::map<UInt16, audio_unit> units;
    std::map<UInt16, audio_unit> io_units;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    std::list<audio_device_io> device_ios;
#endif

    impl(const UInt8 key) : running(false), mutex(), units(), io_units(), _key(key){};

    ~impl()
    {
        stop_all_ios();
        remove_graph_for_key(key());
        remove_all_units();
    }

#if TARGET_OS_IPHONE
    static void setup_notifications()
    {
        if (!_did_become_active_observer) {
            const auto lambda = [](NSNotification *note) { start_all_graphs(); };
            id observer =
                [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                  object:nil
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:lambda];
            _did_become_active_observer = yas::objc::container<>(observer);
        }

        if (!_interruption_observer) {
            const auto lambda = [](NSNotification *note) {
                NSDictionary *info = note.userInfo;
                NSNumber *typeNum = [info valueForKey:AVAudioSessionInterruptionTypeKey];
                AVAudioSessionInterruptionType interruptionType =
                    static_cast<AVAudioSessionInterruptionType>([typeNum unsignedIntegerValue]);

                if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
                    _interrupting = true;
                    stop_all_graphs();
                } else if (interruptionType == AVAudioSessionInterruptionTypeEnded) {
                    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                        start_all_graphs();
                        _interrupting = false;
                    }
                }
            };
            id observer =
                [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification
                                                                  object:nil
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:lambda];
            _interruption_observer = yas::objc::container<>(observer);
        }
    }
#endif

    static const bool is_interrupting()
    {
        return _interrupting;
    }

    static void start_all_graphs()
    {
#if TARGET_OS_IPHONE
        NSError *error = nil;
        if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
            NSLog(@"%@", error);
            return;
        }
#endif

        {
            std::lock_guard<std::recursive_mutex> lock(_global_mutex);
            for (auto &pair : _graphs) {
                if (auto graph = pair.second.lock()) {
                    if (graph.is_running()) {
                        graph.impl_ptr<impl>()->start_all_ios();
                    }
                }
            }
        }

        _interrupting = false;
    }

    static void stop_all_graphs()
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        for (const auto &pair : _graphs) {
            if (const auto graph = pair.second.lock()) {
                graph.impl_ptr<impl>()->stop_all_ios();
            }
        }
    }

    static void add_graph(const audio_graph &graph)
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        _graphs.insert(std::make_pair(graph.impl_ptr<impl>()->key(), to_weak(graph)));
    }

    static void remove_graph_for_key(const UInt8 key)
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        _graphs.erase(key);
    }

    static audio_graph graph_for_key(const UInt8 key)
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        if (_graphs.count(key) > 0) {
            auto weak_graph = _graphs.at(key);
            return weak_graph.lock();
        }
        return nullptr;
    }

    std::experimental::optional<UInt16> next_unit_key()
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        return min_empty_key(units);
    }

    audio_unit unit_for_key(const UInt16 key) const
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        return units.at(key);
    }

    void add_unit_to_units(audio_unit &unit)
    {
        if (!unit) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        auto &unit_from_graph = static_cast<audio_unit_from_graph &>(unit);

        if (unit_from_graph._key()) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is not null.");
        }

        std::lock_guard<std::recursive_mutex> lock(mutex);

        auto unit_key = next_unit_key();
        if (unit_key) {
            unit_from_graph._set_graph_key(key());
            unit_from_graph._set_key(*unit_key);
            auto pair = std::make_pair(*unit_key, unit);
            units.insert(pair);
            if (unit.is_output_unit()) {
                io_units.insert(pair);
            }
        }
    }

    void remove_unit_from_units(audio_unit &unit)
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);

        auto &unit_from_graph = static_cast<audio_unit_from_graph &>(unit);

        if (auto key = unit_from_graph._key()) {
            units.erase(*key);
            io_units.erase(*key);
            unit_from_graph._set_key(nullopt);
            unit_from_graph._set_graph_key(nullopt);
        }
    }

    void remove_audio_unit(audio_unit &unit)
    {
        auto &unit_from_graph = static_cast<audio_unit_from_graph &>(unit);

        if (!unit_from_graph._key()) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is not assigned.");
        }

        unit_from_graph._uninitialize();

        remove_unit_from_units(unit);
    }

    void remove_all_units()
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);

        enumerate(units, [this](const auto &it) {
            auto unit = it->second;
            auto next = std::next(it);
            remove_audio_unit(unit);
            return next;
        });
    }

    void start_all_ios()
    {
#if TARGET_OS_IPHONE
        setup_notifications();
#endif

        for (auto &pair : io_units) {
            auto &audio_unit = pair.second;
            audio_unit.start();
        }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        for (auto &device_io : device_ios) {
            device_io.start();
        }
#endif
    }

    void stop_all_ios()
    {
        for (auto &pair : io_units) {
            auto &audio_unit = pair.second;
            audio_unit.stop();
        }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        for (auto &device_io : device_ios) {
            device_io.stop();
        }
#endif
    }

    UInt8 key() const
    {
        return _key;
    }

   private:
    UInt8 _key;
};

#pragma mark - constructor

audio_graph::audio_graph(std::nullptr_t) : super_class(nullptr)
{
}

audio_graph::~audio_graph() = default;

void audio_graph::prepare()
{
    std::lock_guard<std::recursive_mutex> lock(_global_mutex);
    if (!impl_ptr()) {
        auto key = min_empty_key(_graphs);
        if (key && _graphs.count(*key) == 0) {
            set_impl_ptr(std::make_shared<impl>(*key));
            audio_graph::impl::add_graph(*this);
        }
    }
}

void audio_graph::add_audio_unit(audio_unit &unit)
{
    auto &unit_from_graph = static_cast<audio_unit_from_graph &>(unit);

    if (unit_from_graph._key()) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is assigned.");
    }

    auto imp = impl_ptr<impl>();

    imp->add_unit_to_units(unit);

    unit_from_graph._initialize();

    if (unit.is_output_unit() && is_running() && !imp->is_interrupting()) {
        unit.start();
    }
}

void audio_graph::remove_audio_unit(audio_unit &unit)
{
    impl_ptr<impl>()->remove_audio_unit(unit);
}

void audio_graph::remove_all_units()
{
    impl_ptr<impl>()->remove_all_units();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio_graph::add_audio_device_io(audio_device_io &device_io)
{
    {
        std::lock_guard<std::recursive_mutex> lock(impl_ptr<impl>()->mutex);
        impl_ptr<impl>()->device_ios.push_back(device_io);
    }
    if (is_running() && !impl_ptr<impl>()->is_interrupting()) {
        device_io.start();
    }
}

void audio_graph::remove_audio_device_io(audio_device_io &device_io)
{
    device_io.stop();
    {
        std::lock_guard<std::recursive_mutex> lock(impl_ptr<impl>()->mutex);
        erase_if(impl_ptr<impl>()->device_ios,
                 [&device_io](const auto &device_io_in_vec) { return device_io == device_io_in_vec; });
    }
}

#endif

void audio_graph::start()
{
    auto imp = impl_ptr<impl>();
    if (!imp->running) {
        imp->running = true;
        imp->start_all_ios();
    }
}

void audio_graph::stop()
{
    auto imp = impl_ptr<impl>();
    if (imp->running) {
        imp->running = false;
        imp->stop_all_ios();
    }
}

bool audio_graph::is_running() const
{
    return impl_ptr<impl>()->running;
}

void audio_graph::audio_unit_render(render_parameters &render_parameters)
{
    yas_raise_if_main_thread;

    auto graph = impl::graph_for_key(render_parameters.render_id.graph);
    if (graph) {
        auto unit = graph.impl_ptr<impl>()->unit_for_key(render_parameters.render_id.unit);
        if (unit) {
            unit.callback_render(render_parameters);
        }
    }
}