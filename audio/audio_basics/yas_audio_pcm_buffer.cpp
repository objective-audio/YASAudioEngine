//
//  yas_audio_pcm_buffer.cpp
//

#include <Accelerate/Accelerate.h>
#include <exception>
#include <functional>
#include <iostream>
#include <string>
#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_flex_ptr.h"
#include "yas_result.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - private

struct audio::pcm_buffer::impl : base::impl {
    audio::format const format;
    const AudioBufferList *abl_ptr;
    uint32_t const frame_capacity;
    uint32_t frame_length;

    impl(audio::format const &format, std::pair<audio::abl_uptr, audio::abl_data_uptr> &&abl_pair,
         uint32_t const frame_capacity)
        : impl(format, std::move(abl_pair.first), std::move(abl_pair.second), frame_capacity) {
    }

    impl(audio::format const &format, audio::abl_uptr &&abl, audio::pcm_buffer const &from_buffer,
         channel_map_t const &channel_map)
        : impl(format, std::move(abl), nullptr, from_buffer.frame_length()) {
        auto const &from_format = from_buffer.format();

        if (channel_map.size() != format.channel_count() || format.is_interleaved() || from_format.is_interleaved() ||
            format.pcm_format() != from_format.pcm_format()) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid format.");
        }

        abl_uptr const &to_abl = _abl;

        const AudioBufferList *const from_abl = from_buffer.audio_buffer_list();
        uint32_t bytesPerFrame = format.stream_description().mBytesPerFrame;
        uint32_t const frame_length = from_buffer.frame_length();
        uint32_t to_ch_idx = 0;

        for (auto const &from_ch_idx : channel_map) {
            if (from_ch_idx != -1) {
                to_abl->mBuffers[to_ch_idx].mData = from_abl->mBuffers[from_ch_idx].mData;
                to_abl->mBuffers[to_ch_idx].mDataByteSize = from_abl->mBuffers[from_ch_idx].mDataByteSize;
                uint32_t actual_frame_length = from_abl->mBuffers[0].mDataByteSize / bytesPerFrame;
                if (frame_length != actual_frame_length) {
                    throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) +
                                                " : invalid frame length. frame_length(" +
                                                std::to_string(frame_length) + ") actual_frame_length(" +
                                                std::to_string(actual_frame_length) + ")");
                }
            } else {
                if (to_abl->mBuffers[to_ch_idx].mData == nullptr) {
                    uint32_t const size = bytesPerFrame * frame_length;
                    auto dummy_data = pcm_buffer::impl::dummy_data();
                    if (size <= dummy_data.size()) {
                        to_abl->mBuffers[to_ch_idx].mData = dummy_data.data();
                        to_abl->mBuffers[to_ch_idx].mDataByteSize = size;
                    } else {
                        throw std::overflow_error(std::string(__PRETTY_FUNCTION__) + " : buffer size is overflow(" +
                                                  std::to_string(size) + ")");
                    }
                }
            }
            ++to_ch_idx;
        }
    }

    impl(audio::format const &format, AudioBufferList *ptr, uint32_t const frame_capacity)
        : format(format),
          abl_ptr(ptr),
          frame_capacity(frame_capacity),
          frame_length(frame_capacity),
          _abl(nullptr),
          _data(nullptr) {
    }

    impl(audio::format const &format, abl_uptr &&abl, abl_data_uptr &&data, uint32_t const frame_capacity)
        : format(format),
          frame_capacity(frame_capacity),
          frame_length(frame_capacity),
          abl_ptr(abl.get()),
          _abl(std::move(abl)),
          _data(std::move(data)) {
    }

    impl(audio::format const &format, abl_uptr &&abl, uint32_t const frame_capacity)
        : format(format),
          frame_capacity(frame_capacity),
          frame_length(frame_capacity),
          abl_ptr(abl.get()),
          _abl(std::move(abl)),
          _data(nullptr) {
    }

    flex_ptr flex_ptr_at_index(uint32_t const buf_idx) {
        if (buf_idx >= abl_ptr->mNumberBuffers) {
            throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. buf_idx(" +
                                    std::to_string(buf_idx) + ") _impl->abl_ptr.mNumberBuffers(" +
                                    std::to_string(abl_ptr->mNumberBuffers) + ")");
        }

        return flex_ptr(abl_ptr->mBuffers[buf_idx].mData);
    }

    flex_ptr flex_ptr_at_channel(uint32_t const ch_idx) {
        flex_ptr pointer;

        if (format.stride() > 1) {
            if (ch_idx < abl_ptr->mBuffers[0].mNumberChannels) {
                pointer.v = abl_ptr->mBuffers[0].mData;
                if (ch_idx > 0) {
                    pointer.u8 += ch_idx * format.sample_byte_count();
                }
            } else {
                throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. ch_idx(" +
                                        std::to_string(ch_idx) + ") mNumberChannels(" +
                                        std::to_string(abl_ptr->mBuffers[0].mNumberChannels) + ")");
            }
        } else {
            if (ch_idx < abl_ptr->mNumberBuffers) {
                pointer.v = abl_ptr->mBuffers[ch_idx].mData;
            } else {
                throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. ch_idx(" +
                                        std::to_string(ch_idx) + ") mNumberChannels(" +
                                        std::to_string(abl_ptr->mBuffers[0].mNumberChannels) + ")");
            }
        }

        return pointer;
    }

    static std::vector<uint8_t> &dummy_data() {
        static std::vector<uint8_t> _dummy_data(4096 * 4);
        return _dummy_data;
    }

   private:
    abl_uptr const _abl;
    abl_data_uptr const _data;
};

