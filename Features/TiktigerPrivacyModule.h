#import "TiktigerFeatureModuleDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *TiktigerStringFromPrivacyProtectionState(NSInteger state);

typedef NS_ENUM(NSInteger, TiktigerPrivacyProtectionState) {
    TiktigerPrivacyProtectionStateProtected = 0,
    TiktigerPrivacyProtectionStateReviewRequired,
    TiktigerPrivacyProtectionStateDegraded
};

@interface TiktigerPrivacyModule : TiktigerFeatureModuleDescriptor

+ (NSDictionary<NSString *, id> *)defaultPrivacyConfiguration;
- (BOOL)updatePrivacySetting:(NSString *)key value:(id)value error:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)privacySnapshot;
- (NSDictionary<NSString *, id> *)privacyHealthSnapshot;

@end

NS_ASSUME_NONNULL_END
