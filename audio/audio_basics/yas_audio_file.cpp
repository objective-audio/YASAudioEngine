//
//  yas_audio_file.mm
//

#include "yas_audio_file.h"
#include <AudioToolbox/AudioToolbox.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_exception.h>
#include <cpp_utils/yas_fast_each.h>
#include <cpp_utils/yas_result.h>
#include "yas_audio_pcm_buffer.h"

using namespace yas;

#pragma mark -

audio::file::file() {
}

audio::file::~file() {
    this->close();
}

audio::file::open_result_t audio::file::open(open_args args) {
    if (this->_ext_audio_file) {
        return open_result_t(open_error_t::opened);
    }

    if (!args.file_url || args.pcm_format == audio::pcm_format::other) {
        return open_result_t(open_error_t::invalid_argument);
    }

    this->_url = args.file_url;

    if (!this->_open_ext_audio_file(args.pcm_format, args.interleaved)) {
        return open_result_t(open_error_t::open_failed);
    }

    return open_result_t(nullptr);
}

audio::file::create_result_t audio::file::create(create_args args) {
    if (this->_ext_audio_file) {
        return create_result_t(create_error_t::created);
    }

    if (!args.file_url || !args.settings) {
        return create_result_t(create_error_t::invalid_argument);
    }

    this->_url = args.file_url;
    this->_file_type = args.file_type;

    if (!this->_create_ext_audio_file(args.settings, args.pcm_format, args.interleaved)) {
        return create_result_t(create_error_t::create_failed);
    }

    return create_result_t(nullptr);
}

void audio::file::close() {
    if (this->_ext_audio_file) {
        ext_audio_file_utils::dispose(this->_ext_audio_file);
        this->_ext_audio_file = nullptr;
    }
}

bool audio::file::is_opened() const {
    return this->_ext_audio_file != nullptr;
}

yas::url const &audio::file::url() const {
    return this->_url;
}

audio::file_type audio::file::file_type() const {
    return this->_file_type;
}

audio::format const &audio::file::file_format() const {
    return *this->_file_format;
}

audio::format const &audio::file::processing_format() const {
    return *this->_processing_format;
}

int64_t audio::file::file_length() const {
    if (this->_ext_audio_file) {
        return ext_audio_file_utils::get_file_length_frames(this->_ext_audio_file);
    }
    return 0;
}

int64_t audio::file::processing_length() const {
    if (!this->_processing_format || !this->_file_format) {
        return 0;
    }

    auto const fileLength = file_length();
    auto const rate = this->_processing_format->stream_description().mSampleRate /
                      this->_file_format->stream_description().mSampleRate;
    return fileLength * rate;
}

int64_t audio::file::file_frame_position() const {
    return this->_file_frame_position;
}

void audio::file::set_processing_format(audio::format format) {
    this->_processing_format = std::move(format);
    if (this->_ext_audio_file) {
        ext_audio_file_utils::set_client_format(this->_processing_format->stream_description(), this->_ext_audio_file);
    }
}

void audio::file::set_file_frame_position(uint32_t const position) {
    if (this->_file_frame_position != position) {
        OSStatus err = ExtAudioFileSeek(this->_ext_audio_file, position);
        if (err == noErr) {
            this->_file_frame_position = position;
        }
    }
}

audio::file::read_result_t audio::file::read_into_buffer(audio::pcm_buffer &buffer, uint32_t const frame_length) {
    if (!this->_ext_audio_file) {
        return read_result_t(read_error_t::closed);
    }

    if (buffer.format() != this->_processing_format) {
        return read_result_t(read_error_t::invalid_format);
    }

    if (buffer.frame_capacity() < frame_length) {
        return read_result_t(read_error_t::frame_length_out_of_range);
    }

    OSStatus err = noErr;
    uint32_t out_frame_length = 0;
    uint32_t remain_frames = frame_length > 0 ? frame_length : buffer.frame_capacity();

    auto const &format = buffer.format();
    uint32_t const buffer_count = format.buffer_count();
    uint32_t const stride = format.stride();

    if (auto abl_ptr = allocate_audio_buffer_list(buffer_count, 0, 0).first) {
        AudioBufferList *io_abl = abl_ptr.get();

        while (remain_frames) {
            uint32_t bytesPerFrame = format.stream_description().mBytesPerFrame;
            uint32_t dataByteSize = remain_frames * bytesPerFrame;
            uint32_t dataIndex = out_frame_length * bytesPerFrame;

            auto each = make_fast_each(buffer_count);
            while (yas_each_next(each)) {
                auto const &idx = yas_each_index(each);
                AudioBuffer *ab = &io_abl->mBuffers[idx];
                ab->mNumberChannels = stride;
                ab->mDataByteSize = dataByteSize;
                uint8_t *byte_data = static_cast<uint8_t *>(buffer.audio_buffer_list()->mBuffers[idx].mData);
                ab->mData = &byte_data[dataIndex];
            }

            UInt32 io_frames = remain_frames;

            err = ExtAudioFileRead(this->_ext_audio_file, &io_frames, io_abl);
            if (err != noErr) {
                break;
            }

            if (!io_frames) {
                break;
            }
            remain_frames -= io_frames;
            out_frame_length += io_frames;
        }
    }

    buffer.set_frame_length(out_frame_length);

    if (err != noErr) {
        return read_result_t(read_error_t::read_failed);
    } else {
        err = ExtAudioFileTell(this->_ext_audio_file, &this->_file_frame_position);
        if (err != noErr) {
            return read_result_t(read_error_t::tell_failed);
        }
    }

    return read_result_t(nullptr);
}

