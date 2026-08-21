#import "TiktigerDashboardView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassCard.h"
#import "TiktigerGlassButton.h"
#import "TiktigerGlassRow.h"
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
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIStackView *moduleCardsStack;
@property (nonatomic, strong) UIStackView *quickActionsStack;
@property (nonatomic, strong) TiktigerGlassCard *moduleHubCard;
@property (nonatomic, strong) TiktigerGlassCard *quickActionsCard;
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

    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.accessibilityIdentifier = @"tiktiger.dashboard.scroll";
    [self addSubview:_scrollView];

    _contentStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    _contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStackView.axis = UILayoutConstraintAxisVertical;
    _contentStackView.alignment = UIStackViewAlignmentFill;
    _contentStackView.spacing = [TiktigerDesignTokens sectionGap];
    [_scrollView addSubview:_contentStackView];

    _logoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _logoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _logoLabel.text = @"TIKTIGER";
    _logoLabel.font = [TiktigerDesignTokens titleFont];
    _logoLabel.textColor = [TiktigerDesignTokens vipWhite];
    _logoLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    _logoLabel.accessibilityIdentifier = @"tiktiger.dashboard.logo";

    _versionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _versionLabel.font = [TiktigerDesignTokens developerFont];
    _versionLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _versionLabel.adjustsFontForContentSizeCategory = YES;
    _versionLabel.numberOfLines = 1;

    _settingsButton = [TiktigerGlassButton buttonWithTitle:@"Settings" redAccent:NO];
    _settingsButton.accessibilityHint = @"Open the system settings center when navigation is available.";
    _settingsButton.accessibilityIdentifier = @"tiktiger.dashboard.settings";
    [_settingsButton addTarget:self action:@selector(handleSettingsAction:) forControlEvents:UIControlEventTouchUpInside];
    _settingsButton.enabled = NO;

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[_logoLabel, _versionLabel, _settingsButton]];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.axis = UILayoutConstraintAxisHorizontal;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = [TiktigerDesignTokens sectionGap];
    [self.contentStackView addArrangedSubview:header];

    _statusBadge = [[TiktigerStatusBadge alloc] initWithText:@"Dashboard Ready" state:TiktigerStatusBadgeStateReady];
    _statusBadge.accessibilityIdentifier = @"tiktiger.dashboard.status";
    [self.contentStackView addArrangedSubview:_statusBadge];

    _healthCard = [[TiktigerGlassCard alloc] initWithTitle:@"Health Status"];
    _healthCard.elevated = YES;
    _healthCard.accessibilityIdentifier = @"tiktiger.dashboard.health-card";
    _runtimeCard = [[TiktigerGlassCard alloc] initWithTitle:@"Runtime Status"];
    _runtimeCard.accessibilityIdentifier = @"tiktiger.dashboard.runtime-card";
    _featureCard = [[TiktigerGlassCard alloc] initWithTitle:@"Feature Summary"];
    _featureCard.accessibilityIdentifier = @"tiktiger.dashboard.feature-card";

    UIStackView *summaryStack = [[UIStackView alloc] initWithArrangedSubviews:@[_healthCard, _runtimeCard, _featureCard]];
    summaryStack.translatesAutoresizingMaskIntoConstraints = NO;
    summaryStack.axis = UILayoutConstraintAxisVertical;
    summaryStack.alignment = UIStackViewAlignmentFill;
    summaryStack.spacing = [TiktigerDesignTokens sectionGap];
    [self.contentStackView addArrangedSubview:summaryStack];

    _moduleHubCard = [[TiktigerGlassCard alloc] initWithTitle:@"VIP Modules"];
    _moduleHubCard.accessibilityIdentifier = @"tiktiger.dashboard.module-hub";
    [_moduleHubCard setStatusMessage:@"Live module status and planned VIP centers."];
    _moduleCardsStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _moduleCardsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _moduleCardsStack.axis = UILayoutConstraintAxisVertical;
    _moduleCardsStack.alignment = UIStackViewAlignmentFill;
    _moduleCardsStack.spacing = [TiktigerDesignTokens sectionGap];
    [_moduleHubCard.contentView addSubview:_moduleCardsStack];

    _quickActionsCard = [[TiktigerGlassCard alloc] initWithTitle:@"Quick Actions"];
    _quickActionsCard.accessibilityIdentifier = @"tiktiger.dashboard.quick-actions";
    [_quickActionsCard setStatusMessage:@"Open a center when its module is available."];
    _quickActionsStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _quickActionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _quickActionsStack.axis = UILayoutConstraintAxisVertical;
    _quickActionsStack.alignment = UIStackViewAlignmentFill;
    _quickActionsStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_quickActionsCard.contentView addSubview:_quickActionsStack];

    [self.contentStackView addArrangedSubview:_moduleHubCard];
    [self.contentStackView addArrangedSubview:_quickActionsCard];

    CGFloat margin = [TiktigerDesignTokens screenMargin];
    CGFloat padding = [TiktigerDesignTokens cardPadding];
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor],
        [_scrollView.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor],
        [_contentStackView.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor constant:margin],
        [_contentStackView.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor constant:-margin],
        [_contentStackView.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor constant:margin],
        [_contentStackView.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor constant:-margin],
        [_contentStackView.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor constant:-2.0 * margin],
        [_moduleCardsStack.leadingAnchor constraintEqualToAnchor:_moduleHubCard.contentView.leadingAnchor constant:padding],
        [_moduleCardsStack.trailingAnchor constraintEqualToAnchor:_moduleHubCard.contentView.trailingAnchor constant:-padding],
        [_moduleCardsStack.topAnchor constraintEqualToAnchor:_moduleHubCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_moduleCardsStack.bottomAnchor constraintEqualToAnchor:_moduleHubCard.contentView.bottomAnchor constant:-padding],
        [_quickActionsStack.leadingAnchor constraintEqualToAnchor:_quickActionsCard.contentView.leadingAnchor constant:padding],
        [_quickActionsStack.trailingAnchor constraintEqualToAnchor:_quickActionsCard.contentView.trailingAnchor constant:-padding],
        [_quickActionsStack.topAnchor constraintEqualToAnchor:_quickActionsCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_quickActionsStack.bottomAnchor constraintEqualToAnchor:_quickActionsCard.contentView.bottomAnchor constant:-padding]
    ]];

    self.versionText = @"1.0.0";
    self.runtimeStatusText = @"Runtime is ready for presentation.";
    self.featureSummaryText = @"Feature modules are available through their presentation contracts.";
    [self rebuildModulePresentation];
    [self rebuildQuickActions];
    [self refreshPresentation];
}

