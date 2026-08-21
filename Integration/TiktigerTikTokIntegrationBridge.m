#import "TiktigerTikTokIntegrationBridge.h"
#import "TiktigerHostCoordinator.h"
#import "TiktigerPresentationBridge.h"
#import "TiktigerTikTokIntegrationDiagnostics.h"
#import "TiktigerFeatureRegistry.h"

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

@interface TiktigerTikTokIntegrationBridge ()
@property (nonatomic, weak, readwrite) TiktigerHostCoordinator *hostCoordinator;
@property (nonatomic, weak, readwrite) TiktigerPresentationBridge *presentationBridge;
@property (nonatomic, strong, readwrite) TiktigerTikTokCompatibility *compatibility;
@property (nonatomic, strong, readwrite) TiktigerTikTokIntegrationDiagnostics *diagnostics;
@property (nonatomic, strong) NSLock *bridgeLock;
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
    }
    return self;
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
        @"navigationExecution": @"not-performed"
    };
    [self.bridgeLock unlock];
    return TiktigerRedactedDiagnosticCopy(snapshot);
}

@end


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
