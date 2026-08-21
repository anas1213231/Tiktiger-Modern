#import "TiktigerFeatureModuleDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *TiktigerStringFromProfileConfigurationState(NSInteger state);

typedef NS_ENUM(NSInteger, TiktigerProfileConfigurationState) {
    TiktigerProfileConfigurationStateConfigured = 0,
    TiktigerProfileConfigurationStateReviewRequired,
    TiktigerProfileConfigurationStateDegraded
};

@interface TiktigerProfileModule : TiktigerFeatureModuleDescriptor

+ (NSDictionary<NSString *, id> *)defaultProfileConfiguration;
- (BOOL)updateProfileSetting:(NSString *)key value:(id)value error:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)profileSnapshot;
- (NSDictionary<NSString *, id> *)profileHealthSnapshot;

@end

NS_ASSUME_NONNULL_END
