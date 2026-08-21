#import <UIKit/UIKit.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^TiktigerDashboardNavigationHandler)(NSString *moduleID);

@interface TiktigerDashboardView : UIView

@property (nonatomic, copy) NSString *versionText;
@property (nonatomic, copy) NSString *runtimeStatusText;
@property (nonatomic, copy) NSString *featureSummaryText;
@property (nonatomic, copy, nullable) TiktigerDashboardNavigationHandler navigationHandler;

- (void)refreshPresentation;
- (void)setFeatureBinding:(id<TiktigerFeatureBinding> _Nullable)binding;

@end

NS_ASSUME_NONNULL_END
