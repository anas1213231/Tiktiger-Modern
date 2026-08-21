#import "TiktigerDownloadCenterView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassCard.h"
#import "TiktigerGlassRow.h"
#import "TiktigerGlassButton.h"
#import "TiktigerToast.h"
#import "TiktigerMotionSystem.h"

static NSString * const TiktigerDownloadFeatureID = @"media.download";

@interface TiktigerDownloadHistoryActionButton : TiktigerGlassButton
@property (nonatomic, copy) NSString *taskID;
@property (nonatomic, copy) NSString *actionName;
@end

@implementation TiktigerDownloadHistoryActionButton
@end

@interface TiktigerDownloadCenterView () <UISearchBarDelegate>
- (void)updateRecommendationWithSnapshot:(NSDictionary<NSString *, id> *)snapshot;
- (void)handleApplicationDidEnterBackground;
- (void)handleApplicationWillEnterForeground;
- (void)updateProgressOverlayWithSnapshot:(NSDictionary<NSString *, id> *)snapshot;
- (NSString *)humanReadableErrorFromSnapshot:(NSDictionary<NSString *, id> *)snapshot;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UILabel *currentItemLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *progressOverlayLabel;
@property (nonatomic, strong) UIActivityIndicatorView *downloadActivityIndicator;
@property (nonatomic, strong) UILabel *recommendationLabel;
@property (nonatomic, strong) TiktigerGlassButton *downloadButton;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIStackView *mediaStack;
@property (nonatomic, strong) UIStackView *queueStack;
@property (nonatomic, strong) UIStackView *historyStack;
@property (nonatomic, strong) UIStackView *settingsStack;
@property (nonatomic, strong) TiktigerGlassCard *downloadOptionsCard;
@property (nonatomic, strong) TiktigerGlassCard *progressCard;
@property (nonatomic, strong) TiktigerGlassCard *queueCard;
@property (nonatomic, strong) TiktigerGlassCard *historyCard;
@property (nonatomic, strong) TiktigerGlassCard *settingsCard;
@property (nonatomic, strong) TiktigerGlassCard *detailCard;
@property (nonatomic, strong) TiktigerGlassCard *storageCard;
@property (nonatomic, strong) UIStackView *detailStack;
@property (nonatomic, strong) UIStackView *storageStack;
@property (nonatomic, strong) UISegmentedControl *qualityControl;
@property (nonatomic, strong) UISearchBar *historySearchBar;
@property (nonatomic, strong) UISegmentedControl *historyFilterControl;
@property (nonatomic, copy) NSString *selectedQuality;
@property (nonatomic, copy) NSString *historyQuery;
@property (nonatomic, assign) NSInteger historyFilterIndex;
@property (nonatomic, strong) NSDate *lastTelemetryDate;
@property (nonatomic, assign) long long lastTelemetryBytes;
@property (nonatomic, assign) double lastObservedSpeed;
@property (nonatomic, assign) NSTimeInterval lastObservedRemaining;
@property (nonatomic, weak) id<TiktigerFeatureBinding> featureBinding;
@property (nonatomic, strong) id eventToken;
@property (nonatomic, strong) id backgroundObserver;
@property (nonatomic, strong) id foregroundObserver;
@property (nonatomic, copy) NSString *selectedMediaType;
@property (nonatomic, copy) NSString *lastPresentedErrorSignature;
@property (nonatomic, assign) BOOL isInBackground;
@property (nonatomic, copy) NSDictionary<NSString *, id> *lastSnapshot;
@end

@implementation TiktigerDownloadCenterView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self buildView]; }
    return self;
}

