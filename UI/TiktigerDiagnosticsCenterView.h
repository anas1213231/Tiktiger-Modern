#import <UIKit/UIKit.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerDiagnosticsCenterView : UIView

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding>)binding;
- (void)refreshHealth;

@end

NS_ASSUME_NONNULL_END
