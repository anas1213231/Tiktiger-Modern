#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerMotionSystem : NSObject

+ (BOOL)reduceMotionEnabled;
+ (void)animateView:(UIView *)view duration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^ _Nullable)(BOOL finished))completion;
+ (void)animateViewWithSpring:(UIView *)view animations:(void (^)(void))animations completion:(void (^ _Nullable)(BOOL finished))completion;
+ (void)applyGlowToView:(UIView *)view color:(UIColor *)color active:(BOOL)active;
+ (void)removeGlowFromView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
