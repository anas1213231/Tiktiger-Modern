#import "TiktigerTikTokIntegrationBridge.h"
#import "TiktigerHostCoordinator.h"
#import "TiktigerPresentationBridge.h"
#import "TiktigerTikTokIntegrationDiagnostics.h"
#import "TiktigerFeatureRegistry.h"
#import "TiktigerNavigationContract.h"

static NSString * const TiktigerTikTokIntegrationBridgeErrorDomain = @"com.tiktiger.tiktok-integration-bridge";

static NSError *TiktigerTikTokVideoLifecycleError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TiktigerTikTokIntegrationBridgeErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"Video presentation lifecycle validation failed."}];
}

static NSDictionary *TiktigerTikTokVideoLifecycleDescriptor(TiktigerTikTokVideoPresentationLifecycleState state, NSDictionary *payload) {
    NSMutableDictionary *descriptor = [NSMutableDictionary dictionaryWithDictionary:payload ?: @{}];
    descriptor[@"entryPoint"] = @"video.action";
    descriptor[@"lifecycleState"] = TiktigerStringFromTikTokVideoPresentationLifecycleState(state);
    descriptor[@"presentationExecution"] = @"not-performed";
    descriptor[@"targetAppIntegrated"] = @NO;
    descriptor[@"integrationStatus"] = @"foundation-only";
    descriptor[@"presentationOwner"] = @"host";
    return TiktigerDeepImmutableCopy(descriptor);
}

static NSError *TiktigerTikTokDownloadFlowError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TiktigerTikTokIntegrationBridgeErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"TikTok download flow validation failed."}];
}

static NSError *TiktigerTikTokRuntimeLifecycleError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TiktigerTikTokIntegrationBridgeErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"TikTok runtime lifecycle validation failed."}];
}

static NSDictionary *TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleState state, NSDictionary *payload) {
    NSMutableDictionary *descriptor = [NSMutableDictionary dictionaryWithDictionary:payload ?: @{}];
    descriptor[@"entryPoint"] = @"video.action";
    descriptor[@"runtimeLifecycleState"] = TiktigerStringFromTikTokRuntimeLifecycleState(state);
    descriptor[@"presentationMode"] = @"host-owned";
    descriptor[@"presentationExecution"] = @"not-performed";
    descriptor[@"targetAppIntegrated"] = @NO;
    descriptor[@"integrationStatus"] = @"foundation-only";
    descriptor[@"runtimeIntegrationStatus"] = @"host-owned-runtime-contract";
    return TiktigerDeepImmutableCopy(descriptor);
}

static NSDictionary *TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowState state, NSDictionary *payload) {
    NSMutableDictionary *descriptor = [NSMutableDictionary dictionaryWithDictionary:payload ?: @{}];
    descriptor[@"entryPoint"] = @"video.action";
    descriptor[@"downloadFlowState"] = TiktigerStringFromTikTokDownloadFlowState(state);
    descriptor[@"integrationStatus"] = @"foundation-only";
    descriptor[@"targetAppIntegrated"] = @NO;
    descriptor[@"presentationExecution"] = @"not-performed";
    descriptor[@"downloadExecution"] = @"feature-binding-to-download-engine";
    descriptor[@"returnContext"] = @"video-context";
    return TiktigerDeepImmutableCopy(descriptor);
}

static NSURL *TiktigerTikTokSourceURLFromVideoEntry(NSDictionary *videoEntry, NSError **error) {
    NSDictionary *hostContext = [videoEntry[@"hostContext"] isKindOfClass:[NSDictionary class]] ? videoEntry[@"hostContext"] : @{};
    NSString *sourceString = [videoEntry[@"sourceURL"] isKindOfClass:[NSString class]] ? videoEntry[@"sourceURL"] : hostContext[@"sourceURL"];
    NSURL *sourceURL = [sourceString isKindOfClass:[NSString class]] ? [NSURL URLWithString:sourceString] : nil;
    NSString *scheme = sourceURL.scheme.lowercaseString;
    if (sourceURL == nil || sourceURL.host.length == 0 || (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])) {
        if (error != NULL) { *error = TiktigerTikTokDownloadFlowError(20, @"The video context does not contain a supported HTTP(S) source URL."); }
        return nil;
    }
    return sourceURL;
}

static NSString *TiktigerTikTokSafeMediaType(NSDictionary *options, NSError **error) {
    NSString *mediaType = [options[@"mediaType"] isKindOfClass:[NSString class]] ? [options[@"mediaType"] lowercaseString] : @"video";
    NSSet *allowed = [NSSet setWithObjects:@"video", @"audio", @"image", nil];
    if (![allowed containsObject:mediaType]) {
        if (error != NULL) { *error = TiktigerTikTokDownloadFlowError(21, @"The requested media type is not supported by the Download Module."); }
        return nil;
    }
    return mediaType;
}

static NSString *TiktigerTikTokSafeQuality(NSDictionary *options, NSError **error) {
    NSString *quality = [options[@"quality"] isKindOfClass:[NSString class]] ? options[@"quality"] : @"Auto";
    NSArray *allowed = @[@"Auto", @"1080p", @"720p", @"Audio"];
    if (![allowed containsObject:quality]) {
        if (error != NULL) { *error = TiktigerTikTokDownloadFlowError(22, @"The requested quality option is not available in the Smart Download Sheet."); }
        return nil;
    }
    return quality;
}

static TiktigerTikTokDownloadFlowState TiktigerTikTokDownloadFlowStateFromSnapshot(NSDictionary *snapshot) {
    NSString *state = [snapshot[@"state"] isKindOfClass:[NSString class]] ? [snapshot[@"state"] lowercaseString] : @"";
    if ([state isEqualToString:@"preparing"]) { return TiktigerTikTokDownloadFlowStatePreparing; }
    if ([state isEqualToString:@"loading"] || [state isEqualToString:@"downloading"]) { return TiktigerTikTokDownloadFlowStateDownloading; }
    if ([state isEqualToString:@"processing"]) { return TiktigerTikTokDownloadFlowStateProcessing; }
    if ([state isEqualToString:@"completed"]) { return TiktigerTikTokDownloadFlowStateCompleted; }
    if ([state isEqualToString:@"failed"]) { return TiktigerTikTokDownloadFlowStateFailed; }
    return TiktigerTikTokDownloadFlowStateQueued;
}

