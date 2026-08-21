#import "TiktigerDownloadCenterView.h"
#import "TiktigerDesignTokens.h"
#import "TiktigerGlassCard.h"
#import "TiktigerGlassRow.h"
#import "TiktigerGlassButton.h"
#import "TiktigerToast.h"
#import "TiktigerMotionSystem.h"

@interface TiktigerDownloadCenterView ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIStackView *mediaStack;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) TiktigerGlassButton *downloadButton;
@property (nonatomic, strong) TiktigerGlassCard *queueCard;
@property (nonatomic, strong) UIView *bottomSheet;
@property (nonatomic, weak) id<TiktigerFeatureBinding> featureBinding;
@property (nonatomic, strong) id eventToken;
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

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = @"Download Center";
    _titleLabel.font = [TiktigerDesignTokens titleFont];
    _titleLabel.textColor = [TiktigerDesignTokens vipWhite];
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    [self addSubview:_titleLabel];

    _bottomSheet = [[UIView alloc] initWithFrame:CGRectZero];
    _bottomSheet.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomSheet.backgroundColor = [TiktigerDesignTokens vipSurfaceElevated];
    _bottomSheet.layer.cornerRadius = [TiktigerDesignTokens cornerRadiusCard];
    _bottomSheet.layer.borderWidth = [TiktigerDesignTokens glassBorderWidth];
    _bottomSheet.layer.borderColor = [TiktigerDesignTokens vipGlassBorder].CGColor;
    [self addSubview:_bottomSheet];

    TiktigerGlassRow *videoRow = [[TiktigerGlassRow alloc] initWithTitle:@"Video" detail:@"Save video media" systemImageName:@"video"];
    TiktigerGlassRow *audioRow = [[TiktigerGlassRow alloc] initWithTitle:@"Audio" detail:@"Save audio only" systemImageName:@"music.note"];
    TiktigerGlassRow *imageRow = [[TiktigerGlassRow alloc] initWithTitle:@"Image" detail:@"Save image media" systemImageName:@"photo"];
    videoRow.showsDisclosure = YES;
    audioRow.showsDisclosure = YES;
    imageRow.showsDisclosure = YES;
    _mediaStack = [[UIStackView alloc] initWithArrangedSubviews:@[videoRow, audioRow, imageRow]];
    _mediaStack.translatesAutoresizingMaskIntoConstraints = NO;
    _mediaStack.axis = UILayoutConstraintAxisVertical;
    _mediaStack.spacing = [TiktigerDesignTokens sectionGap] / 2.0;
    [_bottomSheet addSubview:_mediaStack];

    _downloadButton = [TiktigerGlassButton buttonWithTitle:@"Download" redAccent:YES];
    [_downloadButton addTarget:self action:@selector(downloadPressed:) forControlEvents:UIControlEventTouchUpInside];
    _downloadButton.accessibilityHint = @"Start the selected download presentation";
    [_bottomSheet addSubview:_downloadButton];

    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _progressView.translatesAutoresizingMaskIntoConstraints = NO;
    _progressView.progressTintColor = [TiktigerDesignTokens vipRed];
    _progressView.trackTintColor = [TiktigerDesignTokens vipSurface];
    _progressView.progress = 0.0;
    _progressView.accessibilityLabel = @"Download progress";
    [_bottomSheet addSubview:_progressView];

    _queueCard = [[TiktigerGlassCard alloc] initWithTitle:@"Queue"];
    [_queueCard setStatusMessage:@"No downloads in the queue."];
    [self addSubview:_queueCard];

    CGFloat margin = [TiktigerDesignTokens screenMargin];
    CGFloat padding = [TiktigerDesignTokens cardPadding];
    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:margin],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-margin],
        [_titleLabel.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:margin],
        [_bottomSheet.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:margin],
        [_bottomSheet.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-margin],
        [_bottomSheet.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:[TiktigerDesignTokens sectionGap]],
        [_mediaStack.leadingAnchor constraintEqualToAnchor:_bottomSheet.leadingAnchor constant:padding],
        [_mediaStack.trailingAnchor constraintEqualToAnchor:_bottomSheet.trailingAnchor constant:-padding],
        [_mediaStack.topAnchor constraintEqualToAnchor:_bottomSheet.topAnchor constant:padding],
        [_downloadButton.leadingAnchor constraintEqualToAnchor:_bottomSheet.leadingAnchor constant:padding],
        [_downloadButton.trailingAnchor constraintEqualToAnchor:_bottomSheet.trailingAnchor constant:-padding],
        [_downloadButton.topAnchor constraintEqualToAnchor:_mediaStack.bottomAnchor constant:[TiktigerDesignTokens sectionGap]],
        [_downloadButton.heightAnchor constraintEqualToConstant:[TiktigerDesignTokens controlHeight]],
        [_progressView.leadingAnchor constraintEqualToAnchor:_bottomSheet.leadingAnchor constant:padding],
        [_progressView.trailingAnchor constraintEqualToAnchor:_bottomSheet.trailingAnchor constant:-padding],
        [_progressView.topAnchor constraintEqualToAnchor:_downloadButton.bottomAnchor constant:[TiktigerDesignTokens sectionGap] / 2.0],
        [_progressView.bottomAnchor constraintEqualToAnchor:_bottomSheet.bottomAnchor constant:-padding],
        [_queueCard.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor constant:margin],
        [_queueCard.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor constant:-margin],
        [_queueCard.topAnchor constraintEqualToAnchor:_bottomSheet.bottomAnchor constant:[TiktigerDesignTokens sectionGap]],
        [_queueCard.bottomAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-margin]
    ]];
    self.presentationState = TiktigerDownloadPresentationStateIdle;
}