- (void)setVersionText:(NSString *)versionText {
    _versionText = [versionText copy];
    [self refreshPresentation];
}

- (void)setRuntimeStatusText:(NSString *)runtimeStatusText {
    _runtimeStatusText = [runtimeStatusText copy];
    [self refreshPresentation];
}

- (void)setFeatureSummaryText:(NSString *)featureSummaryText {
    _featureSummaryText = [featureSummaryText copy];
    [self refreshPresentation];
}

- (void)setNavigationHandler:(TiktigerDashboardNavigationHandler)navigationHandler {
    _navigationHandler = [navigationHandler copy];
    self.settingsButton.enabled = (_navigationHandler != nil);
    [self rebuildQuickActions];
}

- (void)setFeatureBinding:(id<TiktigerFeatureBinding>)binding {
    if (_featureBinding != nil) { [_featureBinding unsubscribeFromModuleEvents:self.eventToken]; }
    _featureBinding = binding;
    __weak typeof(self) weakSelf = self;
    self.eventToken = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
        (void)event;
        __strong typeof(weakSelf) self = weakSelf;
        if (self != nil) {
            [self refreshPresentation];
            [self rebuildModulePresentation];
            [self rebuildQuickActions];
            [self.moduleStatusCard refreshFromBinding];
        }
    }];
    if (self.moduleStatusCard != nil) {
        [self.moduleStatusCard removeFromSuperview];
        self.moduleStatusCard = nil;
    }
    if (binding != nil) {
        self.moduleStatusCard = [[TiktigerFeatureStatusCard alloc] initWithBinding:binding];
    }
    [self rebuildModulePresentation];
    [self rebuildQuickActions];
    [self refreshPresentation];
}