audio::file::write_result_t audio::file::write_from_buffer(audio::pcm_buffer const &buffer, bool const async) {
    if (!this->_ext_audio_file) {
        return write_result_t(write_error_t::closed);
    }

    if (buffer.format() != this->_processing_format) {
        return write_result_t(write_error_t::invalid_format);
    }

    OSStatus err = noErr;

    if (async) {
        err = ExtAudioFileWriteAsync(this->_ext_audio_file, buffer.frame_length(), buffer.audio_buffer_list());
    } else {
        err = ExtAudioFileWrite(this->_ext_audio_file, buffer.frame_length(), buffer.audio_buffer_list());
    }

    if (err != noErr) {
        return write_result_t(write_error_t::write_failed);
    } else {
        err = ExtAudioFileTell(this->_ext_audio_file, &this->_file_frame_position);
        if (err != noErr) {
            return write_result_t(write_error_t::tell_failed);
        }
    }

    return write_result_t(nullptr);
}

#pragma mark - private

bool audio::file::_open_ext_audio_file(pcm_format const pcm_format, bool const interleaved) {
    if (!ext_audio_file_utils::can_open(this->_url.cf_url())) {
        return false;
    }

    if (!ext_audio_file_utils::open(&this->_ext_audio_file, this->_url.cf_url())) {
        this->_ext_audio_file = nullptr;
        return false;
    };

    AudioStreamBasicDescription asbd;
    if (!ext_audio_file_utils::get_audio_file_format(&asbd, this->_ext_audio_file)) {
        this->close();
        return false;
    }

    AudioFileTypeID file_type_id = ext_audio_file_utils::get_audio_file_type_id(this->_ext_audio_file);

    try {
        this->_file_type = to_file_type(file_type_id);
    } catch (std::exception const &) {
        this->close();
        return false;
    }

    this->_file_format = format{asbd};

    this->_processing_format = format{{.sample_rate = _file_format->sample_rate(),
                                       .channel_count = this->_file_format->channel_count(),
                                       .pcm_format = pcm_format,
                                       .interleaved = interleaved}};

    if (!ext_audio_file_utils::set_client_format(this->_processing_format->stream_description(),
                                                 this->_ext_audio_file)) {
        this->close();
        return false;
    }

    return true;
}

bool audio::file::_create_ext_audio_file(CFDictionaryRef const &settings, pcm_format const pcm_format,
                                         bool const interleaved) {
    this->_file_format = format{settings};

    AudioFileTypeID file_type_id = audio::to_audio_file_type_id(this->_file_type);

    if (!ext_audio_file_utils::create(&this->_ext_audio_file, this->_url.cf_url(), file_type_id,
                                      this->_file_format->stream_description())) {
        this->_ext_audio_file = nullptr;
        return false;
    }

    this->_processing_format = format{{.sample_rate = this->_file_format->sample_rate(),
                                       .channel_count = this->_file_format->channel_count(),
                                       .pcm_format = pcm_format,
                                       .interleaved = interleaved}};

    if (!ext_audio_file_utils::set_client_format(this->_processing_format->stream_description(),
                                                 this->_ext_audio_file)) {
        this->close();
        return false;
    }

    return true;
}

#pragma mark -

audio::file::make_opened_result_t audio::make_opened_file(file::open_args args) {
    audio::file file;
    if (auto result = file.open(std::move(args))) {
        return file::make_opened_result_t{std::move(file)};
    } else {
        return file::make_opened_result_t{std::move(result.error())};
    }
}

audio::file::make_created_result_t audio::make_created_file(file::create_args args) {
    audio::file file;
    if (auto result = file.create(std::move(args))) {
        return file::make_created_result_t{std::move(file)};
    } else {
        return file::make_created_result_t{std::move(result.error())};
    }
}

std::string yas::to_string(audio::file::open_error_t const &error_t) {
    switch (error_t) {
        case audio::file::open_error_t::opened:
            return "opened";
        case audio::file::open_error_t::invalid_argument:
            return "invalid_argument";
        case audio::file::open_error_t::open_failed:
            return "open_failed";
    }
}

std::string yas::to_string(audio::file::read_error_t const &error_t) {
    switch (error_t) {
        case audio::file::read_error_t::closed:
            return "closed";
        case audio::file::read_error_t::invalid_format:
            return "invalid_format";
        case audio::file::read_error_t::read_failed:
            return "read_failed";
        case audio::file::read_error_t::tell_failed:
            return "tell_failed";
        case audio::file::read_error_t::frame_length_out_of_range:
            return "frame_length_out_of_range";
    }
}

std::string yas::to_string(audio::file::create_error_t const &error_t) {
    switch (error_t) {
        case audio::file::create_error_t::created:
            return "created";
        case audio::file::create_error_t::invalid_argument:
            return "invalid_argument";
        case audio::file::create_error_t::create_failed:
            return "create_failed";
    }
}

std::string yas::to_string(audio::file::write_error_t const &error_t) {
    switch (error_t) {
        case audio::file::write_error_t::closed:
            return "closed";
        case audio::file::write_error_t::invalid_format:
            return "invalid_format";
        case audio::file::write_error_t::write_failed:
            return "write_failed";
        case audio::file::write_error_t::tell_failed:
            return "tell_failed";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::file::open_error_t const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::file::read_error_t const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::file::create_error_t const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::file::write_error_t const &value) {
    os << to_string(value);
    return os;
}