@interface TiktigerTikTokIntegrationBridge ()
@property (nonatomic, weak, readwrite) TiktigerHostCoordinator *hostCoordinator;
@property (nonatomic, weak, readwrite) TiktigerPresentationBridge *presentationBridge;
@property (nonatomic, strong, readwrite) TiktigerTikTokCompatibility *compatibility;
@property (nonatomic, strong, readwrite) TiktigerTikTokIntegrationDiagnostics *diagnostics;
@property (nonatomic, strong) NSLock *bridgeLock;
@property (nonatomic, strong) id downloadEventToken;
@property (nonatomic, copy) NSDictionary<NSString *, id> *activeVideoDownloadEntry;
@property (nonatomic, copy) NSString *activeDownloadFlowID;
@property (nonatomic, assign) TiktigerTikTokRuntimeLifecycleState runtimeLifecycleState;
@property (nonatomic, copy) NSDictionary<NSString *, id> *activeRuntimeEntry;
- (void)installDownloadEventObservationIfNeeded;
- (void)recordDownloadSnapshot:(NSDictionary *)snapshot eventAction:(NSString *)eventAction;
@end

@implementation TiktigerTikTokIntegrationBridge

- (instancetype)initWithHostCoordinator:(TiktigerHostCoordinator *)hostCoordinator presentationBridge:(TiktigerPresentationBridge *)presentationBridge compatibility:(TiktigerTikTokCompatibility *)compatibility diagnostics:(TiktigerTikTokIntegrationDiagnostics *)diagnostics {
    self = [super init];
    if (self) {
        _hostCoordinator = hostCoordinator;
        _presentationBridge = presentationBridge;
        _compatibility = compatibility;
        _diagnostics = diagnostics;
        _bridgeLock = [[NSLock alloc] init];
        _runtimeLifecycleState = TiktigerTikTokRuntimeLifecycleStateIdle;
        _activeRuntimeEntry = @{};
    }
    return self;
}

- (void)dealloc {
    id<TiktigerFeatureBinding> binding = self.presentationBridge.binding;
    if (self.downloadEventToken != nil) {
        [binding unsubscribeFromModuleEvents:self.downloadEventToken];
    }
}

- (void)installDownloadEventObservationIfNeeded {
    id<TiktigerFeatureBinding> binding = self.presentationBridge.binding;
    if (binding == nil || self.downloadEventToken != nil) { return; }
    __weak typeof(self) weakSelf = self;
    id token = [binding subscribeToModuleEvents:^(NSDictionary<NSString *,id> *event) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil || ![event[ @"featureID" ] isEqual:@"media.download"]) { return; }
        NSDictionary *snapshot = [event[ @"download" ] isKindOfClass:[NSDictionary class]] ? event[ @"download" ] : @{};
        if (snapshot.count == 0) { return; }
        [strongSelf recordDownloadSnapshot:snapshot eventAction:event[ @"action" ]];
    }];
    self.downloadEventToken = token;
}

- (void)recordDownloadSnapshot:(NSDictionary *)snapshot eventAction:(NSString *)eventAction {
    [self.bridgeLock lock];
    NSDictionary *entry = self.activeVideoDownloadEntry ?: @{};
    NSString *flowID = self.activeDownloadFlowID ?: @"";
    [self.bridgeLock unlock];
    if (entry.count == 0) { return; }
    TiktigerTikTokDownloadFlowState state = TiktigerTikTokDownloadFlowStateFromSnapshot(snapshot);
    NSDictionary *currentItem = [snapshot[ @"currentItem" ] isKindOfClass:[NSDictionary class]] ? snapshot[ @"currentItem" ] : @{};
    NSString *taskID = [currentItem[ @"id" ] isKindOfClass:[NSString class]] ? currentItem[ @"id" ] : flowID;
    NSDictionary *payload = @{
        @"diagnosticEvent": eventAction.length > 0 ? eventAction : TiktigerStringFromTikTokDownloadFlowState(state),
        @"flowID": taskID ?: @"",
        @"engineState": snapshot[ @"engineState" ] ?: @"",
        @"moduleState": snapshot[ @"state" ] ?: @"",
        @"progress": snapshot[ @"progress" ] ?: @0.0,
        @"sourceValidated": @YES,
        @"mediaType": currentItem[ @"mediaType" ] ?: entry[ @"selectedMediaType" ] ?: @"video",
        @"destination": currentItem[ @"destination" ] ?: entry[ @"selectedDestination" ] ?: @"files",
        @"returnContext": @"video-context"
    };
    NSDictionary *descriptor = TiktigerTikTokDownloadFlowDescriptor(state, payload);
    [self.diagnostics recordDownloadFlowState:descriptor];
    if (taskID.length > 0 && ![taskID isEqualToString:flowID]) {
        [self.bridgeLock lock];
        self.activeDownloadFlowID = taskID;
        [self.bridgeLock unlock];
    }
}

- (NSDictionary<NSString *,id> *)receiveHostEntryPoint:(TiktigerTikTokEntryPointKind)kind context:(NSDictionary<NSString *,id> *)context metadata:(NSDictionary<NSString *,id> *)metadata error:(NSError **)error {
    [self.bridgeLock lock];
    NSDictionary *compatibilityMetadata = [metadata[@"compatibilityMetadata"] isKindOfClass:[NSDictionary class]] ? metadata[@"compatibilityMetadata"] : metadata;
    NSDictionary *compatibilityResult = nil;
    NSError *compatibilityError = nil;
    TiktigerTikTokCompatibilityProfile profile = [self.compatibility evaluateMetadata:compatibilityMetadata result:&compatibilityResult error:&compatibilityError];
    [self.diagnostics recordCompatibilityResult:compatibilityResult ?: @{}];
    BOOL navigationAvailable = [metadata[@"navigationAvailable"] isKindOfClass:[NSNumber class]] && [metadata[@"navigationAvailable"] boolValue];
    BOOL runtimeReady = self.hostCoordinator.runtimeState == TiktigerRuntimeStateReady;
    NSError *entryError = nil;
    NSDictionary *descriptor = [TiktigerTikTokEntryPointContract evaluateEntryPoint:kind context:context ?: @{} compatibilityProfile:TiktigerStringFromTikTokCompatibilityProfile(profile) navigationAvailable:navigationAvailable runtimeReady:runtimeReady error:&entryError];
    NSMutableDictionary *result = [descriptor mutableCopy] ?: [[NSMutableDictionary alloc] init];
    result[@"compatibilityResult"] = compatibilityResult ?: @{};
    result[@"hostRuntimeReady"] = @(runtimeReady);
    result[@"navigationAvailable"] = @(navigationAvailable);
    result[@"integrationStatus"] = @"foundation-only";
    result[@"targetAppIntegrated"] = @NO;
    NSDictionary *immutableResult = TiktigerDeepImmutableCopy(result);
    [self.diagnostics recordEntryPointState:immutableResult];
    [self.bridgeLock unlock];
    if (entryError != nil && error != NULL) { *error = entryError; }
    else if (compatibilityError != nil && error != NULL) { *error = compatibilityError; }
    return immutableResult;
}

