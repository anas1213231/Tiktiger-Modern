#import "TiktigerFeatureModuleDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerPreferencesModule : TiktigerFeatureModuleDescriptor

- (BOOL)updateTheme:(NSString *)theme error:(NSError * _Nullable * _Nullable)error;
- (BOOL)updateAnimationSettings:(NSDictionary<NSString *, id> *)settings error:(NSError * _Nullable * _Nullable)error;
- (BOOL)updateInterfaceSettings:(NSDictionary<NSString *, id> *)settings error:(NSError * _Nullable * _Nullable)error;
- (BOOL)updateFeaturePreferences:(NSDictionary<NSString *, id> *)preferences error:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)preferencesSnapshot;

@end

NS_ASSUME_NONNULL_END
