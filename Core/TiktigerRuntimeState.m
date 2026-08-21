#import "TiktigerRuntimeState.h"

NSString *TiktigerStringFromRuntimeState(TiktigerRuntimeState state) {
    switch (state) {
        case TiktigerRuntimeStateStopped: return @"stopped";
        case TiktigerRuntimeStateBootstrapping: return @"bootstrapping";
        case TiktigerRuntimeStateReady: return @"ready";
        case TiktigerRuntimeStateDegraded: return @"degraded";
        case TiktigerRuntimeStateShuttingDown: return @"shutting_down";
    }
    return @"unknown";
}
