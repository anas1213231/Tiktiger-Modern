#import "TiktigerDashboardView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassCard.h"
#import "TiktigerGlassButton.h"
#import "TiktigerStatusBadge.h"
#import "TiktigerFeatureStatusCard.h"

@interface TiktigerDashboardView ()
@property (nonatomic, strong) UILabel *logoLabel;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) TiktigerStatusBadge *statusBadge;
@property (nonatomic, strong) TiktigerGlassCard *healthCard;
@property (nonatomic, strong) TiktigerGlassCard *runtimeCard;
@property (nonatomic, strong) TiktigerGlassCard *featureCard;
@property (nonatomic, strong) TiktigerGlassButton *settingsButton;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) TiktigerFeatureStatusCard *moduleStatusCard;
@property (nonatomic, weak) id<TiktigerFeatureBinding> featureBinding;
@property (nonatomic, strong) id eventToken;
@end

@implementation TiktigerDashboardView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self buildView]; }
    return self;
}

- (void)buildView {
    self.backgroundColor = [TiktigerDesignTokens vipBlack];
    self.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    self.accessibilityViewIsModal = NO;

    _logoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _logoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _logoLabel.text = @"TIKTIGER";
    _logoLabel.font = [TiktigerDesignTokens titleFont];
    _logoLabel.textColor = [TiktigerDesignTokens vipWhite];
    _logoLabel.accessibilityTraits = UIAccessibilityTraitHeader;

    _versionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _versionLabel.font = [TiktigerDesignTokens developerFont];
    _versionLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _versionLabel.adjustsFontForContentSizeCategory = YES;

    _settingsButton = [TiktigerGlassButton buttonWithTitle:@"Settings" redAccent:NO];
    [_settingsButton setTitle:@"Settings" forState:UIControlStateNormal];
    _settingsButton.accessibilityHint = @"Open Tiktiger settings";

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[_logoLabel, _versionLabel, _settingsButton]];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.axis = UILayoutConstraintAxisHorizontal;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = [TiktigerDesignTokens sectionGap];
    [self addSubview:header];

    _statusBadge = [[TiktigerStatusBadge alloc] initWithText:@"Ready" state:TiktigerStatusBadgeStateReady];
    _healthCard = [[TiktigerGlassCard alloc] initWithTitle:@"Health Status"];
    _runtimeCard = [[TiktigerGlassCard alloc] initWithTitle:@"Runtime Status"];
    _featureCard = [[TiktigerGlassCard alloc] initWithTitle:@"Feature Summary"];
    _healthCard.elevated = YES;

    _stackView = [[UIStackView alloc] initWithArrangedSubviews:@[_statusBadge, _healthCard, _runtimeCard, _featureCard]];
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    _stackView.axis = UILayoutConstraintAxisVertical;
    _stackView.spacing = [TiktigerDesignTokens sectionGap];
    _stackView.alignment = UIStackViewAlignmentFill;
    [self addSubview:_stackView];

    CGFloat margin = [TiktigerDesignTokens screenMargin];
    [NSLayoutConstraint activateConstraints:@[
        [header.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:margin],
        [header.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-margin],
        [header.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:margin],
        [_stackView.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:margin],
        [_stackView.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-margin],
        [_stackView.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:[TiktigerDesignTokens sectionGap]],
        [_stackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-margin]
    ]];
    self.versionText = @"Foundation";
    self.runtimeStatusText = @"Runtime is ready for presentation.";
    self.featureSummaryText = @"Feature modules are available through their presentation contracts.";
    [self refreshPresentation];
}

- (void)setVersionText:(NSString *)versionText { _versionText = [versionText copy]; [self refreshPresentation]; }
- (void)setRuntimeStatusText:(NSString *)runtimeStatusText { _runtimeStatusText = [runtimeStatusText copy]; [self refreshPresentation]; }
- (void)setFeatureSummaryText:(NSString *)featureSummaryText { _featureSummaryText = [featureSummaryText copy]; [self refreshPresentation]; }

- (void)setFeatureBinding:(id<TiktigerFeatureBinding>)binding {
    if (_featureBinding != nil) { [_featureBinding unsubscribeFromModuleEvents:self.eventToken]; }
    _featureBinding = binding;
    __weak typeof(self) weakSelf = self;
    self.eventToken = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self != nil) { [self refreshPresentation]; [self.moduleStatusCard refreshFromBinding]; }
    }];
    if (self.moduleStatusCard != nil) {
        [self.stackView removeArrangedSubview:self.moduleStatusCard];
        [self.moduleStatusCard removeFromSuperview];
    }
    if (binding != nil) {
        self.moduleStatusCard = [[TiktigerFeatureStatusCard alloc] initWithBinding:binding];
        [self.stackView addArrangedSubview:self.moduleStatusCard];
    }
}

- (void)refreshPresentation {
    self.versionLabel.text = self.versionText.length ? self.versionText : @"Foundation";
    [self.healthCard setStatusMessage:@"All presentation surfaces are available." ];
    [self.runtimeCard setStatusMessage:self.runtimeStatusText.length ? self.runtimeStatusText : @"Runtime status unavailable." ];
    [self.featureCard setStatusMessage:self.featureSummaryText.length ? self.featureSummaryText : @"No feature summary available." ];
    [self.moduleStatusCard refreshFromBinding];
}

- (void)dealloc {
    [self.featureBinding unsubscribeFromModuleEvents:self.eventToken];
}

@end