std::pair<audio::abl_uptr, audio::abl_data_uptr> audio::allocate_audio_buffer_list(uint32_t const buffer_count,
                                                                                   uint32_t const channel_count,
                                                                                   uint32_t const size) {
    abl_uptr abl_ptr((AudioBufferList *)calloc(1, sizeof(AudioBufferList) + buffer_count * sizeof(AudioBuffer)),
                     [](AudioBufferList *abl) { free(abl); });

    abl_ptr->mNumberBuffers = buffer_count;
    auto data_ptr = std::make_unique<std::vector<std::vector<uint8_t>>>();
    if (size > 0) {
        data_ptr->reserve(buffer_count);
    } else {
        data_ptr = nullptr;
    }

    for (uint32_t i = 0; i < buffer_count; ++i) {
        abl_ptr->mBuffers[i].mNumberChannels = channel_count;
        abl_ptr->mBuffers[i].mDataByteSize = size;
        if (size > 0) {
            data_ptr->push_back(std::vector<uint8_t>(size));
            abl_ptr->mBuffers[i].mData = data_ptr->at(i).data();
        } else {
            abl_ptr->mBuffers[i].mData = nullptr;
        }
    }

    return std::make_pair(std::move(abl_ptr), std::move(data_ptr));
}

static void set_data_byte_size(audio::pcm_buffer &data, uint32_t const data_byte_size) {
    AudioBufferList *abl = data.audio_buffer_list();
    for (uint32_t i = 0; i < abl->mNumberBuffers; i++) {
        abl->mBuffers[i].mDataByteSize = data_byte_size;
    }
}

static void reset_data_byte_size(audio::pcm_buffer &data) {
    uint32_t const data_byte_size =
        (uint32_t const)(data.frame_capacity() * data.format().stream_description().mBytesPerFrame);
    set_data_byte_size(data, data_byte_size);
}

template <typename T>
static bool validate_pcm_format(audio::pcm_format const &pcm_format) {
    switch (pcm_format) {
        case audio::pcm_format::float32:
            return typeid(T) == typeid(float);
        case audio::pcm_format::float64:
            return typeid(T) == typeid(double);
        case audio::pcm_format::fixed824:
            return typeid(T) == typeid(int32_t);
        case audio::pcm_format::int16:
            return typeid(T) == typeid(int16_t);
        default:
            return false;
    }
}

namespace yas {
namespace audio {
    struct abl_info {
        uint32_t channel_count;
        uint32_t frame_length;
        std::vector<uint8_t *> datas;
        std::vector<uint32_t> strides;

        abl_info() : channel_count(0), frame_length(0), datas(0), strides(0) {
        }
    };

    using get_abl_info_result_t = result<abl_info, pcm_buffer::copy_error_t>;

