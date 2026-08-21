#import "TiktigerDownloadCenterView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassCard.h"
#import "TiktigerGlassRow.h"
#import "TiktigerGlassButton.h"
#import "TiktigerToast.h"
#import "TiktigerMotionSystem.h"

static NSString * const TiktigerDownloadFeatureID = @"media.download";

@interface TiktigerDownloadCenterView ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UILabel *currentItemLabel;
@property (nonatomic, strong) UIProgressView *progressView;
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
@property (nonatomic, weak) id<TiktigerFeatureBinding> featureBinding;
@property (nonatomic, strong) id eventToken;
@property (nonatomic, copy) NSString *selectedMediaType;
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
    self.lastSnapshot = @{};

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

    _downloadOptionsCard = [[TiktigerGlassCard alloc] initWithTitle:@"Media Options"];
    _downloadOptionsCard.accessibilityIdentifier = @"tiktiger.download.media-options";
    [_downloadOptionsCard setStatusMessage:@"Choose a media type before queueing an item."];
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

    _downloadButton = [TiktigerGlassButton buttonWithTitle:@"Queue Video" redAccent:YES];
    _downloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    _downloadButton.accessibilityHint = @"Queue the selected media type through the Download Module.";
    _downloadButton.accessibilityIdentifier = @"tiktiger.download.queue-button";
    [_downloadButton addTarget:self action:@selector(downloadPressed:) forControlEvents:UIControlEventTouchUpInside];
    [_downloadOptionsCard.contentView addSubview:_downloadButton];

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
    UIView *progressContent = _progressCard.contentView;
    [progressContent addSubview:_stateLabel];
    [progressContent addSubview:_progressLabel];
    [progressContent addSubview:_currentItemLabel];
    [progressContent addSubview:_progressView];

    _queueCard = [[TiktigerGlassCard alloc] initWithTitle:@"Queue"];
    _queueCard.accessibilityIdentifier = @"tiktiger.download.queue-card";
    _queueStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _queueStack.translatesAutoresizingMaskIntoConstraints = NO;
    _queueStack.axis = UILayoutConstraintAxisVertical;
    _queueStack.alignment = UIStackViewAlignmentFill;
    _queueStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_queueCard.contentView addSubview:_queueStack];

    _historyCard = [[TiktigerGlassCard alloc] initWithTitle:@"History"];
    _historyCard.accessibilityIdentifier = @"tiktiger.download.history-card";
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

    [_contentStackView addArrangedSubview:_downloadOptionsCard];
    [_contentStackView addArrangedSubview:_progressCard];
    [_contentStackView addArrangedSubview:_queueCard];
    [_contentStackView addArrangedSubview:_historyCard];
    [_contentStackView addArrangedSubview:_settingsCard];

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
        [_downloadButton.leadingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.leadingAnchor constant:padding],
        [_downloadButton.trailingAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.trailingAnchor constant:-padding],
        [_downloadButton.topAnchor constraintEqualToAnchor:_mediaStack.bottomAnchor constant:[TiktigerDesignTokens sectionGap]],
        [_downloadButton.heightAnchor constraintEqualToConstant:[TiktigerDesignTokens controlHeight]],
        [_downloadButton.bottomAnchor constraintEqualToAnchor:_downloadOptionsCard.contentView.bottomAnchor constant:-padding],
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
        [_progressView.bottomAnchor constraintEqualToAnchor:progressContent.bottomAnchor constant:-padding],
        [_queueStack.leadingAnchor constraintEqualToAnchor:_queueCard.contentView.leadingAnchor constant:padding],
        [_queueStack.trailingAnchor constraintEqualToAnchor:_queueCard.contentView.trailingAnchor constant:-padding],
        [_queueStack.topAnchor constraintEqualToAnchor:_queueCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_queueStack.bottomAnchor constraintEqualToAnchor:_queueCard.contentView.bottomAnchor constant:-padding],
        [_historyStack.leadingAnchor constraintEqualToAnchor:_historyCard.contentView.leadingAnchor constant:padding],
        [_historyStack.trailingAnchor constraintEqualToAnchor:_historyCard.contentView.trailingAnchor constant:-padding],
        [_historyStack.topAnchor constraintEqualToAnchor:_historyCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_historyStack.bottomAnchor constraintEqualToAnchor:_historyCard.contentView.bottomAnchor constant:-padding],
        [_settingsStack.leadingAnchor constraintEqualToAnchor:_settingsCard.contentView.leadingAnchor constant:padding],
        [_settingsStack.trailingAnchor constraintEqualToAnchor:_settingsCard.contentView.trailingAnchor constant:-padding],
        [_settingsStack.topAnchor constraintEqualToAnchor:_settingsCard.contentView.topAnchor constant:padding + [TiktigerDesignTokens controlHeight]],
        [_settingsStack.bottomAnchor constraintEqualToAnchor:_settingsCard.contentView.bottomAnchor constant:-padding]
    ]];

    self.presentationState = TiktigerDownloadPresentationStateIdle;
    [self refreshQueueAndHistoryWithSnapshot:self.lastSnapshot];
    [self refreshSettingsWithSnapshot:self.lastSnapshot];
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
    _presentationState = presentationState;
    NSString *title = @"Queue Download";
    NSString *stateText = @"Idle";
    BOOL active = NO;
    BOOL canExecute = self.featureBinding != nil;
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
    self.downloadButton.accessibilityValue = stateText;
    self.stateLabel.text = stateText;
    self.stateLabel.accessibilityValue = stateText;
    [TiktigerMotionSystem applyGlowToView:self.downloadButton color:[TiktigerDesignTokens vipRed] active:active];
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
    BOOL success = [self.featureBinding executeFeatureAction:action featureID:TiktigerDownloadFeatureID payload:@{ @"mediaType": self.selectedMediaType ?: @"video", @"destination": destination } error:&error];
    if (!success) {
        [self showToastMessage:error.localizedDescription ?: @"Download request was rejected." state:TiktigerToastStateError];
    } else {
        [self showToastMessage:@"Download intent queued." state:TiktigerToastStateInfo];
    }
}

