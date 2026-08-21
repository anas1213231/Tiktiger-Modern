#import "TiktigerAppearanceEngineView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassCard.h"
#import "TiktigerGlassRow.h"
#import "TiktigerGlassToggle.h"
#import "TiktigerToast.h"
#import "TiktigerMotionSystem.h"

static NSString * const TiktigerAppearanceFeatureID = @"appearance.engine";

@interface TiktigerAppearanceEngineView ()
@property (nonatomic, weak) id<TiktigerFeatureBinding> featureBinding;
@property (nonatomic, strong) id eventToken;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) TiktigerGlassCard *previewCard;
@property (nonatomic, strong) TiktigerGlassCard *themeCard;
@property (nonatomic, strong) TiktigerGlassCard *animationCard;
@property (nonatomic, strong) TiktigerGlassCard *customizationCard;
@property (nonatomic, strong) TiktigerGlassCard *diagnosticsCard;
@property (nonatomic, strong) UIStackView *themeStack;
@property (nonatomic, strong) UIStackView *animationStack;
@property (nonatomic, strong) UIStackView *customizationStack;
@property (nonatomic, strong) UIStackView *diagnosticsStack;
@property (nonatomic, strong) UIView *previewSurface;
@property (nonatomic, strong) UIVisualEffectView *previewBlur;
@property (nonatomic, strong) UILabel *previewTitle;
@property (nonatomic, strong) UILabel *previewDetail;
@property (nonatomic, copy) NSDictionary<NSString *, id> *lastSnapshot;
@end

