#import "TiktigerFeatureModuleDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerSecureConfigurationFeature : TiktigerFeatureModuleDescriptor

- (BOOL)validateConfiguration:(NSDictionary<NSString *, id> *)configuration error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
