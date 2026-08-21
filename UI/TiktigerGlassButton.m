#import "TiktigerGlassButton.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerMotionSystem.h"

@implementation TiktigerGlassButton

+ (instancetype)buttonWithTitle:(NSString *)title redAccent:(BOOL)redAccent {
    TiktigerGlassButton *button = [self buttonWithType:UIButtonTypeSystem];
    button.usesRedAccent = redAccent;
    [button setTitle:title forState:UIControlStateNormal];
    return button;
}

- (void)setUsesRedAccent:(BOOL)usesRedAccent {
    _usesRedAccent = usesRedAccent;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    self.titleLabel.font = [TiktigerDesignTokens bodyFont];
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.layer.cornerRadius = [TiktigerDesignTokens cornerRadiusRow];
    self.layer.borderWidth = [TiktigerDesignTokens glassBorderWidth];
    self.layer.borderColor = [TiktigerDesignTokens vipGlassBorder].CGColor;
    self.backgroundColor = usesRedAccent ? [TiktigerDesignTokens vipRed] : [TiktigerDesignTokens vipSurface];
    [self setTitleColor:[TiktigerDesignTokens vipWhite] forState:UIControlStateNormal];
    [self setTitleColor:[TiktigerDesignTokens vipWhiteSecondary] forState:UIControlStateDisabled];
    self.accessibilityTraits = UIAccessibilityTraitButton;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [TiktigerMotionSystem animateView:self duration:[TiktigerDesignTokens motionFast] animations:^{
        self.alpha = highlighted ? 0.80 : 1.0;
        self.transform = highlighted && ![TiktigerMotionSystem reduceMotionEnabled] ? CGAffineTransformMakeScale(0.98, 0.98) : CGAffineTransformIdentity;
    } completion:nil];
}

@end
