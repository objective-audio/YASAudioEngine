//
//  YASAudioDeviceIO.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import "YASAudioDeviceIO.h"
#import "YASAudioDevice.h"
#import "YASAudioPCMBuffer.h"
#import "YASAudioTime.h"
#import "YASAudioFormat.h"
#import "YASAudioUtility.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"

static UInt32 YASAudioDeviceIOFrameCapacity = 4096;

@interface YASAudioDeviceIOCore : NSObject

@property (nonatomic, strong) YASAudioWritablePCMBuffer *inputBuffer;
@property (nonatomic, strong) YASAudioWritablePCMBuffer *outputBuffer;

@end

@implementation YASAudioDeviceIOCore

- (void)dealloc
{
    YASRelease(_inputBuffer);
    YASRelease(_outputBuffer);

    _inputBuffer = nil;
    _outputBuffer = nil;

    YASSuperDealloc;
}

- (void)clearBuffers
{
    [_inputBuffer clearData];
    [_outputBuffer clearData];
}

@end

@interface YASAudioDeviceIO ()

@property (nonatomic, assign) AudioDeviceIOProcID ioProcID;
@property (nonatomic, strong) YASAudioPCMBuffer *inputBuffer;
@property (nonatomic, strong) YASAudioTime *inputTime;
@property (atomic, strong) YASAudioDeviceIOCore *core;

@end

@implementation YASAudioDeviceIO

- (instancetype)init
{
    return [self initWithAudioDevice:nil];
}

- (instancetype)initWithAudioDevice:(YASAudioDevice *)device
{
    self = [super init];
    if (self) {
        self.audioDevice = device;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioHardwareDidChange:)
                                                     name:YASAudioHardwareDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [self uninitialize];

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    YASRelease(_renderCallbackBlock);
    YASRelease(_audioDevice);
    YASRelease(_inputBuffer);
    YASRelease(_inputTime);
    YASRelease(_core);

    _renderCallbackBlock = nil;
    _audioDevice = nil;
    _inputBuffer = nil;
    _inputTime = nil;
    _core = nil;

    YASSuperDealloc;
}

- (void)initialize
{
    if (!_audioDevice || _ioProcID) {
        return;
    }

    if (!_audioDevice.inputFormat && !_audioDevice.outputFormat) {
        YASLog(@"%s - Audio device do not have io.", __PRETTY_FUNCTION__);
        return;
    }

    YASWeakContainer *container = self.weakContainer;

    YASRaiseIfAUError(AudioDeviceCreateIOProcIDWithBlock(
        &_ioProcID, self.audioDevice.audioDeviceID, NULL,
        ^(const AudioTimeStamp *inNow, const AudioBufferList *inInputData, const AudioTimeStamp *inInputTime,
          AudioBufferList *outOutputData, const AudioTimeStamp *inOutputTime) {
            YASAudioClearAudioBufferList(outOutputData);

            YASAudioDeviceIO *deviceIO = [container retainedObject];

            YASAudioDeviceIOCore *core = deviceIO.core;
            if (core) {
                [core clearBuffers];

                YASAudioWritablePCMBuffer *inputBuffer = core.inputBuffer;
                [inputBuffer copyDataFlexiblyFromAudioBufferList:inInputData];

                const UInt32 inputFrameLength = inputBuffer.frameLength;
                if (inputFrameLength > 0) {
                    deviceIO.inputBuffer = inputBuffer;
                    YASAudioTime *inputTime =
                        [[YASAudioTime alloc] initWithAudioTimeStamp:inInputTime
                                                          sampleRate:inputBuffer.format.sampleRate];
                    deviceIO.inputTime = inputTime;
                    YASRelease(inputTime);
                }

                YASAudioDeviceIOCallbackBlock renderCallbackBlock = deviceIO.renderCallbackBlock;
                if (renderCallbackBlock) {
                    YASAudioWritablePCMBuffer *outputBuffer = core.outputBuffer;
                    if (outputBuffer) {
                        const UInt32 frameLength = YASAudioGetFrameLengthFromAudioBufferList(
                            outOutputData, outputBuffer.format.sampleByteCount);
                        if (frameLength > 0) {
                            outputBuffer.frameLength = frameLength;
                            YASAudioTime *time =
                                [[YASAudioTime alloc] initWithAudioTimeStamp:inOutputTime
                                                                  sampleRate:outputBuffer.format.sampleRate];
                            renderCallbackBlock(outputBuffer, time);
                            YASRelease(time);
                            [outputBuffer copyDataFlexiblyToAudioBufferList:outOutputData];
                        }
                    } else if (deviceIO.inputBuffer) {
                        renderCallbackBlock(NULL, NULL);
                    }
                }
            }

            deviceIO.inputBuffer = nil;
            deviceIO.inputTime = nil;
            YASRelease(deviceIO);
        }));

    [self _updateCore];
}