- (void)buildView {
    self.backgroundColor = [TiktigerDesignTokens vipBlack];
    self.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    self.accessibilityViewIsModal = NO;
    self.selectedMediaType = @"video";
    self.selectedQuality = @"Auto";
    self.historyQuery = @"";
    self.historyFilterIndex = 0;
    self.lastSnapshot = @{};
    self.lastPresentedErrorSignature = @"";
    self.isInBackground = NO;
    __weak typeof(self) weakSelf = self;
    self.backgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        (void)note;
        [weakSelf handleApplicationDidEnterBackground];
    }];
    self.foregroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        (void)note;
        [weakSelf handleApplicationWillEnterForeground];
    }];

    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.accessibilityIdentifier = @"tiktiger.download.scroll";
    [self addSubview:_scrollView];

    _contentStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    _contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStackView.axis = UILayoutConstraintAxisVertical;
    _contentStackView.alignment = UIStackViewAlignmentFill;
    _contentStackView.spacing = [TiktigerDesignTokens sectionGap];
    [_scrollView addSubview:_contentStackView];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = @"Download Center";
    _titleLabel.font = [TiktigerDesignTokens titleFont];
    _titleLabel.textColor = [TiktigerDesignTokens vipWhite];
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    _titleLabel.accessibilityIdentifier = @"tiktiger.download.title";

    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.text = @"Queue media through the Download Module contract.";
    _subtitleLabel.font = [TiktigerDesignTokens bodyFont];
    _subtitleLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _subtitleLabel.numberOfLines = 0;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;

    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _subtitleLabel]];
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    heading.axis = UILayoutConstraintAxisVertical;
    heading.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_contentStackView addArrangedSubview:heading];

    _downloadOptionsCard = [[TiktigerGlassCard alloc] initWithTitle:@"Smart Download Sheet"];
    _downloadOptionsCard.accessibilityIdentifier = @"tiktiger.download.media-options";
    [_downloadOptionsCard setElevated:YES];
    [_downloadOptionsCard setStatusMessage:@"Choose media and quality preferences before queueing an item."];
    _mediaStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _mediaStack.translatesAutoresizingMaskIntoConstraints = NO;
    _mediaStack.axis = UILayoutConstraintAxisVertical;
    _mediaStack.alignment = UIStackViewAlignmentFill;
    _mediaStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_downloadOptionsCard.contentView addSubview:_mediaStack];

    TiktigerGlassRow *videoRow = [self mediaRowWithTitle:@"Video" detail:@"Queue video media" icon:@"video" type:@"video"];
    TiktigerGlassRow *audioRow = [self mediaRowWithTitle:@"Audio" detail:@"Queue audio extraction request" icon:@"music.note" type:@"audio"];
    TiktigerGlassRow *imageRow = [self mediaRowWithTitle:@"Image" detail:@"Queue image media" icon:@"photo" type:@"image"];
    [_mediaStack addArrangedSubview:videoRow];
    [_mediaStack addArrangedSubview:audioRow];
    [_mediaStack addArrangedSubview:imageRow];

    UILabel *qualityLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    qualityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    qualityLabel.text = @"Quality preference";
    qualityLabel.font = [TiktigerDesignTokens statusFont];
    qualityLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    qualityLabel.adjustsFontForContentSizeCategory = YES;
    qualityLabel.accessibilityIdentifier = @"tiktiger.download.quality-label";
    [_downloadOptionsCard.contentView addSubview:qualityLabel];
    self.qualityControl = [[UISegmentedControl alloc] initWithItems:@[@"Auto", @"1080p", @"720p", @"Audio"]];
    self.qualityControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.qualityControl.selectedSegmentIndex = 0;
    self.qualityControl.tintColor = [TiktigerDesignTokens vipRed];
    self.qualityControl.accessibilityLabel = @"Quality preference";
    self.qualityControl.accessibilityIdentifier = @"tiktiger.download.quality-control";
    [self.qualityControl addTarget:self action:@selector(qualityChanged:) forControlEvents:UIControlEventValueChanged];
    [_downloadOptionsCard.contentView addSubview:self.qualityControl];
    self.recommendationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.recommendationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.recommendationLabel.font = [TiktigerDesignTokens statusFont];
    self.recommendationLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    self.recommendationLabel.numberOfLines = 0;
    self.recommendationLabel.adjustsFontForContentSizeCategory = YES;
    self.recommendationLabel.accessibilityIdentifier = @"tiktiger.download.recommendation";
    self.recommendationLabel.accessibilityLabel = @"Recommended download option";
    [_downloadOptionsCard.contentView addSubview:self.recommendationLabel];

    _downloadButton = [TiktigerGlassButton buttonWithTitle:@"Queue Video" redAccent:YES];
    _downloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    _downloadButton.accessibilityHint = @"Queue the selected media type through the Download Module.";
    _downloadButton.accessibilityIdentifier = @"tiktiger.download.queue-button";
    [_downloadButton addTarget:self action:@selector(downloadPressed:) forControlEvents:UIControlEventTouchUpInside];
    [_downloadOptionsCard.contentView addSubview:_downloadButton];
    self.downloadActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.downloadActivityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.downloadActivityIndicator.color = [TiktigerDesignTokens vipWhite];
    self.downloadActivityIndicator.hidesWhenStopped = YES;
    self.downloadActivityIndicator.accessibilityLabel = @"Download request in progress";
    self.downloadActivityIndicator.accessibilityIdentifier = @"tiktiger.download.button.loading";
    [_downloadButton addSubview:self.downloadActivityIndicator];

    _progressCard = [[TiktigerGlassCard alloc] initWithTitle:@"Current Operation"];
    _progressCard.accessibilityIdentifier = @"tiktiger.download.progress-card";
    [_progressCard setStatusMessage:@"No active download operation."];
    _stateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _stateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _stateLabel.font = [TiktigerDesignTokens statusFont];
    _stateLabel.textColor = [TiktigerDesignTokens vipWhite];
    _stateLabel.adjustsFontForContentSizeCategory = YES;
    _stateLabel.accessibilityIdentifier = @"tiktiger.download.state";
    _progressLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _progressLabel.font = [TiktigerDesignTokens numericFont];
    _progressLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _progressLabel.textAlignment = NSTextAlignmentNatural;
    _progressLabel.accessibilityIdentifier = @"tiktiger.download.progress-label";
    _currentItemLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _currentItemLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _currentItemLabel.font = [TiktigerDesignTokens bodyFont];
    _currentItemLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    _currentItemLabel.numberOfLines = 0;
    _currentItemLabel.adjustsFontForContentSizeCategory = YES;
    _currentItemLabel.accessibilityIdentifier = @"tiktiger.download.current-item";
    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _progressView.translatesAutoresizingMaskIntoConstraints = NO;
    _progressView.progressTintColor = [TiktigerDesignTokens vipRed];
    _progressView.trackTintColor = [TiktigerDesignTokens vipSurface];
    _progressView.accessibilityLabel = @"Download progress";
    self.progressOverlayLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.progressOverlayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressOverlayLabel.font = [TiktigerDesignTokens statusFont];
    self.progressOverlayLabel.textColor = [TiktigerDesignTokens vipWhiteSecondary];
    self.progressOverlayLabel.numberOfLines = 0;
    self.progressOverlayLabel.adjustsFontForContentSizeCategory = YES;
    self.progressOverlayLabel.accessibilityIdentifier = @"tiktiger.download.progress-overlay";
    self.progressOverlayLabel.accessibilityLabel = @"Download progress details";
    UIView *progressContent = _progressCard.contentView;
    [progressContent addSubview:_stateLabel];
    [progressContent addSubview:_progressLabel];
    [progressContent addSubview:_currentItemLabel];
    [progressContent addSubview:_progressView];
    [progressContent addSubview:self.progressOverlayLabel];

    _queueCard = [[TiktigerGlassCard alloc] initWithTitle:@"Queue"];
    _queueCard.accessibilityIdentifier = @"tiktiger.download.queue-card";
    _queueStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _queueStack.translatesAutoresizingMaskIntoConstraints = NO;
    _queueStack.axis = UILayoutConstraintAxisVertical;
    _queueStack.alignment = UIStackViewAlignmentFill;
    _queueStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_queueCard.contentView addSubview:_queueStack];

    _historyCard = [[TiktigerGlassCard alloc] initWithTitle:@"Advanced History"];
    _historyCard.accessibilityIdentifier = @"tiktiger.download.history-card";
    [_historyCard setStatusMessage:@"Search, filter, retry, open, or remove recorded items."];
    self.historySearchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.historySearchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.historySearchBar.delegate = self;
    self.historySearchBar.placeholder = @"Search downloads";
    self.historySearchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.historySearchBar.tintColor = [TiktigerDesignTokens vipRed];
    self.historySearchBar.accessibilityLabel = @"Search download history";
    self.historySearchBar.accessibilityIdentifier = @"tiktiger.download.history-search";
    [_historyCard.contentView addSubview:self.historySearchBar];
    self.historyFilterControl = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Completed", @"Failed"]];
    self.historyFilterControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.historyFilterControl.selectedSegmentIndex = 0;
    self.historyFilterControl.tintColor = [TiktigerDesignTokens vipRed];
    self.historyFilterControl.accessibilityLabel = @"History filter";
    self.historyFilterControl.accessibilityIdentifier = @"tiktiger.download.history-filter";
    [self.historyFilterControl addTarget:self action:@selector(historyFilterChanged:) forControlEvents:UIControlEventValueChanged];
    [_historyCard.contentView addSubview:self.historyFilterControl];
    _historyStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _historyStack.translatesAutoresizingMaskIntoConstraints = NO;
    _historyStack.axis = UILayoutConstraintAxisVertical;
    _historyStack.alignment = UIStackViewAlignmentFill;
    _historyStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_historyCard.contentView addSubview:_historyStack];

    _settingsCard = [[TiktigerGlassCard alloc] initWithTitle:@"Download Settings"];
    _settingsCard.accessibilityIdentifier = @"tiktiger.download.settings-card";
    _settingsStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _settingsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _settingsStack.axis = UILayoutConstraintAxisVertical;
    _settingsStack.alignment = UIStackViewAlignmentFill;
    _settingsStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_settingsCard.contentView addSubview:_settingsStack];

    _detailCard = [[TiktigerGlassCard alloc] initWithTitle:@"Download Details"];
    _detailCard.accessibilityIdentifier = @"tiktiger.download.detail-card";
    [_detailCard setStatusMessage:@"Detailed telemetry appears when a task is active."];
    _detailStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _detailStack.translatesAutoresizingMaskIntoConstraints = NO;
    _detailStack.axis = UILayoutConstraintAxisVertical;
    _detailStack.alignment = UIStackViewAlignmentFill;
    _detailStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_detailCard.contentView addSubview:_detailStack];

    _storageCard = [[TiktigerGlassCard alloc] initWithTitle:@"Storage Dashboard"];
    _storageCard.accessibilityIdentifier = @"tiktiger.download.storage-card";
    [_storageCard setStatusMessage:@"Storage usage is calculated from the active destination."];
    _storageStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _storageStack.translatesAutoresizingMaskIntoConstraints = NO;
    _storageStack.axis = UILayoutConstraintAxisVertical;
    _storageStack.alignment = UIStackViewAlignmentFill;
    _storageStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_storageCard.contentView addSubview:_storageStack];

    [_contentStackView addArrangedSubview:_downloadOptionsCard];
    [_contentStackView addArrangedSubview:_progressCard];
    [_contentStackView addArrangedSubview:_queueCard];
    [_contentStackView addArrangedSubview:_historyCard];
    [_contentStackView addArrangedSubview:_settingsCard];
    [_contentStackView addArrangedSubview:_detailCard];
    [_contentStackView addArrangedSubview:_storageCard];

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
        [_mediaStack.leadingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.leadingAnchor constant:padding],
        [_mediaStack.trailingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.trailingAnchor constant:-padding],
        [_mediaStack.topAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [qualityLabel.leadingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.leadingAnchor constant:padding],
        [qualityLabel.trailingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.trailingAnchor constant:-padding],
        [qualityLabel.topAnchor constraintEqualToAnchor:_mediaStack.bottomAnchor constant:[TiktigerDesignTokens sectionGap]],
        [self.qualityControl.leadingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.leadingAnchor constant:padding],
        [self.qualityControl.trailingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.trailingAnchor constant:-padding],
        [self.qualityControl.topAnchor constraintEqualToAnchor:qualityLabel.bottomAnchor constant:[TiktigerDesignTokens sectionGap] / 2.0],
        [self.qualityControl.heightAnchor constraintEqualToConstant:[TiktigerDesignTokens controlHeight]],
        [self.recommendationLabel.leadingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.leadingAnchor constant:padding],
        [self.recommendationLabel.trailingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.trailingAnchor constant:-padding],
        [self.recommendationLabel.topAnchor constraintEqualToAnchor:self.qualityControl.bottomAnchor constant:[TiktigerDesignTokens sectionGap] / 2.0],
        [_downloadButton.leadingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.leadingAnchor constant:padding],
        [_downloadButton.trailingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.trailingAnchor constant:-padding],
        [_downloadButton.topAnchor constraintEqualToAnchor:self.recommendationLabel.bottomAnchor constant:[TiktigerDesignTokens sectionGap]],
        [_downloadButton.heightAnchor constraintEqualToConstant:[TiktigerDesignTokens controlHeight]],
        [_downloadButton.bottomAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.bottomAnchor constant:-padding],
        [self.downloadActivityIndicator.trailingAnchor constraintEqualToAnchor:_downloadButton.trailingAnchor constant:-padding],
        [self.downloadActivityIndicator.centerYAnchor constraintEqualToAnchor:_downloadButton.centerYAnchor],
        [_stateLabel.leadingAnchor constraintEqualToAnchor:progressContent.leadingAnchor constant:padding],
        [_stateLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_progressLabel.leadingAnchor constant:-padding],
        [_stateLabel.topAnchor constraintEqualToAnchor:progressContent.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_progressLabel.trailingAnchor constraintEqualToAnchor:progressContent.trailingAnchor constant:-padding],
        [_progressLabel.centerYAnchor constraintEqualToAnchor:_stateLabel.centerYAnchor],
        [_currentItemLabel.leadingAnchor constraintEqualToAnchor:progressContent.leadingAnchor constant:padding],
        [_currentItemLabel.trailingAnchor constraintEqualToAnchor:progressContent.trailingAnchor constant:-padding],
        [_currentItemLabel.topAnchor constraintEqualToAnchor:_stateLabel.bottomAnchor constant:[TiktigerDesignTokens sectionGap] / 2.0],
        [_progressView.leadingAnchor constraintEqualToAnchor:progressContent.leadingAnchor constant:padding],
        [_progressView.trailingAnchor constraintEqualToAnchor:progressContent.trailingAnchor constant:-padding],
        [_progressView.topAnchor constraintEqualToAnchor:_currentItemLabel.bottomAnchor constant:[TiktigerDesignTokens sectionGap]],
        [self.progressOverlayLabel.leadingAnchor constraintEqualToAnchor:progressContent.leadingAnchor constant:padding],
        [self.progressOverlayLabel.trailingAnchor constraintEqualToAnchor:progressContent.trailingAnchor constant:-padding],
        [self.progressOverlayLabel.topAnchor constraintEqualToAnchor:_progressView.bottomAnchor constant:[TiktigerDesignTokens sectionGap] / 2.0],
        [self.progressOverlayLabel.bottomAnchor constraintEqualToAnchor:progressContent.bottomAnchor constant:-padding],
        [_queueStack.leadingAnchor constraintEqualToAnchor:_queueCard.contentView.leadingAnchor constant:padding],
        [_queueStack.trailingAnchor constraintEqualToAnchor:_queueCard.contentView.trailingAnchor constant:-padding],
        [_queueStack.topAnchor constraintEqualToAnchor:_queueCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_queueStack.bottomAnchor constraintEqualToAnchor:_queueCard.contentView.bottomAnchor constant:-padding],
        [self.historySearchBar.leadingAnchor constraintEqualToAnchor:_historyCard.contentView.leadingAnchor constant:padding],
        [self.historySearchBar.trailingAnchor constraintEqualToAnchor:_historyCard.contentView.trailingAnchor constant:-padding],
        [self.historySearchBar.topAnchor constraintEqualToAnchor:_historyCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [self.historySearchBar.heightAnchor constraintEqualToConstant:[TiktigerDesignTokens controlHeight]],
        [self.historyFilterControl.leadingAnchor constraintEqualToAnchor:_historyCard.contentView.leadingAnchor constant:padding],
        [self.historyFilterControl.trailingAnchor constraintEqualToAnchor:_historyCard.contentView.trailingAnchor constant:-padding],
        [self.historyFilterControl.topAnchor constraintEqualToAnchor:self.historySearchBar.bottomAnchor constant:[TiktigerDesignTokens sectionGap] / 2.0],
        [self.historyFilterControl.heightAnchor constraintEqualToConstant:[TiktigerDesignTokens controlHeight]],
        [_historyStack.leadingAnchor constraintEqualToAnchor:_historyCard.contentView.leadingAnchor constant:padding],
        [_historyStack.trailingAnchor constraintEqualToAnchor:_historyCard.contentView.trailingAnchor constant:-padding],
        [_historyStack.topAnchor constraintEqualToAnchor:self.historyFilterControl.bottomAnchor constant:[TiktigerDesignTokens sectionGap] / 2.0],
        [_historyStack.bottomAnchor constraintEqualToAnchor:_historyCard.contentView.bottomAnchor constant:-padding],
        [_settingsStack.leadingAnchor constraintEqualToAnchor:_settingsCard.contentView.leadingAnchor constant:padding],
        [_settingsStack.trailingAnchor constraintEqualToAnchor:_settingsCard.contentView.trailingAnchor constant:-padding],
        [_settingsStack.topAnchor constraintEqualToAnchor:_settingsCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_settingsStack.bottomAnchor constraintEqualToAnchor:_settingsCard.contentView.bottomAnchor constant:-padding],
        [_detailStack.leadingAnchor constraintEqualToAnchor:_detailCard.contentView.leadingAnchor constant:padding],
        [_detailStack.trailingAnchor constraintEqualToAnchor:_detailCard.contentView.trailingAnchor constant:-padding],
        [_detailStack.topAnchor constraintEqualToAnchor:_detailCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_detailStack.bottomAnchor constraintEqualToAnchor:_detailCard.contentView.bottomAnchor constant:-padding],
        [_storageStack.leadingAnchor constraintEqualToAnchor:_storageCard.contentView.leadingAnchor constant:padding],
        [_storageStack.trailingAnchor constraintEqualToAnchor:_storageCard.contentView.trailingAnchor constant:-padding],
        [_storageStack.topAnchor constraintEqualToAnchor:_storageCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_storageStack.bottomAnchor constraintEqualToAnchor:_storageCard.contentView.bottomAnchor constant:-padding]
    ]];

    self.presentationState = TiktigerDownloadPresentationStateIdle;
    [self refreshQueueAndHistoryWithSnapshot:self.lastSnapshot];
    [self refreshSettingsWithSnapshot:self.lastSnapshot];
    [self updateRecommendationWithSnapshot:self.lastSnapshot];
}