- (NSDictionary<NSString *,id> *)receiveVideoActionContext:(NSDictionary<NSString *,id> *)context metadata:(NSDictionary<NSString *,id> *)metadata error:(NSError **)error {
    NSError *entryError = nil;
    NSDictionary *entry = [self receiveHostEntryPoint:TiktigerTikTokEntryPointKindVideoAction context:context ?: @{} metadata:metadata ?: @{} error:&entryError];
    BOOL available = [entry[@"available"] isKindOfClass:[NSNumber class]] && [entry[@"available"] boolValue];
    TiktigerTikTokVideoPresentationLifecycleState lifecycleState = available ? TiktigerTikTokVideoPresentationLifecycleStateEntryReceived : TiktigerTikTokVideoPresentationLifecycleStateFailed;
    NSMutableDictionary *payload = [entry mutableCopy] ?: [[NSMutableDictionary alloc] init];
    payload[@"placement"] = @"host-owned-video-action";
    payload[@"returnContext"] = @"video-context";
    payload[@"presentationLifecycle"] = TiktigerStringFromTikTokVideoPresentationLifecycleState(lifecycleState);
    payload[@"diagnosticEvent"] = available ? @"entry-received" : @"entry-failed";
    NSDictionary *result = TiktigerTikTokVideoLifecycleDescriptor(lifecycleState, payload);
    [self.diagnostics recordPresentationState:result];
    if (!available && error != NULL) {
        *error = entryError ?: TiktigerTikTokVideoLifecycleError(10, entry[@"reason"] ?: @"Video action entry is unavailable.");
    } else if (entryError != nil && error != NULL) {
        *error = entryError;
    }
    return result;
}

- (NSDictionary<NSString *,id> *)requestDashboardForVideoEntry:(NSDictionary<NSString *,id> *)videoEntry error:(NSError **)error {
    NSString *entryPoint = [videoEntry[@"entryPoint"] isKindOfClass:[NSString class]] ? videoEntry[@"entryPoint"] : @"";
    NSString *profile = [videoEntry[@"compatibilityProfile"] isKindOfClass:[NSString class]] ? videoEntry[@"compatibilityProfile"] : @"error";
    BOOL available = [videoEntry[@"available"] isKindOfClass:[NSNumber class]] && [videoEntry[@"available"] boolValue];
    BOOL compatible = [profile isEqualToString:@"supported"] || [profile isEqualToString:@"supported-limited"];
    if (![entryPoint isEqualToString:@"video.action"] || !available || !compatible) {
        NSError *requestError = TiktigerTikTokVideoLifecycleError(11, ![entryPoint isEqualToString:@"video.action"] ? @"Only the video.action entry can request the Phase 25 Dashboard presentation." : @"Video Dashboard presentation is blocked by entry availability or compatibility state.");
        NSDictionary *failure = TiktigerTikTokVideoLifecycleDescriptor(TiktigerTikTokVideoPresentationLifecycleStateFailed, @{
            @"diagnosticEvent": @"presentation-failed",
            @"reason": requestError.localizedDescription,
            @"placement": @"host-owned-video-action",
            @"returnContext": @"video-context"
        });
        [self.diagnostics recordPresentationState:failure];
        if (error != NULL) { *error = requestError; }
        return failure;
    }
    NSError *dashboardError = nil;
    NSDictionary *dashboard = [self openDashboardDescriptor:&dashboardError];
    if (dashboardError != nil || dashboard == nil || ![dashboard[@"state"] isEqualToString:@"ready"]) {
        NSError *requestError = dashboardError ?: TiktigerTikTokVideoLifecycleError(12, @"The existing Dashboard Presentation Bridge did not return a ready descriptor.");
        NSDictionary *failure = TiktigerTikTokVideoLifecycleDescriptor(TiktigerTikTokVideoPresentationLifecycleStateFailed, @{
            @"diagnosticEvent": @"presentation-failed",
            @"reason": requestError.localizedDescription,
            @"dashboard": dashboard ?: @{},
            @"placement": @"host-owned-video-action",
            @"returnContext": @"video-context"
        });
        [self.diagnostics recordPresentationState:failure];
        if (error != NULL) { *error = requestError; }
        return failure;
    }
    NSDictionary *requested = TiktigerTikTokVideoLifecycleDescriptor(TiktigerTikTokVideoPresentationLifecycleStatePresentationRequested, @{
        @"diagnosticEvent": @"presentation-requested",
        @"dashboard": dashboard,
        @"placement": @"host-owned-video-action",
        @"returnContext": @"video-context",
        @"navigationExecution": @"not-performed"
    });
    [self.diagnostics recordPresentationState:requested];
    return requested;
}

- (NSDictionary<NSString *,id> *)handleVideoActionContext:(NSDictionary<NSString *,id> *)context metadata:(NSDictionary<NSString *,id> *)metadata error:(NSError **)error {
    NSError *entryError = nil;
    NSDictionary *entry = [self receiveVideoActionContext:context metadata:metadata error:&entryError];
    if (![entry[@"available"] boolValue]) {
        if (error != NULL) { *error = entryError; }
        return entry;
    }
    NSError *requestError = nil;
    NSDictionary *requested = [self requestDashboardForVideoEntry:entry error:&requestError];
    if (error != NULL) { *error = requestError ?: entryError; }
    NSMutableDictionary *result = [entry mutableCopy] ?: [[NSMutableDictionary alloc] init];
    [result addEntriesFromDictionary:requested ?: @{}];
    result[@"diagnosticEvent"] = requestError == nil ? @"presentation-requested" : @"presentation-failed";
    return TiktigerDeepImmutableCopy(result);
}