    static get_abl_info_result_t get_abl_info(const AudioBufferList *abl, uint32_t const sample_byte_count) {
        if (!abl || sample_byte_count == 0 || sample_byte_count > 8) {
            return get_abl_info_result_t(pcm_buffer::copy_error_t::invalid_argument);
        }

        uint32_t const buffer_count = abl->mNumberBuffers;

        audio::abl_info data_info;

        for (uint32_t buf_idx = 0; buf_idx < buffer_count; ++buf_idx) {
            uint32_t const stride = abl->mBuffers[buf_idx].mNumberChannels;
            uint32_t const frame_length = abl->mBuffers[buf_idx].mDataByteSize / stride / sample_byte_count;
            if (data_info.frame_length == 0) {
                data_info.frame_length = frame_length;
            } else if (data_info.frame_length != frame_length) {
                return get_abl_info_result_t(pcm_buffer::copy_error_t::invalid_abl);
            }
            data_info.channel_count += stride;
        }

        if (data_info.channel_count > 0) {
            for (uint32_t buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
                uint32_t const stride = abl->mBuffers[buf_idx].mNumberChannels;
                uint8_t *data = static_cast<uint8_t *>(abl->mBuffers[buf_idx].mData);
                for (uint32_t ch_idx = 0; ch_idx < stride; ++ch_idx) {
                    data_info.datas.push_back(&data[ch_idx * sample_byte_count]);
                    data_info.strides.push_back(stride);
                }
            }
        }

        return get_abl_info_result_t(std::move(data_info));
    }
}
}

#pragma mark - public

audio::pcm_buffer::pcm_buffer(std::nullptr_t) : base(nullptr) {
}

audio::pcm_buffer::pcm_buffer(audio::format const &format, AudioBufferList *abl)
    : base(std::make_shared<impl>(format, abl,
                                  abl->mBuffers[0].mDataByteSize / format.stream_description().mBytesPerFrame)) {
    if (!format || !abl) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }
}

audio::pcm_buffer::pcm_buffer(audio::format const &format, uint32_t const frame_capacity)
    : base(std::make_shared<impl>(
          format, allocate_audio_buffer_list(format.buffer_count(), format.stride(),
                                             frame_capacity * format.stream_description().mBytesPerFrame),
          frame_capacity)) {
    if (frame_capacity == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }
}

audio::pcm_buffer::pcm_buffer(audio::format const &format, audio::pcm_buffer const &from_buffer,
                              channel_map_t const &channel_map)
    : base(std::make_shared<impl>(format, allocate_audio_buffer_list(format.buffer_count(), format.stride(), 0).first,
                                  from_buffer, channel_map)) {
}

audio::format const &audio::pcm_buffer::format() const {
    return impl_ptr<impl>()->format;
}

AudioBufferList *audio::pcm_buffer::audio_buffer_list() {
    return const_cast<AudioBufferList *>(impl_ptr<impl>()->abl_ptr);
}

const AudioBufferList *audio::pcm_buffer::audio_buffer_list() const {
    return impl_ptr<impl>()->abl_ptr;
}

flex_ptr audio::pcm_buffer::flex_ptr_at_index(uint32_t const buf_idx) const {
    return impl_ptr<impl>()->flex_ptr_at_index(buf_idx);
}

flex_ptr audio::pcm_buffer::flex_ptr_at_channel(uint32_t const ch_idx) const {
    return impl_ptr<impl>()->flex_ptr_at_channel(ch_idx);
}

template <typename T>
T *audio::pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) {
    if (!validate_pcm_format<T>(format().pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
        return nullptr;
    }

    return static_cast<T *>(flex_ptr_at_index(buf_idx).v);
}

template float *audio::pcm_buffer::data_ptr_at_index(uint32_t const buf_idx);
template double *audio::pcm_buffer::data_ptr_at_index(uint32_t const buf_idx);
template int32_t *audio::pcm_buffer::data_ptr_at_index(uint32_t const buf_idx);
template int16_t *audio::pcm_buffer::data_ptr_at_index(uint32_t const buf_idx);

template <typename T>
T *audio::pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) {
    if (!validate_pcm_format<T>(format().pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
        return nullptr;
    }

    return static_cast<T *>(flex_ptr_at_channel(ch_idx).v);
}

template float *audio::pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx);
template double *audio::pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx);
template int32_t *audio::pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx);
template int16_t *audio::pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx);

template <typename T>
const T *audio::pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) const {
    if (!validate_pcm_format<T>(format().pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
        return nullptr;
    }

    return static_cast<const T *>(flex_ptr_at_index(buf_idx).v);
}

template const float *audio::pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) const;
template const double *audio::pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) const;
template const int32_t *audio::pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) const;
template const int16_t *audio::pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) const;

