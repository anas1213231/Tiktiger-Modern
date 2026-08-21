#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerRuntimeState) {
    TiktigerRuntimeStateStopped = 0,
    TiktigerRuntimeStateBootstrapping,
    TiktigerRuntimeStateReady,
    TiktigerRuntimeStateDegraded,
    TiktigerRuntimeStateShuttingDown
};

FOUNDATION_EXPORT NSString *TiktigerStringFromRuntimeState(TiktigerRuntimeState state);

NS_ASSUME_NONNULL_END