- (NSDictionary<NSString *,id> *)completeVideoPresentation:(NSDictionary<NSString *,id> *)hostEvent error:(NSError **)error {
    BOOL success = ![hostEvent[@"success"] isKindOfClass:[NSNumber class]] || [hostEvent[@"success"] boolValue];
    if (!success) {
        NSError *completionError = TiktigerTikTokVideoLifecycleError(13, @"The host reported that the video Dashboard presentation did not complete.");
        NSDictionary *failure = TiktigerTikTokVideoLifecycleDescriptor(TiktigerTikTokVideoPresentationLifecycleStateFailed, @{
            @"diagnosticEvent": @"presentation-failed",
            @"reason": completionError.localizedDescription,
            @"hostEvent": hostEvent ?: @{},
            @"returnContext": @"video-context"
        });
        [self.diagnostics recordPresentationState:failure];
        if (error != NULL) { *error = completionError; }
        return failure;
    }
    NSDictionary *completed = TiktigerTikTokVideoLifecycleDescriptor(TiktigerTikTokVideoPresentationLifecycleStatePresentationCompleted, @{
        @"diagnosticEvent": @"presentation-completed",
        @"hostEvent": hostEvent ?: @{},
        @"returnContext": @"video-context"
    });
    [self.diagnostics recordPresentationState:completed];
    return completed;
}

- (NSDictionary<NSString *,id> *)closeVideoPresentationWithReason:(NSString *)reason error:(NSError **)error {
    NSString *safeReason = [reason isKindOfClass:[NSString class]] && reason.length > 0 ? reason : @"host-dismissed";
    NSDictionary *closed = TiktigerTikTokVideoLifecycleDescriptor(TiktigerTikTokVideoPresentationLifecycleStatePresentationClosed, @{
        @"diagnosticEvent": @"presentation-closed",
        @"closeReason": safeReason,
        @"returnContext": @"video-context"
    });
    [self.diagnostics recordPresentationState:closed];
    return closed;
}

- (NSDictionary<NSString *,id> *)returnToVideoContext:(NSDictionary<NSString *,id> *)hostEvent error:(NSError **)error {
    NSDictionary *returned = TiktigerTikTokVideoLifecycleDescriptor(TiktigerTikTokVideoPresentationLifecycleStateReturnedToContext, @{
        @"diagnosticEvent": @"returned-to-context",
        @"hostEvent": hostEvent ?: @{},
        @"returnContext": @"video-context",
        @"contextRestoration": @"host-owned"
    });
    [self.diagnostics recordPresentationState:returned];
    return returned;
}

- (NSDictionary<NSString *,id> *)requestSmartDownloadSheetForVideoEntry:(NSDictionary<NSString *,id> *)videoEntry options:(NSDictionary<NSString *,id> *)options error:(NSError **)error {
    NSString *entryPoint = [videoEntry[@"entryPoint"] isKindOfClass:[NSString class]] ? videoEntry[@"entryPoint"] : @"";
    NSString *profile = [videoEntry[@"compatibilityProfile"] isKindOfClass:[NSString class]] ? videoEntry[@"compatibilityProfile"] : @"error";
    BOOL available = [videoEntry[@"available"] isKindOfClass:[NSNumber class]] && [videoEntry[@"available"] boolValue];
    BOOL compatible = [profile isEqualToString:@"supported"] || [profile isEqualToString:@"supported-limited"];
    if (![entryPoint isEqualToString:@"video.action"] || !available || !compatible) {
        NSError *flowError = TiktigerTikTokDownloadFlowError(23, @"The video entry is unavailable or compatibility-gated for Download Flow.");
        NSDictionary *failure = TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowStateFailed, @{
            @"diagnosticEvent": @"context-validation-failed",
            @"reason": flowError.localizedDescription,
            @"sourceValidated": @NO
        });
        [self.diagnostics recordDownloadFlowState:failure];
        if (error != NULL) { *error = flowError; }
        return failure;
    }
    NSError *sourceError = nil;
    NSURL *sourceURL = TiktigerTikTokSourceURLFromVideoEntry(videoEntry, &sourceError);
    if (sourceURL == nil) {
        NSDictionary *failure = TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowStateFailed, @{
            @"diagnosticEvent": @"source-validation-failed",
            @"reason": sourceError.localizedDescription ?: @"The video source is unavailable.",
            @"sourceValidated": @NO
        });
        [self.diagnostics recordDownloadFlowState:failure];
        if (error != NULL) { *error = sourceError; }
        return failure;
    }
    NSError *mediaError = nil;
    NSString *mediaType = TiktigerTikTokSafeMediaType(options ?: @{}, &mediaError);
    NSError *qualityError = nil;
    NSString *quality = TiktigerTikTokSafeQuality(options ?: @{}, &qualityError);
    if (mediaType == nil || quality == nil) {
        NSError *selectionError = mediaError ?: qualityError;
        NSDictionary *failure = TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowStateFailed, @{
            @"diagnosticEvent": @"sheet-selection-failed",
            @"reason": selectionError.localizedDescription ?: @"The Smart Download Sheet selection is invalid.",
            @"sourceValidated": @YES
        });
        [self.diagnostics recordDownloadFlowState:failure];
        if (error != NULL) { *error = selectionError; }
        return failure;
    }
    NSError *routeError = nil;
    NSDictionary *downloadRoute = [self routeHostEventToRoute:TiktigerNavigationRouteDownload error:&routeError];
    if (downloadRoute == nil || [downloadRoute[@"state"] isEqualToString:@"rejected"]) {
        NSError *flowError = routeError ?: TiktigerTikTokDownloadFlowError(24, @"The Download Center navigation contract is unavailable.");
        NSDictionary *failure = TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowStateFailed, @{
            @"diagnosticEvent": @"download-route-failed",
            @"reason": flowError.localizedDescription,
            @"sourceValidated": @YES
        });
        [self.diagnostics recordDownloadFlowState:failure];
        if (error != NULL) { *error = flowError; }
        return failure;
    }
    NSError *stateError = nil;
    NSDictionary *downloadState = [self.presentationBridge presentationStateForRoute:TiktigerNavigationRouteDownload error:&stateError] ?: @{};
    NSString *configuredDestination = [downloadState[@"configuration"][@"destination"] isKindOfClass:[NSString class]] ? downloadState[@"configuration"][@"destination"] : @"files";
    NSString *destination = [options[@"destination"] isKindOfClass:[NSString class]] && [options[@"destination"] length] > 0 ? options[@"destination"] : configuredDestination;
    NSString *flowID = [NSUUID UUID].UUIDString;
    NSMutableDictionary *activeEntry = [videoEntry mutableCopy] ?: [[NSMutableDictionary alloc] init];
    activeEntry[@"sourceURL"] = sourceURL.absoluteString;
    activeEntry[@"selectedMediaType"] = mediaType;
    activeEntry[@"selectedQuality"] = quality;
    activeEntry[@"selectedDestination"] = destination;
    activeEntry[@"flowID"] = flowID;
    [self.bridgeLock lock];
    self.activeVideoDownloadEntry = TiktigerDeepImmutableCopy(activeEntry);
    self.activeDownloadFlowID = flowID;
    [self.bridgeLock unlock];
    [self installDownloadEventObservationIfNeeded];
    NSDictionary *sheet = TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowStateSmartSheetRequested, @{
        @"diagnosticEvent": @"smart-download-sheet-requested",
        @"flowID": flowID,
        @"sourceURL": sourceURL.absoluteString,
        @"sourceValidated": @YES,
        @"compatibilityProfile": profile,
        @"mediaTypeOptions": @[@"video", @"audio", @"image"],
        @"qualityOptions": @[@"Auto", @"1080p", @"720p", @"Audio"],
        @"destinationOptions": @[@"files"],
        @"selectedMediaType": mediaType,
        @"selectedQuality": quality,
        @"selectedDestination": destination,
        @"downloadRoute": downloadRoute ?: @{},
        @"downloadPresentationState": downloadState,
        @"presentationMode": @"host-owned-existing-download-center"
    });
    [self.diagnostics recordDownloadFlowState:sheet];
    if (stateError != nil && error != NULL) { *error = stateError; }
    return sheet;
}

