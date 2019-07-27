//
//  yas_audio_au.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include <cpp_utils/yas_base.h>
#include <unordered_map>
#include "yas_audio_engine_au_protocol.h"
#include "yas_audio_engine_node_protocol.h"
#include "yas_audio_unit.h"

namespace yas::audio {
class graph;
}

namespace yas::audio::engine {
class node;

struct au : manageable_au, std::enable_shared_from_this<au> {
    enum class method {
        will_update_connections,
        did_update_connections,
    };

    using chaining_pair_t = std::pair<method, std::shared_ptr<au>>;
    using prepare_unit_f = std::function<void(audio::unit &)>;

    struct args {
        audio::engine::node_args node_args;
        AudioComponentDescription acd;
    };

    virtual ~au();

    void set_prepare_unit_handler(prepare_unit_f);

    std::shared_ptr<audio::unit> unit() const;
    std::unordered_map<AudioUnitScope, std::unordered_map<AudioUnitParameterID, audio::unit::parameter>> const &
    parameters() const;
    std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &global_parameters() const;
    std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &input_parameters() const;
    std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &output_parameters() const;

    uint32_t input_element_count() const;
    uint32_t output_element_count() const;

    void set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value);
    float global_parameter_value(AudioUnitParameterID const parameter_id) const;
    void set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                   AudioUnitElement const element);
    float input_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const;
    void set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                    AudioUnitElement const element);
    float output_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const;

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<std::shared_ptr<au>, chaining_pair_t> chain(method const) const;

    audio::engine::node const &node() const;
    audio::engine::node &node();

    std::shared_ptr<manageable_au> manageable();

   private:
    std::shared_ptr<audio::engine::node> _node;
    AudioComponentDescription _acd;
    std::unordered_map<AudioUnitScope, unit::parameter_map_t> _parameters;
    chaining::notifier<chaining_pair_t> _notifier;
    chaining::any_observer_ptr _reset_observer = nullptr;
    chaining::any_observer_ptr _connections_observer = nullptr;
    prepare_unit_f _prepare_unit_handler;

    struct core;
    std::unique_ptr<core> _core;

    explicit au(node_args &&);

    void _prepare(AudioComponentDescription const &acd);

    au(au const &) = delete;
    au(au &&) = delete;
    au &operator=(au const &) = delete;
    au &operator=(au &&) = delete;

    void prepare_unit() override;
    void prepare_parameters() override;
    void reload_unit() override;

    void _update_unit_connections();
    void _will_reset();

   public:
    static std::shared_ptr<au> make_shared(OSType const type, OSType const sub_type);
    static std::shared_ptr<au> make_shared(AudioComponentDescription const &);
    static std::shared_ptr<au> make_shared(au::args &&);
};
}  // namespace yas::audio::engine
