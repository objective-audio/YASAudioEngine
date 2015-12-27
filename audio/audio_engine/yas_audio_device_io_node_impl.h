//
//  yas_audio_device_io_node_impl.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

class yas::audio::device_io_node::impl : public node::impl {
   public:
    impl();
    virtual ~impl();

    void prepare(const device_io_node &, const audio::device &);

    virtual UInt32 input_bus_count() const override;
    virtual UInt32 output_bus_count() const override;

    virtual void update_connections() override;

    void add_device_io();
    void remove_device_io();
    audio::device_io &device_io() const;

    void set_device(const audio::device &device);
    audio::device device() const;

    virtual void render(pcm_buffer &buffer, const UInt32 bus_idx, const time &when) override;

   private:
    using super_class = super_class::impl;

    class core;
    std::unique_ptr<core> _core;

    bool _validate_connections() const;
};

#endif