- (NSDictionary<NSString *,id> *)startDownloadForVideoEntry:(NSDictionary<NSString *,id> *)videoEntry options:(NSDictionary<NSString *,id> *)options error:(NSError **)error {
    NSError *sheetError = nil;
    NSDictionary *sheet = [self requestSmartDownloadSheetForVideoEntry:videoEntry options:options error:&sheetError];
    if (![sheet[@"downloadFlowState"] isEqualToString:@"smart-sheet-requested"]) {
        if (error != NULL) { *error = sheetError; }
        return sheet;
    }
    id<TiktigerFeatureBinding> binding = self.presentationBridge.binding;
    if (binding == nil) {
        NSError *bindingError = TiktigerTikTokDownloadFlowError(25, @"The Download Module Feature Binding is unavailable.");
        NSDictionary *failure = TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowStateFailed, @{
            @"diagnosticEvent": @"download-binding-unavailable",
            @"reason": bindingError.localizedDescription,
            @"sourceValidated": @YES,
            @"flowID": sheet[@"flowID"] ?: @""
        });
        [self.diagnostics recordDownloadFlowState:failure];
        if (error != NULL) { *error = bindingError; }
        return failure;
    }
    NSError *sourceError = nil;
    NSURL *sourceURL = TiktigerTikTokSourceURLFromVideoEntry(sheet, &sourceError);
    if (sourceURL == nil) {
        NSDictionary *failure = TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowStateFailed, @{
            @"diagnosticEvent": @"source-validation-failed",
            @"reason": sourceError.localizedDescription ?: @"The validated video source could not be handed to the Download Module.",
            @"sourceValidated": @NO,
            @"flowID": sheet[@"flowID"] ?: @""
        });
        [self.diagnostics recordDownloadFlowState:failure];
        if (error != NULL) { *error = sourceError; }
        return failure;
    }
    NSDictionary *payload = @{
        @"mediaType": sheet[@"selectedMediaType"] ?: @"video",
        @"quality": sheet[@"selectedQuality"] ?: @"Auto",
        @"destination": sheet[@"selectedDestination"] ?: @"files",
        @"sourceURL": sourceURL.absoluteString
    };
    NSError *enqueueError = nil;
    BOOL accepted = [binding executeFeatureAction:@"startDownload" featureID:@"media.download" payload:payload error:&enqueueError];
    if (!accepted) {
        NSDictionary *failure = TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowStateFailed, @{
            @"diagnosticEvent": @"download-enqueue-failed",
            @"reason": enqueueError.localizedDescription ?: @"The Download Module rejected the validated source.",
            @"sourceValidated": @YES,
            @"flowID": sheet[@"flowID"] ?: @"",
            @"mediaType": payload[@"mediaType"],
            @"destination": payload[@"destination"]
        });
        [self.diagnostics recordDownloadFlowState:failure];
        if (error != NULL) { *error = enqueueError; }
        return failure;
    }
    NSDictionary *downloadSnapshot = [binding downloadPresentationState] ?: @{};
    TiktigerTikTokDownloadFlowState state = TiktigerTikTokDownloadFlowStateFromSnapshot(downloadSnapshot);
    NSDictionary *currentItem = [downloadSnapshot[@"currentItem"] isKindOfClass:[NSDictionary class]] ? downloadSnapshot[@"currentItem"] : @{};
    NSDictionary *queued = TiktigerTikTokDownloadFlowDescriptor(state, @{
        @"diagnosticEvent": @"download-enqueued",
        @"flowID": sheet[@"flowID"] ?: currentItem[@"id"] ?: @"",
        @"taskID": currentItem[@"id"] ?: @"",
        @"sourceURL": sourceURL.absoluteString,
        @"sourceValidated": @YES,
        @"mediaType": payload[@"mediaType"],
        @"quality": payload[@"quality"],
        @"destination": payload[@"destination"],
        @"downloadSnapshot": downloadSnapshot,
        @"engineState": downloadSnapshot[@"engineState"] ?: @""
    });
    [self.diagnostics recordDownloadFlowState:queued];
    if (error != NULL) { *error = nil; }
    return queued;
}

- (NSDictionary<NSString *,id> *)closeTikTokDownloadFlowWithReason:(NSString *)reason error:(NSError **)error {
    [self.bridgeLock lock];
    NSString *flowID = self.activeDownloadFlowID ?: @"";
    [self.bridgeLock unlock];
    NSString *safeReason = [reason isKindOfClass:[NSString class]] && reason.length > 0 ? reason : @"host-dismissed";
    NSDictionary *closed = TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowStateClosed, @{
        @"diagnosticEvent": @"download-flow-closed",
        @"flowID": flowID,
        @"closeReason": safeReason,
        @"downloadTaskPreserved": @YES,
        @"engineControl": @"unchanged"
    });
    [self.diagnostics recordDownloadFlowState:closed];
    return closed;
}

