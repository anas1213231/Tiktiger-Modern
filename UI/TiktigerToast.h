#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerToastState) {
    TiktigerToastStateInfo = 0,
    TiktigerToastStateSuccess,
    TiktigerToastStateError
};

@interface TiktigerToast : UIView

+ (instancetype)toastWithMessage:(NSString *)message state:(TiktigerToastState)state;
- (void)presentInView:(UIView *)view;
- (void)dismissAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
