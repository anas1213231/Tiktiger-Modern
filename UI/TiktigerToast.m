#import "TiktigerToast.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerMotionSystem.h"

@interface TiktigerToast ()
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) NSLayoutConstraint *bottomConstraint;
@end

@implementation TiktigerToast

+ (instancetype)toastWithMessage:(NSString *)message state:(TiktigerToastState)state {
    TiktigerToast *toast = [[self alloc] initWithFrame:CGRectZero];
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    toast.backgroundColor = [TiktigerDesignTokens vipSurfaceElevated];
    toast.layer.cornerRadius = [TiktigerDesignTokens cornerRadiusRow];
    toast.layer.borderWidth = [TiktigerDesignTokens glassBorderWidth];
    toast.layer.borderColor = (state == TiktigerToastStateError ? [TiktigerDesignTokens vipRed] : [TiktigerDesignTokens vipGlassBorder]).CGColor;
    toast.isAccessibilityElement = YES;
    toast.accessibilityTraits = UIAccessibilityTraitStaticText;
    toast.accessibilityLabel = message;
    toast->_label = [[UILabel alloc] initWithFrame:CGRectZero];
    toast->_label.translatesAutoresizingMaskIntoConstraints = NO;
    toast->_label.text = message;
    toast->_label.font = [TiktigerDesignTokens statusFont];
    toast->_label.textColor = [TiktigerDesignTokens vipWhite];
    toast->_label.numberOfLines = 0;
    toast->_label.textAlignment = NSTextAlignmentCenter;
    toast->_label.adjustsFontForContentSizeCategory = YES;
    [toast addSubview:toast->_label];
    CGFloat padding = [TiktigerDesignTokens cardPadding];
    [NSLayoutConstraint activateConstraints:@[
        [toast->_label.leadingAnchor constraintEqualToAnchor:toast.leadingAnchor constant:padding],
        [toast->_label.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-padding],
        [toast->_label.topAnchor constraintEqualToAnchor:toast.topAnchor constant:padding / 2.0],
        [toast->_label.bottomAnchor constraintEqualToAnchor:toast.bottomAnchor constant:-padding / 2.0]
    ]];
    return toast;
}

- (void)presentInView:(UIView *)view {
    [view addSubview:self];
    self.alpha = 0.0;
    self.transform = CGAffineTransformMakeTranslation(0.0, [TiktigerDesignTokens rowHeight]);
    [NSLayoutConstraint activateConstraints:@[
        [self.leadingAnchor constraintGreaterThanOrEqualToAnchor:view.leadingAnchor constant:[TiktigerDesignTokens screenMargin]],
        [self.trailingAnchor constraintLessThanOrEqualToAnchor:view.trailingAnchor constant:-[TiktigerDesignTokens screenMargin]],
        [self.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [self.bottomAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.bottomAnchor constant:-[TiktigerDesignTokens sectionGap]]
    ]];
    [TiktigerMotionSystem animateView:self duration:[TiktigerDesignTokens motionStandard] animations:^{
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
    [self performSelector:@selector(dismissAnimated:) withObject:@YES afterDelay:[TiktigerDesignTokens motionSlow] + [TiktigerDesignTokens motionSlow]];
}

- (void)dismissAnimated:(BOOL)animated {
    void (^animations)(void) = ^{
        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeTranslation(0.0, [TiktigerDesignTokens rowHeight]);
    };
    if (animated) {
        [TiktigerMotionSystem animateView:self duration:[TiktigerDesignTokens motionStandard] animations:animations completion:^(BOOL finished) {
            [self removeFromSuperview];
        }];
    } else {
        animations();
        [self removeFromSuperview];
    }
}

@end
