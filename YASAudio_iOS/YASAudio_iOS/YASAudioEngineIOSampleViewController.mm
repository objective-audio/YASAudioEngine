//
//  YASAudioEngineIOSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineIOSampleViewController.h"
#import "YASAudioEngineIOSampleSelectionViewController.h"
#import "YASAudioSliderCell.h"
#import "yas_audio.h"
#import <Accelerate/Accelerate.h>

static UInt32 const YASAudioEngineIOSampleConnectionMaxChannels = 2;

typedef NS_ENUM(NSUInteger, YASAudioEngineIOSampleSection) {
    YASAudioEngineIOSampleSectionInfo,
    YASAudioEngineIOSampleSectionSlider,
    YASAudioEngineIOSampleSectionNotify,
    YASAudioEngineIOSampleSectionChannelMapOutput,
    YASAudioEngineIOSampleSectionChannelMapInput,
    YASAudioEngineIOSampleSectionChannelRouteOutput,
    YASAudioEngineIOSampleSectionChannelRouteInput,
    YASAudioEngineIOSampleSectionCount,
};

namespace yas
{
    namespace sample
    {
        class meter_input_tap_node;

        using meter_input_tap_node_ptr = std::shared_ptr<meter_input_tap_node>;

        class meter_input_tap_node : public audio_input_tap_node
        {
           public:
            enum class property_key {
                meter_level,
            };

            yas::property<property_key, Float32>::sptr meter_level;

            using property_observer_ptr = yas::observer::sptr;

            static meter_input_tap_node_ptr create()
            {
                auto node = meter_input_tap_node_ptr(new meter_input_tap_node);

                std::weak_ptr<meter_input_tap_node> weak_node = node;

                node->set_render_function([weak_node](const yas::audio_pcm_buffer_sptr &buffer, const UInt32 bus_idx,
                                                      const yas::audio_time_sptr &when) {
                    if (auto node = weak_node.lock()) {
                        node->render_source(buffer, bus_idx, when);

                        Float32 current_max = 0;
                        yas::audio_frame_enumerator enumerator(buffer);
                        const auto *flex_ptr = enumerator.pointer();
                        while (flex_ptr->v) {
                            current_max =
                                MAX(current_max,
                                    fabsf(flex_ptr->f32[cblas_isamax((int)buffer->frame_length(), flex_ptr->f32, 1)]));
                            yas_audio_frame_enumerator_move_channel(enumerator);
                        }

                        const CFAbsoluteTime current_time = CFAbsoluteTimeGetCurrent();
                        const CFAbsoluteTime max_duration = node->_last_update_max_time_on_render > 0 ?
                                                                current_time - node->_last_update_max_time_on_render :
                                                                0.0f;
                        const Float32 reduced_level = MAX(0.0f, node->_last_max_on_render - max_duration * 1.0);
                        const Float32 level = MAX(reduced_level, MIN(1.0f, current_max));
                        node->_last_max_on_render = level;
                        node->_last_update_max_time_on_render = current_time;

                        const CFAbsoluteTime meter_duration = current_time - node->_last_update_meter_time_on_render;
                        if (meter_duration > 1.0 / 15.0f) {
                            auto update_function = [weak_node, level]() {
                                if (auto strong_node = weak_node.lock()) {
                                    strong_node->meter_level->set_value(level);
                                }
                            };
                            dispatch_async(dispatch_get_main_queue(), update_function);
                            node->_last_update_meter_time_on_render = current_time;
                        }
                    }
                });

                return node;
            }

            meter_input_tap_node()
                : meter_level(yas::make_property(property_key::meter_level, 0.0f)),
                  _last_max_on_render(0.0f),
                  _last_update_max_time_on_render(0.0),
                  _last_update_meter_time_on_render(0.0)
            {
            }

            virtual ~meter_input_tap_node()
            {
            }

           private:
            Float32 _last_max_on_render;
            CFAbsoluteTime _last_update_max_time_on_render;
            CFAbsoluteTime _last_update_meter_time_on_render;
        };
    }
}

@interface YASAudioEngineIOSampleViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;

@end

@implementation YASAudioEngineIOSampleViewController {
    yas::audio_engine_sptr _engine;
    yas::audio_unit_mixer_node_sptr _mixer_node;
    yas::audio_unit_io_node_sptr _io_node;

    yas::observer::sptr _engine_observer;
}

- (void)dealloc
{
    YASRelease(_slider);

    _slider = nil;

    YASSuperDealloc;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        BOOL success = NO;
        NSString *errorMessage = nil;
        NSError *error = nil;

        if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryMultiRoute error:&error]) {
            [self setupEngine];

            const auto start_result = _engine->start_render();
            if (start_result) {
                [self.tableView reloadData];
                [self _updateSlider];
                success = YES;
            } else {
                const auto error_string = yas::to_string(start_result.error());
                errorMessage = (__bridge NSString *)yas::to_cf_object(error_string);
            }
        } else {
            errorMessage = error.description;
        }

        if (!success) {
            [self _showErrorAlertWithMessage:errorMessage];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        if (_engine) {
            _engine->stop();
        }

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(UITableViewCell *)cell
{
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioEngineIOSampleSelectionViewController class]]) {
        YASAudioEngineIOSampleSelectionViewController *controller = destinationViewController;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        controller.fromCellIndexPath = indexPath;
        switch (indexPath.section) {
            case YASAudioEngineIOSampleSectionChannelMapOutput:
                controller.channelCount = [self _connectionChannelCountForDirection:yas::direction::output];
                break;
            case YASAudioEngineIOSampleSectionChannelMapInput:
                controller.channelCount = [self _connectionChannelCountForDirection:yas::direction::input];
                break;
            default:
                break;
        }
    }
}

