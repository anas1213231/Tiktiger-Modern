#import "TiktigerStatusBadge.h"
#import "TiktigerDesignTokens.h"

@interface TiktigerStatusBadge ()
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIView *dot;
@end

@implementation TiktigerStatusBadge

- (instancetype)initWithText:(NSString *)text state:(TiktigerStatusBadgeState)state {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = [TiktigerDesignTokens cornerRadiusBadge];
        self.backgroundColor = [TiktigerDesignTokens vipSurfaceElevated];
        self.semanticContentAttribute = UISemanticContentAttributeUnspecified;
        _dot = [[UIView alloc] initWithFrame:CGRectZero];
        _dot.translatesAutoresizingMaskIntoConstraints = NO;
        _dot.layer.cornerRadius = [TiktigerDesignTokens cornerRadiusBadge] / 4.0;
        [self addSubview:_dot];
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.translatesAutoresizingMaskIntoConstraints = NO;
        _label.font = [TiktigerDesignTokens statusFont];
        _label.textColor = [TiktigerDesignTokens vipWhite];
        _label.adjustsFontForContentSizeCategory = YES;
        [self addSubview:_label];
        [NSLayoutConstraint activateConstraints:@[
            [_dot.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:[TiktigerDesignTokens cardPadding] / 2.0],
            [_dot.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_dot.widthAnchor constraintEqualToConstant:[TiktigerDesignTokens cornerRadiusBadge] / 12.0],
            [_dot.heightAnchor constraintEqualToAnchor:_dot.widthAnchor],
            [_label.leadingAnchor constraintEqualToAnchor:_dot.trailingAnchor constant:[TiktigerDesignTokens cardPadding] / 3.0],
            [_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-[TiktigerDesignTokens cardPadding] / 2.0],
            [_label.topAnchor constraintEqualToAnchor:self.topAnchor constant:[TiktigerDesignTokens cardPadding] / 3.0],
            [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-[TiktigerDesignTokens cardPadding] / 3.0]
        ]];
        self.text = text;
        self.state = state;
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitStaticText;
    }
    return self;
}

- (void)setText:(NSString *)text {
    _text = [text copy];
    self.label.text = text;
    self.accessibilityLabel = text;
}

- (void)setState:(TiktigerStatusBadgeState)state {
    _state = state;
    UIColor *color = [TiktigerDesignTokens vipWhiteSecondary];
    switch (state) {
        case TiktigerStatusBadgeStateReady: color = [TiktigerDesignTokens vipWhiteSecondary]; break;
        case TiktigerStatusBadgeStateLoading: color = [TiktigerDesignTokens vipRed]; break;
        case TiktigerStatusBadgeStateSuccess: color = [TiktigerDesignTokens vipSuccess]; break;
        case TiktigerStatusBadgeStateDegraded: color = [TiktigerDesignTokens vipRed]; break;
        case TiktigerStatusBadgeStateFailed: color = [TiktigerDesignTokens vipRed]; break;
    }
    self.dot.backgroundColor = color;
}

@end