- (TiktigerGlassRow *)mediaRowWithTitle:(NSString *)title detail:(NSString *)detail icon:(NSString *)icon type:(NSString *)type {
    TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:title detail:detail systemImageName:icon];
    row.showsDisclosure = YES;
    row.accessibilityIdentifier = [NSString stringWithFormat:@"tiktiger.download.media.%@", type];
    row.accessibilityHint = @"Select this media type for the next queue intent.";
    row.tag = [@[@"video", @"audio", @"image"] indexOfObject:type];
    [row addTarget:self action:@selector(selectMediaType:) forControlEvents:UIControlEventTouchUpInside];
    [row setActive:[type isEqualToString:self.selectedMediaType]];
    return row;
}

- (void)setPresentationState:(TiktigerDownloadPresentationState)presentationState {
    TiktigerDownloadPresentationState previousState = _presentationState;
    _presentationState = presentationState;
    NSString *title = @"Queue Download";
    NSString *stateText = @"Idle";
    BOOL active = NO;
    BOOL canExecute = self.featureBinding != nil && !self.isInBackground;
    switch (presentationState) {
        case TiktigerDownloadPresentationStateIdle:
            title = @"Queue Download";
            stateText = @"Idle";
            break;
        case TiktigerDownloadPresentationStatePreparing:
            title = @"Preparing";
            stateText = @"Preparing";
            active = YES;
            canExecute = NO;
            break;
        case TiktigerDownloadPresentationStateDownloading:
            title = @"Downloading";
            stateText = @"Downloading";
            active = YES;
            canExecute = NO;
            break;
        case TiktigerDownloadPresentationStateProcessing:
            title = @"Processing";
            stateText = @"Processing";
            active = YES;
            canExecute = NO;
            break;
        case TiktigerDownloadPresentationStateCompleted:
            title = @"Queue Another";
            stateText = @"Completed";
            break;
        case TiktigerDownloadPresentationStateFailed:
            title = @"Retry Download";
            stateText = @"Failed";
            break;
    }
    [self.downloadButton setTitle:title forState:UIControlStateNormal];
    self.downloadButton.enabled = canExecute;
    self.downloadButton.accessibilityValue = self.isInBackground ? [NSString stringWithFormat:@"%@. View is backgrounded; the last verified snapshot is preserved.", stateText] : stateText;
    self.downloadButton.accessibilityHint = active ? @"Download is active. The button is disabled until the real operation reaches a terminal state." : (presentationState == TiktigerDownloadPresentationStateFailed ? @"Retry the failed download through the Download Module." : @"Queue the selected media through the Download Module.");
    if (active && ![TiktigerMotionSystem reduceMotionEnabled] && !self.isInBackground) {
        [self.downloadActivityIndicator startAnimating];
    } else {
        [self.downloadActivityIndicator stopAnimating];
    }
    self.stateLabel.text = stateText;
    self.stateLabel.accessibilityValue = self.downloadButton.accessibilityValue;
    [TiktigerMotionSystem applyGlowToView:self.downloadButton color:[TiktigerDesignTokens vipRed] active:active && !self.isInBackground];
    if (previousState != presentationState && self.progressCard != nil) {
        __weak typeof(self) weakSelf = self;
        [TiktigerMotionSystem animateViewWithSpring:self.progressCard animations:^{
            weakSelf.progressCard.alpha = 0.96;
        } completion:^(BOOL finished) {
            (void)finished;
            weakSelf.progressCard.alpha = 1.0;
        }];
    }
}

