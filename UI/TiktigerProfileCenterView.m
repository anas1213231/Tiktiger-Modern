#import "TiktigerProfileCenterView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassCard.h"
#import "TiktigerGlassRow.h"
#import "TiktigerGlassToggle.h"
#import "TiktigerToast.h"
#import "TiktigerMotionSystem.h"

static NSString * const TiktigerProfileFeatureID = @"profile.center";

@interface TiktigerProfileCenterView ()
@property (nonatomic, weak) id<TiktigerFeatureBinding> featureBinding;
@property (nonatomic, strong) id eventToken;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) TiktigerGlassCard *statusCard;
@property (nonatomic, strong) TiktigerGlassCard *creatorCard;
@property (nonatomic, strong) TiktigerGlassCard *featureCard;
@property (nonatomic, strong) TiktigerGlassCard *settingsCard;
@property (nonatomic, strong) TiktigerGlassCard *diagnosticsCard;
@property (nonatomic, strong) UIStackView *creatorStack;
@property (nonatomic, strong) UIStackView *featureStack;
@property (nonatomic, strong) UIStackView *settingsStack;
@property (nonatomic, strong) UIStackView *diagnosticsStack;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *statusDetailLabel;
@property (nonatomic, copy) NSDictionary<NSString *, id> *lastSnapshot;
@property (nonatomic, copy) NSDictionary<NSString *, id> *lastDownloadSnapshot;
- (void)refreshCreatorWithDownloadSnapshot:(NSDictionary<NSString *, id> *)snapshot;
@end

@implementation TiktigerProfileCenterView

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding>)binding {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _featureBinding = binding;
        [self buildView];
        [self setFeatureBinding:binding];
    }
    return self;
}