- (NSArray<NSDictionary<NSString *, id> *> *)dashboardCards {
    NSArray *cards = [self.featureBinding dashboardFeatureCards];
    return [cards isKindOfClass:[NSArray class]] ? cards : @[];
}

- (NSDictionary<NSString *, id> *)plannedModuleDefinitionForID:(NSString *)moduleID {
    for (NSDictionary *definition in [self plannedModuleDefinitions]) {
        if ([definition[@"id"] isEqualToString:moduleID]) { return definition; }
    }
    return @{};
}

- (NSArray<NSDictionary<NSString *, id> *> *)plannedModuleDefinitions {
    return @[
        @{ @"id": @"media.download", @"title": @"Download Center", @"summary": @"Media queue and download status", @"icon": @"arrow.down.circle" },
        @{ @"id": @"privacy.center", @"title": @"Privacy Center", @"summary": @"Privacy controls and visibility state", @"icon": @"lock.shield" },
        @{ @"id": @"chat.center", @"title": @"Chat Center", @"summary": @"Chat utilities placeholder", @"icon": @"bubble.left.and.bubble.right" },
        @{ @"id": @"profile.center", @"title": @"Profile Center", @"summary": @"Profile tools placeholder", @"icon": @"person.crop.circle" },
        @{ @"id": @"appearance.engine", @"title": @"Appearance Engine", @"summary": @"Glass, OLED, theme and motion policy", @"icon": @"circle.lefthalf.filled" },
        @{ @"id": @"system.center", @"title": @"System Center", @"summary": @"Diagnostics, feature manager and backup", @"icon": @"gearshape.2" }
    ];
}

- (NSDictionary<NSString *, id> * _Nullable)liveCardForModuleID:(NSString *)moduleID {
    for (NSDictionary *card in [self dashboardCards]) {
        if ([card[@"id"] isEqualToString:moduleID]) { return card; }
    }
    return nil;
}