template <typename T>
const T *audio::pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) const {
    if (!validate_pcm_format<T>(format().pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
        return nullptr;
    }

    return static_cast<const T *>(flex_ptr_at_channel(ch_idx).v);
}

template const float *audio::pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) const;
template const double *audio::pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) const;
template const int32_t *audio::pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) const;
template const int16_t *audio::pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) const;

uint32_t audio::pcm_buffer::frame_capacity() const {
    return impl_ptr<impl>()->frame_capacity;
}

uint32_t audio::pcm_buffer::frame_length() const {
    return impl_ptr<impl>()->frame_length;
}

void audio::pcm_buffer::set_frame_length(uint32_t const length) {
    if (length > frame_capacity()) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. frame_length(" +
                                std::to_string(length) + ") frame_capacity(" + std::to_string(frame_capacity()) + ")");
        return;
    }

    impl_ptr<impl>()->frame_length = length;

    uint32_t const data_byte_size = format().stream_description().mBytesPerFrame * length;
    set_data_byte_size(*this, data_byte_size);
}

void audio::pcm_buffer::reset() {
    set_frame_length(frame_capacity());
    audio::clear(audio_buffer_list());
}

void audio::pcm_buffer::clear() {
    clear(0, frame_length());
}

void audio::pcm_buffer::clear(uint32_t const start_frame, uint32_t const length) {
    if ((start_frame + length) > frame_length()) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. frame(" +
                                std::to_string(start_frame) + " length(" + std::to_string(length) + " frame_length(" +
                                std::to_string(frame_length()) + ")");
    }

    uint32_t const bytes_per_frame = format().stream_description().mBytesPerFrame;
    for (uint32_t i = 0; i < format().buffer_count(); i++) {
        uint8_t *byte_data = static_cast<uint8_t *>(audio_buffer_list()->mBuffers[i].mData);
        memset(&byte_data[start_frame * bytes_per_frame], 0, length * bytes_per_frame);
    }
}

audio::pcm_buffer::copy_result audio::pcm_buffer::copy_from(audio::pcm_buffer const &from_buffer,
                                                            uint32_t const from_start_frame,
                                                            uint32_t const to_start_frame, uint32_t const length) {
    if (!from_buffer) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::buffer_is_null);
    }

    auto from_format = from_buffer.format();

    if ((from_format.pcm_format() != format().pcm_format()) ||
        (from_format.channel_count() != format().channel_count())) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::invalid_format);
    }

    const AudioBufferList *const from_abl = from_buffer.audio_buffer_list();
    AudioBufferList *const to_abl = audio_buffer_list();

    auto result = copy(from_abl, to_abl, from_format.sample_byte_count(), from_start_frame, to_start_frame, length);

    if (result && from_start_frame == 0 && to_start_frame == 0 && length == 0) {
        set_frame_length(result.value());
    }

    return result;
}

audio::pcm_buffer::copy_result audio::pcm_buffer::copy_from(const AudioBufferList *const from_abl,
                                                            uint32_t const from_start_frame,
                                                            uint32_t const to_start_frame, uint32_t const length) {
    set_frame_length(0);
    reset_data_byte_size(*this);

    AudioBufferList *to_abl = audio_buffer_list();

    auto result = copy(from_abl, to_abl, format().sample_byte_count(), from_start_frame, to_start_frame, length);

    if (result) {
        set_frame_length(result.value());
    }

    return result;
}

audio::pcm_buffer::copy_result audio::pcm_buffer::copy_to(AudioBufferList *const to_abl,
                                                          uint32_t const from_start_frame,
                                                          uint32_t const to_start_frame, uint32_t const length) {
    const AudioBufferList *const from_abl = audio_buffer_list();

    return copy(from_abl, to_abl, format().sample_byte_count(), from_start_frame, to_start_frame, length);
}

#pragma mark - global

void audio::clear(AudioBufferList *abl) {
    for (uint32_t i = 0; i < abl->mNumberBuffers; ++i) {
        if (abl->mBuffers[i].mData) {
            memset(abl->mBuffers[i].mData, 0, abl->mBuffers[i].mDataByteSize);
        }
    }
}

