#import <Foundation/Foundation.h>
#import "TiktigerTikTokEntryPoint.h"
#import "TiktigerTikTokCompatibility.h"
@class TiktigerHostCoordinator;
@class TiktigerPresentationBridge;
@class TiktigerTikTokIntegrationDiagnostics;

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerTikTokIntegrationBridge : NSObject

@property (nonatomic, weak, readonly) TiktigerHostCoordinator *hostCoordinator;
@property (nonatomic, weak, readonly) TiktigerPresentationBridge *presentationBridge;
@property (nonatomic, strong, readonly) TiktigerTikTokCompatibility *compatibility;
@property (nonatomic, strong, readonly) TiktigerTikTokIntegrationDiagnostics *diagnostics;

- (instancetype)initWithHostCoordinator:(TiktigerHostCoordinator *)hostCoordinator
                     presentationBridge:(TiktigerPresentationBridge *)presentationBridge
                          compatibility:(TiktigerTikTokCompatibility *)compatibility
                            diagnostics:(TiktigerTikTokIntegrationDiagnostics *)diagnostics;

/// Receives a host event and returns an immutable entry descriptor; it never presents or executes.
- (NSDictionary<NSString *, id> *)receiveHostEntryPoint:(TiktigerTikTokEntryPointKind)kind
                                                context:(NSDictionary<NSString *, id> *)context
                                               metadata:(NSDictionary<NSString *, id> *)metadata
                                                 error:(NSError * _Nullable * _Nullable)error;

/// Opens the Dashboard through validated host presentation contracts without creating a controller.
- (NSDictionary<NSString *, id> *)openDashboardDescriptor:(NSError * _Nullable * _Nullable)error;

/// Resolves a stable route through Presentation Bridge and returns a host routing descriptor only.
- (NSDictionary<NSString *, id> * _Nullable)routeHostEventToRoute:(NSString *)route error:(NSError * _Nullable * _Nullable)error;

- (NSDictionary<NSString *, id> *)statusSnapshot;

@end

NS_ASSUME_NONNULL_END
