#import <Foundation/Foundation.h>
#import "TiktigerTikTokEntryPoint.h"
#import "TiktigerTikTokCompatibility.h"
@class TiktigerHostCoordinator;
@class TiktigerPresentationBridge;
@class TiktigerTikTokIntegrationDiagnostics;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerTikTokVideoPresentationLifecycleState) {
    TiktigerTikTokVideoPresentationLifecycleStateEntryReceived = 0,
    TiktigerTikTokVideoPresentationLifecycleStatePresentationRequested,
    TiktigerTikTokVideoPresentationLifecycleStatePresentationCompleted,
    TiktigerTikTokVideoPresentationLifecycleStatePresentationClosed,
    TiktigerTikTokVideoPresentationLifecycleStateReturnedToContext,
    TiktigerTikTokVideoPresentationLifecycleStateFailed
};

FOUNDATION_EXPORT NSString *TiktigerStringFromTikTokVideoPresentationLifecycleState(TiktigerTikTokVideoPresentationLifecycleState state);

typedef NS_ENUM(NSInteger, TiktigerTikTokDownloadFlowState) {
    TiktigerTikTokDownloadFlowStateContextValidated = 0,
    TiktigerTikTokDownloadFlowStateSmartSheetRequested,
    TiktigerTikTokDownloadFlowStateQueued,
    TiktigerTikTokDownloadFlowStatePreparing,
    TiktigerTikTokDownloadFlowStateDownloading,
    TiktigerTikTokDownloadFlowStateProcessing,
    TiktigerTikTokDownloadFlowStateCompleted,
    TiktigerTikTokDownloadFlowStateFailed,
    TiktigerTikTokDownloadFlowStateClosed,
    TiktigerTikTokDownloadFlowStateReturnedToContext
};

FOUNDATION_EXPORT NSString *TiktigerStringFromTikTokDownloadFlowState(TiktigerTikTokDownloadFlowState state);

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

/// Video-only entry contract. It validates the video context and records entry-received state.
- (NSDictionary<NSString *, id> *)receiveVideoActionContext:(NSDictionary<NSString *, id> *)context
                                                   metadata:(NSDictionary<NSString *, id> *)metadata
                                                      error:(NSError * _Nullable * _Nullable)error;

/// Connects a validated video entry to the existing Dashboard Presentation Bridge descriptor.
/// The host remains responsible for presenting the returned descriptor.
- (NSDictionary<NSString *, id> *)requestDashboardForVideoEntry:(NSDictionary<NSString *, id> *)videoEntry
                                                            error:(NSError * _Nullable * _Nullable)error;

/// Convenience contract for receive + dashboard request. It never executes presentation.
- (NSDictionary<NSString *, id> *)handleVideoActionContext:(NSDictionary<NSString *, id> *)context
                                                   metadata:(NSDictionary<NSString *, id> *)metadata
                                                      error:(NSError * _Nullable * _Nullable)error;

/// Records an explicit host acknowledgement that the dashboard presentation completed.
- (NSDictionary<NSString *, id> *)completeVideoPresentation:(NSDictionary<NSString *, id> *)hostEvent
                                                       error:(NSError * _Nullable * _Nullable)error;

/// Records an explicit host close event for the video-launched Dashboard.
- (NSDictionary<NSString *, id> *)closeVideoPresentationWithReason:(NSString *)reason
                                                              error:(NSError * _Nullable * _Nullable)error;

/// Records an explicit host return-to-video-context event.
- (NSDictionary<NSString *, id> *)returnToVideoContext:(NSDictionary<NSString *, id> *)hostEvent
                                                 error:(NSError * _Nullable * _Nullable)error;

/// Returns the existing Smart Download Sheet contract with validated source and current UI options.
- (NSDictionary<NSString *, id> *)requestSmartDownloadSheetForVideoEntry:(NSDictionary<NSString *, id> *)videoEntry
                                                                   options:(NSDictionary<NSString *, id> * _Nullable)options
                                                                      error:(NSError * _Nullable * _Nullable)error;

/// Starts a real Download Module action through Feature Binding using the validated source URL.
- (NSDictionary<NSString *, id> *)startDownloadForVideoEntry:(NSDictionary<NSString *, id> *)videoEntry
                                                      options:(NSDictionary<NSString *, id> * _Nullable)options
                                                         error:(NSError * _Nullable * _Nullable)error;

/// Records host closure of the TikTok-originated Download flow without cancelling the engine task.
- (NSDictionary<NSString *, id> *)closeTikTokDownloadFlowWithReason:(NSString *)reason
                                                                error:(NSError * _Nullable * _Nullable)error;

/// Records host restoration of the originating TikTok video context.
- (NSDictionary<NSString *, id> *)returnToTikTokFromDownloadFlow:(NSDictionary<NSString *, id> * _Nullable)hostEvent
                                                             error:(NSError * _Nullable * _Nullable)error;

/// Opens the Dashboard through validated host presentation contracts without creating a controller.
- (NSDictionary<NSString *, id> *)openDashboardDescriptor:(NSError * _Nullable * _Nullable)error;

/// Resolves a stable route through Presentation Bridge and returns a host routing descriptor only.
- (NSDictionary<NSString *, id> * _Nullable)routeHostEventToRoute:(NSString *)route error:(NSError * _Nullable * _Nullable)error;

- (NSDictionary<NSString *, id> *)statusSnapshot;

@end

NS_ASSUME_NONNULL_END