- (void)setProgress:(CGFloat)progress {
    _progress = MIN(MAX(progress, 0.0), 1.0);
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        CGFloat value = _progress;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf setProgress:value]; });
        return;
    }
    [TiktigerMotionSystem animateView:self.progressView duration:[TiktigerDesignTokens motionFast] animations:^{
        self.progressView.progress = self->_progress;
    } completion:nil];
    self.progressLabel.text = [NSString stringWithFormat:@"%0.f%%", self->_progress * 100.0];
    self.progressLabel.accessibilityValue = self.progressLabel.text;
}

- (void)updateRecommendationWithSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    if (self.recommendationLabel == nil) { return; }
    NSDictionary *currentItem = [snapshot[@"currentItem"] isKindOfClass:[NSDictionary class]] ? snapshot[@"currentItem"] : @{};
    NSDictionary *configuration = [snapshot[@"configuration"] isKindOfClass:[NSDictionary class]] ? snapshot[@"configuration"] : @{};
    NSString *detectedMedia = [currentItem[@"mediaType"] isKindOfClass:[NSString class]] && [currentItem[@"mediaType"] length] > 0 ? currentItem[@"mediaType"] : (self.selectedMediaType ?: @"video");
    NSString *quality = self.selectedQuality ?: ([configuration[@"quality"] isKindOfClass:[NSString class]] ? configuration[@"quality"] : @"Auto");
    NSString *destination = [configuration[@"destination"] isKindOfClass:[NSString class]] && [configuration[@"destination"] length] > 0 ? configuration[@"destination"] : @"files";
    NSString *state = [snapshot[@"state"] isKindOfClass:[NSString class]] ? snapshot[@"state"] : @"idle";
    NSString *prefix = [state isEqualToString:@"idle"] ? @"Recommended" : @"Detected media";
    self.recommendationLabel.text = [NSString stringWithFormat:@"%@ %@ · %@ · %@", prefix, detectedMedia.capitalizedString, quality, destination];
    self.recommendationLabel.accessibilityValue = self.recommendationLabel.text;
}