@implementation TiktigerAppearanceEngineView

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
    _scrollView.accessibilityIdentifier = @"tiktiger.appearance.scroll";
    [self addSubview:_scrollView];

    _contentStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.alignment = UIStackViewAlignmentFill;
    _contentStack.spacing = [TiktigerDesignTokens sectionGap];
    [_scrollView addSubview:_contentStack];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Appearance Engine";
    title.font = [TiktigerDesignTokens titleFont];
    title.textColor = [TiktigerDesignTokens vipWhite];
    title.adjustsFontForContentSizeCategory = YES;
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    title.accessibilityIdentifier = @"tiktiger.appearance.title";

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Shape the Tiktiger look while keeping every choice transparent and reversible.";
    subtitle.font = [TiktigerDesignTokens bodyFont];
    subtitle.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    subtitle.numberOfLines = 0;
    subtitle.adjustsFontForContentSizeCategory = YES;
    subtitle.accessibilityIdentifier = @"tiktiger.appearance.subtitle";

    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle]];
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    heading.axis = UILayoutConstraintAxisVertical;
    heading.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_contentStack addArrangedSubview:heading];

    _previewCard = [[TiktigerGlassCard alloc] initWithTitle:@"Live Preview"];
    _previewCard.accessibilityIdentifier = @"tiktiger.appearance.preview-card";
    [_previewCard setStatusMessage:@"Preview is local to this screen; the host applies shared tokens."];
    _previewSurface = [[UIView alloc] initWithFrame:CGRectZero];
    _previewSurface.translatesAutoresizingMaskIntoConstraints = NO;
    _previewSurface.layer.masksToBounds = YES;
    _previewSurface.accessibilityIdentifier = @"tiktiger.appearance.preview-surface";
    _previewBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[TiktigerDesignTokens glassBlurStyle]]];
    _previewBlur.translatesAutoresizingMaskIntoConstraints = NO;
    _previewBlur.userInteractionEnabled = NO;
    [_previewSurface addSubview:_previewBlur];
    _previewTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    _previewTitle.translatesAutoresizingMaskIntoConstraints = NO;
    _previewTitle.text = @"Tiktiger VIP";
    _previewTitle.font = [TiktigerDesignTokens titleFont];
    _previewTitle.textColor = [TiktigerDesignTokens vipWhite];
    _previewTitle.adjustsFontForContentSizeCategory = YES;
    _previewTitle.accessibilityIdentifier = @"tiktiger.appearance.preview-title";
    _previewDetail = [[UILabel alloc] initWithFrame:CGRectZero];
    _previewDetail.translatesAutoresizingMaskIntoConstraints = NO;
    _previewDetail.font = [TiktigerDesignTokens bodyFont];
    _previewDetail.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _previewDetail.numberOfLines = 0;
    _previewDetail.adjustsFontForContentSizeCategory = YES;
    _previewDetail.accessibilityIdentifier = @"tiktiger.appearance.preview-detail";
    [_previewSurface addSubview:_previewTitle];
    [_previewSurface addSubview:_previewDetail];
    [_previewCard.contentView addSubview:_previewSurface];

    _themeCard = [[TiktigerGlassCard alloc] initWithTitle:@"Theme Engine"];
    _themeCard.accessibilityIdentifier = @"tiktiger.appearance.theme-card";
    [_themeCard setStatusMessage:@"Choose a foundation theme and accent without changing the shared design system."];
    _themeStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _themeStack.translatesAutoresizingMaskIntoConstraints = NO;
    _themeStack.axis = UILayoutConstraintAxisVertical;
    _themeStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_themeCard.contentView addSubview:_themeStack];

    _animationCard = [[TiktigerGlassCard alloc] initWithTitle:@"Animation Engine"];
    _animationCard.accessibilityIdentifier = @"tiktiger.appearance.animation-card";
    [_animationCard setStatusMessage:@"Motion remains subordinate to Reduce Motion and accessibility preferences."];
    _animationStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _animationStack.translatesAutoresizingMaskIntoConstraints = NO;
    _animationStack.axis = UILayoutConstraintAxisVertical;
    _animationStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_animationCard.contentView addSubview:_animationStack];

    _customizationCard = [[TiktigerGlassCard alloc] initWithTitle:@"UI Customization"];
    _customizationCard.accessibilityIdentifier = @"tiktiger.appearance.customization-card";
    [_customizationCard setStatusMessage:@"Adjust blur, card style, radius, and glow within validated ranges."];
    _customizationStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _customizationStack.translatesAutoresizingMaskIntoConstraints = NO;
    _customizationStack.axis = UILayoutConstraintAxisVertical;
    _customizationStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_customizationCard.contentView addSubview:_customizationStack];

    _diagnosticsCard = [[TiktigerGlassCard alloc] initWithTitle:@"Appearance Diagnostics"];
    _diagnosticsCard.accessibilityIdentifier = @"tiktiger.appearance.diagnostics-card";
    [_diagnosticsCard setStatusMessage:@"Module status and configuration health are read from Feature Binding."];
    _diagnosticsStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _diagnosticsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _diagnosticsStack.axis = UILayoutConstraintAxisVertical;
    _diagnosticsStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_diagnosticsCard.contentView addSubview:_diagnosticsStack];

    [_contentStack addArrangedSubview:_previewCard];
    [_contentStack addArrangedSubview:_themeCard];
    [_contentStack addArrangedSubview:_animationCard];
    [_contentStack addArrangedSubview:_customizationCard];
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
        [_previewSurface.leadingAnchor constraintEqualToAnchor:_previewCard.contentView.leadingAnchor constant:padding],
        [_previewSurface.trailingAnchor constraintEqualToAnchor:_previewCard.contentView.trailingAnchor constant:-padding],
        [_previewSurface.topAnchor constraintEqualToAnchor:_previewCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_previewSurface.heightAnchor constraintGreaterThanOrEqualToConstant:[TiktigerDesignTokens rowHeight] * 2.0],
        [_previewSurface.bottomAnchor constraintEqualToAnchor:_previewCard.contentView.bottomAnchor constant:-padding],
        [_previewBlur.leadingAnchor constraintEqualToAnchor:_previewSurface.leadingAnchor],
        [_previewBlur.trailingAnchor constraintEqualToAnchor:_previewSurface.trailingAnchor],
        [_previewBlur.topAnchor constraintEqualToAnchor:_previewSurface.topAnchor],
        [_previewBlur.bottomAnchor constraintEqualToAnchor:_previewSurface.bottomAnchor],
        [_previewTitle.leadingAnchor constraintEqualToAnchor:_previewSurface.leadingAnchor constant:padding],
        [_previewTitle.trailingAnchor constraintEqualToAnchor:_previewSurface.trailingAnchor constant:-padding],
        [_previewTitle.topAnchor constraintEqualToAnchor:_previewSurface.topAnchor constant:padding],
        [_previewDetail.leadingAnchor constraintEqualToAnchor:_previewSurface.leadingAnchor constant:padding],
        [_previewDetail.trailingAnchor constraintEqualToAnchor:_previewSurface.trailingAnchor constant:-padding],
        [_previewDetail.topAnchor constraintEqualToAnchor:_previewTitle.bottomAnchor constant:[TiktigerDesignTokens sectionGap] / 2.0],
        [_previewDetail.bottomAnchor constraintLessThanOrEqualToAnchor:_previewSurface.bottomAnchor constant:-padding],
        [_themeStack.leadingAnchor constraintEqualToAnchor:_themeCard.contentView.leadingAnchor constant:padding],
        [_themeStack.trailingAnchor constraintEqualToAnchor:_themeCard.contentView.trailingAnchor constant:-padding],
        [_themeStack.topAnchor constraintEqualToAnchor:_themeCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_themeStack.bottomAnchor constraintEqualToAnchor:_themeCard.contentView.bottomAnchor constant:-padding],
        [_animationStack.leadingAnchor constraintEqualToAnchor:_animationCard.contentView.leadingAnchor constant:padding],
        [_animationStack.trailingAnchor constraintEqualToAnchor:_animationCard.contentView.trailingAnchor constant:-padding],
        [_animationStack.topAnchor constraintEqualToAnchor:_animationCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_animationStack.bottomAnchor constraintEqualToAnchor:_animationCard.contentView.bottomAnchor constant:-padding],
        [_customizationStack.leadingAnchor constraintEqualToAnchor:_customizationCard.contentView.leadingAnchor constant:padding],
        [_customizationStack.trailingAnchor constraintEqualToAnchor:_customizationCard.contentView.trailingAnchor constant:-padding],
        [_customizationStack.topAnchor constraintEqualToAnchor:_customizationCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_customizationStack.bottomAnchor constraintEqualToAnchor:_customizationCard.contentView.bottomAnchor constant:-padding],
        [_diagnosticsStack.leadingAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.leadingAnchor constant:padding],
        [_diagnosticsStack.trailingAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.trailingAnchor constant:-padding],
        [_diagnosticsStack.topAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_diagnosticsStack.bottomAnchor constraintEqualToAnchor:_diagnosticsCard.contentView.bottomAnchor constant:-padding]
    ]];
    [self refreshThemeControlsWithSnapshot:self.lastSnapshot];
    [self refreshAnimationControlsWithSnapshot:self.lastSnapshot];
    [self refreshCustomizationControlsWithSnapshot:self.lastSnapshot];
    [self refreshDiagnosticsWithSnapshot:self.lastSnapshot];
}

