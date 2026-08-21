#import "TiktigerPresentationContracts.h"

NSString *TiktigerStringFromPresentationState(TiktigerPresentationState state) {
    switch (state) {
        case TiktigerPresentationStateLoading: return @"loading";
        case TiktigerPresentationStateEmpty: return @"empty";
        case TiktigerPresentationStateReady: return @"ready";
        case TiktigerPresentationStateSuccess: return @"success";
        case TiktigerPresentationStateFailed: return @"failed";
        case TiktigerPresentationStateDegraded: return @"degraded";
    }
    return @"unknown";
}
