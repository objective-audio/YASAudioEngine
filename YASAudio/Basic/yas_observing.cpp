//
//  yas_observing.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_observing.h"
#include "yas_audio_types.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - impl

class observer::impl : public base::impl
{
   public:
    class handler_holder
    {
        std::map<const std::experimental::optional<std::string>, const handler_f> functions;

       public:
        void add_handler(const std::experimental::optional<std::string> &key, const handler_f &handler)
        {
            functions.insert(std::make_pair(key, handler));
        }

        void remove_handler(const std::experimental::optional<std::string> &key)
        {
            if (functions.count(key) > 0) {
                functions.erase(key);
            }
        }

        void call_handler(const std::string &key, const yas::any &sender) const
        {
            if (functions.count(key) > 0) {
                functions.at(key)(key, sender);
            }
        }

        void call_wild_card_handler(const std::string &key, const yas::any &sender) const
        {
            if (functions.count(nullopt)) {
                functions.at(nullopt)(key, sender);
            }
        }

        size_t size() const
        {
            return functions.size();
        }
    };

    std::map<const subject *, handler_holder> handlers;

    void call_handler(const subject &subject, const std::string &key, const yas::any &object)
    {
        if (handlers.count(&subject) > 0) {
            handlers.at(&subject).call_handler(key, object);
        }
    }

    void call_wild_card_handler(const subject &subject, const std::string &key, const yas::any &object)
    {
        if (handlers.count(&subject) > 0) {
            handlers.at(&subject).call_wild_card_handler(key, object);
        }
    }
};

class subject::impl
{
   public:
    using weak_observers_vector_t = std::vector<base_weak<observer>>;
    using weak_observers_map_t = std::map<const std::experimental::optional<std::string>, weak_observers_vector_t>;
    weak_observers_map_t observers;

    void add_observer(observer &obs, const std::experimental::optional<std::string> &key)
    {
        if (observers.count(key) == 0) {
            observers.insert(std::make_pair(key, weak_observers_vector_t()));
        }

        auto &vector = observers.at(key);
        vector.push_back(base_weak<observer>(obs));
    }

    void remove_observer(const observer &obs, const std::experimental::optional<std::string> &key)
    {
        if (observers.count(key) > 0) {
            auto &vector = observers.at(key);

            erase_if(vector, [&obs](const base_weak<observer> &weak_observer) {
                if (auto shared_observer = weak_observer.lock()) {
                    if (shared_observer == obs) {
                        return true;
                    }
                }
                return false;
            });

            if (vector.size() == 0) {
                observers.erase(key);
            }
        }
    }

    void remove_observer(const observer &observer)
    {
        erase_if(observers, [&observer](auto &pair) {
            auto &vector = pair.second;

            erase_if(vector, [&observer](const auto &weak_observer) {
                if (auto shared_observer = weak_observer.lock()) {
                    if (shared_observer == observer) {
                        return true;
                    }
                }
                return false;
            });

            return vector.size() == 0;
        });
    }
};

#pragma mark - observer

observer::observer() : super_class(std::make_shared<impl>())
{
}

observer::observer(std::nullptr_t) : super_class(nullptr)
{
}

void observer::add_handler(subject &subject, const std::string &key, const handler_f &handler)
{
    auto impl = _impl_ptr();
    auto subject_ptr = &subject;
    if (impl->handlers.count(subject_ptr) == 0) {
        impl->handlers.insert(std::make_pair(&subject, yas::observer::impl::handler_holder()));
    };
    impl->handlers.at(&subject).add_handler(key, handler);
    subject._impl->add_observer(*this, key);
}

void observer::remove_handler(subject &subject, const std::string &key)
{
    auto impl = _impl_ptr();
    if (impl->handlers.count(&subject) > 0) {
        auto &handler_holder = impl->handlers.at(&subject);
        handler_holder.remove_handler(key);
        if (handler_holder.size() == 0) {
            impl->handlers.erase(&subject);
        }
    }
    subject._impl->remove_observer(*this, key);
}

void observer::add_wild_card_handler(subject &subject, const handler_f &handler)
{
    auto impl = _impl_ptr();
    auto subject_ptr = &subject;
    if (impl->handlers.count(subject_ptr) == 0) {
        impl->handlers.insert(std::make_pair(&subject, yas::observer::impl::handler_holder()));
    };
    impl->handlers.at(&subject).add_handler(nullopt, handler);
    subject._impl->add_observer(*this, nullopt);
}

void observer::remove_wild_card_handler(subject &subject)
{
    auto impl = _impl_ptr();
    if (impl->handlers.count(&subject) > 0) {
        auto &handler_holder = impl->handlers.at(&subject);
        handler_holder.remove_handler(nullopt);
        if (handler_holder.size() == 0) {
            impl->handlers.erase(&subject);
        }
    }
    subject._impl->remove_observer(*this, nullopt);
}

void observer::clear()
{
    auto impl = _impl_ptr();
    for (auto &pair : impl->handlers) {
        auto &subject_ptr = pair.first;
        subject_ptr->_impl->remove_observer(*this);
    }
    impl->handlers.clear();
}

std::shared_ptr<observer::impl> observer::_impl_ptr() const
{
    return impl_ptr<observer::impl>();
}

observer yas::make_subject_dispatcher(const subject &source, const std::initializer_list<subject *> &destinations)
{
    yas::observer observer;
    auto handler = [&source](const auto &method, const auto &value) { source.notify(method, value); };

    for (const auto &destination : destinations) {
        observer.add_wild_card_handler(*destination, handler);
    }

    return observer;
}

#pragma mark - subject

subject::subject() : _impl(std::make_unique<impl>())
{
}

subject::~subject()
{
    for (auto &pair : _impl->observers) {
        for (auto &weak_observer : pair.second) {
            if (auto observer = weak_observer.lock()) {
                observer._impl_ptr()->handlers.erase(this);
            }
        }
    }
}

bool subject::operator==(const subject &other) const
{
    return this == &other;
}

bool subject::operator!=(const subject &other) const
{
    return this != &other;
}

void subject::notify(const std::string &key) const
{
    notify(key, nullptr);
}

void subject::notify(const std::string &key, const yas::any &object) const
{
    if (_impl->observers.count(key)) {
        for (auto &weak_observer : _impl->observers.at(key)) {
            if (auto observer = weak_observer.lock()) {
                observer._impl_ptr()->call_handler(*this, key, object);
            }
        }
    }
    if (_impl->observers.count(nullopt)) {
        for (auto &weak_observer : _impl->observers.at(nullopt)) {
            if (auto observer = weak_observer.lock()) {
                observer._impl_ptr()->call_wild_card_handler(*this, key, object);
            }
        }
    }
}
