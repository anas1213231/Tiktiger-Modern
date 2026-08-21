#import "TiktigerFeatureModuleDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

@class TiktigerModuleManager;

FOUNDATION_EXPORT NSString *TiktigerStringFromSystemConfigurationState(NSInteger state);

typedef NS_ENUM(NSInteger, TiktigerSystemConfigurationState) {
    TiktigerSystemConfigurationStateReady = 0,
    TiktigerSystemConfigurationStateReviewRequired,
    TiktigerSystemConfigurationStateDegraded
};

@interface TiktigerSystemModule : TiktigerFeatureModuleDescriptor

- (instancetype)initWithModuleManager:(TiktigerModuleManager *)moduleManager;
- (NSDictionary<NSString *, id> *)systemSnapshot;
- (NSDictionary<NSString *, id> *)featureManagerSnapshot;
- (NSDictionary<NSString *, id> *)diagnosticsHubSnapshot;
- (NSDictionary<NSString *, id> *)backupExportSnapshot;
- (BOOL)setManagedFeatureID:(NSString *)featureID enabled:(BOOL)enabled error:(NSError * _Nullable * _Nullable)error;
- (BOOL)importBackupPayload:(NSDictionary<NSString *, id> *)payload error:(NSError * _Nullable * _Nullable)error;
- (BOOL)resetSystemConfiguration:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
