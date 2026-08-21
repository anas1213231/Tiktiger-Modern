#import "TiktigerGlassCard.h"
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerFeatureStatusCard : TiktigerGlassCard

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding>)binding;
- (void)refreshFromBinding;

@end

NS_ASSUME_NONNULL_END