- (void)setFeatureBinding:(id<TiktigerFeatureBinding>)binding {
    if (_featureBinding != nil && self.eventToken != nil) { [_featureBinding unsubscribeFromModuleEvents:self.eventToken]; }
    _featureBinding = binding;
    __weak typeof(self) weakSelf = self;
    self.eventToken = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self != nil && [event[@"featureID"] isEqual:TiktigerAppearanceFeatureID]) {
            [self applyAppearancePresentation:event[@"appearance"] ?: [binding appearancePresentationState]];
        }
    }];
    [self applyAppearancePresentation:binding != nil ? [binding appearancePresentationState] : @{}];
}

- (void)applyAppearancePresentation:(NSDictionary<NSString *,id> *)snapshot {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        NSDictionary *copy = [snapshot copy] ?: @{};
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf applyAppearancePresentation:copy]; });
        return;
    }
    self.lastSnapshot = [snapshot isKindOfClass:[NSDictionary class]] ? [snapshot copy] : @{};
    [self refreshThemeControlsWithSnapshot:self.lastSnapshot];
    [self refreshAnimationControlsWithSnapshot:self.lastSnapshot];
    [self refreshCustomizationControlsWithSnapshot:self.lastSnapshot];
    [self refreshDiagnosticsWithSnapshot:self.lastSnapshot];
    NSDictionary *configuration = [self.lastSnapshot[@"configuration"] isKindOfClass:[NSDictionary class]] ? self.lastSnapshot[@"configuration"] : @{};
    NSString *theme = [configuration[@"theme"] isKindOfClass:[NSString class]] ? configuration[@"theme"] : @"tiger-black";
    NSString *accent = [configuration[@"accent"] isKindOfClass:[NSString class]] ? configuration[@"accent"] : @"red";
    NSDictionary *animation = [configuration[@"animation"] isKindOfClass:[NSDictionary class]] ? configuration[@"animation"] : @{};
    NSDictionary *ui = [configuration[@"ui"] isKindOfClass:[NSDictionary class]] ? configuration[@"ui"] : @{};
    CGFloat blurLevel = [ui[@"blurLevel"] doubleValue];
    CGFloat radius = [ui[@"cornerRadius"] doubleValue];
    self.previewSurface.backgroundColor = [theme isEqualToString:@"glass"] ? [TiktigerDesignTokens vipGlassContent] : [TiktigerDesignTokens vipBlack];
    self.previewSurface.layer.cornerRadius = radius > 0 ? radius : [TiktigerDesignTokens cornerRadiusCard];
    self.previewBlur.alpha = [animation[@"enabled"] boolValue] ? MAX(0.0, MIN(1.0, blurLevel)) : 0.0;
    self.previewTitle.textColor = [accent isEqualToString:@"white"] ? [TiktigerDesignTokens vipWhite] : [TiktigerDesignTokens vipRed];
    self.previewDetail.text = [NSString stringWithFormat:@"%@ · %@\nPreview state: %@", [theme capitalizedString], [accent capitalizedString], self.lastSnapshot[@"previewState"] ?: @"configuration-preview"];
    self.previewSurface.accessibilityValue = self.previewDetail.text;
    [TiktigerMotionSystem animateView:self.previewSurface duration:[TiktigerDesignTokens motionFast] animations:^{ self.previewSurface.alpha = 0.98; } completion:^(BOOL finished) { (void)finished; self.previewSurface.alpha = 1.0; }];
}

