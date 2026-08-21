#import "TiktigerSettingsView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassRow.h"
#import "TiktigerGlassToggle.h"
#import "TiktigerFeatureControlsView.h"

@interface TiktigerSettingsView ()
@property (nonatomic, strong, readwrite) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) TiktigerFeatureControlsView *featureControlsView;
@property (nonatomic, weak) id<TiktigerFeatureBinding> featureBinding;
@property (nonatomic, strong) id eventToken;
@end

@implementation TiktigerSettingsView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self buildView]; }
    return self;
}

- (void)setFeatureBinding:(id<TiktigerFeatureBinding>)binding {
    if (_featureBinding != nil) { [_featureBinding unsubscribeFromModuleEvents:self.eventToken]; }
    _featureBinding = binding;
    __weak typeof(self) weakSelf = self;
    self.eventToken = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self != nil) { dispatch_async(dispatch_get_main_queue(), ^{ [self.featureControlsView refreshControls]; }); }
    }];
    if (self.featureControlsView != nil) {
        [self.contentStack removeArrangedSubview:self.featureControlsView];
        [self.featureControlsView removeFromSuperview];
    }
    if (binding != nil) {
        self.featureControlsView = [[TiktigerFeatureControlsView alloc] initWithBinding:binding];
        [self.contentStack addArrangedSubview:self.featureControlsView];
    }
}

- (void)preferenceToggleChanged:(TiktigerGlassToggle *)toggle {
    NSString *rowTitle = toggle.accessibilityIdentifier ?: @"";
    NSString *controlID = @"user.preferences.features";
    NSString *key = @"haptics";
    if ([rowTitle isEqualToString:@"Reduce Motion"]) { controlID = @"user.preferences.animation"; key = @"reduceMotion"; }
    else if ([rowTitle isEqualToString:@"Glass intensity"]) { controlID = @"user.preferences.interface"; key = @"glassIntensity"; }
    else if ([rowTitle isEqualToString:@"Retention"]) { key = @"retention"; }
    NSError *error = nil;
    BOOL success = [self.featureBinding executeFeatureAction:@"updateConfiguration" featureID:@"user.preferences" payload:@{ @"controlID": controlID, @"key": key, @"value": @(toggle.isOn) } error:&error];
    if (!success) { [toggle setOn:!toggle.isOn animated:NO]; }
}

- (void)buildView {
    self.backgroundColor = [TiktigerDesignTokens vipBlack];
    self.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.accessibilityLabel = @"Tiktiger settings";
    [self addSubview:_scrollView];
    _contentStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = [TiktigerDesignTokens sectionGap];
    [_scrollView addSubview:_contentStack];

    NSArray<NSString *> *groups = @[@"GENERAL", @"DOWNLOAD", @"PRIVACY", @"INTERFACE", @"ADVANCED", @"ABOUT"];
    NSArray<NSArray<NSString *> *> *rows = @[
        @[@"Language", @"Haptics"],
        @[@"Default quality", @"Destination"],
        @[@"Permissions", @"Retention"],
        @[@"Reduce Motion", @"Glass intensity"],
        @[@"Configuration status", @"Diagnostics"],
        @[@"Version", @"Support"]
    ];
    for (NSUInteger index = 0; index < groups.count; index++) {
        UILabel *groupLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        groupLabel.translatesAutoresizingMaskIntoConstraints = NO;
        groupLabel.text = groups[index];
        groupLabel.font = [TiktigerDesignTokens statusFont];
        groupLabel.textColor = [TiktigerDesignTokens vipRed];
        groupLabel.adjustsFontForContentSizeCategory = YES;
        [_contentStack addArrangedSubview:groupLabel];
        for (NSString *rowTitle in rows[index]) {
            TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:rowTitle detail:@"Tiktiger preference" systemImageName:@"slider.horizontal.3"];
            BOOL usesToggle = [rowTitle isEqualToString:@"Haptics"] || [rowTitle isEqualToString:@"Retention"] || [rowTitle isEqualToString:@"Reduce Motion"] || [rowTitle isEqualToString:@"Glass intensity"];
            row.showsDisclosure = !usesToggle;
            if (usesToggle) {
                TiktigerGlassToggle *toggle = [[TiktigerGlassToggle alloc] initWithFrame:CGRectZero];
                toggle.accessibilityStateLabel = rowTitle;
                toggle.accessibilityIdentifier = rowTitle;
                [toggle addTarget:self action:@selector(preferenceToggleChanged:) forControlEvents:UIControlEventValueChanged];
                toggle.on = [rowTitle isEqualToString:@"Haptics"];
                [row addSubview:toggle];
                CGFloat trailing = [TiktigerDesignTokens cardPadding];
                [NSLayoutConstraint activateConstraints:@[
                    [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-trailing],
                    [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
                ]];
                row.accessibilityHint = @"Toggle setting";
            }
            [_contentStack addArrangedSubview:row];
        }
    }
    CGFloat margin = [TiktigerDesignTokens screenMargin];
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_scrollView.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_contentStack.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor constant:margin],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor constant:-margin],
        [_contentStack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor constant:margin],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor constant:-margin],
        [_contentStack.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor constant:-2.0 * margin]
    ]];
}

- (void)dealloc {
    [self.featureBinding unsubscribeFromModuleEvents:self.eventToken];
}

@end
