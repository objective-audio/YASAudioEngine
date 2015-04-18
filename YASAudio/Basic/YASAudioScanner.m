//
//  YASAudioFrameScanner.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioScanner.h"
#import "YASAudioData.h"
#import "YASAudioFormat.h"
#import "NSException+YASAudio.h"
#import "YASMacros.h"

@implementation YASAudioScanner

- (instancetype)initWithAudioData:(YASAudioData *)data atChannel:(const NSUInteger)channel
{
    YASAudioMutablePointer pointer = [data pointerAtChannel:channel];
    YASAudioFormat *format = data.format;
    NSUInteger stride = format.stride * format.sampleByteCount;
    return [self initWithPointer:pointer stride:stride length:data.frameLength];
}

- (instancetype)initWithPointer:(const YASAudioMutablePointer)pointer
                         stride:(const NSUInteger)stride
                         length:(const NSUInteger)length
{
    self = [super init];
    if (self) {
        if (!pointer.v || stride == 0 || length == 0) {
            YASRaiseWithReason(([NSString stringWithFormat:@"%s - Invalid argument.", __PRETTY_FUNCTION__]));
            YASRelease(self);
            return nil;
        }
        _pointer = _topPointer = pointer;
        _stride = stride;
        _length = length;
        _index = 0;
    }
    return self;
}

- (const YASAudioPointer *)pointer
{
    return (YASAudioPointer *)&_pointer;
}

- (const NSUInteger *)index
{
    return &_index;
}

- (void)move
{
    if (++_index >= _length) {
        _pointer.v = NULL;
    } else {
        _pointer.v += _stride;
    }
}

- (void)setPosition:(const NSUInteger)index
{
    if (index >= _length) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Overflow index.", __PRETTY_FUNCTION__]));
        return;
    }
    _index = index;
    _pointer.v = _topPointer.v + (_stride * index);
}

- (void)reset
{
    _index = 0;
    _pointer.v = _topPointer.v;
}

@end

@implementation YASAudioMutableScanner

- (const YASAudioMutablePointer *)mutablePointer
{
    return &_pointer;
}

@end

@implementation YASAudioFrameScanner

- (instancetype)initWithAudioData:(YASAudioData *)data
{
    self = [super init];
    if (self) {
        YASAudioFormat *format = data.format;
        NSUInteger bufferCount = format.bufferCount;
        NSUInteger stride = format.stride;
        NSUInteger sampleByteCount = data.format.sampleByteCount;

        _frame = _channel = 0;
        _frameLength = data.frameLength;
        _channelCount = bufferCount * stride;
        _frameStride = stride * sampleByteCount;
        _pointersSize = _channelCount * sizeof(YASAudioMutablePointer *);
        _pointers = calloc(_pointersSize, 1);
        _topPointers = calloc(_channelCount, sizeof(YASAudioMutablePointer *));

        NSUInteger channel = 0;
        for (NSInteger buffer = 0; buffer < bufferCount; buffer++) {
            YASAudioMutablePointer pointer = [data pointerAtBuffer:buffer];
            for (NSInteger ch = 0; ch < stride; ch++) {
                _pointers[channel].v = _topPointers[channel].v = pointer.v;
                pointer.u8 += sampleByteCount;
                channel++;
            }
        }

        _pointer.v = _pointers->v;
    }
    return self;
}

- (void)dealloc
{
    free(_pointers);
    free(_topPointers);

    YASSuperDealloc;
}

- (const YASAudioPointer *)pointer
{
    return (YASAudioPointer *)&_pointer;
}

- (const NSUInteger *)frame
{
    return &_frame;
}

- (const NSUInteger *)channel
{
    return &_channel;
}

- (void)moveFrame
{
    if (++_frame >= _frameLength) {
        memset(_pointers, 0, _pointersSize);
        _pointer.v = NULL;
    } else {
        NSUInteger index = _channelCount;
        while (index--) {
            _pointers[index].u8 += _frameStride;
        }

        if (_pointer.v) {
            _pointer.v = _pointers[_channel].v;
        } else {
            _channel = 0;
            _pointer.v = _pointers->v;
        }
    }
}

- (void)moveChannel
{
    if (++_channel >= _channelCount) {
        _pointer.v = NULL;
    } else {
        _pointer.v = _pointers[_channel].v;
    }
}

- (void)setFramePosition:(const NSUInteger)frame
{
    if (frame >= _frameLength) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Overflow frame.", __PRETTY_FUNCTION__]));
        return;
    }

    _frame = frame;

    NSUInteger stride = _frameStride * frame;
    NSUInteger index = _channelCount;
    while (index--) {
        _pointers[index].v = _topPointers[index].v + stride;
    }

    if (_pointer.v) {
        _pointer.v = _pointers[_channel].v;
    } else {
        _channel = 0;
        _pointer.v = _pointers->v;
    }
}

- (void)setChannelPosition:(const NSUInteger)channel
{
    if (channel >= _channelCount) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Overflow channel.", __PRETTY_FUNCTION__]));
        return;
    }

    _channel = channel;
    _pointer.v = _pointers[_channel].v;
}

- (void)reset
{
    _frame = 0;
    _channel = 0;
    memcpy(_pointers, _topPointers, _channelCount * sizeof(YASAudioMutablePointer *));
    _pointer.v = _pointers->v;
}

@end

@implementation YASAudioMutableFrameScanner

- (const YASAudioMutablePointer *)mutablePointer
{
    return &_pointer;
}

@end
