#import <UIKit/UIKit.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerSettingsView : UIView

@property (nonatomic, strong, readonly) UIScrollView *scrollView;

- (void)setFeatureBinding:(id<TiktigerFeatureBinding> _Nullable)binding;

@end

NS_ASSUME_NONNULL_END
