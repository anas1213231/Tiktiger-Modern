#import <UIKit/UIKit.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerDownloadPresentationState) {
    TiktigerDownloadPresentationStateIdle = 0,
    TiktigerDownloadPresentationStateLoading,
    TiktigerDownloadPresentationStateSuccess,
    TiktigerDownloadPresentationStateFailed
};

@interface TiktigerDownloadCenterView : UIView

@property (nonatomic, assign) TiktigerDownloadPresentationState presentationState;
@property (nonatomic, assign) CGFloat progress;

- (void)showToastMessage:(NSString *)message state:(NSInteger)state;
- (void)setFeatureBinding:(id<TiktigerFeatureBinding> _Nullable)binding;
- (void)applyDownloadPresentation:(NSDictionary<NSString *, id> *)snapshot;

@end

NS_ASSUME_NONNULL_END