- (void)uninitialize
{
    [self stop];

    if (!_audioDevice || !_ioProcID) {
        return;
    }

    YASRaiseIfAUError(AudioDeviceDestroyIOProcID(self.audioDevice.audioDeviceID, _ioProcID));

    _ioProcID = NULL;

    [self _updateCore];
}

- (void)start
{
    _isRunning = YES;

    if (!_audioDevice || !_ioProcID) {
        return;
    }

    YASRaiseIfAUError(AudioDeviceStart(self.audioDevice.audioDeviceID, _ioProcID));
}

- (void)stop
{
    if (!_isRunning) {
        return;
    }

    _isRunning = NO;

    if (!_audioDevice || !_ioProcID) {
        return;
    }

    YASRaiseIfAUError(AudioDeviceStop(self.audioDevice.audioDeviceID, _ioProcID));
}

- (void)setAudioDevice:(YASAudioDevice *)audioDevice
{
    if (![self.audioDevice isEqualToAudioDevice:audioDevice]) {
        BOOL isRunning = _isRunning;

        [self uninitialize];

        if (_audioDevice) {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:YASAudioDeviceDidChangeNotification
                                                          object:_audioDevice];
        }

        YASRelease(_audioDevice);
        _audioDevice = YASRetain(audioDevice);

        if (audioDevice) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(audioDeviceDidChange:)
                                                         name:YASAudioDeviceDidChangeNotification
                                                       object:audioDevice];
        }

        [self initialize];

        if (isRunning) {
            [self start];
        }
    }
}

#pragma mark Notification

- (void)audioHardwareDidChange:(NSNotification *)notification
{
    if (_audioDevice && ![YASAudioDevice deviceForID:_audioDevice.audioDeviceID]) {
        self.audioDevice = nil;
    }
}

- (void)audioDeviceDidChange:(NSNotification *)notification
{
    [self _updateCore];
}

#pragma mark Private

- (void)_updateCore
{
    self.core = nil;

    if (!_audioDevice || !_ioProcID) {
        return;
    }

    YASAudioDeviceIOCore *core = [[YASAudioDeviceIOCore alloc] init];
    YASAudioFormat *inputFormat = self.audioDevice.inputFormat;
    YASAudioFormat *outputFormat = self.audioDevice.outputFormat;

    if (inputFormat) {
        YASAudioWritablePCMBuffer *inputBuffer =
            [[YASAudioWritablePCMBuffer alloc] initWithPCMFormat:inputFormat frameCapacity:YASAudioDeviceIOFrameCapacity];
        core.inputBuffer = inputBuffer;
        YASRelease(inputBuffer);
    }

    if (outputFormat) {
        YASAudioWritablePCMBuffer *outputBuffer =
            [[YASAudioWritablePCMBuffer alloc] initWithPCMFormat:outputFormat frameCapacity:YASAudioDeviceIOFrameCapacity];
        core.outputBuffer = outputBuffer;
        YASRelease(outputBuffer);
    }

    self.core = core;
    YASRelease(core);
}

#pragma mark Render thread

- (YASAudioPCMBuffer *)inputBufferOnRender
{
    return self.inputBuffer;
}

- (YASAudioTime *)inputTimeOnRender
{
    return self.inputTime;
}

@end

#endif
