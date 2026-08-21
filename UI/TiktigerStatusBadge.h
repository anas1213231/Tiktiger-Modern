#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerStatusBadgeState) {
    TiktigerStatusBadgeStateReady = 0,
    TiktigerStatusBadgeStateLoading,
    TiktigerStatusBadgeStateSuccess,
    TiktigerStatusBadgeStateDegraded,
    TiktigerStatusBadgeStateFailed
};

@interface TiktigerStatusBadge : UIView

@property (nonatomic, assign) TiktigerStatusBadgeState state;
@property (nonatomic, copy) NSString *text;

- (instancetype)initWithText:(NSString *)text state:(TiktigerStatusBadgeState)state;

@end

NS_ASSUME_NONNULL_END
