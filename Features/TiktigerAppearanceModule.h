#import "TiktigerFeatureModuleDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *TiktigerStringFromAppearanceConfigurationState(NSInteger state);

typedef NS_ENUM(NSInteger, TiktigerAppearanceConfigurationState) {
    TiktigerAppearanceConfigurationStateValid = 0,
    TiktigerAppearanceConfigurationStateReviewRequired,
    TiktigerAppearanceConfigurationStateDegraded
};

@interface TiktigerAppearanceModule : TiktigerFeatureModuleDescriptor

+ (NSDictionary<NSString *, id> *)defaultAppearanceConfiguration;
- (BOOL)updateAppearanceSetting:(NSString *)key value:(id)value error:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)appearanceSnapshot;
- (NSDictionary<NSString *, id> *)appearanceHealthSnapshot;

@end

NS_ASSUME_NONNULL_END
