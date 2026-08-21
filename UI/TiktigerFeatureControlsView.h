#import <UIKit/UIKit.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerFeatureControlsView : UIView

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding>)binding;
- (void)refreshControls;

@end

NS_ASSUME_NONNULL_END
