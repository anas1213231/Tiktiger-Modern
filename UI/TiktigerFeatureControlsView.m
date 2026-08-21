#import "TiktigerFeatureControlsView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassRow.h"
#import "TiktigerGlassToggle.h"

@interface TiktigerFeatureControlsView ()
@property (nonatomic, weak) id<TiktigerFeatureBinding> binding;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) id eventToken;
@end

@implementation TiktigerFeatureControlsView

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding>)binding {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _binding = binding;
        __weak typeof(self) weakSelf = self;
        _eventToken = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
            __strong typeof(weakSelf) self = weakSelf;
            if (self != nil) { [self refreshControls]; }
        }];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [TiktigerDesignTokens vipBlack];
        _stack = [[UIStackView alloc] initWithFrame:CGRectZero];
        _stack.translatesAutoresizingMaskIntoConstraints = NO;
        _stack.axis = UILayoutConstraintAxisVertical;
        _stack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
        [self addSubview:_stack];
        CGFloat margin = [TiktigerDesignTokens screenMargin];
        [NSLayoutConstraint activateConstraints:@[
            [_stack.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:margin],
            [_stack.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-margin],
            [_stack.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:margin],
            [_stack.bottomAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-margin]
        ]];
        [self refreshControls];
    }
    return self;
}

- (void)refreshControls {
    for (UIView *view in [self.stack.arrangedSubviews copy]) { [self.stack removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSDictionary *groups = [self.binding settingsFeatureControls];
    [groups enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSArray<NSDictionary *> *controls, BOOL *stop) {
        UILabel *groupLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        groupLabel.translatesAutoresizingMaskIntoConstraints = NO;
        groupLabel.text = [key uppercaseString];
        groupLabel.font = [TiktigerDesignTokens statusFont];
        groupLabel.textColor = [TiktigerDesignTokens vipRed];
        groupLabel.adjustsFontForContentSizeCategory = YES;
        [self.stack addArrangedSubview:groupLabel];
        for (NSDictionary *control in controls) {
            NSString *title = control[@"title"] ?: @"Feature";
            TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:title detail:@"Feature control" systemImageName:@"slider.horizontal.3"];
            BOOL toggleControl = [control[@"control"] isEqual:@"toggle"];
            row.showsDisclosure = !toggleControl;
            if (toggleControl) {
                TiktigerGlassToggle *toggle = [[TiktigerGlassToggle alloc] initWithFrame:CGRectZero];
                toggle.accessibilityStateLabel = title;
                toggle.accessibilityIdentifier = control[@"id"];
                NSString *preferenceKey = control[@"key"] ?: @"";
                NSDictionary *preferenceConfiguration = [self.binding preferencesPresentation][@"configuration"] ?: @{};
                NSDictionary *section = [control[@"id"] containsString:@"animation"] ? preferenceConfiguration[@"animation"] : preferenceConfiguration[@"features"];
                toggle.on = [section[preferenceKey] boolValue];
                [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
                [row addSubview:toggle];
                [NSLayoutConstraint activateConstraints:@[
                    [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-[TiktigerDesignTokens cardPadding]],
                    [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
                ]];
            }
            [self.stack addArrangedSubview:row];
        }
    }];
}

- (void)toggleChanged:(TiktigerGlassToggle *)toggle {
    NSError *error = nil;
    NSString *controlID = toggle.accessibilityIdentifier ?: @"";
    NSString *key = [controlID containsString:@"animation"] ? @"glow" : @"haptics";
    BOOL success = [self.binding executeFeatureAction:@"updateConfiguration" featureID:@"user.preferences" payload:@{ @"controlID": controlID, @"key": key, @"value": @(toggle.isOn) } error:&error];
    if (!success) { [toggle setOn:!toggle.isOn animated:NO]; }
    toggle.accessibilityValue = success ? (toggle.isOn ? @"On" : @"Off") : @"Update failed";
}

- (void)dealloc {
    [self.binding unsubscribeFromModuleEvents:self.eventToken];
}

@end