- (void)selectMediaType:(TiktigerGlassRow *)sender {
    NSArray<NSString *> *mediaTypes = @[@"video", @"audio", @"image"];
    if (sender.tag < 0 || sender.tag >= (NSInteger)mediaTypes.count) { return; }
    self.selectedMediaType = mediaTypes[(NSUInteger)sender.tag];
    for (UIView *view in self.mediaStack.arrangedSubviews) {
        if ([view isKindOfClass:[TiktigerGlassRow class]]) {
            TiktigerGlassRow *row = (TiktigerGlassRow *)view;
            [row setActive:row.tag == sender.tag];
        }
    }
    NSString *title = [self.selectedMediaType capitalizedString];
    [self.downloadButton setTitle:[NSString stringWithFormat:@"Queue %@", title] forState:UIControlStateNormal];
    self.downloadButton.accessibilityHint = [NSString stringWithFormat:@"Queue %@ media through the Download Module.", title];
    [self updateRecommendationWithSnapshot:self.lastSnapshot];
}

- (void)qualityChanged:(UISegmentedControl *)sender {
    NSArray<NSString *> *qualities = @[@"Auto", @"1080p", @"720p", @"Audio"];
    if (sender.selectedSegmentIndex < 0 || sender.selectedSegmentIndex >= (NSInteger)qualities.count) { return; }
    self.selectedQuality = qualities[(NSUInteger)sender.selectedSegmentIndex];
    self.qualityControl.accessibilityValue = self.selectedQuality;
    [self updateRecommendationWithSnapshot:self.lastSnapshot];
}

- (void)downloadPressed:(UIButton *)sender {
    (void)sender;
    if (self.featureBinding == nil) {
        [self showToastMessage:@"Download Module binding is unavailable." state:TiktigerToastStateError];
        return;
    }
    NSString *action = self.presentationState == TiktigerDownloadPresentationStateFailed ? @"retryDownload" : @"startDownload";
    NSDictionary *configuration = self.lastSnapshot[@"configuration"];
    NSString *destination = [configuration[@"destination"] isKindOfClass:[NSString class]] ? configuration[@"destination"] : @"files";
    NSError *error = nil;
    BOOL success = [self.featureBinding executeFeatureAction:action featureID:TiktigerDownloadFeatureID payload:@{ @"mediaType": self.selectedMediaType ?: @"video", @"quality": self.selectedQuality ?: @"Auto", @"destination": destination } error:&error];
    if (!success) {
        [self showToastMessage:error.localizedDescription ?: @"Download request was rejected." state:TiktigerToastStateError];
    } else {
        [self showToastMessage:@"Download intent queued." state:TiktigerToastStateInfo];
    }
}

- (void)setFeatureBinding:(id<TiktigerFeatureBinding>)binding {
    if (_featureBinding != nil) { [_featureBinding unsubscribeFromModuleEvents:self.eventToken]; }
    _featureBinding = binding;
    self.eventToken = nil;
    __weak typeof(self) weakSelf = self;
    self.eventToken = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self != nil && [event[@"featureID"] isEqual:TiktigerDownloadFeatureID]) {
            [self applyDownloadPresentation:event[@"download"] ?: [binding downloadPresentationState]];
        }
    }];
    if (binding != nil) {
        [self applyDownloadPresentation:[binding downloadPresentationState]];
    } else {
        [self applyDownloadPresentation:@{}];
    }
}

- (void)applyDownloadPresentation:(NSDictionary<NSString *,id> *)snapshot {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        NSDictionary *copy = [snapshot copy] ?: @{};
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf applyDownloadPresentation:copy]; });
        return;
    }
    self.lastSnapshot = [snapshot isKindOfClass:[NSDictionary class]] ? [snapshot copy] : @{};
    NSString *state = [self.lastSnapshot[@"state"] isKindOfClass:[NSString class]] ? self.lastSnapshot[@"state"] : @"idle";
    if ([state isEqualToString:@"preparing"]) {
        self.presentationState = TiktigerDownloadPresentationStatePreparing;
    } else if ([state isEqualToString:@"loading"]) {
        self.presentationState = TiktigerDownloadPresentationStateDownloading;
    } else if ([state isEqualToString:@"processing"]) {
        self.presentationState = TiktigerDownloadPresentationStateProcessing;
    } else if ([state isEqualToString:@"completed"]) {
        self.presentationState = TiktigerDownloadPresentationStateCompleted;
    } else if ([state isEqualToString:@"failed"]) {
        self.presentationState = TiktigerDownloadPresentationStateFailed;
    } else {
        self.presentationState = TiktigerDownloadPresentationStateIdle;
    }
    self.progress = [self.lastSnapshot[@"progress"] doubleValue];
    NSDictionary *currentItem = [self.lastSnapshot[@"currentItem"] isKindOfClass:[NSDictionary class]] ? self.lastSnapshot[@"currentItem"] : @{};
    NSString *mediaType = [currentItem[@"mediaType"] isKindOfClass:[NSString class]] ? currentItem[@"mediaType"] : @"";
    NSString *destination = [currentItem[@"destination"] isKindOfClass:[NSString class]] ? currentItem[@"destination"] : @"";
    self.currentItemLabel.text = mediaType.length > 0 ? [NSString stringWithFormat:@"Current: %@%@", mediaType, destination.length > 0 ? [NSString stringWithFormat:@" · %@", destination] : @""] : @"No active item.";
    self.currentItemLabel.accessibilityValue = self.currentItemLabel.text;
    [self refreshQueueAndHistoryWithSnapshot:self.lastSnapshot];
    [self refreshSettingsWithSnapshot:self.lastSnapshot];
    [self refreshDetailWithSnapshot:self.lastSnapshot];
    [self refreshStorageWithSnapshot:self.lastSnapshot];
    [self updateRecommendationWithSnapshot:self.lastSnapshot];
    [self updateProgressOverlayWithSnapshot:self.lastSnapshot];
    NSString *humanError = [self humanReadableErrorFromSnapshot:self.lastSnapshot];
    if ([state isEqualToString:@"failed"] && humanError.length > 0 && ![self.lastPresentedErrorSignature isEqualToString:humanError]) {
        self.lastPresentedErrorSignature = humanError;
        [self showToastMessage:humanError state:TiktigerToastStateError];
    } else if (![state isEqualToString:@"failed"]) {
        self.lastPresentedErrorSignature = @"";
    }
}

- (NSString *)humanReadableErrorFromSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    NSDictionary *lastError = [snapshot[@"lastError"] isKindOfClass:[NSDictionary class]] ? snapshot[@"lastError"] : @{};
    NSString *message = [lastError[@"message"] isKindOfClass:[NSString class]] ? lastError[@"message"] : ([lastError[@"localizedDescription"] isKindOfClass:[NSString class]] ? lastError[@"localizedDescription"] : @"");
    if (message.length == 0 && [snapshot[@"state"] isEqualToString:@"failed"]) { message = @"Download failed. Review the source and retry through the Download Module."; }
    return message;
}

