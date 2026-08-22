#import "TiktigerHostTestRunner.h"
#import "../Features/TiktigerFeatureBootstrap.h"
#import "../Features/TiktigerModuleManager.h"
#import "../UIBridge/TiktigerFeatureBindingAdapter.h"
#import "../UIBridge/TiktigerNavigationContract.h"

static NSString * const TiktigerHostTestErrorDomain = @"com.tiktiger.host-test";

@interface TiktigerHostTestRunner ()
@property (nonatomic, strong, readwrite) TiktigerHostCoordinator *hostCoordinator;
@property (nonatomic, strong, readwrite) TiktigerPresentationBridge *presentationBridge;
@property (nonatomic, strong, readwrite) TiktigerTikTokIntegrationBridge *integrationBridge;
@property (nonatomic, strong, readwrite) TiktigerTikTokIntegrationDiagnostics *diagnostics;
@property (nonatomic, strong) TiktigerDynamicLibraryLoader *loader;
@property (nonatomic, strong) TiktigerTikTokCompatibility *compatibility;
@property (nonatomic, strong) TiktigerFeatureBindingAdapter *binding;
@property (nonatomic, strong) TiktigerModuleManager *moduleManager;
@end

@implementation TiktigerHostTestRunner

- (instancetype)init {
    self = [super init];
    if (self) {
        _loader = [[TiktigerDynamicLibraryLoader alloc] initWithExpectedVersion:@"1.0.0"
                                                            expectedInstallName:@"@rpath/Tiktiger.dylib"
                                                               expectedArchitecture:@"arm64"];
        _hostCoordinator = [[TiktigerHostCoordinator alloc] initWithLoader:_loader];
        _moduleManager = [[TiktigerModuleManager alloc] init];
        _diagnostics = [[TiktigerTikTokIntegrationDiagnostics alloc] init];
        _compatibility = [[TiktigerTikTokCompatibility alloc] initWithApprovedProductIdentifier:@"com.tiktok.ios"
                                                                                approvedVersions:@[@"40.0.0"]];
        NSError *bootstrapError = nil;
        [TiktigerFeatureBootstrap registerPriorityModulesIntoManager:_moduleManager error:&bootstrapError];
        _binding = [[TiktigerFeatureBindingAdapter alloc] initWithModuleManager:_moduleManager];
        _presentationBridge = [[TiktigerPresentationBridge alloc] initWithBinding:_binding];
        _integrationBridge = [[TiktigerTikTokIntegrationBridge alloc] initWithHostCoordinator:_hostCoordinator
                                                                            presentationBridge:_presentationBridge
                                                                                 compatibility:_compatibility
                                                                                   diagnostics:_diagnostics];
        (void)bootstrapError;
    }
    return self;
}

- (NSDictionary<NSString *,id> *)validArtifactMetadata {
    return @{
        @"version": @"1.0.0",
        @"installName": @"@rpath/Tiktiger.dylib",
        @"architecture": @"arm64",
        @"product": @"Tiktiger.dylib",
        @"signed": @YES,
        @"loaded": @YES
    };
}

- (NSDictionary<NSString *,id> *)validCompatibilityMetadata {
    return @{
        @"productIdentifier": @"com.tiktok.ios",
        @"version": @"40.0.0",
        @"build": @"host-test-1",
        @"metadataAvailable": @YES,
        @"capabilitySnapshot": @{
            @"navigation": @YES,
            @"dashboard": @YES,
            @"media": @YES
        }
    };
}

- (NSDictionary<NSString *,id> *)validVideoContext {
    return @{
        @"sourceAvailable": @YES,
        @"permissionGranted": @YES,
        @"mediaCapability": @YES,
        @"preparing": @NO,
        @"sourceURL": @"https://host-test.invalid/video/verified-context"
    };
}

- (BOOL)prepareWithError:(NSError **)error {
    NSDictionary *descriptor = [self.integrationBridge initializeRuntimeWithArtifactMetadata:[self validArtifactMetadata] error:error];
    return [descriptor[@"runtimeLifecycleState"] isEqualToString:@"ready"] && self.hostCoordinator.runtimeState == TiktigerRuntimeStateReady;
}

