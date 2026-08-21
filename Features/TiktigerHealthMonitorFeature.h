#import "TiktigerFeatureModuleDescriptor.h"
@class TiktigerModuleManager;

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerHealthMonitorFeature : TiktigerFeatureModuleDescriptor

- (instancetype)initWithModuleManager:(TiktigerModuleManager *)moduleManager;

@end

NS_ASSUME_NONNULL_END