- (void)updateProgressOverlayWithSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    if (self.progressOverlayLabel == nil) { return; }
    NSString *state = [snapshot[@"state"] isKindOfClass:[NSString class]] ? snapshot[@"state"] : @"idle";
    double progress = MIN(MAX([snapshot[@"progress"] doubleValue], 0.0), 1.0);
    NSString *progressText = [NSString stringWithFormat:@"%.0f%%", progress * 100.0];
    NSString *status = [state capitalizedString];
    NSString *detail = @"Select media and queue a verified source.";
    if ([state isEqualToString:@"preparing"] || [state isEqualToString:@"loading"] || [state isEqualToString:@"processing"]) {
        NSString *speedText = self.lastObservedSpeed > 0 ? [NSString stringWithFormat:@"%@/s", [self formattedBytes:(unsigned long long)self.lastObservedSpeed]] : @"Waiting for telemetry";
        detail = [NSString stringWithFormat:@"%@ · %@ · %@ remaining", progressText, speedText, [self formattedDuration:self.lastObservedRemaining]];
    } else if ([state isEqualToString:@"completed"]) {
        detail = @"Success · File is ready. Open or Share from history.";
    } else if ([state isEqualToString:@"failed"]) {
        detail = [NSString stringWithFormat:@"%@ · Retry is available.", [self humanReadableErrorFromSnapshot:snapshot]];
    }
    if (self.isInBackground) {
        detail = [NSString stringWithFormat:@"Backgrounded · Last verified snapshot preserved · %@", progressText];
    }
    self.progressOverlayLabel.text = [NSString stringWithFormat:@"%@ · %@", status, detail];
    self.progressOverlayLabel.accessibilityValue = self.progressOverlayLabel.text;
}

- (void)refreshQueueAndHistoryWithSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    if (self.queueStack == nil || self.historyStack == nil) { return; }
    for (UIView *view in [self.queueStack.arrangedSubviews copy]) {
        [self.queueStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    for (UIView *view in [self.historyStack.arrangedSubviews copy]) {
        [self.historyStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSDictionary *queue = [snapshot[@"queue"] isKindOfClass:[NSDictionary class]] ? snapshot[@"queue"] : @{};
    NSArray *items = [queue[@"items"] isKindOfClass:[NSArray class]] ? queue[@"items"] : @[];
    NSUInteger queued = [queue[@"queued"] unsignedIntegerValue];
    BOOL active = [queue[@"active"] boolValue];
    NSString *queueStatus = active ? [NSString stringWithFormat:@"%lu queued · active", (unsigned long)queued] : [NSString stringWithFormat:@"%lu queued", (unsigned long)queued];
    [self.queueCard setStatusMessage:queueStatus];
    for (NSDictionary *item in items) {
        NSString *mediaType = item[@"mediaType"] ?: @"media";
        NSString *state = item[@"state"] ?: @"queued";
        NSString *detail = [NSString stringWithFormat:@"%@ · %0.f%%", state, [item[@"progress"] doubleValue] * 100.0];
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:[mediaType capitalizedString] detail:detail systemImageName:@"arrow.down.circle"];
        row.enabled = NO;
        row.accessibilityIdentifier = [NSString stringWithFormat:@"tiktiger.download.queue.%@", item[@"id"] ?: @"item"];
        [self.queueStack addArrangedSubview:row];
    }
    if (items.count == 0) {
        TiktigerGlassRow *emptyRow = [[TiktigerGlassRow alloc] initWithTitle:@"Queue is empty" detail:@"Queued media will appear here." systemImageName:@"tray"];
        emptyRow.enabled = NO;
        [self.queueStack addArrangedSubview:emptyRow];
    }

    NSArray *history = [snapshot[@"history"] isKindOfClass:[NSArray class]] ? snapshot[@"history"] : @[];
    NSMutableArray *filteredHistory = [[NSMutableArray alloc] init];
    NSString *query = self.historyQuery.lowercaseString ?: @"";
    for (NSDictionary *item in history) {
        NSString *state = [item[@"state"] isKindOfClass:[NSString class]] ? item[@"state"] : @"unknown";
        BOOL matchesFilter = self.historyFilterIndex == 0 || (self.historyFilterIndex == 1 && [state isEqualToString:@"completed"]) || (self.historyFilterIndex == 2 && [state isEqualToString:@"failed"]);
        NSString *searchable = [[NSString stringWithFormat:@"%@ %@ %@ %@", item[@"mediaType"] ?: @"", state, item[@"destination"] ?: @"", item[@"destinationURL"] ?: @""] lowercaseString];
        if (matchesFilter && (query.length == 0 || [searchable containsString:query])) { [filteredHistory addObject:item]; }
    }
    [self.historyCard setStatusMessage:history.count > 0 ? [NSString stringWithFormat:@"%lu shown · %lu recorded", (unsigned long)filteredHistory.count, (unsigned long)history.count] : @"No completed or failed operations recorded."];
    for (NSDictionary *item in [filteredHistory reverseObjectEnumerator]) {
        NSString *mediaType = [item[@"mediaType"] isKindOfClass:[NSString class]] ? item[@"mediaType"] : @"media";
        NSString *state = [item[@"state"] isKindOfClass:[NSString class]] ? item[@"state"] : @"unknown";
        NSString *filename = [item[@"destinationURL"] isKindOfClass:[NSString class]] ? [item[@"destinationURL"] lastPathComponent] : @"No file path";
        NSString *detail = [NSString stringWithFormat:@"%@ · %@", state, filename.length > 0 ? filename : (item[@"destination"] ?: @"files")];
        BOOL completed = [state isEqualToString:@"completed"];
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:[mediaType capitalizedString] detail:detail systemImageName:completed ? @"checkmark.circle" : @"exclamationmark.triangle"];
        row.enabled = NO;
        row.accessibilityIdentifier = [NSString stringWithFormat:@"tiktiger.download.history.%@", item[@"id"] ?: @"item"];
        row.accessibilityValue = detail;
        [self.historyStack addArrangedSubview:row];

        UIStackView *actions = [[UIStackView alloc] initWithFrame:CGRectZero];
        actions.translatesAutoresizingMaskIntoConstraints = NO;
        actions.axis = UILayoutConstraintAxisHorizontal;
        actions.alignment = UIStackViewAlignmentFill;
        actions.distribution = UIStackViewDistributionFillEqually;
        actions.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
        if (completed) {
            [actions addArrangedSubview:[self historyActionButtonWithTitle:@"Open" action:@"open" taskID:item[@"id"]]];
            [actions addArrangedSubview:[self historyActionButtonWithTitle:@"Share" action:@"share" taskID:item[@"id"]]];
        } else {
            [actions addArrangedSubview:[self historyActionButtonWithTitle:@"Retry" action:@"retry" taskID:item[@"id"]]];
        }
        [actions addArrangedSubview:[self historyActionButtonWithTitle:@"Delete" action:@"delete" taskID:item[@"id"]]];
        [self.historyStack addArrangedSubview:actions];
        [actions.heightAnchor constraintEqualToConstant:[TiktigerDesignTokens controlHeight]].active = YES;
    }
    if (filteredHistory.count == 0) {
        NSString *emptyTitle = history.count == 0 ? @"No download history" : @"No matching history";
        NSString *emptyDetail = history.count == 0 ? @"Completed and failed operations appear here." : @"Try another search or filter.";
        TiktigerGlassRow *emptyRow = [[TiktigerGlassRow alloc] initWithTitle:emptyTitle detail:emptyDetail systemImageName:@"clock"];
        emptyRow.enabled = NO;
        [self.historyStack addArrangedSubview:emptyRow];
    }
}

- (TiktigerDownloadHistoryActionButton *)historyActionButtonWithTitle:(NSString *)title action:(NSString *)action taskID:(NSString *)taskID {
    TiktigerDownloadHistoryActionButton *button = [TiktigerDownloadHistoryActionButton buttonWithTitle:title redAccent:[action isEqualToString:@"delete"]];
    button.taskID = [taskID isKindOfClass:[NSString class]] ? taskID : @"";
    button.actionName = action;
    button.accessibilityIdentifier = [NSString stringWithFormat:@"tiktiger.download.history.%@.%@", action, button.taskID];
    button.accessibilityHint = [NSString stringWithFormat:@"%@ this history item.", title];
    button.accessibilityLabel = [NSString stringWithFormat:@"%@ %@ download", title, taskID ?: @"file"];
    button.enabled = self.featureBinding != nil;
    [button addTarget:self action:@selector(historyActionPressed:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)historyFilterChanged:(UISegmentedControl *)sender {
    self.historyFilterIndex = sender.selectedSegmentIndex;
    [self refreshQueueAndHistoryWithSnapshot:self.lastSnapshot];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.historyQuery = searchText ?: @"";
    [self refreshQueueAndHistoryWithSnapshot:self.lastSnapshot];
}

- (void)historyActionPressed:(TiktigerDownloadHistoryActionButton *)sender {
    if (self.featureBinding == nil || sender.taskID.length == 0) {
        [self showToastMessage:@"Download history binding is unavailable." state:TiktigerToastStateError];
        return;
    }
    NSError *error = nil;
    if ([sender.actionName isEqualToString:@"open"] || [sender.actionName isEqualToString:@"share"]) {
        NSURL *fileURL = [self.featureBinding downloadHistoryFileURLForID:sender.taskID error:&error];
        if (fileURL == nil) {
            [self showToastMessage:error.localizedDescription ?: @"The stored file is unavailable." state:TiktigerToastStateError];
        } else if ([sender.actionName isEqualToString:@"open"] && self.openFileHandler != nil) {
            self.openFileHandler(fileURL);
        } else if ([sender.actionName isEqualToString:@"share"] && self.shareFileHandler != nil) {
            self.shareFileHandler(fileURL);
        } else {
            [self showToastMessage:[sender.actionName isEqualToString:@"share"] ? @"A host share handler is required to share this file." : @"A host file handler is required to open this file." state:TiktigerToastStateInfo];
        }
        return;
    }
    NSString *action = [sender.actionName isEqualToString:@"delete"] ? @"deleteHistoryItem" : @"retryDownload";
    BOOL success = [self.featureBinding executeFeatureAction:action featureID:TiktigerDownloadFeatureID payload:@{ @"taskID": sender.taskID } error:&error];
    if (!success) {
        [self showToastMessage:error.localizedDescription ?: @"The history action was rejected." state:TiktigerToastStateError];
    } else {
        [self showToastMessage:[sender.actionName isEqualToString:@"delete"] ? @"History item deleted." : @"Retry intent queued." state:[sender.actionName isEqualToString:@"delete"] ? TiktigerToastStateSuccess : TiktigerToastStateInfo];
    }
}

- (void)refreshSettingsWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
    if (self.settingsStack == nil) { return; }
    for (UIView *view in [self.settingsStack.arrangedSubviews copy]) {
        [self.settingsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    NSDictionary *configuration = [snapshot[@"configuration"] isKindOfClass:[NSDictionary class]] ? snapshot[@"configuration"] : @{};
    NSString *quality = [configuration[@"quality"] isKindOfClass:[NSString class]] ? configuration[@"quality"] : @"Foundation default";
    NSString *destination = [configuration[@"destination"] isKindOfClass:[NSString class]] ? configuration[@"destination"] : @"files";
    NSString *queueLimit = configuration[@"queueLimit"] != nil ? [NSString stringWithFormat:@"%@", configuration[@"queueLimit"]] : @"5";
    NSArray *rows = @[
        @[ @"Default Quality", quality, @"dial.max" ],
        @[ @"Destination", destination, @"folder" ],
        @[ @"Queue Limit", queueLimit, @"list.number" ],
        @[ @"Engine", @"NSURLSession · binding ready", @"bolt.horizontal" ]
    ];
    [self.settingsCard setStatusMessage:@"Read-only foundation settings; updates will be exposed through binding contracts."];
    for (NSArray *definition in rows) {
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:definition[0] detail:definition[1] systemImageName:definition[2]];
        row.enabled = NO;
        [self.settingsStack addArrangedSubview:row];
    }
}

- (NSString *)formattedBytes:(unsigned long long)bytes {
    if (bytes < 1024) { return [NSString stringWithFormat:@"%llu B", bytes]; }
    if (bytes < 1024 * 1024) { return [NSString stringWithFormat:@"%.1f KB", (double)bytes / 1024.0]; }
    if (bytes < 1024 * 1024 * 1024) { return [NSString stringWithFormat:@"%.1f MB", (double)bytes / (1024.0 * 1024.0)]; }
    return [NSString stringWithFormat:@"%.1f GB", (double)bytes / (1024.0 * 1024.0 * 1024.0)];
}

- (NSString *)formattedDuration:(NSTimeInterval)seconds {
    if (seconds <= 0 || !isfinite(seconds)) { return @"—"; }
    NSInteger total = (NSInteger)ceil(seconds);
    NSInteger hours = total / 3600;
    NSInteger minutes = (total % 3600) / 60;
    NSInteger remaining = total % 60;
    if (hours > 0) { return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)remaining]; }
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)remaining];
}

- (TiktigerGlassRow *)informationRowWithTitle:(NSString *)title detail:(NSString *)detail icon:(NSString *)icon identifier:(NSString *)identifier {
    TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:title detail:detail systemImageName:icon];
    row.enabled = NO;
    row.accessibilityIdentifier = identifier;
    row.accessibilityValue = detail;
    return row;
}

