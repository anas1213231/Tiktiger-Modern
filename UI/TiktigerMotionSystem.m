#import "TiktigerMotionSystem.h"
#import "TiktigerDesignTokens.h"

@implementation TiktigerMotionSystem

+ (BOOL)reduceMotionEnabled {
    return UIAccessibilityIsReduceMotionEnabled();
}

+ (void)animateView:(UIView *)view duration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL))completion {
    NSTimeInterval effectiveDuration = [self reduceMotionEnabled] ? [TiktigerDesignTokens motionFast] : duration;
    [UIView animateWithDuration:effectiveDuration
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:animations
                     completion:completion];
}

+ (void)animateViewWithSpring:(UIView *)view animations:(void (^)(void))animations completion:(void (^)(BOOL))completion {
    if ([self reduceMotionEnabled]) {
        [self animateView:view duration:[TiktigerDesignTokens motionFast] animations:animations completion:completion];
        return;
    }
    [UIView animateWithDuration:[TiktigerDesignTokens motionSlow]
                          delay:0.0
         usingSpringWithDamping:[TiktigerDesignTokens springDamping]
          initialSpringVelocity:[TiktigerDesignTokens springVelocity]
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:animations
                     completion:completion];
}

+ (void)applyGlowToView:(UIView *)view color:(UIColor *)color active:(BOOL)active {
    if (active && ![self reduceMotionEnabled]) {
        view.layer.shadowColor = color.CGColor;
        view.layer.shadowRadius = [TiktigerDesignTokens glowRadius];
        view.layer.shadowOpacity = [TiktigerDesignTokens glowOpacity];
        view.layer.shadowOffset = CGSizeZero;
    } else {
        [self removeGlowFromView:view];
    }
}

+ (void)removeGlowFromView:(UIView *)view {
    view.layer.shadowColor = [TiktigerDesignTokens vipClear].CGColor;
    view.layer.shadowRadius = 0.0;
    view.layer.shadowOpacity = 0.0;
    view.layer.shadowOffset = CGSizeZero;
}

@end