- (NSDictionary<NSString *,id> *)returnToTikTokFromDownloadFlow:(NSDictionary<NSString *,id> *)hostEvent error:(NSError **)error {
    [self.bridgeLock lock];
    NSString *flowID = self.activeDownloadFlowID ?: @"";
    [self.bridgeLock unlock];
    NSDictionary *returned = TiktigerTikTokDownloadFlowDescriptor(TiktigerTikTokDownloadFlowStateReturnedToContext, @{
        @"diagnosticEvent": @"download-returned-to-tiktok",
        @"flowID": flowID,
        @"hostEvent": hostEvent ?: @{},
        @"contextRestoration": @"host-owned",
        @"downloadTaskPreserved": @YES,
        @"returnContext": @"video-context"
    });
    [self.diagnostics recordDownloadFlowState:returned];
    [self.bridgeLock lock];
    self.activeVideoDownloadEntry = nil;
    self.activeDownloadFlowID = nil;
    [self.bridgeLock unlock];
    return returned;
}

- (NSDictionary<NSString *,id> *)openDashboardDescriptor:(NSError **)error {
    [self.bridgeLock lock];
    BOOL runtimeReady = self.hostCoordinator.runtimeState == TiktigerRuntimeStateReady;
    if (!runtimeReady || self.presentationBridge == nil) {
        NSError *dashboardError = [NSError errorWithDomain:TiktigerTikTokIntegrationBridgeErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: runtimeReady ? @"Presentation Bridge is unavailable." : @"Tiktiger runtime is not ready for dashboard presentation."}];
        NSDictionary *failure = @{ @"surface": @"dashboard", @"state": @"unavailable", @"reason": dashboardError.localizedDescription, @"presentationExecution": @"not-performed", @"targetAppIntegrated": @NO, @"integrationStatus": @"foundation-only" };
        [self.diagnostics recordNavigationState:failure];
        [self.bridgeLock unlock];
        if (error != NULL) { *error = dashboardError; }
        return TiktigerDeepImmutableCopy(failure);
    }
    NSDictionary *entry = [self.presentationBridge dashboardPresentationEntry];
    NSDictionary *descriptor = TiktigerDeepImmutableCopy(@{
        @"surface": @"dashboard",
        @"state": @"ready",
        @"entry": entry ?: @{},
        @"presentationExecution": @"not-performed",
        @"hostNavigationOwner": @YES,
        @"targetAppIntegrated": @NO,
        @"integrationStatus": @"foundation-only"
    });
    [self.diagnostics recordNavigationState:descriptor];
    [self.bridgeLock unlock];
    return descriptor;
}

- (NSDictionary<NSString *,id> *)routeHostEventToRoute:(NSString *)route error:(NSError **)error {
    [self.bridgeLock lock];
    NSDictionary *descriptor = [self.presentationBridge routingDescriptorForRoute:route error:error];
    if (descriptor == nil) {
        NSDictionary *failure = @{ @"route": route ?: @"", @"state": @"rejected", @"presentationExecution": @"not-performed", @"targetAppIntegrated": @NO, @"integrationStatus": @"foundation-only" };
        [self.diagnostics recordNavigationState:failure];
        [self.bridgeLock unlock];
        return TiktigerDeepImmutableCopy(failure);
    }
    NSMutableDictionary *result = [descriptor mutableCopy];
    result[@"hostEvent"] = @YES;
    result[@"integrationStatus"] = @"foundation-only";
    result[@"targetAppIntegrated"] = @NO;
    NSDictionary *immutableResult = TiktigerDeepImmutableCopy(result);
    [self.diagnostics recordNavigationState:immutableResult];
    [self.bridgeLock unlock];
    return immutableResult;
}

- (NSDictionary<NSString *,id> *)initializeRuntimeWithArtifactMetadata:(NSDictionary<NSString *,id> *)artifactMetadata error:(NSError **)error {
    [self.bridgeLock lock];
    self.runtimeLifecycleState = TiktigerTikTokRuntimeLifecycleStateInitializing;
    [self.bridgeLock unlock];
    [self.diagnostics recordRuntimeState:TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStateInitializing, @{
        @"event": @"initialize-requested",
        @"hostOwned": @YES
    })];

    NSError *initializationError = nil;
    BOOL success = artifactMetadata != nil ? [self.hostCoordinator initializeHostWithArtifactMetadata:artifactMetadata error:&initializationError] : [self.hostCoordinator initializeHost:&initializationError];
    TiktigerTikTokRuntimeLifecycleState state = success ? TiktigerTikTokRuntimeLifecycleStateReady : TiktigerTikTokRuntimeLifecycleStateFailed;
    [self.bridgeLock lock];
    self.runtimeLifecycleState = state;
    if (!success) { self.activeRuntimeEntry = @{}; }
    [self.bridgeLock unlock];
    NSDictionary *hostStatus = [self.hostCoordinator statusSnapshot] ?: @{};
    NSDictionary *descriptor = TiktigerTikTokRuntimeDescriptor(state, @{
        @"event": success ? @"initialize-completed" : @"initialize-failed",
        @"hostCoordinatorState": hostStatus[@"state"] ?: @"unknown",
        @"runtimeState": hostStatus[@"runtimeState"] ?: @"unknown",
        @"lastError": initializationError.localizedDescription ?: hostStatus[@"lastError"] ?: @"",
        @"recoveryAvailable": @(!success)
    });
    [self.diagnostics recordRuntimeState:descriptor];
    if (!success && error != NULL) { *error = initializationError ?: TiktigerTikTokRuntimeLifecycleError(30, @"Tiktiger runtime initialization failed."); }
    return descriptor;
}

