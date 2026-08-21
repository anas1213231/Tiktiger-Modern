#import <Foundation/Foundation.h>
#import "TiktigerRuntimeState.h"
@class TiktigerDynamicLibraryLoader;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerHostCoordinatorState) {
    TiktigerHostCoordinatorStateIdle = 0,
    TiktigerHostCoordinatorStateInitializing,
    TiktigerHostCoordinatorStateReady,
    TiktigerHostCoordinatorStateDegraded,
    TiktigerHostCoordinatorStateShuttingDown,
    TiktigerHostCoordinatorStateStopped,
    TiktigerHostCoordinatorStateFailed
};

FOUNDATION_EXPORT NSString *TiktigerStringFromHostCoordinatorState(TiktigerHostCoordinatorState state);

@interface TiktigerHostCoordinator : NSObject

@property (nonatomic, assign, readonly) TiktigerHostCoordinatorState state;
@property (nonatomic, assign, readonly) TiktigerRuntimeState runtimeState;
@property (nonatomic, copy, readonly) NSString *lastErrorMessage;

- (instancetype)initWithLoader:(TiktigerDynamicLibraryLoader *)loader;

/// Preparation lifecycle only: calls the public lifecycle API after an explicit loader preflight.
- (BOOL)initializeHost:(NSError * _Nullable * _Nullable)error;

/// Performs metadata preflight, then initializes the already loaded library through the public API.
- (BOOL)initializeHostWithArtifactMetadata:(NSDictionary<NSString *, id> *)metadata error:(NSError * _Nullable * _Nullable)error;

/// Idempotent shutdown ownership for the host preparation layer.
- (BOOL)shutdownHost:(NSError * _Nullable * _Nullable)error;

/// Bounded recovery attempt after a failed or degraded preparation state.
- (BOOL)recoverHost:(NSError * _Nullable * _Nullable)error;

- (NSDictionary<NSString *, id> *)statusSnapshot;

@end

NS_ASSUME_NONNULL_END
