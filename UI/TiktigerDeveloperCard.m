#import "TiktigerDeveloperCard.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassCard.h"

@interface TiktigerDeveloperCard ()
@property (nonatomic, strong) UIView *photoPlaceholder;
@property (nonatomic, strong) UILabel *logoLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *telegramLabel;
@property (nonatomic, strong) UILabel *versionLabel;
@end

@implementation TiktigerDeveloperCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self buildView]; }
    return self;
}

- (void)buildView {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = [TiktigerDesignTokens vipSurface];
    self.layer.cornerRadius = [TiktigerDesignTokens cornerRadiusCard];
    self.layer.borderWidth = [TiktigerDesignTokens glassBorderWidth];
    self.layer.borderColor = [TiktigerDesignTokens vipGlassBorder].CGColor;
    self.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    self.isAccessibilityElement = NO;

    _photoPlaceholder = [[UIView alloc] initWithFrame:CGRectZero];
    _photoPlaceholder.translatesAutoresizingMaskIntoConstraints = NO;
    _photoPlaceholder.backgroundColor = [TiktigerDesignTokens vipSurfaceElevated];
    _photoPlaceholder.layer.cornerRadius = [TiktigerDesignTokens cornerRadiusBadge];
    _photoPlaceholder.isAccessibilityElement = YES;
    _photoPlaceholder.accessibilityLabel = @"Developer photo placeholder";
    [self addSubview:_photoPlaceholder];

    _logoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _logoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _logoLabel.text = @"T";
    _logoLabel.font = [TiktigerDesignTokens titleFont];
    _logoLabel.textColor = [TiktigerDesignTokens vipRed];
    _logoLabel.textAlignment = NSTextAlignmentCenter;
    _logoLabel.accessibilityTraits = UIAccessibilityTraitImage;
    [_photoPlaceholder addSubview:_logoLabel];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [TiktigerDesignTokens subtitleFont];
    _nameLabel.textColor = [TiktigerDesignTokens vipWhite];
    _nameLabel.adjustsFontForContentSizeCategory = YES;
    [_photoPlaceholder.superview addSubview:_nameLabel];

    _telegramLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _telegramLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _telegramLabel.font = [TiktigerDesignTokens developerFont];
    _telegramLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _telegramLabel.adjustsFontForContentSizeCategory = YES;
    [_photoPlaceholder.superview addSubview:_telegramLabel];

    _versionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _versionLabel.font = [TiktigerDesignTokens developerFont];
    _versionLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _versionLabel.adjustsFontForContentSizeCategory = YES;
    [_photoPlaceholder.superview addSubview:_versionLabel];

    CGFloat padding = [TiktigerDesignTokens cardPadding];
    [NSLayoutConstraint activateConstraints:@[
        [_photoPlaceholder.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
        [_photoPlaceholder.topAnchor constraintEqualToAnchor:self.topAnchor constant:padding],
        [_photoPlaceholder.widthAnchor constraintEqualToConstant:[TiktigerDesignTokens controlHeight]],
        [_photoPlaceholder.heightAnchor constraintEqualToAnchor:_photoPlaceholder.widthAnchor],
        [_logoLabel.centerXAnchor constraintEqualToAnchor:_photoPlaceholder.centerXAnchor],
        [_logoLabel.centerYAnchor constraintEqualToAnchor:_photoPlaceholder.centerYAnchor],
        [_nameLabel.leadingAnchor constraintEqualToAnchor:_photoPlaceholder.trailingAnchor constant:padding],
        [_nameLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding],
        [_nameLabel.topAnchor constraintEqualToAnchor:_photoPlaceholder.topAnchor],
        [_telegramLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_telegramLabel.trailingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor],
        [_telegramLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:padding / 3.0],
        [_versionLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_versionLabel.trailingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor],
        [_versionLabel.topAnchor constraintEqualToAnchor:_telegramLabel.bottomAnchor constant:padding / 3.0],
        [_versionLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-padding]
    ]];
    self.developerName = @"Developer";
    self.telegramHandle = @"Contact hidden until release policy is set";
    self.versionText = @"Tiktiger UI Foundation";
}

- (void)setDeveloperName:(NSString *)developerName { _developerName = [developerName copy]; self.nameLabel.text = developerName; }
- (void)setTelegramHandle:(NSString *)telegramHandle { _telegramHandle = [telegramHandle copy]; self.telegramLabel.text = telegramHandle; }
- (void)setVersionText:(NSString *)versionText { _versionText = [versionText copy]; self.versionLabel.text = versionText; }

@end