- (NSDictionary<NSString *,id> *)startRuntimeExperienceForVideoContext:(NSDictionary<NSString *,id> *)context metadata:(NSDictionary<NSString *,id> *)metadata artifactMetadata:(NSDictionary<NSString *,id> *)artifactMetadata error:(NSError **)error {
    [self.bridgeLock lock];
    BOOL ready = self.hostCoordinator.runtimeState == TiktigerRuntimeStateReady;
    [self.bridgeLock unlock];
    if (!ready) {
        NSDictionary *initialization = [self initializeRuntimeWithArtifactMetadata:artifactMetadata error:error];
        if (![initialization[@"runtimeLifecycleState"] isEqualToString:@"ready"]) {
            return initialization;
        }
    }
    NSError *entryError = nil;
    NSDictionary *entry = [self receiveVideoActionContext:context metadata:metadata error:&entryError];
    if (entryError != nil || [entry[@"state"] isEqualToString:@"unavailable"] || [entry[@"state"] isEqualToString:@"failed"]) {
        [self.bridgeLock lock];
        self.runtimeLifecycleState = TiktigerTikTokRuntimeLifecycleStateFailed;
        [self.bridgeLock unlock];
        NSDictionary *failure = TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStateFailed, @{
            @"event": @"entry-failed",
            @"reason": entryError.localizedDescription ?: entry[@"reason"] ?: @"Video entry is unavailable.",
            @"entry": entry ?: @{}
        });
        [self.diagnostics recordRuntimeState:failure];
        if (error != NULL) { *error = entryError ?: TiktigerTikTokRuntimeLifecycleError(31, failure[@"reason"]); }
        return failure;
    }
    NSError *dashboardError = nil;
    NSDictionary *dashboard = [self requestDashboardForVideoEntry:entry error:&dashboardError];
    if (dashboardError != nil || [dashboard[@"state"] isEqualToString:@"unavailable"]) {
        [self.bridgeLock lock];
        self.runtimeLifecycleState = TiktigerTikTokRuntimeLifecycleStateFailed;
        [self.bridgeLock unlock];
        NSDictionary *failure = TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStateFailed, @{
            @"event": @"dashboard-failed",
            @"reason": dashboardError.localizedDescription ?: dashboard[@"reason"] ?: @"Dashboard descriptor is unavailable.",
            @"entry": entry ?: @{},
            @"dashboard": dashboard ?: @{}
        });
        [self.diagnostics recordRuntimeState:failure];
        if (error != NULL) { *error = dashboardError ?: TiktigerTikTokRuntimeLifecycleError(32, failure[@"reason"]); }
        return failure;
    }
    [self.bridgeLock lock];
    self.runtimeLifecycleState = TiktigerTikTokRuntimeLifecycleStatePresenting;
    self.activeRuntimeEntry = entry ?: @{};
    [self.bridgeLock unlock];
    NSDictionary *descriptor = TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStatePresenting, @{
        @"event": @"presentation-requested",
        @"entry": entry ?: @{},
        @"dashboard": dashboard ?: @{},
        @"compatibility": entry[@"compatibilityResult"] ?: @{},
        @"hostPresentationRequired": @YES
    });
    [self.diagnostics recordRuntimeState:descriptor];
    return descriptor;
}

- (NSDictionary<NSString *,id> *)presentRuntimeExperienceForEntry:(NSDictionary<NSString *,id> *)runtimeEntry hostEvent:(NSDictionary<NSString *,id> *)hostEvent error:(NSError **)error {
    [self.bridgeLock lock];
    NSDictionary *active = self.activeRuntimeEntry ?: @{};
    BOOL valid = active.count > 0 && runtimeEntry.count > 0;
    [self.bridgeLock unlock];
    if (!valid) {
        NSError *presentationError = TiktigerTikTokRuntimeLifecycleError(33, @"No active Video Action runtime entry is available for presentation acknowledgement.");
        NSDictionary *failure = TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStateFailed, @{
            @"event": @"presentation-failed",
            @"reason": presentationError.localizedDescription,
            @"hostEventReceived": @(hostEvent.count > 0)
        });
        [self.diagnostics recordRuntimeState:failure];
        if (error != NULL) { *error = presentationError; }
        return failure;
    }
    [self.bridgeLock lock];
    self.runtimeLifecycleState = TiktigerTikTokRuntimeLifecycleStatePresented;
    [self.bridgeLock unlock];
    NSDictionary *descriptor = TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStatePresented, @{
        @"event": @"presentation-completed",
        @"hostAcknowledged": @YES,
        @"hostEventReceived": @(hostEvent.count > 0),
        @"presentationExecutionState": @"host-acknowledged"
    });
    [self.diagnostics recordPresentationState:descriptor];
    [self.diagnostics recordRuntimeState:descriptor];
    return descriptor;
}

- (NSDictionary<NSString *,id> *)closeRuntimeExperienceWithReason:(NSString *)reason error:(NSError **)error {
    [self.bridgeLock lock];
    BOOL active = self.activeRuntimeEntry.count > 0;
    [self.bridgeLock unlock];
    if (!active) {
        NSError *closeError = TiktigerTikTokRuntimeLifecycleError(34, @"No active runtime presentation is available to close.");
        NSDictionary *failure = TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStateFailed, @{
            @"event": @"close-failed",
            @"reason": closeError.localizedDescription
        });
        [self.diagnostics recordRuntimeState:failure];
        if (error != NULL) { *error = closeError; }
        return failure;
    }
    [self.bridgeLock lock];
    self.runtimeLifecycleState = TiktigerTikTokRuntimeLifecycleStateClosing;
    [self.bridgeLock unlock];
    NSDictionary *descriptor = TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStateClosing, @{
        @"event": @"presentation-closed",
        @"reason": reason.length > 0 ? reason : @"host-closed",
        @"downloadTasksPreserved": @YES
    });
    [self.diagnostics recordPresentationState:descriptor];
    [self.diagnostics recordRuntimeState:descriptor];
    return descriptor;
}

- (NSDictionary<NSString *,id> *)returnToTikTokRuntimeContext:(NSDictionary<NSString *,id> *)hostEvent error:(NSError **)error {
    [self.bridgeLock lock];
    BOOL active = self.activeRuntimeEntry.count > 0;
    [self.bridgeLock unlock];
    if (!active) {
        NSError *returnError = TiktigerTikTokRuntimeLifecycleError(35, @"No active runtime presentation is available for return-to-context.");
        NSDictionary *failure = TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStateFailed, @{
            @"event": @"return-failed",
            @"reason": returnError.localizedDescription
        });
        [self.diagnostics recordRuntimeState:failure];
        if (error != NULL) { *error = returnError; }
        return failure;
    }
    [self.bridgeLock lock];
    self.runtimeLifecycleState = TiktigerTikTokRuntimeLifecycleStateReturnedToContext;
    self.activeRuntimeEntry = @{};
    [self.bridgeLock unlock];
    NSDictionary *descriptor = TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStateReturnedToContext, @{
        @"event": @"returned-to-tiktok-context",
        @"hostEventReceived": @(hostEvent.count > 0),
        @"returnContext": @"video-context",
        @"downloadTasksPreserved": @YES
    });
    [self.diagnostics recordPresentationState:descriptor];
    [self.diagnostics recordRuntimeState:descriptor];
    return descriptor;
}

