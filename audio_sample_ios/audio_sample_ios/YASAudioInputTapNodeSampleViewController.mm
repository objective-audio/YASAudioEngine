//
//  YASAudioInputTapNodeSampleViewController.mm
//

#import "YASAudioInputTapNodeSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <audio/yas_audio_umbrella.h>
#import <objc_utils/yas_objc_macros.h>

using namespace yas;

@interface YASAudioInputTapNodeSampleViewController ()

@property (nonatomic, strong) IBOutlet UIProgressView *progressView;
@property (nonatomic, strong) IBOutlet UILabel *label;
@property (nonatomic, strong) CADisplayLink *displayLink;

@end

namespace yas::sample {
struct input_tap_vc_internal {
    std::shared_ptr<audio::engine::manager> manager = audio::engine::make_manager();
    std::shared_ptr<audio::engine::au_input> au_input = audio::engine::make_au_input();
    std::shared_ptr<audio::engine::tap> input_tap = audio::engine::make_tap({.is_input = true});

    chaining::value::holder<float> input_level{audio::math::decibel_from_linear(0.0f)};

    input_tap_vc_internal() = default;

    void prepare() {
        double const sample_rate = au_input->au_io().device_sample_rate();
        audio::format format{{.sample_rate = sample_rate, .channel_count = 2}};
        manager->connect(au_input->au_io().au().node(), input_tap->node(), format);

        input_tap->set_render_handler([input_level = input_level, sample_rate](auto args) mutable {
            audio::pcm_buffer &buffer = args.buffer;

            auto each = audio::make_each_data<float>(buffer);
            int const frame_length = buffer.frame_length();
            float level = 0;

            while (yas_each_data_next_ch(each)) {
                auto const *const ptr = yas_each_data_ptr(each);
                level = std::max(fabsf(ptr[cblas_isamax(frame_length, ptr, 1)]), level);
            }

            float prev_level = input_level.raw() - frame_length / sample_rate * 30.0f;
            level = std::max(prev_level, audio::math::decibel_from_linear(level));
            input_level.set_value(level);
        });
    }

    void stop() {
        manager->stop();

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
};
}

@implementation YASAudioInputTapNodeSampleViewController {
    sample::input_tap_vc_internal _internal;
    CFTimeInterval _lastLabelUpdatedTime;
}

- (void)dealloc {
    yas_release(_label);
    yas_release(_progressView);

    _label = nil;
    _progressView = nil;

    yas_super_dealloc();
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    BOOL success = NO;
    NSError *error = nil;
    NSString *errorMessage = nil;

    if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
        _internal.prepare();
        auto start_result = _internal.manager->start_render();
        if (start_result) {
            success = YES;
            self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateUI:)];
            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        } else {
            auto const error_string = to_string(start_result.error());
            errorMessage = (__bridge NSString *)to_cf_object(error_string);
        }
    } else {
        errorMessage = error.description;
    }

    if (errorMessage) {
        [self _showErrorAlertWithMessage:errorMessage];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.displayLink invalidate];
    self.displayLink = nil;

    _internal.manager->stop();
}

- (void)updateUI:(CADisplayLink *)sender {
    float value = _internal.input_level.raw();

    self.progressView.progress = std::max((value + 72.0f) / 72.0f, 0.0f);

    CFTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
    if (currentTime - _lastLabelUpdatedTime > 0.1) {
        self.label.text = [NSString stringWithFormat:@"%.1f dB", value];
        _lastLabelUpdatedTime = currentTime;
    }
}

#pragma mark -

- (void)_showErrorAlertWithMessage:(NSString *)message {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error"
                                                                        message:message
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
                                                     [self.navigationController popViewControllerAnimated:YES];
                                                 }]];
    [self presentViewController:controller animated:YES completion:NULL];
}

@end