- (void)setFeatureBinding:(id<TiktigerFeatureBinding>)binding {
    if (_featureBinding != nil) { [_featureBinding unsubscribeFromModuleEvents:self.eventToken]; }
    _featureBinding = binding;
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
    NSDictionary *lastError = self.lastSnapshot[@"lastError"];
    if ([state isEqualToString:@"failed"] && [lastError[@"message"] length] > 0) {
        [self showToastMessage:lastError[@"message"] state:TiktigerToastStateError];
    }
}

- (void)refreshQueueAndHistoryWithSnapshot:(NSDictionary<NSString *,id> *)snapshot {
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
    [self.historyCard setStatusMessage:history.count > 0 ? [NSString stringWithFormat:@"%lu recorded operation(s)", (unsigned long)history.count] : @"No completed or failed operations recorded."];
    for (NSDictionary *item in [history reverseObjectEnumerator]) {
        NSString *mediaType = item[@"mediaType"] ?: @"media";
        NSString *state = item[@"state"] ?: @"unknown";
        NSString *detail = [NSString stringWithFormat:@"%@ · %@", state, item[@"destination"] ?: @"files"];
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:[mediaType capitalizedString] detail:detail systemImageName:[state isEqualToString:@"completed"] ? @"checkmark.circle" : @"exclamationmark.triangle"];
        row.enabled = NO;
        [self.historyStack addArrangedSubview:row];
    }
    if (history.count == 0) {
        TiktigerGlassRow *emptyRow = [[TiktigerGlassRow alloc] initWithTitle:@"No download history" detail:@"Completed and failed operations appear here." systemImageName:@"clock"];
        emptyRow.enabled = NO;
        [self.historyStack addArrangedSubview:emptyRow];
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
        @[ @"Engine", @"Foundation-only · no network engine", @"bolt.horizontal" ]
    ];
    [self.settingsCard setStatusMessage:@"Read-only foundation settings; updates will be exposed through binding contracts."];
    for (NSArray *definition in rows) {
        TiktigerGlassRow *row = [[TiktigerGlassRow alloc] initWithTitle:definition[0] detail:definition[1] systemImageName:definition[2]];
        row.enabled = NO;
        [self.settingsStack addArrangedSubview:row];
    }
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
}

@end