- (void)refreshDetailWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
    if (self.detailStack == nil) { return; }
    for (UIView *view in [self.detailStack.arrangedSubviews copy]) {
        [self.detailStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    NSDictionary *item = [snapshot[@"currentItem"] isKindOfClass:[NSDictionary class]] ? snapshot[@"currentItem"] : @{};
    NSString *state = [item[@"state"] isKindOfClass:[NSString class]] ? item[@"state"] : ([snapshot[@"state"] isKindOfClass:[NSString class]] ? snapshot[@"state"] : @"idle");
    NSString *mediaType = [item[@"mediaType"] isKindOfClass:[NSString class]] ? item[@"mediaType"] : @"—";
    NSString *destination = [item[@"destination"] isKindOfClass:[NSString class]] ? item[@"destination"] : @"—";
    NSString *destinationPath = [item[@"destinationURL"] isKindOfClass:[NSString class]] ? item[@"destinationURL"] : @"—";
    unsigned long long bytes = [item[@"bytesWritten"] unsignedLongLongValue];
    unsigned long long totalBytes = [item[@"totalBytesExpected"] unsignedLongLongValue];
    NSDate *now = [NSDate date];
    NSTimeInterval elapsed = self.lastTelemetryDate != nil ? [now timeIntervalSinceDate:self.lastTelemetryDate] : 0;
    double speed = elapsed > 0.05 && bytes >= (unsigned long long)MAX(self.lastTelemetryBytes, 0) ? (double)(bytes - (unsigned long long)MAX(self.lastTelemetryBytes, 0)) / elapsed : 0;
    if (bytes > 0 || item.count > 0) {
        self.lastTelemetryDate = now;
        self.lastTelemetryBytes = (long long)bytes;
    }
    double progress = [snapshot[@"progress"] doubleValue];
    if (progress <= 0 && totalBytes > 0) { progress = (double)bytes / (double)totalBytes; }
    NSTimeInterval remaining = speed > 0 && totalBytes > bytes ? (double)(totalBytes - bytes) / speed : 0;
    self.lastObservedSpeed = speed;
    self.lastObservedRemaining = remaining;
    NSString *fileName = destinationPath.length > 0 && ![destinationPath isEqualToString:@"—"] ? destinationPath.lastPathComponent : @"No file assigned";
    BOOL active = ![state isEqualToString:@"idle"] && ![state isEqualToString:@"completed"] && ![state isEqualToString:@"failed"];
    [self.detailCard setStatusMessage:active ? @"Live task telemetry from the Download Engine." : ([state isEqualToString:@"completed"] ? @"The last task completed successfully." : ([state isEqualToString:@"failed"] ? @"The last task failed; recovery details remain available." : @"No active download task."))];
    NSArray *rows = @[
        @[ @"File", fileName, @"doc", @"tiktiger.download.detail.file" ],
        @[ @"Media", [mediaType capitalizedString], @"film", @"tiktiger.download.detail.media" ],
        @[ @"Status", [state capitalizedString], @"circle.fill", @"tiktiger.download.detail.status" ],
        @[ @"Progress", [NSString stringWithFormat:@"%.0f%% · %@ / %@", progress * 100.0, [self formattedBytes:bytes], [self formattedBytes:totalBytes]], @"chart.bar.fill", @"tiktiger.download.detail.progress" ],
        @[ @"Speed", speed > 0 ? [NSString stringWithFormat:@"%@/s", [self formattedBytes:(unsigned long long)speed]] : @"Waiting for telemetry", @"speedometer", @"tiktiger.download.detail.speed" ],
        @[ @"Remaining", [self formattedDuration:remaining], @"timer", @"tiktiger.download.detail.remaining" ],
        @[ @"Destination", destination.length > 0 ? destination : @"—", @"folder", @"tiktiger.download.detail.destination" ]
    ];
    for (NSArray *definition in rows) {
        [self.detailStack addArrangedSubview:[self informationRowWithTitle:definition[0] detail:definition[1] icon:definition[2] identifier:definition[3]]];
    }
}

- (unsigned long long)storageUsageAtPath:(NSString *)path {
    if (path.length == 0) { return 0; }
    unsigned long long total = 0;
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
    for (NSString *relativePath in enumerator) {
        NSString *fullPath = [path stringByAppendingPathComponent:relativePath];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
        total += [attributes[NSFileSize] unsignedLongLongValue];
    }
    return total;
}

- (void)refreshStorageWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
    if (self.storageStack == nil) { return; }
    for (UIView *view in [self.storageStack.arrangedSubviews copy]) {
        [self.storageStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    NSDictionary *engine = [snapshot[@"engine"] isKindOfClass:[NSDictionary class]] ? snapshot[@"engine"] : @{};
    NSDictionary *storage = [engine[@"storage"] isKindOfClass:[NSDictionary class]] ? engine[@"storage"] : @{};
    NSString *root = [storage[@"root"] isKindOfClass:[NSString class]] ? storage[@"root"] : @"Unavailable";
    NSUInteger fileCount = [storage[@"fileCount"] unsignedIntegerValue];
    unsigned long long usage = [self storageUsageAtPath:root];
    NSDictionary *filesystem = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    unsigned long long freeSpace = [filesystem[NSFileSystemFreeSize] unsignedLongLongValue];
    [self.storageCard setStatusMessage:[storage[@"exists"] boolValue] ? @"Storage is available for verified files." : @"Storage root will be created for the next verified file."];
    NSArray *rows = @[
        @[ @"Files", [NSString stringWithFormat:@"%lu", (unsigned long)fileCount], @"doc.on.doc", @"tiktiger.download.storage.files" ],
        @[ @"Usage", [self formattedBytes:usage], @"externaldrive", @"tiktiger.download.storage.usage" ],
        @[ @"Free space", [self formattedBytes:freeSpace], @"internaldrive", @"tiktiger.download.storage.free" ],
        @[ @"Root", root, @"folder", @"tiktiger.download.storage.root" ]
    ];
    for (NSArray *definition in rows) {
        [self.storageStack addArrangedSubview:[self informationRowWithTitle:definition[0] detail:definition[1] icon:definition[2] identifier:definition[3]]];
    }
}

- (void)handleApplicationDidEnterBackground {
    self.isInBackground = YES;
    [self.downloadActivityIndicator stopAnimating];
    [self setPresentationState:self.presentationState];
    [self updateProgressOverlayWithSnapshot:self.lastSnapshot];
}

- (void)handleApplicationWillEnterForeground {
    self.isInBackground = NO;
    [self applyDownloadPresentation:self.lastSnapshot ?: @{}];
}

- (void)prepareForReturnToContext {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf prepareForReturnToContext]; });
        return;
    }
    [self.downloadActivityIndicator stopAnimating];
    [self.progressCard setStatusMessage:@"Returning to host context. The last verified Download Module snapshot is preserved."];
    [self updateProgressOverlayWithSnapshot:self.lastSnapshot ?: @{}];
}

- (void)showToastMessage:(NSString *)message state:(NSInteger)state {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        NSString *copy = [message copy];
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf showToastMessage:copy state:state]; });
        return;
    }
    TiktigerToast *toast = [TiktigerToast toastWithMessage:message state:(TiktigerToastState)state];
    [toast presentInView:self];
}

- (void)dealloc {
    [self.featureBinding unsubscribeFromModuleEvents:self.eventToken];
    if (self.backgroundObserver != nil) { [[NSNotificationCenter defaultCenter] removeObserver:self.backgroundObserver]; }
    if (self.foregroundObserver != nil) { [[NSNotificationCenter defaultCenter] removeObserver:self.foregroundObserver]; }
}

@end
