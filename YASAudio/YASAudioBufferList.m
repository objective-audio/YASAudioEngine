
/**
 *
 *  YASAudioBufferList.m
 *
 *  Created by Yuki Yasoshima
 *
 */

#import "YASAudioBufferList.h"
#import "YASAudioUtilities.h"
#import <AudioToolbox/AudioToolbox.h>

@implementation YASAudioBufferList {
    AudioBufferList *_audioBufferList;
}

+ (id)audioBufferWithBufferCount:(NSUInteger)bufferCount channels:(NSUInteger)ch bufferSize:(NSUInteger)size
{
    return [[[YASAudioBufferList alloc] initWithBufferCount:bufferCount channels:ch bufferSize:size] autorelease];
}

- (id)initWithBufferCount:(NSUInteger)bufferCount channels:(NSUInteger)ch bufferSize:(NSUInteger)size
{
    self = [super init];
    if (self) {
        _audioBufferList = YASAllocateAudioBufferList((UInt32)bufferCount, (UInt32)ch, (UInt32)size);
        _bufferCount = bufferCount;
        _channels = ch;
        _bufferSize = size;
    }
    return self;
}

- (void)dealloc
{
    YASRemoveAudioBufferList(_audioBufferList);
    [super dealloc];
}

- (void *)dataAtBufferIndex:(NSUInteger)bufferIndex
{
    if (bufferIndex >= _bufferCount) {
        return NULL;
    }
    return _audioBufferList->mBuffers[bufferIndex].mData;
}

@end