- (UISegmentedControl *)segmentedControlWithTitles:(NSArray<NSString *> *)titles identifier:(NSString *)identifier {
    UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:titles];
    control.translatesAutoresizingMaskIntoConstraints = NO;
    control.accessibilityIdentifier = identifier;
    control.accessibilityLabel = identifier;
    control.selectedSegmentTintColor = [TiktigerDesignTokens vipRed];
    [control setTitleTextAttributes:@{NSForegroundColorAttributeName: [TiktigerDesignTokens vipWhite]} forState:UIControlStateNormal];
    [control setTitleTextAttributes:@{NSForegroundColorAttributeName: [TiktigerDesignTokens vipBlack]} forState:UIControlStateSelected];
    [control addTarget:self action:@selector(appearanceControlChanged:) forControlEvents:UIControlEventValueChanged];
    return control;
}

- (TiktigerGlassRow *)rowWithTitle:(NSString *)title detail:(NSString *)detail control:(UIView *)control identifier:(NSString *)identifier {
    TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:title detail:detail systemImageName:@"slider.horizontal.3"];
    row.accessibilityIdentifier = identifier;
    row.accessibilityHint = @"Appearance setting is validated before it is applied.";
    if (control != nil) {
        control.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:control];
        [NSLayoutConstraint activateConstraints:@[
            [control.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-[TiktigerDesignTokens cardPadding]],
            [control.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [control.widthAnchor constraintLessThanOrEqualToConstant:[TiktigerDesignTokens rowHeight] * 3.0]
        ]];
    }
    return row;
}

