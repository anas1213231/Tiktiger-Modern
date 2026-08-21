#import "TiktigerFeatureModuleDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerUserPreferencesFeature : TiktigerFeatureModuleDescriptor

- (BOOL)validatePreferences:(NSDictionary<NSString *, id> *)preferences error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
