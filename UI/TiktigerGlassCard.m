#import "TiktigerGlassCard.h"
#import "TiktigerDesignTokens.h"

@interface TiktigerGlassCard ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation TiktigerGlassCard

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self configureView];
        [self setTitle:title];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self configureView]; }
    return self;
}

- (void)configureView {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = [TiktigerDesignTokens vipSurface];
    self.layer.cornerRadius = [TiktigerDesignTokens cornerRadiusCard];
    self.layer.borderWidth = [TiktigerDesignTokens glassBorderWidth];
    self.layer.borderColor = [TiktigerDesignTokens vipGlassBorder].CGColor;
    self.clipsToBounds = YES;
    self.isAccessibilityElement = NO;
    self.semanticContentAttribute = UISemanticContentAttributeUnspecified;

    _blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[TiktigerDesignTokens glassBlurStyle]]];
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    _blurView.alpha = [TiktigerDesignTokens glassAlpha];
    [self addSubview:_blurView];
    [NSLayoutConstraint activateConstraints:@[
        [_blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    _contentView = [[UIView alloc] initWithFrame:CGRectZero];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentView.backgroundColor = [TiktigerDesignTokens vipGlassContent];
    [_blurView.contentView addSubview:_contentView];
    [NSLayoutConstraint activateConstraints:@[
        [_contentView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_contentView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [TiktigerDesignTokens subtitleFont];
    _titleLabel.textColor = [TiktigerDesignTokens vipWhite];
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [_contentView addSubview:_titleLabel];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.font = [TiktigerDesignTokens statusFont];
    _statusLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _statusLabel.numberOfLines = 0;
    _statusLabel.adjustsFontForContentSizeCategory = YES;
    [_contentView addSubview:_statusLabel];

    CGFloat padding = [TiktigerDesignTokens cardPadding];
    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:padding],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-padding],
        [_titleLabel.topAnchor constraintEqualToAnchor:_contentView.topAnchor constant:padding],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:padding],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-padding],
        [_statusLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:[TiktigerDesignTokens sectionGap] / 2.0],
        [_statusLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_contentView.bottomAnchor constant:-padding]
    ]];
}

- (void)setElevated:(BOOL)elevated {
    _elevated = elevated;
    self.backgroundColor = elevated ? [TiktigerDesignTokens vipSurfaceElevated] : [TiktigerDesignTokens vipSurface];
}

- (void)setTitle:(NSString *)title {
    self.titleLabel.text = title;
    self.titleLabel.hidden = title.length == 0;
}

- (void)setStatusMessage:(NSString *)message {
    self.statusLabel.text = message;
    self.statusLabel.hidden = message.length == 0;
}

@end
