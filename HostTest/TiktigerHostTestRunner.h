#import <Foundation/Foundation.h>
#import "../Public/Tiktiger.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerHostTestRunner : NSObject

@property (nonatomic, strong, readonly) TiktigerHostCoordinator *hostCoordinator;
@property (nonatomic, strong, readonly) TiktigerPresentationBridge *presentationBridge;
@property (nonatomic, strong, readonly) TiktigerTikTokIntegrationBridge *integrationBridge;
@property (nonatomic, strong, readonly) TiktigerTikTokIntegrationDiagnostics *diagnostics;

- (BOOL)prepareWithError:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)validArtifactMetadata;
- (NSDictionary<NSString *, id> *)validCompatibilityMetadata;
- (NSDictionary<NSString *, id> *)validVideoContext;
- (NSDictionary<NSString *, id> *)runLifecycleValidation:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)runCompatibilityRecoveryValidation:(NSError * _Nullable * _Nullable)error;
- (BOOL)validateBindingRoutesAndDiagnostics:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