- (NSDictionary<NSString *,id> *)runLifecycleValidation:(NSError **)error {
    if (![self prepareWithError:error]) { return @{}; }
    NSDictionary *metadata = @{
        @"compatibilityMetadata": [self validCompatibilityMetadata],
        @"navigationAvailable": @YES
    };
    NSDictionary *start = [self.integrationBridge startRuntimeExperienceForVideoContext:[self validVideoContext]
                                                                                 metadata:metadata
                                                                          artifactMetadata:nil
                                                                                      error:error];
    BOOL presenting = [start[@"runtimeLifecycleState"] isEqualToString:@"presenting"];
    NSDictionary *dashboard = start[@"dashboard"];
    BOOL dashboardReady = [dashboard[@"surface"] isEqualToString:@"dashboard"];
    NSDictionary *presented = [self.integrationBridge presentRuntimeExperienceForEntry:start hostEvent:@{ @"host": @"controlled-host" } error:error];
    BOOL presentedReady = [presented[@"runtimeLifecycleState"] isEqualToString:@"presented"];
    NSDictionary *closed = [self.integrationBridge closeRuntimeExperienceWithReason:@"host-test-close" error:error];
    BOOL closedReady = [closed[@"runtimeLifecycleState"] isEqualToString:@"closing"];
    NSDictionary *returned = [self.integrationBridge returnToTikTokRuntimeContext:@{ @"host": @"controlled-host" } error:error];
    BOOL returnedReady = [returned[@"runtimeLifecycleState"] isEqualToString:@"returned-to-context"];
    NSError *shutdownError = nil;
    BOOL shutdown = [self.hostCoordinator shutdownHost:&shutdownError];
    if (!shutdown && error != NULL && *error == nil) { *error = shutdownError; }
    BOOL result = presenting && dashboardReady && presentedReady && closedReady && returnedReady && shutdown;
    return @{
        @"test": @"runtime-lifecycle",
        @"passed": @(result),
        @"initialize": @"ready",
        @"presentation": @(presentedReady),
        @"dashboard": @(dashboardReady),
        @"close": @(closedReady),
        @"returnToContext": @(returnedReady),
        @"shutdown": @(shutdown),
        @"runtimeState": [self.hostCoordinator statusSnapshot][@"runtimeState"] ?: @"unknown"
    };
}

- (NSDictionary<NSString *,id> *)runCompatibilityRecoveryValidation:(NSError **)error {
    if (![self prepareWithError:error]) { return @{}; }
    NSDictionary *unsupportedMetadata = @{
        @"compatibilityMetadata": @{
            @"productIdentifier": @"com.tiktok.ios",
            @"version": @"0.0.0-host-test",
            @"build": @"unsupported",
            @"metadataAvailable": @YES,
            @"capabilitySnapshot": @{ @"navigation": @YES, @"dashboard": @YES, @"media": @YES }
        },
        @"navigationAvailable": @YES
    };
    NSDictionary *failed = [self.integrationBridge startRuntimeExperienceForVideoContext:[self validVideoContext]
                                                                                   metadata:unsupportedMetadata
                                                                            artifactMetadata:nil
                                                                                        error:NULL];
    BOOL rejected = [failed[@"runtimeLifecycleState"] isEqualToString:@"failed"];
    NSDictionary *recovered = [self.integrationBridge recoverRuntimeWithArtifactMetadata:nil reason:@"host-test-recovery" error:error];
    BOOL recoveryReady = [recovered[@"runtimeLifecycleState"] isEqualToString:@"ready"];
    NSError *shutdownError = nil;
    BOOL shutdown = [self.hostCoordinator shutdownHost:&shutdownError];
    if (!shutdown && error != NULL && *error == nil) { *error = shutdownError; }
    return @{
        @"test": @"compatibility-and-recovery",
        @"passed": @(rejected && recoveryReady && shutdown),
        @"unsupportedRejected": @(rejected),
        @"recovery": @(recoveryReady),
        @"shutdown": @(shutdown)
    };
}

- (BOOL)validateBindingRoutesAndDiagnostics:(NSError **)error {
    NSDictionary *dashboard = [self.presentationBridge dashboardPresentationEntry];
    if (![dashboard[@"surface"] isEqualToString:@"dashboard"]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerHostTestErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Dashboard presentation contract did not return the dashboard surface."}]; }
        return NO;
    }
    NSArray<NSString *> *routes = TiktigerSupportedNavigationRoutes();
    for (NSString *route in routes) {
        NSError *routeError = nil;
        NSDictionary *descriptor = [self.integrationBridge routeHostEventToRoute:route error:&routeError];
        if (descriptor == nil || routeError != nil || ![descriptor[@"navigationExecution"] isEqualToString:@"not-performed"]) {
            if (error != NULL) { *error = routeError ?: [NSError errorWithDomain:TiktigerHostTestErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Route validation failed for %@.", route]}]; }
            return NO;
        }
    }
    NSDictionary *health = [self.binding diagnosticsModuleHealth];
    NSDictionary *diagnostics = [self.diagnostics snapshot];
    BOOL bindingReady = self.binding != nil && health.count > 0;
    BOOL diagnosticsReady = [diagnostics[@"runtimeCount"] unsignedIntegerValue] > 0 && [diagnostics[@"compatibilityCount"] unsignedIntegerValue] > 0;
    if (!bindingReady || !diagnosticsReady) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerHostTestErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Feature Binding or integration diagnostics did not expose the expected host-test state."}]; }
        return NO;
    }
    return YES;
}

@end
