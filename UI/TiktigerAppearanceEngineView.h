#import <UIKit/UIKit.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerAppearanceEngineView : UIView

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding> _Nullable)binding;
- (void)setFeatureBinding:(id<TiktigerFeatureBinding> _Nullable)binding;
- (void)applyAppearancePresentation:(NSDictionary<NSString *, id> *)snapshot;

@end

NS_ASSUME_NONNULL_END