- (void)buildView {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = [TiktigerDesignTokens vipBlack];
    self.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    self.lastSnapshot = @{};

    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.accessibilityIdentifier = @"tiktiger.profile.scroll";
    [self addSubview:_scrollView];

    _contentStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.alignment = UIStackViewAlignmentFill;
    _contentStack.spacing = [TiktigerDesignTokens sectionGap];
    [_scrollView addSubview:_contentStack];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Profile Center";
    title.font = [TiktigerDesignTokens titleFont];
    title.textColor = [TiktigerDesignTokens vipWhite];
    title.adjustsFontForContentSizeCategory = YES;
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    title.accessibilityIdentifier = @"tiktiger.profile.title";

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"A calm, transparent place for profile configuration and module health.";
    subtitle.font = [TiktigerDesignTokens bodyFont];
    subtitle.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    subtitle.numberOfLines = 0;
    subtitle.adjustsFontForContentSizeCategory = YES;
    subtitle.accessibilityIdentifier = @"tiktiger.profile.subtitle";

    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle]];
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    heading.axis = UILayoutConstraintAxisVertical;
    heading.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_contentStack addArrangedSubview:heading];

    _statusCard = [[TiktigerGlassCard alloc] initWithTitle:@"Profile Status"];
    _statusCard.accessibilityIdentifier = @"tiktiger.profile.status-card";
    [_statusCard setElevated:YES];
    [_statusCard setStatusMessage:@"Waiting for Profile Module state."];
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.font = [TiktigerDesignTokens titleFont];
    _statusLabel.textColor = [TiktigerDesignTokens vipWhite];
    _statusLabel.adjustsFontForContentSizeCategory = YES;
    _statusLabel.accessibilityIdentifier = @"tiktiger.profile.status";
    _statusDetailLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusDetailLabel.font = [TiktigerDesignTokens bodyFont];
    _statusDetailLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _statusDetailLabel.numberOfLines = 0;
    _statusDetailLabel.adjustsFontForContentSizeCategory = YES;
    _statusDetailLabel.accessibilityIdentifier = @"tiktiger.profile.status-detail";
    [_statusCard.contentView addSubview:_statusLabel];
    [_statusCard.contentView addSubview:_statusDetailLabel];

    _creatorCard = [[TiktigerGlassCard alloc] initWithTitle:@"Creator Center"];
    _creatorCard.accessibilityIdentifier = @"tiktiger.creator.card";
    [_creatorCard setStatusMessage:@"Saved content and creator workflow are organized from verified Download history."];
    _creatorStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _creatorStack.translatesAutoresizingMaskIntoConstraints = NO;
    _creatorStack.axis = UILayoutConstraintAxisVertical;
    _creatorStack.alignment = UIStackViewAlignmentFill;
    _creatorStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_creatorCard.contentView addSubview:_creatorStack];

    _featureCard = [[TiktigerGlassCard alloc] initWithTitle:@"Profile Feature Cards"];
    _featureCard.accessibilityIdentifier = @"tiktiger.profile.feature-card";
    [_featureCard setStatusMessage:@"A live overview of the four profile configuration domains."];
    _featureStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _featureStack.translatesAutoresizingMaskIntoConstraints = NO;
    _featureStack.axis = UILayoutConstraintAxisVertical;
    _featureStack.alignment = UIStackViewAlignmentFill;
    _featureStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_featureCard.contentView addSubview:_featureStack];

    _settingsCard = [[TiktigerGlassCard alloc] initWithTitle:@"Profile Configuration"];
    _settingsCard.accessibilityIdentifier = @"tiktiger.profile.settings-card";
    [_settingsCard setStatusMessage:@"Changes are validated and stored as configuration only; no profile behavior is added."];
    _settingsStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _settingsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _settingsStack.axis = UILayoutConstraintAxisVertical;
    _settingsStack.alignment = UIStackViewAlignmentFill;
    _settingsStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_settingsCard.contentView addSubview:_settingsStack];

    _diagnosticsCard = [[TiktigerGlassCard alloc] initWithTitle:@"Profile Diagnostics"];
    _diagnosticsCard.accessibilityIdentifier = @"tiktiger.profile.diagnostics-card";
    [_diagnosticsCard setStatusMessage:@"Module health, configuration validity, last action, and errors are supplied by the binding snapshot."];
    _diagnosticsStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _diagnosticsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _diagnosticsStack.axis = UILayoutConstraintAxisVertical;
    _diagnosticsStack.alignment = UIStackViewAlignmentFill;
    _diagnosticsStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_diagnosticsCard.contentView addSubview:_diagnosticsStack];

    [_contentStack addArrangedSubview:_statusCard];
    [_contentStack addArrangedSubview:_creatorCard];
    [_contentStack addArrangedSubview:_featureCard];
    [_contentStack addArrangedSubview:_settingsCard];
    [_contentStack addArrangedSubview:_diagnosticsCard];

    CGFloat margin = [TiktigerDesignTokens screenMargin];
    CGFloat padding = [TiktigerDesignTokens cardPadding];
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor],
        [_scrollView.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor],
        [_contentStack.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor constant:margin],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor constant:-margin],
        [_contentStack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor constant:margin],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor constant:-margin],
        [_contentStack.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor constant:-2.0 * margin],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:_statusCard.contentView.leadingAnchor constant:padding],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:_statusCard.contentView.trailingAnchor constant:-padding],
        [_statusLabel.topAnchor constraintEqualToAnchor:_statusCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_statusDetailLabel.leadingAnchor constraintEqualToAnchor:_statusCard.contentView.leadingAnchor constant:padding],
        [_statusDetailLabel.trailingAnchor constraintEqualToAnchor:_statusCard.contentView.trailingAnchor constant:-padding],
        [_statusDetailLabel.topAnchor constraintEqualToAnchor:_statusLabel.bottomAnchor constant:[TiktigerDesignTokens sectionGap] / 2.0],
        [_statusDetailLabel.bottomAnchor constraintEqualToAnchor:_statusCard.contentView.bottomAnchor constant:-padding],
        [_creatorStack.leadingAnchor constraintEqualToAnchor:_creatorCard.contentView.leadingAnchor constant:padding],
        [_creatorStack.trailingAnchor constraintEqualToAnchor:_creatorCard.contentView.trailingAnchor constant:-padding],
        [_creatorStack.topAnchor constraintEqualToAnchor:_creatorCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_creatorStack.bottomAnchor constraintEqualToAnchor:_creatorCard.contentView.bottomAnchor constant:-padding],
        [_featureStack.leadingAnchor constraintEqualToAnchor:_featureCard.contentView.leadingAnchor constant:padding],
        [_featureStack.trailingAnchor constraintEqualToAnchor:_featureCard.contentView.trailingAnchor constant:-padding],
        [_featureStack.topAnchor constraintEqualToAnchor:_featureCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_featureStack.bottomAnchor constraintEqualToAnchor:_featureCard.contentView.bottomAnchor constant:-padding],
        [_settingsStack.leadingAnchor constraintEqualToAnchor:_settingsCard.contentView.leadingAnchor constant:padding],
        [_settingsStack.trailingAnchor constraintEqualToAnchor:_settingsCard.contentView.trailingAnchor constant:-padding],
        [_settingsStack.topAnchor constraintEqualToAnchor:_settingsCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_settingsStack.bottomAnchor constraintEqualToAnchor:_settingsCard.contentView.bottomAnchor constant:-padding],
        [_diagnosticsStack.leadingAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.leadingAnchor constant:padding],
        [_diagnosticsStack.trailingAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.trailingAnchor constant:-padding],
        [_diagnosticsStack.topAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_diagnosticsStack.bottomAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.bottomAnchor constant:-padding]
    ]];

    [self refreshCreatorWithDownloadSnapshot:self.lastDownloadSnapshot ?: @{}];
    [self refreshFeatureCardsWithSnapshot:self.lastSnapshot];
    [self refreshSettingsWithSnapshot:self.lastSnapshot];
    [self refreshDiagnosticsWithSnapshot:self.lastSnapshot];
}

