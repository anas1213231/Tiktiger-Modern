#import "TiktigerGlassRow.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerMotionSystem.h"

@interface TiktigerGlassRow ()
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *detailLabel;
@property (nonatomic, strong, readwrite) UIImageView *iconView;
@property (nonatomic, strong) UIImageView *disclosureView;
@property (nonatomic, strong) UIView *surfaceView;
@end

@implementation TiktigerGlassRow

- (instancetype)initWithTitle:(NSString *)title detail:(NSString *)detail systemImageName:(NSString *)systemImageName {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.semanticContentAttribute = UISemanticContentAttributeUnspecified;
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
        self.accessibilityLabel = title;
        self.accessibilityHint = detail;
        [self buildWithTitle:title detail:detail imageName:systemImageName];
    }
    return self;
}

- (void)buildWithTitle:(NSString *)title detail:(NSString *)detail imageName:(NSString *)imageName {
    _surfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.backgroundColor = [TiktigerDesignTokens vipSurface];
    _surfaceView.layer.cornerRadius = [TiktigerDesignTokens cornerRadiusRow];
    _surfaceView.layer.borderWidth = [TiktigerDesignTokens glassBorderWidth];
    _surfaceView.layer.borderColor = [TiktigerDesignTokens vipGlassBorder].CGColor;
    [self addSubview:_surfaceView];

    _iconView = [[UIImageView alloc] initWithImage:(imageName.length ? [UIImage systemImageNamed:imageName] : nil)];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.tintColor = [TiktigerDesignTokens vipWhiteSecondary];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.accessibilityElementsHidden = YES;
    [_surfaceView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = title;
    _titleLabel.font = [TiktigerDesignTokens bodyFont];
    _titleLabel.textColor = [TiktigerDesignTokens vipWhite];
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    [_surfaceView addSubview:_titleLabel];

    _detailLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailLabel.text = detail;
    _detailLabel.font = [TiktigerDesignTokens developerFont];
    _detailLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _detailLabel.adjustsFontForContentSizeCategory = YES;
    _detailLabel.numberOfLines = 1;
    [_surfaceView addSubview:_detailLabel];

    _disclosureView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"]];
    _disclosureView.translatesAutoresizingMaskIntoConstraints = NO;
    _disclosureView.tintColor = [TiktigerDesignTokens vipWhiteSecondary];
    _disclosureView.accessibilityElementsHidden = YES;
    _disclosureView.hidden = YES;
    [_surfaceView addSubview:_disclosureView];

    CGFloat margin = [TiktigerDesignTokens cardPadding];
    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_surfaceView.heightAnchor constraintGreaterThanOrEqualToConstant:[TiktigerDesignTokens rowHeight]],
        [_iconView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:margin],
        [_iconView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:[TiktigerDesignTokens controlHeight] / 2.0],
        [_iconView.heightAnchor constraintEqualToAnchor:_iconView.widthAnchor],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:margin / 2.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_disclosureView.leadingAnchor constant:-margin / 2.0],
        [_titleLabel.topAnchor constraintGreaterThanOrEqualToAnchor:_surfaceView.topAnchor constant:margin / 2.0],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor constant:-margin / 4.0],
        [_detailLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_detailLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_detailLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2.0],
        [_detailLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_surfaceView.bottomAnchor constant:-margin / 2.0],
        [_disclosureView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-margin],
        [_disclosureView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_disclosureView.widthAnchor constraintEqualToConstant:[TiktigerDesignTokens controlHeight] / 2.0],
        [_disclosureView.heightAnchor constraintEqualToAnchor:_disclosureView.widthAnchor]
    ]];
}

- (void)setShowsDisclosure:(BOOL)showsDisclosure {
    _showsDisclosure = showsDisclosure;
    self.disclosureView.hidden = !showsDisclosure;
}

- (void)setActive:(BOOL)active {
    self.surfaceView.layer.borderColor = (active ? [TiktigerDesignTokens vipRed] : [TiktigerDesignTokens vipGlassBorder]).CGColor;
    self.titleLabel.textColor = active ? [TiktigerDesignTokens vipWhite] : [TiktigerDesignTokens vipWhite];
    [TiktigerMotionSystem applyGlowToView:self.surfaceView color:[TiktigerDesignTokens vipRed] active:active];
    self.accessibilityTraits = active ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [TiktigerMotionSystem animateView:self.surfaceView duration:[TiktigerDesignTokens motionFast] animations:^{
        self.surfaceView.alpha = highlighted ? 0.78 : 1.0;
    } completion:nil];
}

@end