- (void)setPresentationState:(TiktigerDownloadPresentationState)presentationState {
    _presentationState = presentationState;
    NSString *title = @"Download";
    switch (presentationState) {
        case TiktigerDownloadPresentationStateIdle: title = @"Download"; break;
        case TiktigerDownloadPresentationStateLoading: title = @"Loading"; break;
        case TiktigerDownloadPresentationStateSuccess: title = @"Saved"; break;
        case TiktigerDownloadPresentationStateFailed: title = @"Retry"; break;
    }
    [self.downloadButton setTitle:title forState:UIControlStateNormal];
    self.downloadButton.accessibilityValue = title;
    self.downloadButton.backgroundColor = presentationState == TiktigerDownloadPresentationStateFailed ? [TiktigerDesignTokens vipSurfaceElevated] : [TiktigerDesignTokens vipRed];
    [TiktigerMotionSystem applyGlowToView:self.downloadButton color:[TiktigerDesignTokens vipRed] active:presentationState == TiktigerDownloadPresentationStateLoading];
}

- (void)setProgress:(CGFloat)progress {
    _progress = MIN(MAX(progress, 0.0), 1.0);
    [TiktigerMotionSystem animateView:self.progressView duration:[TiktigerDesignTokens motionFast] animations:^{
        self.progressView.progress = self->_progress;
    } completion:nil];
}

- (void)downloadPressed:(UIButton *)sender {
    NSError *error = nil;
    NSString *action = self.presentationState == TiktigerDownloadPresentationStateFailed ? @"retryDownload" : @"startDownload";
    BOOL success = [self.featureBinding executeFeatureAction:action featureID:@"media.download" payload:@{ @"mediaType": @"video", @"destination": @"files" } error:&error];
    if (!success) {
        self.presentationState = TiktigerDownloadPresentationStateFailed;
        [self showToastMessage:error.localizedDescription ?: @"Download unavailable" state:TiktigerToastStateError];
    }
}

- (void)setFeatureBinding:(id<TiktigerFeatureBinding>)binding {
    if (_featureBinding != nil) { [_featureBinding unsubscribeFromModuleEvents:self.eventToken]; }
    _featureBinding = binding;
    __weak typeof(self) weakSelf = self;
    self.eventToken = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self != nil && [event[@"featureID"] isEqual:@"media.download"]) { [self applyDownloadPresentation:event[@"download"] ?: [binding downloadPresentationState]]; }
    }];
    if (binding != nil) { [self applyDownloadPresentation:[binding downloadPresentationState]]; }
}

- (void)applyDownloadPresentation:(NSDictionary<NSString *,id> *)snapshot {
    NSString *state = snapshot[@"state"] ?: @"idle";
    if ([state isEqualToString:@"completed"]) {
        self.presentationState = TiktigerDownloadPresentationStateSuccess;
    } else if ([state isEqualToString:@"failed"]) {
        self.presentationState = TiktigerDownloadPresentationStateFailed;
    } else if ([state isEqualToString:@"preparing"] || [state isEqualToString:@"loading"] || [state isEqualToString:@"processing"]) {
        self.presentationState = TiktigerDownloadPresentationStateLoading;
    } else {
        self.presentationState = TiktigerDownloadPresentationStateIdle;
    }
    self.progress = [snapshot[@"progress"] doubleValue];
    NSDictionary *queue = snapshot[@"queue"];
    NSUInteger queued = [queue[@"queued"] unsignedIntegerValue];
    BOOL active = [queue[@"active"] boolValue];
    NSString *queueText = active ? [NSString stringWithFormat:@"%lu queued · active", (unsigned long)queued] : [NSString stringWithFormat:@"%lu queued", (unsigned long)queued];
    [self.queueCard setStatusMessage:queueText];
    NSDictionary *lastError = snapshot[@"lastError"];
    if ([state isEqualToString:@"failed"] && [lastError[@"message"] length] > 0) {
        [self showToastMessage:lastError[@"message"] state:TiktigerToastStateError];
    }
}

- (void)showToastMessage:(NSString *)message state:(NSInteger)state {
    TiktigerToast *toast = [TiktigerToast toastWithMessage:message state:(TiktigerToastState)state];
    [toast presentInView:self];
}

- (void)dealloc {
    [self.featureBinding unsubscribeFromModuleEvents:self.eventToken];
}

@end