- (NSDictionary<NSString *,id> *)recoverRuntimeWithArtifactMetadata:(NSDictionary<NSString *,id> *)artifactMetadata reason:(NSString *)reason error:(NSError **)error {
    [self.bridgeLock lock];
    self.runtimeLifecycleState = TiktigerTikTokRuntimeLifecycleStateRecovering;
    [self.bridgeLock unlock];
    [self.diagnostics recordRuntimeState:TiktigerTikTokRuntimeDescriptor(TiktigerTikTokRuntimeLifecycleStateRecovering, @{
        @"event": @"recovery-requested",
        @"reason": reason.length > 0 ? reason : @"host-requested"
    })];
    NSError *recoveryError = nil;
    BOOL recovered = [self.hostCoordinator recoverHost:&recoveryError];
    TiktigerTikTokRuntimeLifecycleState state = recovered ? TiktigerTikTokRuntimeLifecycleStateReady : TiktigerTikTokRuntimeLifecycleStateFailed;
    [self.bridgeLock lock];
    self.runtimeLifecycleState = state;
    if (!recovered) { self.activeRuntimeEntry = @{}; }
    [self.bridgeLock unlock];
    NSDictionary *descriptor = TiktigerTikTokRuntimeDescriptor(state, @{
        @"event": recovered ? @"recovery-completed" : @"recovery-failed",
        @"hostCoordinatorState": [self.hostCoordinator statusSnapshot][@"state"] ?: @"unknown",
        @"lastError": recoveryError.localizedDescription ?: @"",
        @"artifactMetadataProvided": @(artifactMetadata != nil)
    });
    [self.diagnostics recordRuntimeState:descriptor];
    if (!recovered && error != NULL) { *error = recoveryError ?: TiktigerTikTokRuntimeLifecycleError(36, @"Runtime recovery failed."); }
    return descriptor;
}

- (NSDictionary<NSString *,id> *)statusSnapshot {
    [self.bridgeLock lock];
    NSDictionary *snapshot = @{
        @"integrationStatus": @"foundation-only",
        @"targetAppIntegrated": @NO,
        @"hostCoordinator": [self.hostCoordinator statusSnapshot] ?: @{},
        @"compatibility": [self.compatibility compatibilitySnapshot] ?: @{},
        @"diagnostics": [self.diagnostics snapshot] ?: @{},
        @"supportedEntryPoints": [TiktigerTikTokEntryPointContract supportedEntryPointIdentifiers],
        @"videoActionIntegration": @{
            @"entryPoint": @"video.action",
            @"placement": @"host-owned-video-action",
            @"supportedLifecycleStates": @[@"entry-received", @"presentation-requested", @"presentation-completed", @"presentation-closed", @"returned-to-context", @"failed"],
            @"presentationExecution": @"not-performed",
            @"returnContext": @"video-context"
        },
        @"downloadFlowIntegration": @{
            @"entryPoint": @"video.action",
            @"route": TiktigerNavigationRouteDownload,
            @"supportedStates": @[@"context-validated", @"smart-sheet-requested", @"queued", @"preparing", @"downloading", @"processing", @"completed", @"failed", @"closed", @"returned-to-context"],
            @"sourceValidation": @"http-or-https-only",
            @"executionPath": @"feature-binding-to-download-engine",
            @"presentationExecution": @"not-performed",
            @"returnContext": @"video-context"
        },
        @"runtimeIntegration": @{
            @"entryPoint": @"video.action",
            @"lifecycleState": TiktigerStringFromTikTokRuntimeLifecycleState(self.runtimeLifecycleState),
            @"supportedStates": @[@"idle", @"initializing", @"ready", @"presenting", @"presented", @"closing", @"returned-to-context", @"recovering", @"failed"],
            @"presentationMode": @"host-owned",
            @"presentationExecution": @"not-performed",
            @"activeEntry": @(self.activeRuntimeEntry.count > 0),
            @"compatibilityEnforced": @YES,
            @"returnContext": @"video-context"
        },
        @"navigationExecution": @"not-performed"
    };
    [self.bridgeLock unlock];
    return TiktigerRedactedDiagnosticCopy(snapshot);
}

@end


NSString *TiktigerStringFromTikTokRuntimeLifecycleState(TiktigerTikTokRuntimeLifecycleState state) {
    switch (state) {
        case TiktigerTikTokRuntimeLifecycleStateIdle: return @"idle";
        case TiktigerTikTokRuntimeLifecycleStateInitializing: return @"initializing";
        case TiktigerTikTokRuntimeLifecycleStateReady: return @"ready";
        case TiktigerTikTokRuntimeLifecycleStatePresenting: return @"presenting";
        case TiktigerTikTokRuntimeLifecycleStatePresented: return @"presented";
        case TiktigerTikTokRuntimeLifecycleStateClosing: return @"closing";
        case TiktigerTikTokRuntimeLifecycleStateReturnedToContext: return @"returned-to-context";
        case TiktigerTikTokRuntimeLifecycleStateRecovering: return @"recovering";
        case TiktigerTikTokRuntimeLifecycleStateFailed: return @"failed";
    }
    return @"unknown";
}

NSString *TiktigerStringFromTikTokDownloadFlowState(TiktigerTikTokDownloadFlowState state) {
    switch (state) {
        case TiktigerTikTokDownloadFlowStateContextValidated: return @"context-validated";
        case TiktigerTikTokDownloadFlowStateSmartSheetRequested: return @"smart-sheet-requested";
        case TiktigerTikTokDownloadFlowStateQueued: return @"queued";
        case TiktigerTikTokDownloadFlowStatePreparing: return @"preparing";
        case TiktigerTikTokDownloadFlowStateDownloading: return @"downloading";
        case TiktigerTikTokDownloadFlowStateProcessing: return @"processing";
        case TiktigerTikTokDownloadFlowStateCompleted: return @"completed";
        case TiktigerTikTokDownloadFlowStateFailed: return @"failed";
        case TiktigerTikTokDownloadFlowStateClosed: return @"closed";
        case TiktigerTikTokDownloadFlowStateReturnedToContext: return @"returned-to-context";
    }
    return @"unknown";
}

NSString *TiktigerStringFromTikTokVideoPresentationLifecycleState(TiktigerTikTokVideoPresentationLifecycleState state) {
    switch (state) {
        case TiktigerTikTokVideoPresentationLifecycleStateEntryReceived: return @"entry-received";
        case TiktigerTikTokVideoPresentationLifecycleStatePresentationRequested: return @"presentation-requested";
        case TiktigerTikTokVideoPresentationLifecycleStatePresentationCompleted: return @"presentation-completed";
        case TiktigerTikTokVideoPresentationLifecycleStatePresentationClosed: return @"presentation-closed";
        case TiktigerTikTokVideoPresentationLifecycleStateReturnedToContext: return @"returned-to-context";
        case TiktigerTikTokVideoPresentationLifecycleStateFailed: return @"failed";
    }
    return @"unknown";
}