audio::pcm_buffer::copy_result audio::copy(const AudioBufferList *const from_abl, AudioBufferList *const to_abl,
                                           uint32_t const sample_byte_count, uint32_t const from_start_frame,
                                           uint32_t const to_start_frame, uint32_t const length) {
    auto from_result = get_abl_info(from_abl, sample_byte_count);
    if (!from_result) {
        return pcm_buffer::copy_result(from_result.error());
    }

    auto to_result = get_abl_info(to_abl, sample_byte_count);
    if (!to_result) {
        return pcm_buffer::copy_result(to_result.error());
    }

    auto from_info = from_result.value();
    auto to_info = to_result.value();

    uint32_t const copy_length = length ?: (from_info.frame_length - from_start_frame);

    if ((from_start_frame + copy_length) > from_info.frame_length ||
        (to_start_frame + copy_length) > to_info.frame_length || from_info.channel_count > to_info.channel_count) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::out_of_range);
    }

    for (uint32_t ch_idx = 0; ch_idx < from_info.channel_count; ch_idx++) {
        uint32_t const &from_stride = from_info.strides[ch_idx];
        uint32_t const &to_stride = to_info.strides[ch_idx];
        const void *from_data = &(from_info.datas[ch_idx][from_start_frame * sample_byte_count * from_stride]);
        void *to_data = &(to_info.datas[ch_idx][to_start_frame * sample_byte_count * to_stride]);

        if (from_stride == 1 && to_stride == 1) {
            memcpy(to_data, from_data, copy_length * sample_byte_count);
        } else {
            if (sample_byte_count == sizeof(float)) {
                auto from_float32_data = static_cast<const float *>(from_data);
                auto to_float_data = static_cast<float *>(to_data);
                cblas_scopy(copy_length, from_float32_data, from_stride, to_float_data, to_stride);
            } else if (sample_byte_count == sizeof(double)) {
                auto from_float64_data = static_cast<const double *>(from_data);
                auto to_float64_data = static_cast<double *>(to_data);
                cblas_dcopy(copy_length, from_float64_data, from_stride, to_float64_data, to_stride);
            } else {
                for (uint32_t frame = 0; frame < copy_length; ++frame) {
                    uint32_t const sample_frame = frame * sample_byte_count;
                    auto from_byte_data = static_cast<const uint8_t *>(from_data);
                    auto to_byte_data = static_cast<uint8_t *>(to_data);
                    memcpy(&to_byte_data[sample_frame * to_stride], &from_byte_data[sample_frame * from_stride],
                           sample_byte_count);
                }
            }
        }
    }

    return pcm_buffer::copy_result(copy_length);
}

uint32_t audio::frame_length(const AudioBufferList *const abl, uint32_t const sample_byte_count) {
    if (sample_byte_count > 0) {
        uint32_t out_frame_length = 0;
        for (uint32_t buf = 0; buf < abl->mNumberBuffers; buf++) {
            const AudioBuffer *const ab = &abl->mBuffers[buf];
            uint32_t const stride = ab->mNumberChannels;
            uint32_t const frame_length = ab->mDataByteSize / stride / sample_byte_count;
            if (buf == 0) {
                out_frame_length = frame_length;
            } else if (out_frame_length != frame_length) {
                return 0;
            }
        }
        return out_frame_length;
    } else {
        return 0;
    }
}

bool audio::is_equal_structure(AudioBufferList const &abl1, AudioBufferList const &abl2) {
    if (abl1.mNumberBuffers != abl2.mNumberBuffers) {
        return false;
    }

    for (uint32_t i = 0; i < abl1.mNumberBuffers; i++) {
        if (abl1.mBuffers[i].mData != abl2.mBuffers[i].mData) {
            return false;
        } else if (abl1.mBuffers[i].mNumberChannels != abl2.mBuffers[i].mNumberChannels) {
            return false;
        }
    }

    return true;
}

std::string yas::to_string(audio::pcm_buffer::copy_error_t const &error) {
    switch (error) {
        case audio::pcm_buffer::copy_error_t::invalid_argument:
            return "invalid_argument";
        case audio::pcm_buffer::copy_error_t::invalid_abl:
            return "invalid_abl";
        case audio::pcm_buffer::copy_error_t::invalid_format:
            return "invalid_format";
        case audio::pcm_buffer::copy_error_t::out_of_range:
            return "out_of_range";
        case audio::pcm_buffer::copy_error_t::buffer_is_null:
            return "buffer_is_null";
    }
}
