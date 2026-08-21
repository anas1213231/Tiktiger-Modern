#import "TiktigerSystemCenterView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassCard.h"
#import "TiktigerGlassRow.h"
#import "TiktigerGlassToggle.h"
#import "TiktigerToast.h"
#import "TiktigerMotionSystem.h"

static NSString * const TiktigerSystemFeatureID = @"system.center";

@interface TiktigerSystemCenterView ()
@property (nonatomic, weak) id<TiktigerFeatureBinding> featureBinding;
@property (nonatomic, strong) id eventToken;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) TiktigerGlassCard *statusCard;
@property (nonatomic, strong) TiktigerGlassCard *featureCard;
@property (nonatomic, strong) TiktigerGlassCard *diagnosticsCard;
@property (nonatomic, strong) TiktigerGlassCard *backupCard;
@property (nonatomic, strong) UIStackView *featureStack;
@property (nonatomic, strong) UIStackView *diagnosticsStack;
@property (nonatomic, strong) UIStackView *backupStack;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *statusDetailLabel;
@property (nonatomic, copy) NSDictionary<NSString *, id> *lastSnapshot;
@end

@implementation TiktigerSystemCenterView

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
    _scrollView.accessibilityIdentifier = @"tiktiger.system.scroll";
    [self addSubview:_scrollView];

    _contentStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.alignment = UIStackViewAlignmentFill;
    _contentStack.spacing = [TiktigerDesignTokens sectionGap];
    [_scrollView addSubview:_contentStack];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"System Center";
    title.font = [TiktigerDesignTokens titleFont];
    title.textColor = [TiktigerDesignTokens vipWhite];
    title.adjustsFontForContentSizeCategory = YES;
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    title.accessibilityIdentifier = @"tiktiger.system.title";

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"A calm control room for runtime status, modules, diagnostics, and safe configuration backup.";
    subtitle.font = [TiktigerDesignTokens bodyFont];
    subtitle.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    subtitle.numberOfLines = 0;
    subtitle.adjustsFontForContentSizeCategory = YES;
    subtitle.accessibilityIdentifier = @"tiktiger.system.subtitle";

    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle]];
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    heading.axis = UILayoutConstraintAxisVertical;
    heading.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_contentStack addArrangedSubview:heading];

    _statusCard = [[TiktigerGlassCard alloc] initWithTitle:@"System Dashboard"];
    _statusCard.accessibilityIdentifier = @"tiktiger.system.status-card";
    [_statusCard setElevated:YES];
    [_statusCard setStatusMessage:@"Waiting for runtime and system health state."];
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.font = [TiktigerDesignTokens titleFont];
    _statusLabel.textColor = [TiktigerDesignTokens vipWhite];
    _statusLabel.adjustsFontForContentSizeCategory = YES;
    _statusLabel.accessibilityIdentifier = @"tiktiger.system.status";
    _statusDetailLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusDetailLabel.font = [TiktigerDesignTokens bodyFont];
    _statusDetailLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _statusDetailLabel.numberOfLines = 0;
    _statusDetailLabel.adjustsFontForContentSizeCategory = YES;
    _statusDetailLabel.accessibilityIdentifier = @"tiktiger.system.status-detail";
    [_statusCard.contentView addSubview:_statusLabel];
    [_statusCard.contentView addSubview:_statusDetailLabel];

    _featureCard = [[TiktigerGlassCard alloc] initWithTitle:@"Feature Manager"];
    _featureCard.accessibilityIdentifier = @"tiktiger.system.feature-card";
    [_featureCard setStatusMessage:@"Manage the five registered user-facing modules through validated enable/disable intents."];
    _featureStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _featureStack.translatesAutoresizingMaskIntoConstraints = NO;
    _featureStack.axis = UILayoutConstraintAxisVertical;
    _featureStack.alignment = UIStackViewAlignmentFill;
    _featureStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_featureCard.contentView addSubview:_featureStack];

    _diagnosticsCard = [[TiktigerGlassCard alloc] initWithTitle:@"Diagnostics Hub"];
    _diagnosticsCard.accessibilityIdentifier = @"tiktiger.system.diagnostics-card";
    [_diagnosticsCard setStatusMessage:@"Aggregate logs, errors, last actions, and health checks are read from module diagnostics."];
    _diagnosticsStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _diagnosticsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _diagnosticsStack.axis = UILayoutConstraintAxisVertical;
    _diagnosticsStack.alignment = UIStackViewAlignmentFill;
    _diagnosticsStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_diagnosticsCard.contentView addSubview:_diagnosticsStack];

    _backupCard = [[TiktigerGlassCard alloc] initWithTitle:@"Backup Center"];
    _backupCard.accessibilityIdentifier = @"tiktiger.system.backup-card";
    [_backupCard setStatusMessage:@"Configuration export/import structure and safe reset are available as non-destructive foundations."];
    _backupStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _backupStack.translatesAutoresizingMaskIntoConstraints = NO;
    _backupStack.axis = UILayoutConstraintAxisVertical;
    _backupStack.alignment = UIStackViewAlignmentFill;
    _backupStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_backupCard.contentView addSubview:_backupStack];

    [_contentStack addArrangedSubview:_statusCard];
    [_contentStack addArrangedSubview:_featureCard];
    [_contentStack addArrangedSubview:_diagnosticsCard];
    [_contentStack addArrangedSubview:_backupCard];

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
        [_featureStack.leadingAnchor constraintEqualToAnchor:_featureCard.contentView.leadingAnchor constant:padding],
        [_featureStack.trailingAnchor constraintEqualToAnchor:_featureCard.contentView.trailingAnchor constant:-padding],
        [_featureStack.topAnchor constraintEqualToAnchor:_featureCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_featureStack.bottomAnchor constraintEqualToAnchor:_featureCard.contentView.bottomAnchor constant:-padding],
        [_diagnosticsStack.leadingAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.leadingAnchor constant:padding],
        [_diagnosticsStack.trailingAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.trailingAnchor constant:-padding],
        [_diagnosticsStack.topAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_diagnosticsStack.bottomAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.bottomAnchor constant:-padding],
        [_backupStack.leadingAnchor constraintEqualToAnchor:_backupCard.contentView.leadingAnchor constant:padding],
        [_backupStack.trailingAnchor constraintEqualToAnchor:_backupCard.contentView.trailingAnchor constant:-padding],
        [_backupStack.topAnchor constraintEqualToAnchor:_backupCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_backupStack.bottomAnchor constraintEqualToAnchor:_backupCard.contentView.bottomAnchor constant:-padding]
    ]];

    [self refreshFeatureManagerWithSnapshot:self.lastSnapshot];
    [self refreshDiagnosticsWithSnapshot:self.lastSnapshot];
    [self refreshBackupWithSnapshot:self.lastSnapshot];
}