- (void)refreshThemeControlsWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
    if (self.themeStack == nil) { return; }
    for (UIView *view in [self.themeStack.arrangedSubviews copy]) { [self.themeStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSDictionary *configuration = snapshot[@"configuration"] ?: @{};
    UISegmentedControl *theme = [self segmentedControlWithTitles:@[@"Tiger Black", @"OLED Black", @"Glass"] identifier:@"tiktiger.appearance.theme"];
    NSArray *themeKeys = @[@"tiger-black", @"oled-black", @"glass"];
    theme.selectedSegmentIndex = MAX(0, [themeKeys indexOfObject:configuration[@"theme"]] == NSNotFound ? 0 : (NSInteger)[themeKeys indexOfObject:configuration[@"theme"]]);
    UISegmentedControl *accent = [self segmentedControlWithTitles:@[@"Red", @"White"] identifier:@"tiktiger.appearance.accent"];
    accent.selectedSegmentIndex = [configuration[@"accent"] isEqualToString:@"white"] ? 1 : 0;
    [self.themeStack addArrangedSubview:[self rowWithTitle:@"Theme" detail:@"Black, OLED, or glass foundation" control:theme identifier:@"tiktiger.appearance.theme-row"]];
    [self.themeStack addArrangedSubview:[self rowWithTitle:@"Accent" detail:@"Red or neutral white" control:accent identifier:@"tiktiger.appearance.accent-row"]];
}

- (void)refreshAnimationControlsWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
    if (self.animationStack == nil) { return; }
    for (UIView *view in [self.animationStack.arrangedSubviews copy]) { [self.animationStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSDictionary *animation = [snapshot[@"configuration"][@"animation"] isKindOfClass:[NSDictionary class]] ? snapshot[@"configuration"][@"animation"] : @{};
    TiktigerGlassToggle *enabled = [[TiktigerGlassToggle alloc] initWithFrame:CGRectZero];
    enabled.on = [animation[@"enabled"] boolValue];
    enabled.accessibilityIdentifier = @"tiktiger.appearance.animation.enabled";
    enabled.accessibilityStateLabel = @"Animations";
    enabled.accessibilityValue = enabled.isOn ? @"On" : @"Off";
    [enabled addTarget:self action:@selector(appearanceControlChanged:) forControlEvents:UIControlEventValueChanged];
    UISlider *intensity = [[UISlider alloc] initWithFrame:CGRectZero];
    intensity.minimumValue = 0.0;
    intensity.maximumValue = 1.0;
    intensity.value = [animation[@"intensity"] floatValue];
    intensity.minimumTrackTintColor = [TiktigerDesignTokens vipRed];
    intensity.accessibilityIdentifier = @"tiktiger.appearance.animation.intensity";
    intensity.accessibilityLabel = @"Animation intensity";
    intensity.accessibilityValue = [NSString stringWithFormat:@"%.0f%%", intensity.value * 100.0];
    [intensity addTarget:self action:@selector(appearanceControlChanged:) forControlEvents:UIControlEventValueChanged];
    [self.animationStack addArrangedSubview:[self rowWithTitle:@"Animations" detail:@"Enabled unless Reduce Motion is active" control:enabled identifier:@"tiktiger.appearance.animation.enabled-row"]];
    [self.animationStack addArrangedSubview:[self rowWithTitle:@"Intensity" detail:@"Validated 0–100% range" control:intensity identifier:@"tiktiger.appearance.animation.intensity-row"]];
}

- (void)refreshCustomizationControlsWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
    if (self.customizationStack == nil) { return; }
    for (UIView *view in [self.customizationStack.arrangedSubviews copy]) { [self.customizationStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSDictionary *ui = [snapshot[@"configuration"][@"ui"] isKindOfClass:[NSDictionary class]] ? snapshot[@"configuration"][@"ui"] : @{};
    UISlider *blur = [[UISlider alloc] initWithFrame:CGRectZero];
    blur.minimumValue = 0.0; blur.maximumValue = 1.0; blur.value = [ui[@"blurLevel"] floatValue];
    blur.minimumTrackTintColor = [TiktigerDesignTokens vipRed]; blur.accessibilityIdentifier = @"tiktiger.appearance.ui.blurLevel"; blur.accessibilityLabel = @"Blur level"; blur.accessibilityValue = [NSString stringWithFormat:@"%.0f%%", blur.value * 100.0];
    [blur addTarget:self action:@selector(appearanceControlChanged:) forControlEvents:UIControlEventValueChanged];
    UISegmentedControl *style = [self segmentedControlWithTitles:@[@"Glass", @"Solid"] identifier:@"tiktiger.appearance.ui.cardStyle"];
    style.selectedSegmentIndex = [ui[@"cardStyle"] isEqualToString:@"solid"] ? 1 : 0;
    UISlider *radius = [[UISlider alloc] initWithFrame:CGRectZero];
    radius.minimumValue = 0.0; radius.maximumValue = 40.0; radius.value = [ui[@"cornerRadius"] floatValue];
    radius.minimumTrackTintColor = [TiktigerDesignTokens vipRed]; radius.accessibilityIdentifier = @"tiktiger.appearance.ui.cornerRadius"; radius.accessibilityLabel = @"Corner radius"; radius.accessibilityValue = [NSString stringWithFormat:@"%.0f points", radius.value];
    [radius addTarget:self action:@selector(appearanceControlChanged:) forControlEvents:UIControlEventValueChanged];
    TiktigerGlassToggle *glow = [[TiktigerGlassToggle alloc] initWithFrame:CGRectZero];
    glow.on = [ui[@"glow"] boolValue]; glow.accessibilityIdentifier = @"tiktiger.appearance.ui.glow"; glow.accessibilityStateLabel = @"Glow"; glow.accessibilityValue = glow.isOn ? @"On" : @"Off";
    [glow addTarget:self action:@selector(appearanceControlChanged:) forControlEvents:UIControlEventValueChanged];
    [self.customizationStack addArrangedSubview:[self rowWithTitle:@"Blur" detail:@"Glass intensity" control:blur identifier:@"tiktiger.appearance.ui.blur-row"]];
    [self.customizationStack addArrangedSubview:[self rowWithTitle:@"Card style" detail:@"Glass or solid surface" control:style identifier:@"tiktiger.appearance.ui.card-style-row"]];
    [self.customizationStack addArrangedSubview:[self rowWithTitle:@"Corner radius" detail:@"Validated 0–40 point range" control:radius identifier:@"tiktiger.appearance.ui.radius-row"]];
    [self.customizationStack addArrangedSubview:[self rowWithTitle:@"Glow" detail:@"Preview accent treatment" control:glow identifier:@"tiktiger.appearance.ui.glow-row"]];
}

- (void)refreshDiagnosticsWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
    if (self.diagnosticsStack == nil) { return; }
    for (UIView *view in [self.diagnosticsStack.arrangedSubviews copy]) { [self.diagnosticsStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSArray *rows = @[
        @[ @"Module status", snapshot[@"state"] ?: @"unknown", @"checkmark.shield", @"tiktiger.appearance.diagnostics.module" ],
        @[ @"Configuration", snapshot[@"configurationState"] ?: @"unknown", @"gearshape", @"tiktiger.appearance.diagnostics.configuration" ],
        @[ @"Preview", snapshot[@"previewState"] ?: @"unknown", @"rectangle.on.rectangle", @"tiktiger.appearance.diagnostics.preview" ],
        @[ @"Last action", snapshot[@"lastAction"] ?: @"unknown", @"clock.arrow.circlepath", @"tiktiger.appearance.diagnostics.last-action" ],
        @[ @"Errors", [NSString stringWithFormat:@"%@", snapshot[@"errorCount"] ?: @0], @"exclamationmark.triangle", @"tiktiger.appearance.diagnostics.errors" ]
    ];
    for (NSArray *definition in rows) {
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:definition[0] detail:definition[1] systemImageName:definition[2]];
        row.enabled = NO; row.accessibilityIdentifier = definition[3]; row.accessibilityValue = definition[1];
        [self.diagnosticsStack addArrangedSubview:row];
    }
}

- (void)appearanceControlChanged:(UIControl *)control {
    if (self.featureBinding == nil) { return; }
    NSString *identifier = control.accessibilityIdentifier ?: @"";
    NSString *key = @"";
    id value = nil;
    if ([identifier isEqualToString:@"tiktiger.appearance.theme"]) {
        NSArray *keys = @[@"tiger-black", @"oled-black", @"glass"]; key = @"theme"; value = keys[[(UISegmentedControl *)control selectedSegmentIndex]];
    } else if ([identifier isEqualToString:@"tiktiger.appearance.accent"]) {
        key = @"accent"; value = [(UISegmentedControl *)control selectedSegmentIndex] == 1 ? @"white" : @"red";
    } else if ([identifier isEqualToString:@"tiktiger.appearance.animation.enabled"]) {
        key = @"animation.enabled"; value = @([(UISwitch *)control isOn]);
    } else if ([identifier isEqualToString:@"tiktiger.appearance.animation.intensity"]) {
        key = @"animation.intensity"; value = @([(UISlider *)control value]);
    } else if ([identifier isEqualToString:@"tiktiger.appearance.ui.blurLevel"]) {
        key = @"ui.blurLevel"; value = @([(UISlider *)control value]);
    } else if ([identifier isEqualToString:@"tiktiger.appearance.ui.cardStyle"]) {
        key = @"ui.cardStyle"; value = [(UISegmentedControl *)control selectedSegmentIndex] == 1 ? @"solid" : @"glass";
    } else if ([identifier isEqualToString:@"tiktiger.appearance.ui.cornerRadius"]) {
        key = @"ui.cornerRadius"; value = @([(UISlider *)control value]);
    } else if ([identifier isEqualToString:@"tiktiger.appearance.ui.glow"]) {
        key = @"ui.glow"; value = @([(UISwitch *)control isOn]);
    }
    if (key.length == 0 || value == nil) { return; }
    NSError *error = nil;
    BOOL success = [self.featureBinding executeFeatureAction:@"updateAppearanceSetting" featureID:TiktigerAppearanceFeatureID payload:@{ @"key": key, @"value": value } error:&error];
    if (!success) {
        [self applyAppearancePresentation:self.lastSnapshot];
        [self showToastMessage:error.localizedDescription ?: @"Appearance setting was rejected safely."];
    } else {
        [self showToastMessage:@"Appearance configuration updated."];
    }
}

- (void)showToastMessage:(NSString *)message {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        NSString *copy = [message copy];
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf showToastMessage:copy]; });
        return;
    }
    [[TiktigerToast toastWithMessage:message state:TiktigerToastStateInfo] presentInView:self];
}

- (void)dealloc {
    [self.featureBinding unsubscribeFromModuleEvents:self.eventToken];
}

@end
