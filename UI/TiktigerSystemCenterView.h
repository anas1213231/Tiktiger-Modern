#import <UIKit/UIKit.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerSystemCenterView : UIView

- (instancetype)initWithBinding:(nullable id<TiktigerFeatureBinding>)binding;
- (void)setFeatureBinding:(nullable id<TiktigerFeatureBinding>)binding;
- (void)applySystemPresentation:(NSDictionary<NSString *, id> *)snapshot;

@end

NS_ASSUME_NONNULL_END
