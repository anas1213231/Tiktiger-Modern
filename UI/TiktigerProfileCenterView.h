#import <UIKit/UIKit.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerProfileCenterView : UIView

- (instancetype)initWithBinding:(nullable id<TiktigerFeatureBinding>)binding;
- (void)setFeatureBinding:(nullable id<TiktigerFeatureBinding>)binding;
- (void)applyProfilePresentation:(NSDictionary<NSString *, id> *)snapshot;

@end

NS_ASSUME_NONNULL_END