- (TiktigerGlassRow *)systemRowWithTitle:(NSString *)title detail:(NSString *)detail icon:(NSString *)icon identifier:(NSString *)identifier {
    TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:title detail:detail systemImageName:icon];
    row.enabled = NO;
    row.accessibilityIdentifier = identifier;
    row.accessibilityValue = detail;
    return row;
}

- (void)setFeatureBinding:(id<TiktigerFeatureBinding>)binding {
    if (_featureBinding != nil && self.eventToken != nil) { [_featureBinding unsubscribeFromModuleEvents:self.eventToken]; }
    _featureBinding = binding;
    __weak typeof(self) weakSelf = self;
    self.eventToken = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self != nil && [event[@"featureID"] isEqual:TiktigerSystemFeatureID]) {
            [self applySystemPresentation:event[@"system"] ?: [binding systemPresentationState]];
        }
    }];
    [self applySystemPresentation:binding != nil ? [binding systemPresentationState] : @{}];
}

- (void)applySystemPresentation:(NSDictionary<NSString *,id> *)snapshot {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        NSDictionary *copy = [snapshot copy] ?: @{};
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf applySystemPresentation:copy]; });
        return;
    }
    self.lastSnapshot = [snapshot isKindOfClass:[NSDictionary class]] ? [snapshot copy] : @{};
    NSString *runtimeStatus = [self.lastSnapshot[@"runtimeStatus"] isKindOfClass:[NSString class]] ? self.lastSnapshot[@"runtimeStatus"] : @"unknown";
    NSString *runtimeVersion = [self.lastSnapshot[@"runtimeVersion"] isKindOfClass:[NSString class]] ? self.lastSnapshot[@"runtimeVersion"] : @"unknown";
    NSDictionary *build = [self.lastSnapshot[@"build"] isKindOfClass:[NSDictionary class]] ? self.lastSnapshot[@"build"] : @{};
    NSDictionary *storage = [self.lastSnapshot[@"storage"] isKindOfClass:[NSDictionary class]] ? self.lastSnapshot[@"storage"] : @{};
    NSDictionary *health = [self.lastSnapshot[@"healthSummary"] isKindOfClass:[NSDictionary class]] ? self.lastSnapshot[@"healthSummary"] : @{};
    BOOL healthy = [self.lastSnapshot[@"configurationValid"] boolValue] && [health[@"healthy"] boolValue];
    self.statusLabel.text = healthy ? @"System healthy" : @"Review required";
    self.statusLabel.accessibilityValue = self.statusLabel.text;
    NSString *freeBytes = [NSByteCountFormatter stringFromByteCount:[storage[@"freeBytes"] longLongValue] countStyle:NSByteCountFormatterCountStyleFile];
    self.statusDetailLabel.text = [NSString stringWithFormat:@"Runtime: %@\nVersion: %@\nBuild: %@ · %@ · %@\nStorage free: %@\nHealth: %@", runtimeStatus, runtimeVersion, build[@"configuration"] ?: @"unknown", build[@"architecture"] ?: @"unknown", build[@"deployment"] ?: @"unknown", freeBytes, health[@"healthy"] ? ([health[@"healthy"] boolValue] ? @"healthy" : @"review") : @"unknown"];
    self.statusDetailLabel.accessibilityValue = self.statusDetailLabel.text;
    [self.statusCard setStatusMessage:healthy ? @"Runtime, managed modules, and configuration diagnostics are healthy." : @"System Center has a review state; no destructive action was performed."];
    [self refreshFeatureManagerWithSnapshot:self.lastSnapshot];
    [self refreshDiagnosticsWithSnapshot:self.lastSnapshot];
    [self refreshBackupWithSnapshot:self.lastSnapshot];
    [TiktigerMotionSystem animateView:self.statusCard duration:[TiktigerDesignTokens motionFast] animations:^{ self.statusCard.alpha = 0.98; } completion:^(BOOL finished) { (void)finished; self.statusCard.alpha = 1.0; }];
}

- (void)refreshFeatureManagerWithSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    if (self.featureStack == nil) { return; }
    for (UIView *view in [self.featureStack.arrangedSubviews copy]) { [self.featureStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSDictionary *featureManager = [snapshot[@"featureManager"] isKindOfClass:[NSDictionary class]] ? snapshot[@"featureManager"] : @{};
    NSArray *modules = [featureManager[@"modules"] isKindOfClass:[NSArray class]] ? featureManager[@"modules"] : @[];
    for (NSDictionary *module in modules) {
        NSString *featureID = [module[@"id"] isKindOfClass:[NSString class]] ? module[@"id"] : @"";
        NSString *name = [module[@"name"] isKindOfClass:[NSString class]] ? module[@"name"] : featureID;
        NSString *state = [module[@"state"] isKindOfClass:[NSString class]] ? module[@"state"] : @"unknown";
        NSString *version = [module[@"version"] isKindOfClass:[NSString class]] ? module[@"version"] : @"unknown";
        BOOL healthy = [module[@"healthy"] boolValue];
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:name detail:[NSString stringWithFormat:@"%@ · v%@ · %@", state, version, healthy ? @"healthy" : @"review"] systemImageName:@"square.stack.3d.up"];
        row.accessibilityIdentifier = [NSString stringWithFormat:@"tiktiger.system.module.%@", featureID];
        row.accessibilityHint = @"Enable or disable this registered module through the validated System Center binding.";
        TiktigerGlassToggle *toggle = [[TiktigerGlassToggle alloc] initWithFrame:CGRectZero];
        toggle.translatesAutoresizingMaskIntoConstraints = NO;
        toggle.on = [state isEqualToString:@"enabled"];
        toggle.accessibilityStateLabel = name;
        toggle.accessibilityIdentifier = [NSString stringWithFormat:@"tiktiger.system.module-toggle.%@", featureID];
        toggle.accessibilityValue = toggle.isOn ? @"On" : @"Off";
        [toggle addTarget:self action:@selector(systemModuleToggleChanged:) forControlEvents:UIControlEventValueChanged];
        [row addSubview:toggle];
        [NSLayoutConstraint activateConstraints:@[
            [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-[TiktigerDesignTokens cardPadding]],
            [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
        ]];
        [self.featureStack addArrangedSubview:row];
    }
    if (modules.count == 0) {
        [self.featureStack addArrangedSubview:[self systemRowWithTitle:@"No managed modules" detail:@"The feature manager is waiting for registered module snapshots." icon:@"questionmark.square" identifier:@"tiktiger.system.module.empty"]];
    }
}

- (void)systemModuleToggleChanged:(TiktigerGlassToggle *)toggle {
    if (self.featureBinding == nil) { [toggle setOn:!toggle.isOn animated:NO]; return; }
    NSString *prefix = @"tiktiger.system.module-toggle.";
    NSString *featureID = [toggle.accessibilityIdentifier hasPrefix:prefix] ? [toggle.accessibilityIdentifier substringFromIndex:prefix.length] : @"";
    NSError *error = nil;
    BOOL success = [self.featureBinding executeFeatureAction:@"setManagedFeature" featureID:TiktigerSystemFeatureID payload:@{ @"managedFeatureID": featureID, @"enabled": @(toggle.isOn) } error:&error];
    if (!success) {
        [toggle setOn:!toggle.isOn animated:NO];
        toggle.accessibilityValue = @"Update failed";
        [self showToastMessage:error.localizedDescription ?: @"Module state change was rejected safely."];
    } else {
        toggle.accessibilityValue = toggle.isOn ? @"On" : @"Off";
        [self showToastMessage:toggle.isOn ? @"Module enabled." : @"Module disabled."];
    }
}

- (void)refreshDiagnosticsWithSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    if (self.diagnosticsStack == nil) { return; }
    for (UIView *view in [self.diagnosticsStack.arrangedSubviews copy]) { [self.diagnosticsStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSDictionary *diagnostics = [snapshot[@"diagnosticsHub"] isKindOfClass:[NSDictionary class]] ? snapshot[@"diagnosticsHub"] : @{};
    NSArray *errors = [diagnostics[@"errors"] isKindOfClass:[NSArray class]] ? diagnostics[@"errors"] : @[];
    NSArray *lastActions = [diagnostics[@"lastActions"] isKindOfClass:[NSArray class]] ? diagnostics[@"lastActions"] : @[];
    NSArray *logs = [diagnostics[@"logsOverview"] isKindOfClass:[NSArray class]] ? diagnostics[@"logsOverview"] : @[];
    NSDictionary *healthChecks = [diagnostics[@"healthChecks"] isKindOfClass:[NSDictionary class]] ? diagnostics[@"healthChecks"] : @{};
    NSArray *rows = @[
        @[ @"Hub status", [diagnostics[@"healthy"] boolValue] ? @"healthy" : @"review", @"waveform.path.ecg", @"tiktiger.system.diagnostics.status" ],
        @[ @"Logs overview", [NSString stringWithFormat:@"%@ modules", @(logs.count)], @"doc.text.magnifyingglass", @"tiktiger.system.diagnostics.logs" ],
        @[ @"Errors", [NSString stringWithFormat:@"%@", @(errors.count)], @"exclamationmark.triangle", @"tiktiger.system.diagnostics.errors" ],
        @[ @"Last actions", [NSString stringWithFormat:@"%@", @(lastActions.count)], @"clock.arrow.circlepath", @"tiktiger.system.diagnostics.last-actions" ],
        @[ @"Health checks", [NSString stringWithFormat:@"%@ modules", @(healthChecks.count)], @"checkmark.shield", @"tiktiger.system.diagnostics.health" ]
    ];
    for (NSArray *definition in rows) { [self.diagnosticsStack addArrangedSubview:[self systemRowWithTitle:definition[0] detail:definition[1] icon:definition[2] identifier:definition[3]]]; }
}

- (void)refreshBackupWithSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    if (self.backupStack == nil) { return; }
    for (UIView *view in [self.backupStack.arrangedSubviews copy]) { [self.backupStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSDictionary *backup = [snapshot[@"backup"] isKindOfClass:[NSDictionary class]] ? snapshot[@"backup"] : @{};
    NSArray *managedIDs = [backup[@"managedFeatureIDs"] isKindOfClass:[NSArray class]] ? backup[@"managedFeatureIDs"] : @[];
    NSArray *rows = @[
        @[ @"Format", backup[@"format"] ?: @"pending", @"doc.badge.gearshape", @"tiktiger.system.backup.format" ],
        @[ @"Schema", [NSString stringWithFormat:@"%@", backup[@"backupSchemaVersion"] ?: @"unknown"], @"number.square", @"tiktiger.system.backup.schema" ],
        @[ @"Mode", backup[@"mode"] ?: @"configuration-only", @"arrow.up.doc", @"tiktiger.system.backup.mode" ],
        @[ @"Managed modules", [NSString stringWithFormat:@"%@", @(managedIDs.count)], @"square.stack.3d.up", @"tiktiger.system.backup.modules" ],
        @[ @"Safe reset", @"Available as a validated foundation", @"arrow.counterclockwise", @"tiktiger.system.backup.reset" ]
    ];
    for (NSArray *definition in rows) { [self.backupStack addArrangedSubview:[self systemRowWithTitle:definition[0] detail:definition[1] icon:definition[2] identifier:definition[3]]]; }
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
