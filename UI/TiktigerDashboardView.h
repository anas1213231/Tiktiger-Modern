#import <UIKit/UIKit.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerDashboardView : UIView

@property (nonatomic, copy) NSString *versionText;
@property (nonatomic, copy) NSString *runtimeStatusText;
@property (nonatomic, copy) NSString *featureSummaryText;

- (void)refreshPresentation;
- (void)setFeatureBinding:(id<TiktigerFeatureBinding> _Nullable)binding;

@end

NS_ASSUME_NONNULL_END
