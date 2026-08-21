#import "TiktigerDiagnosticsCenterView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassCard.h"
#import "TiktigerGlassRow.h"

@interface TiktigerDiagnosticsCenterView ()
@property (nonatomic, weak) id<TiktigerFeatureBinding> binding;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) id eventToken;
@end

@implementation TiktigerDiagnosticsCenterView

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding>)binding {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _binding = binding;
        __weak typeof(self) weakSelf = self;
        _eventToken = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
            __strong typeof(weakSelf) self = weakSelf;
            if (self != nil) { [self refreshHealth]; }
        }];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [TiktigerDesignTokens vipBlack];
        _stack = [[UIStackView alloc] initWithFrame:CGRectZero];
        _stack.translatesAutoresizingMaskIntoConstraints = NO;
        _stack.axis = UILayoutConstraintAxisVertical;
        _stack.spacing = [TiktigerDesignTokens sectionGap];
        [self addSubview:_stack];
        CGFloat margin = [TiktigerDesignTokens screenMargin];
        [NSLayoutConstraint activateConstraints:@[
            [_stack.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:margin],
            [_stack.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-margin],
            [_stack.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:margin],
            [_stack.bottomAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-margin]
        ]];
        [self refreshHealth];
    }
    return self;
}

- (void)refreshHealth {
    for (UIView *view in [self.stack.arrangedSubviews copy]) { [self.stack removeArrangedSubview:view]; [view removeFromSuperview]; }
    TiktigerGlassCard *summary = [[TiktigerGlassCard alloc] initWithTitle:@"Diagnostics Center"];
    NSDictionary *health = [self.binding diagnosticsModuleHealth];
    NSUInteger failed = 0;
    for (NSDictionary *item in health.allValues) { if ([item[@"healthy"] respondsToSelector:@selector(boolValue)] && ![item[@"healthy"] boolValue]) { failed += 1; } }
    [summary setStatusMessage:[NSString stringWithFormat:@"%lu modules checked · %lu unhealthy", (unsigned long)health.count, (unsigned long)failed]];
    [_stack addArrangedSubview:summary];
    for (NSDictionary *item in health.allValues) {
        NSString *title = item[@"name"] ?: item[@"featureID"] ?: @"Module";
        NSString *detail = [NSString stringWithFormat:@"%@ · %@", item[@"state"] ?: @"unknown", [item[@"healthy"] boolValue] ? @"Healthy" : @"Needs attention"];
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:title detail:detail systemImageName:@"waveform.path.ecg"];
        row.showsDisclosure = YES;
        [row setActive:[item[@"healthy"] boolValue]];
        [_stack addArrangedSubview:row];
    }
}

- (void)dealloc {
    [self.binding unsubscribeFromModuleEvents:self.eventToken];
}

@end
