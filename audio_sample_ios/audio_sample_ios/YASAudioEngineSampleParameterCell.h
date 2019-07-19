//
//  YASAudioEngineSampleParameterCell.h
//

#import <UIKit/UIKit.h>
#import <memory>
#import <optional>

namespace yas::audio::engine {
class au;
}

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)set_engine_au:(std::shared_ptr<yas::audio::engine::au> const &)node_opt index:(uint32_t const)index;

@end
