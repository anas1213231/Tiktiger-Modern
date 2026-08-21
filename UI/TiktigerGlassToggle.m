#import "TiktigerGlassToggle.h"
#import "TiktigerDesignTokens.h"

@implementation TiktigerGlassToggle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.onTintColor = [TiktigerDesignTokens vipRed];
        self.thumbTintColor = [TiktigerDesignTokens vipWhite];
        self.tintColor = [TiktigerDesignTokens vipSurfaceElevated];
        self.semanticContentAttribute = UISemanticContentAttributeUnspecified;
        self.accessibilityTraits = UIAccessibilityTraitButton;
        [self addTarget:self action:@selector(tiktiger_valueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return self;
}

- (void)setAccessibilityStateLabel:(NSString *)accessibilityStateLabel {
    _accessibilityStateLabel = [accessibilityStateLabel copy];
    [self updateAccessibilityValue];
}

- (void)tiktiger_valueChanged:(UISwitch *)sender {
    [self updateAccessibilityValue];
}

- (void)updateAccessibilityValue {
    NSString *state = self.on ? @"On" : @"Off";
    self.accessibilityValue = self.accessibilityStateLabel.length ? [NSString stringWithFormat:@"%@, %@", self.accessibilityStateLabel, state] : state;
}

@end