- (TiktigerGlassRow *)profileRowWithTitle:(NSString *)title detail:(NSString *)detail icon:(NSString *)icon identifier:(NSString *)identifier {
    TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:title detail:detail systemImageName:icon];
    row.enabled = NO;
    row.accessibilityIdentifier = identifier;
    row.accessibilityValue = detail;
    return row;
}

- (void)setFeatureBinding:(id<TiktigerFeatureBinding>)binding {
    if (_featureBinding != nil && self.eventToken != nil) { [_featureBinding unsubscribeFromModuleEvents:self.eventToken]; }
    _featureBinding = binding;
    self.lastDownloadSnapshot = binding != nil ? [binding downloadPresentationState] : @{};
    __weak typeof(self) weakSelf = self;
    self.eventToken = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self == nil) { return; }
        if ([event[@"featureID"] isEqual:TiktigerProfileFeatureID]) {
            [self applyProfilePresentation:event[@"profile"] ?: [binding profilePresentationState]];
        }
        if ([event[@"featureID"] isEqual:@"media.download"]) {
            self.lastDownloadSnapshot = [event[@"download"] isKindOfClass:[NSDictionary class]] ? [event[@"download"] copy] : [binding downloadPresentationState];
            [self refreshCreatorWithDownloadSnapshot:self.lastDownloadSnapshot ?: @{}];
        }
    }];
    [self applyProfilePresentation:binding != nil ? [binding profilePresentationState] : @{}];
    [self refreshCreatorWithDownloadSnapshot:self.lastDownloadSnapshot ?: @{}];
}

- (void)applyProfilePresentation:(NSDictionary<NSString *,id> *)snapshot {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        NSDictionary *copy = [snapshot copy] ?: @{};
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf applyProfilePresentation:copy]; });
        return;
    }
    self.lastSnapshot = [snapshot isKindOfClass:[NSDictionary class]] ? [snapshot copy] : @{};
    NSString *moduleState = [self.lastSnapshot[@"state"] isKindOfClass:[NSString class]] ? self.lastSnapshot[@"state"] : @"unknown";
    NSString *configurationState = [self.lastSnapshot[@"configurationState"] isKindOfClass:[NSString class]] ? self.lastSnapshot[@"configurationState"] : @"unknown";
    NSString *behaviorState = [self.lastSnapshot[@"behaviorState"] isKindOfClass:[NSString class]] ? self.lastSnapshot[@"behaviorState"] : @"unknown";
    BOOL healthy = [configurationState isEqualToString:@"configured"] && ![moduleState isEqualToString:@"failed"];
    self.statusLabel.text = healthy ? @"Configured" : ([configurationState isEqualToString:@"review-required"] ? @"Review required" : @"Needs attention");
    self.statusLabel.accessibilityValue = self.statusLabel.text;
    self.statusDetailLabel.text = [NSString stringWithFormat:@"Configuration: %@\nModule: %@\nBehavior: %@", configurationState, moduleState, behaviorState];
    self.statusDetailLabel.accessibilityValue = self.statusDetailLabel.text;
    [self.statusCard setStatusMessage:healthy ? @"Profile configuration is valid; behavior remains configuration-only." : @"Profile configuration is using a safe review state."];
    [self refreshFeatureCardsWithSnapshot:self.lastSnapshot];
    [self refreshSettingsWithSnapshot:self.lastSnapshot];
    [self refreshDiagnosticsWithSnapshot:self.lastSnapshot];
    [TiktigerMotionSystem animateView:self.statusCard duration:[TiktigerDesignTokens motionFast] animations:^{ self.statusCard.alpha = 0.98; } completion:^(BOOL finished) { (void)finished; self.statusCard.alpha = 1.0; }];
}

- (void)refreshCreatorWithDownloadSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    if (self.creatorStack == nil) { return; }
    for (UIView *view in [self.creatorStack.arrangedSubviews copy]) {
        [self.creatorStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    NSArray *history = [snapshot[@"history"] isKindOfClass:[NSArray class]] ? snapshot[@"history"] : @[];
    NSDictionary *queue = [snapshot[@"queue"] isKindOfClass:[NSDictionary class]] ? snapshot[@"queue"] : @{};
    NSArray *queueItems = [queue[@"items"] isKindOfClass:[NSArray class]] ? queue[@"items"] : @[];
    NSDictionary *currentItem = [snapshot[@"currentItem"] isKindOfClass:[NSDictionary class]] ? snapshot[@"currentItem"] : @{};
    NSUInteger completedCount = 0;
    NSUInteger failedCount = 0;
    for (NSDictionary *item in history) {
        NSString *state = [item[@"state"] isKindOfClass:[NSString class]] ? item[@"state"] : @"";
        if ([state isEqualToString:@"completed"]) { completedCount += 1; }
        if ([state isEqualToString:@"failed"]) { failedCount += 1; }
    }
    BOOL workflowActive = [queue[@"active"] boolValue] || currentItem.count > 0;
    NSString *workflow = workflowActive ? ([currentItem[@"mediaType"] isKindOfClass:[NSString class]] ? [NSString stringWithFormat:@"Active %@ workflow", [currentItem[@"mediaType"] capitalizedString]] : @"Active creator workflow") : @"Ready for a new creator workflow";
    [self.creatorCard setStatusMessage:history.count > 0 ? @"Saved content is organized from verified Download history." : @"Creator Center is ready; saved content will appear after verified downloads."];
    NSArray *rows = @[
        @[ @"Saved Content", [NSString stringWithFormat:@"%lu verified files", (unsigned long)completedCount], @"bookmark.fill", @"tiktiger.creator.saved-content" ],
        @[ @"Download History", [NSString stringWithFormat:@"%lu recorded · %lu failed", (unsigned long)history.count, (unsigned long)failedCount], @"clock.arrow.circlepath", @"tiktiger.creator.history" ],
        @[ @"Collections", @"Foundation ready · 0 created", @"square.stack.3d.up", @"tiktiger.creator.collections" ],
        @[ @"Creator Workflow", [NSString stringWithFormat:@"%@ · %lu queued", workflow, (unsigned long)queueItems.count], @"wand.and.stars", @"tiktiger.creator.workflow" ]
    ];
    for (NSArray *definition in rows) {
        [self.creatorStack addArrangedSubview:[self profileRowWithTitle:definition[0] detail:definition[1] icon:definition[2] identifier:definition[3]]];
    }
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)profileDefinitions {
    return @[
        @{ @"key": @"profileTools", @"title": @"Profile Tools", @"detail": @"Stores profile tool preferences for future host-controlled behavior.", @"icon": @"wrench.and.screwdriver" },
        @{ @"key": @"mediaPreferences", @"title": @"Media Preferences", @"detail": @"Stores validated profile media preferences without changing media behavior.", @"icon": @"photo.on.rectangle" },
        @{ @"key": @"avatarSettings", @"title": @"Avatar Settings", @"detail": @"Stores avatar preferences as a safe configuration foundation.", @"icon": @"person.crop.circle.badge.checkmark" },
        @{ @"key": @"accountPreferences", @"title": @"Account Preferences", @"detail": @"Stores account preference configuration with schema validation.", @"icon": @"person.text.rectangle" }
    ];
}

- (void)refreshFeatureCardsWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
    if (self.featureStack == nil) { return; }
    for (UIView *view in [self.featureStack.arrangedSubviews copy]) { [self.featureStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSDictionary *configuration = [snapshot[@"configuration"] isKindOfClass:[NSDictionary class]] ? snapshot[@"configuration"] : @{};
    for (NSDictionary *definition in [self profileDefinitions]) {
        NSDictionary *section = [configuration[definition[@"key"]] isKindOfClass:[NSDictionary class]] ? configuration[definition[@"key"]] : @{};
        BOOL enabled = [section[@"enabled"] boolValue];
        NSString *detail = [NSString stringWithFormat:@"%@ · %@", enabled ? @"Configured on" : @"Review", definition[@"detail"]];
        [self.featureStack addArrangedSubview:[self profileRowWithTitle:definition[@"title"] detail:detail icon:definition[@"icon"] identifier:[NSString stringWithFormat:@"tiktiger.profile.feature.%@", definition[@"key"]]]];
    }
}

- (void)refreshSettingsWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
    if (self.settingsStack == nil) { return; }
    for (UIView *view in [self.settingsStack.arrangedSubviews copy]) { [self.settingsStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSDictionary *configuration = [snapshot[@"configuration"] isKindOfClass:[NSDictionary class]] ? snapshot[@"configuration"] : @{};
    for (NSDictionary *definition in [self profileDefinitions]) {
        NSString *key = definition[@"key"];
        NSDictionary *section = [configuration[key] isKindOfClass:[NSDictionary class]] ? configuration[key] : @{};
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:definition[@"title"] detail:definition[@"detail"] systemImageName:definition[@"icon"]];
        row.accessibilityIdentifier = [NSString stringWithFormat:@"tiktiger.profile.setting.%@", key];
        row.accessibilityHint = @"Toggle the validated profile configuration setting.";
        TiktigerGlassToggle *toggle = [[TiktigerGlassToggle alloc] initWithFrame:CGRectZero];
        toggle.translatesAutoresizingMaskIntoConstraints = NO;
        toggle.on = [section[@"enabled"] boolValue];
        toggle.accessibilityStateLabel = definition[@"title"];
        toggle.accessibilityIdentifier = [NSString stringWithFormat:@"tiktiger.profile.toggle.%@", key];
        toggle.accessibilityValue = toggle.isOn ? @"On" : @"Off";
        [toggle addTarget:self action:@selector(profileToggleChanged:) forControlEvents:UIControlEventValueChanged];
        [row addSubview:toggle];
        [NSLayoutConstraint activateConstraints:@[
            [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-[TiktigerDesignTokens cardPadding]],
            [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
        ]];
        [self.settingsStack addArrangedSubview:row];
    }
}

- (void)profileToggleChanged:(TiktigerGlassToggle *)toggle {
    if (self.featureBinding == nil) { [toggle setOn:!toggle.isOn animated:NO]; return; }
    NSString *prefix = @"tiktiger.profile.toggle.";
    NSString *key = [toggle.accessibilityIdentifier hasPrefix:prefix] ? [toggle.accessibilityIdentifier substringFromIndex:prefix.length] : @"";
    NSError *error = nil;
    BOOL success = [self.featureBinding executeFeatureAction:@"updateProfileSetting" featureID:TiktigerProfileFeatureID payload:@{ @"key": key, @"value": @(toggle.isOn) } error:&error];
    if (!success) {
        [toggle setOn:!toggle.isOn animated:NO];
        toggle.accessibilityValue = @"Update failed";
        [self showToastMessage:error.localizedDescription ?: @"Profile setting was rejected safely."];
    } else {
        toggle.accessibilityValue = toggle.isOn ? @"On" : @"Off";
        [self showToastMessage:@"Profile configuration updated."];
    }
}

- (void)refreshDiagnosticsWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
    if (self.diagnosticsStack == nil) { return; }
    for (UIView *view in [self.diagnosticsStack.arrangedSubviews copy]) { [self.diagnosticsStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSString *moduleState = [snapshot[@"state"] isKindOfClass:[NSString class]] ? snapshot[@"state"] : @"unknown";
    NSString *configurationState = [snapshot[@"configurationState"] isKindOfClass:[NSString class]] ? snapshot[@"configurationState"] : @"unknown";
    NSString *behaviorState = [snapshot[@"behaviorState"] isKindOfClass:[NSString class]] ? snapshot[@"behaviorState"] : @"configuration-only";
    NSString *lastAction = [snapshot[@"lastAction"] isKindOfClass:[NSString class]] ? snapshot[@"lastAction"] : @"unknown";
    NSArray *rows = @[
        @[ @"Module status", moduleState, @"checkmark.shield", @"tiktiger.profile.diagnostics.module" ],
        @[ @"Configuration", configurationState, @"gearshape", @"tiktiger.profile.diagnostics.configuration" ],
        @[ @"Behavior", behaviorState, @"person.crop.circle", @"tiktiger.profile.diagnostics.behavior" ],
        @[ @"Last action", lastAction, @"clock.arrow.circlepath", @"tiktiger.profile.diagnostics.last-action" ],
        @[ @"Errors", [NSString stringWithFormat:@"%@", snapshot[@"errorCount"] ?: @0], @"exclamationmark.triangle", @"tiktiger.profile.diagnostics.errors" ]
    ];
    for (NSArray *definition in rows) { [self.diagnosticsStack addArrangedSubview:[self profileRowWithTitle:definition[0] detail:definition[1] icon:definition[2] identifier:definition[3]]]; }
}

- (void)showToastMessage:(NSString *)message {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        NSString *copy = [message copy];
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf showToastMessage:copy]; });
        return;
    }
    TiktigerToast *toast = [TiktigerToast toastWithMessage:message state:TiktigerToastStateInfo];
    [toast presentInView:self];
}

- (void)dealloc {
    [self.featureBinding unsubscribeFromModuleEvents:self.eventToken];
}

@end
