#import "TiktigerFeatureModuleDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *TiktigerStringFromChatConfigurationState(NSInteger state);

typedef NS_ENUM(NSInteger, TiktigerChatConfigurationState) {
    TiktigerChatConfigurationStateConfigured = 0,
    TiktigerChatConfigurationStateReviewRequired,
    TiktigerChatConfigurationStateDegraded
};

@interface TiktigerChatModule : TiktigerFeatureModuleDescriptor

+ (NSDictionary<NSString *, id> *)defaultChatConfiguration;
- (BOOL)updateChatSetting:(NSString *)key value:(id)value error:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)chatSnapshot;
- (NSDictionary<NSString *, id> *)chatHealthSnapshot;

@end

NS_ASSUME_NONNULL_END
