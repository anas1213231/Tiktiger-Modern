#import "TiktigerFeatureStatusCard.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassRow.h"

@interface TiktigerFeatureStatusCard ()
@property (nonatomic, weak) id<TiktigerFeatureBinding> binding;
@property (nonatomic, strong) UIStackView *moduleStack;
@end

@implementation TiktigerFeatureStatusCard

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding>)binding {
    self = [super initWithTitle:@"Feature Modules"];
    if (self) {
        _binding = binding;
        _moduleStack = [[UIStackView alloc] initWithFrame:CGRectZero];
        _moduleStack.translatesAutoresizingMaskIntoConstraints = NO;
        _moduleStack.axis = UILayoutConstraintAxisVertical;
        _moduleStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
        [self.contentView addSubview:_moduleStack];
        CGFloat padding = [TiktigerDesignTokens cardPadding];
        [NSLayoutConstraint activateConstraints:@[
            [_moduleStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
            [_moduleStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
            [_moduleStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
            [_moduleStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-padding]
        ]];
        [self refreshFromBinding];
    }
    return self;
}

- (void)refreshFromBinding {
    for (UIView *view in [self.moduleStack.arrangedSubviews copy]) { [self.moduleStack removeArrangedSubview:view]; [view removeFromSuperview]; }
    for (NSDictionary *card in [self.binding dashboardFeatureCards]) {
        NSString *title = card[@"title"] ?: @"Feature";
        NSString *detail = [NSString stringWithFormat:@"%@ · %@", card[@"state"] ?: @"unknown", card[@"version"] ?: @"—"];
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:title detail:detail systemImageName:@"circle.grid.2x2"];
        row.showsDisclosure = YES;
        [row setActive:[card[@"state"] isEqual:@"enabled"]];
        [self.moduleStack addArrangedSubview:row];
    }
    if (self.moduleStack.arrangedSubviews.count == 0) { [self setStatusMessage:@"No feature modules registered."]; }
}

@end
