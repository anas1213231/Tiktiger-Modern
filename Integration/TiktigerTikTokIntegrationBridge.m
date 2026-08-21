#import "TiktigerTikTokIntegrationBridge.h"
#import "TiktigerHostCoordinator.h"
#import "TiktigerPresentationBridge.h"
#import "TiktigerTikTokIntegrationDiagnostics.h"
#import "TiktigerFeatureRegistry.h"

static NSString * const TiktigerTikTokIntegrationBridgeErrorDomain = @"com.tiktiger.tiktok-integration-bridge";

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
        @"navigationExecution": @"not-performed"
    };
    [self.bridgeLock unlock];
    return TiktigerRedactedDiagnosticCopy(snapshot);
}

@end
