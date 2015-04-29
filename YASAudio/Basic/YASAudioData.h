//
//  YASAudioData.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "YASAudioTypes.h"

@class YASAudioFormat;

@interface YASAudioData : NSObject <NSCopying>

@property (nonatomic, strong, readonly) YASAudioFormat *format;
@property (nonatomic, readonly) const AudioBufferList *audioBufferList;
@property (nonatomic, readonly) AudioBufferList *mutableAudioBufferList;

@property (nonatomic, readonly) UInt32 frameCapacity;
@property (nonatomic) UInt32 frameLength;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFormat:(YASAudioFormat *)format frameCapacity:(UInt32)frameCapacity;

- (YASAudioMutablePointer)pointerAtBuffer:(NSUInteger)buffer;
- (YASAudioMutablePointer)pointerAtChannel:(NSUInteger)channel;

- (void)clear;
- (void)clearWithStartFrame:(UInt32)frame length:(UInt32)length;

- (BOOL)copyFromData:(YASAudioData *)fromData;
- (BOOL)copyFromData:(YASAudioData *)fromData
      fromStartFrame:(UInt32)fromFrame
        toStartFrame:(UInt32)toFrame
              length:(UInt32)length;

- (BOOL)copyFlexiblyFromData:(YASAudioData *)data;
- (BOOL)copyFlexiblyFromAudioBufferList:(const AudioBufferList *)fromAbl;
- (BOOL)copyFlexiblyToAudioBufferList:(AudioBufferList *)toAbl;

@end
