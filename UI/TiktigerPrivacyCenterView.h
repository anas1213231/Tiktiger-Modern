#import <UIKit/UIKit.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerPrivacyCenterView : UIView

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding> _Nullable)binding;
- (void)setFeatureBinding:(id<TiktigerFeatureBinding> _Nullable)binding;
- (void)applyPrivacyPresentation:(NSDictionary<NSString *, id> *)snapshot;

@end

NS_ASSUME_NONNULL_END