- (IBAction)unwindForSegue:(UIStoryboardSegue *)segue
{
    id sourceViewController = segue.sourceViewController;
    if ([sourceViewController isKindOfClass:[YASAudioEngineIOSampleSelectionViewController class]]) {
        YASAudioEngineIOSampleSelectionViewController *controller = sourceViewController;
        NSIndexPath *indexPath = controller.fromCellIndexPath;

        yas::direction dir = [self _directionForSection:indexPath.section];

        auto map = _io_node->channel_map(dir);
        if (map.empty()) {
            map.resize([self _deviceChannelCountForDirection:dir], -1);
        }

        auto &value = map.at(indexPath.row);
        value = controller.selectedValue;

        _io_node->set_channel_map(map, dir);

        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (IBAction)volumeSliderChanged:(UISlider *)sender
{
    const Float32 value = sender.value;
    if (_mixer_node) {
        _mixer_node->set_input_volume(value, 0);
    }
}

- (void)setupEngine
{
    _engine = yas::audio_engine::create();
    _io_node = yas::audio_unit_io_node::create();
    _mixer_node = yas::audio_unit_mixer_node::create();

    _mixer_node->set_input_volume(1.0, 0);

    auto weak_self = yas::objc_weak_container::create(self);
    _engine_observer = yas::observer::create();
    _engine_observer->add_handler(
        _engine->subject(), yas::audio_engine_method::configuration_change,
        [weak_self](const auto &method, const auto &sender) {
            if (auto strong_self = weak_self->lock()) {
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                    YASAudioEngineIOSampleViewController *controller = strong_self.object();
                    [controller _updateEngine];
                }
            }
        });

    [self _connectNodes];
}

- (void)_updateEngine
{
    [self _disconnectNodes];
    [self _connectNodes];

    [self.tableView reloadData];
    [self _updateSlider];
}

- (void)_disconnectNodes
{
    _engine->disconnect(_mixer_node);
}

- (void)_connectNodes
{
    const Float64 sample_rate = _io_node->device_sample_rate();

    const UInt32 output_channel_count = [self _connectionChannelCountForDirection:yas::direction::output];
    if (output_channel_count > 0) {
        auto output_format = yas::audio_format(sample_rate, output_channel_count);
        _engine->connect(_mixer_node, _io_node, output_format);
    }

    const UInt32 input_channel_count = [self _connectionChannelCountForDirection:yas::direction::input];
    if (input_channel_count > 0) {
        auto input_format = yas::audio_format(sample_rate, input_channel_count);
        _engine->connect(_io_node, _mixer_node, input_format);
    }
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (!_engine) {
        return 0;
    }

    return YASAudioEngineIOSampleSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (!_engine) {
        return 0;
    }

    switch (section) {
        case YASAudioEngineIOSampleSectionInfo:
        case YASAudioEngineIOSampleSectionSlider:
        case YASAudioEngineIOSampleSectionNotify:
            return 1;
        case YASAudioEngineIOSampleSectionChannelMapOutput:
        case YASAudioEngineIOSampleSectionChannelMapInput:
            return [self _deviceChannelCountForSection:section] + 1;
        case YASAudioEngineIOSampleSectionChannelRouteOutput:
            return [AVAudioSession sharedInstance].currentRoute.outputs.count;
        case YASAudioEngineIOSampleSectionChannelRouteInput:
            return [AVAudioSession sharedInstance].currentRoute.inputs.count;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case YASAudioEngineIOSampleSectionInfo:
        case YASAudioEngineIOSampleSectionSlider:
        case YASAudioEngineIOSampleSectionNotify:
            return nil;
        case YASAudioEngineIOSampleSectionChannelMapOutput:
            return @"Output Channel Map";
        case YASAudioEngineIOSampleSectionChannelMapInput:
            return @"Input Channel Map";
        case YASAudioEngineIOSampleSectionChannelRouteOutput:
            return @"Output Channel Routes";
        case YASAudioEngineIOSampleSectionChannelRouteInput:
            return @"Input Channel Routes";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case YASAudioEngineIOSampleSectionInfo: {
            UITableViewCell *cell = [self _dequeueNormalCellWithIndexPath:indexPath];
            cell.textLabel.text = [NSString stringWithFormat:@"sr:%@ out:%@ in:%@", @(_io_node->device_sample_rate()),
                                                             @(_io_node->output_device_channel_count()),
                                                             @(_io_node->input_device_channel_count())];
            return cell;
        } break;

        case YASAudioEngineIOSampleSectionSlider: {
            YASAudioSliderCell *cell = [self _dequeueSliderWithIndexPath:indexPath];
            cell.slider.value = _mixer_node->input_volume(0);
            return cell;
        } break;

        case YASAudioEngineIOSampleSectionNotify: {
            UITableViewCell *cell = [self _dequeueNormalCellWithIndexPath:indexPath];
            cell.textLabel.text = @"Send Notify";
            return cell;
        } break;

        case YASAudioEngineIOSampleSectionChannelMapOutput:
        case YASAudioEngineIOSampleSectionChannelMapInput: {
            UITableViewCell *cell = [self _dequeueChannelMapCellWithIndexPath:indexPath];

            yas::direction dir = [self _directionForSection:indexPath.section];
            UInt32 map_size = [self _deviceChannelCountForDirection:dir];

            if (indexPath.row < map_size) {
                const auto &map = _io_node->channel_map(dir);
                NSString *selected = nil;
                if (map.empty()) {
                    selected = @"empty";
                } else {
                    selected = [NSString stringWithFormat:@"%@", @(map.at(indexPath.row))];
                }
                cell.textLabel.text = [NSString stringWithFormat:@"%@ - %@", @(indexPath.row), selected];
            } else {
                cell.textLabel.text = @"Clear";
            }

            return cell;
        } break;

        case YASAudioEngineIOSampleSectionChannelRouteOutput: {
            AVAudioSessionPortDescription *port = [AVAudioSession sharedInstance].currentRoute.outputs[indexPath.row];
            UITableViewCell *cell = [self _dequeueNormalCellWithIndexPath:indexPath];
            cell.textLabel.text =
                [NSString stringWithFormat:@"name:%@ channels:%@", port.portName, @(port.channels.count)];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        } break;

        case YASAudioEngineIOSampleSectionChannelRouteInput: {
            AVAudioSessionPortDescription *port = [AVAudioSession sharedInstance].currentRoute.inputs[indexPath.row];
            UITableViewCell *cell = [self _dequeueNormalCellWithIndexPath:indexPath];
            cell.textLabel.text =
                [NSString stringWithFormat:@"name:%@ channels:%@", port.portName, @(port.channels.count)];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        } break;
    }

    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case YASAudioEngineIOSampleSectionNotify: {
            if (_engine) {
                _engine->subject().notify(yas::audio_engine_method::configuration_change);
            }
        } break;

        case YASAudioEngineIOSampleSectionChannelMapOutput:
        case YASAudioEngineIOSampleSectionChannelMapInput: {
            yas::direction dir = [self _directionForSection:indexPath.section];
            auto map = _io_node->channel_map(dir);
            if (indexPath.row == [self _deviceChannelCountForSection:indexPath.section]) {
                map.clear();
                _io_node->set_channel_map(map, dir);

                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        } break;

        case YASAudioEngineIOSampleSectionChannelRouteOutput: {
            AVAudioSessionPortDescription *port = [AVAudioSession sharedInstance].currentRoute.outputs[indexPath.row];
            auto map = yas::to_channel_map(port.channels, yas::direction::output);
            _io_node->set_channel_map(map, yas::direction::output);

            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:YASAudioEngineIOSampleSectionChannelMapOutput]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        } break;

        case YASAudioEngineIOSampleSectionChannelRouteInput: {
            AVAudioSessionPortDescription *port = [AVAudioSession sharedInstance].currentRoute.inputs[indexPath.row];
            auto map = yas::to_channel_map(port.channels, yas::direction::input);
            _io_node->set_channel_map(map, yas::direction::input);

            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:YASAudioEngineIOSampleSectionChannelMapInput]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        } break;
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark -

- (void)_showErrorAlertWithMessage:(NSString *)message
{
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

- (YASAudioSliderCell *)_dequeueSliderWithIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"SliderCell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return (YASAudioSliderCell *)cell;
}

- (UITableViewCell *)_dequeueNormalCellWithIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

- (UITableViewCell *)_dequeueChannelMapCellWithIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < [self _deviceChannelCountForSection:indexPath.section]) {
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"PushCell" forIndexPath:indexPath];
        cell.textLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else {
        return [self _dequeueNormalCellWithIndexPath:indexPath];
    }
}

