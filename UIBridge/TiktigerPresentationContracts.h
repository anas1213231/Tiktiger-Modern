#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerPresentationState) {
    TiktigerPresentationStateLoading = 0,
    TiktigerPresentationStateEmpty,
    TiktigerPresentationStateReady,
    TiktigerPresentationStateSuccess,
    TiktigerPresentationStateFailed,
    TiktigerPresentationStateDegraded
};

FOUNDATION_EXPORT NSString *TiktigerStringFromPresentationState(TiktigerPresentationState state);

NS_ASSUME_NONNULL_END