- (void)rebuildModulePresentation {
    if (self.moduleCardsStack == nil) { return; }
    for (UIView *view in [self.moduleCardsStack.arrangedSubviews copy]) {
        [self.moduleCardsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSArray *definitions = [self plannedModuleDefinitions];
    NSUInteger liveCount = 0;
    for (NSDictionary *definition in definitions) {
        NSString *moduleID = definition[@"id"];
        NSDictionary *liveCard = [self liveCardForModuleID:moduleID];
        BOOL isLive = (liveCard != nil);
        if (isLive) { liveCount += 1; }
        NSString *state = liveCard[@"state"] ?: @"planned";
        NSString *version = liveCard[@"version"];
        NSString *detail = isLive
            ? [NSString stringWithFormat:@"%@%@", state, version.length ? [NSString stringWithFormat:@" · %@", version] : @""]
            : @"Planned module · implementation not started";
        NSString *summary = definition[@"summary"] ?: @"VIP module placeholder";
        TiktigerGlassCard *card = [[TiktigerGlassCard alloc] initWithTitle:definition[@"title"]];
        [card setStatusMessage:[NSString stringWithFormat:@"%@ · %@", summary, detail]];
        card.accessibilityIdentifier = [NSString stringWithFormat:@"tiktiger.dashboard.module.%@", moduleID];
        card.isAccessibilityElement = YES;
        card.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", definition[@"title"], [NSString stringWithFormat:@"%@ · %@", summary, detail]];
        card.accessibilityTraits = UIAccessibilityTraitSummaryElement;
        [self.moduleCardsStack addArrangedSubview:card];
    }
    NSString *hubStatus = liveCount > 0
        ? [NSString stringWithFormat:@"%lu live module(s) · %lu VIP centers planned", (unsigned long)liveCount, (unsigned long)definitions.count]
        : [NSString stringWithFormat:@"%lu VIP centers planned · module binding pending", (unsigned long)definitions.count];
    [self.moduleHubCard setStatusMessage:hubStatus];
}

- (void)rebuildQuickActions {
    if (self.quickActionsStack == nil) { return; }
    for (UIView *view in [self.quickActionsStack.arrangedSubviews copy]) {
        [self.quickActionsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSArray *definitions = [self plannedModuleDefinitions];
    for (NSDictionary *definition in definitions) {
        NSString *moduleID = definition[@"id"];
        NSDictionary *liveCard = [self liveCardForModuleID:moduleID];
        BOOL available = (liveCard != nil && self.navigationHandler != nil);
        NSString *detail = liveCard != nil ? [NSString stringWithFormat:@"%@ · %@", liveCard[@"state"] ?: @"registered", available ? @"Open module" : @"Navigation pending"] : @"Planned · no feature action"];
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:definition[@"title"] detail:detail systemImageName:definition[@"icon"]];
        row.showsDisclosure = YES;
        row.enabled = available;
        row.accessibilityIdentifier = [NSString stringWithFormat:@"tiktiger.dashboard.quick-action.%@", moduleID];
        row.accessibilityHint = available ? @"Open the module navigation surface." : @"This module is a placeholder and has no executable action.";
        [row setActive:(liveCard != nil)];
        [row addTarget:self action:@selector(handleModuleNavigation:) forControlEvents:UIControlEventTouchUpInside];
        [self.quickActionsStack addArrangedSubview:row];
    }
    [self.quickActionsCard setStatusMessage:self.navigationHandler != nil ? @"Available modules can be opened through the host navigation contract." : @"Navigation contract pending · no feature action is executed here."];
}

- (void)handleSettingsAction:(TiktigerGlassButton *)sender {
    (void)sender;
    if (self.navigationHandler != nil) { self.navigationHandler(@"system.settings"); }
}

- (void)handleModuleNavigation:(TiktigerGlassRow *)sender {
    if (self.navigationHandler != nil && sender.accessibilityIdentifier.length > 0) {
        NSString *prefix = @"tiktiger.dashboard.quick-action.";
        NSString *moduleID = [sender.accessibilityIdentifier hasPrefix:prefix] ? [sender.accessibilityIdentifier substringFromIndex:prefix.length] : @"";
        if (moduleID.length > 0) { self.navigationHandler(moduleID); }
    }
}

- (void)refreshPresentation {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf refreshPresentation]; });
        return;
    }
    self.versionLabel.text = self.versionText.length ? self.versionText : @"1.0.0";
    [self.healthCard setStatusMessage:@"Dashboard foundation is available through the feature binding contract."];
    [self.runtimeCard setStatusMessage:self.runtimeStatusText.length ? self.runtimeStatusText : @"Runtime status unavailable."];
    [self.featureCard setStatusMessage:self.featureSummaryText.length ? self.featureSummaryText : @"No feature summary available."];

    BOOL hasDegradedModule = NO;
    BOOL hasFailedModule = NO;
    for (NSDictionary *card in [self dashboardCards]) {
        NSString *state = [card[@"state"] lowercaseString];
        hasDegradedModule = hasDegradedModule || [state isEqualToString:@"degraded"];
        hasFailedModule = hasFailedModule || [state isEqualToString:@"failed"];
    }
    if (hasFailedModule || hasDegradedModule) {
        [self.statusBadge setState:TiktigerStatusBadgeStateDegraded];
        [self.statusBadge setText:hasFailedModule ? @"Module Attention Required" : @"Module Degraded"];
    } else {
        [self.statusBadge setState:TiktigerStatusBadgeStateReady];
        [self.statusBadge setText:@"Dashboard Ready"];
    }
    [self.moduleStatusCard refreshFromBinding];
}

- (void)dealloc {
    [self.featureBinding unsubscribeFromModuleEvents:self.eventToken];
}

@end