- (void)_updateSlider
{
    if (_mixer_node) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:YASAudioEngineIOSampleSectionSlider];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            for (UIView *view in cell.contentView.subviews) {
                if ([view isKindOfClass:[UISlider class]]) {
                    UISlider *slider = (UISlider *)view;
                    slider.value = _mixer_node->input_volume(0);
                }
            }
        }
    }
}

- (yas::direction)_directionForSection:(NSInteger)section
{
    if (section - YASAudioEngineIOSampleSectionChannelMapOutput) {
        return yas::direction::input;
    } else {
        return yas::direction::output;
    }
}

- (UInt32)_connectionChannelCountForDirection:(yas::direction)dir
{
    switch (dir) {
        case yas::direction::output:
            return MIN(_io_node->output_device_channel_count(), YASAudioEngineIOSampleConnectionMaxChannels);
        case yas::direction::input:
            return MIN(_io_node->input_device_channel_count(), YASAudioEngineIOSampleConnectionMaxChannels);
        default:
            return 0;
    }
}

- (UInt32)_deviceChannelCountForDirection:(yas::direction)dir
{
    switch (dir) {
        case yas::direction::output:
            return _io_node->output_device_channel_count();
        case yas::direction::input:
            return _io_node->input_device_channel_count();
        default:
            return 0;
    }
}

- (UInt32)_deviceChannelCountForSection:(NSInteger)section
{
    switch (section) {
        case YASAudioEngineIOSampleSectionChannelMapOutput:
            return _io_node->output_device_channel_count();
        case YASAudioEngineIOSampleSectionChannelMapInput:
            return _io_node->input_device_channel_count();
        default:
            return 0;
    }
}

@end
