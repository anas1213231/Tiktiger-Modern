#import "TiktigerHostTestRunner.h"
#import <objc/message.h>
#import "../UIBridge/TiktigerNavigationContract.h"

static NSString * const TiktigerHostTestErrorDomain = @"com.tiktiger.host-test";

@interface TiktigerHostTestRunner ()
@property (nonatomic, strong, readwrite) TiktigerHostCoordinator *hostCoordinator;
@property (nonatomic, strong, readwrite) TiktigerPresentationBridge *presentationBridge;
@property (nonatomic, strong, readwrite) TiktigerTikTokIntegrationBridge *integrationBridge;
@property (nonatomic, strong, readwrite) TiktigerTikTokIntegrationDiagnostics *diagnostics;
@property (nonatomic, strong) TiktigerDynamicLibraryLoader *loader;
@property (nonatomic, strong) TiktigerTikTokCompatibility *compatibility;
@property (nonatomic, strong) id binding;
@property (nonatomic, strong) id moduleManager;
@end

@implementation TiktigerHostTestRunner

- (instancetype)init {
    self = [super init];
    if (self) {
        Class loaderClass = NSClassFromString(@"TiktigerDynamicLibraryLoader");
        Class coordinatorClass = NSClassFromString(@"TiktigerHostCoordinator");
        Class moduleManagerClass = NSClassFromString(@"TiktigerModuleManager");
        Class diagnosticsClass = NSClassFromString(@"TiktigerTikTokIntegrationDiagnostics");
        Class compatibilityClass = NSClassFromString(@"TiktigerTikTokCompatibility");
        Class bootstrapClass = NSClassFromString(@"TiktigerFeatureBootstrap");
        Class bindingClass = NSClassFromString(@"TiktigerFeatureBindingAdapter");
        Class presentationClass = NSClassFromString(@"TiktigerPresentationBridge");
        Class bridgeClass = NSClassFromString(@"TiktigerTikTokIntegrationBridge");
        if (loaderClass == Nil || coordinatorClass == Nil || moduleManagerClass == Nil || diagnosticsClass == Nil || compatibilityClass == Nil || bootstrapClass == Nil || bindingClass == Nil || presentationClass == Nil || bridgeClass == Nil) {
            return self;
        }

        id (*LoaderInit)(id, SEL, id, id, id) = (void *)objc_msgSend;
        id loader = LoaderInit([loaderClass alloc], @selector(initWithExpectedVersion:expectedInstallName:expectedArchitecture:), @"1.0.0", @"@rpath/Tiktiger.dylib", @"arm64");
        id (*OneArgInit)(id, SEL, id) = (void *)objc_msgSend;
        id coordinator = OneArgInit([coordinatorClass alloc], @selector(initWithLoader:), loader);
        id moduleManager = [moduleManagerClass new];
        id diagnostics = [diagnosticsClass new];
        id (*CompatibilityInit)(id, SEL, id, id) = (void *)objc_msgSend;
        id compatibility = CompatibilityInit([compatibilityClass alloc], @selector(initWithApprovedProductIdentifier:approvedVersions:), @"com.tiktok.ios", @[@"40.0.0"]);
        NSError *bootstrapError = nil;
        BOOL (*Bootstrap)(id, SEL, id, NSError **) = (void *)objc_msgSend;
        Bootstrap(bootstrapClass, @selector(registerPriorityModulesIntoManager:error:), moduleManager, &bootstrapError);
        id binding = OneArgInit([bindingClass alloc], @selector(initWithModuleManager:), moduleManager);
        id presentation = OneArgInit([presentationClass alloc], @selector(initWithBinding:), binding);
        id (*BridgeInit)(id, SEL, id, id, id, id) = (void *)objc_msgSend;
        id bridge = BridgeInit([bridgeClass alloc], @selector(initWithHostCoordinator:presentationBridge:compatibility:diagnostics:), coordinator, presentation, compatibility, diagnostics);
        _loader = loader;
        _hostCoordinator = coordinator;
        _moduleManager = moduleManager;
        _diagnostics = diagnostics;
        _compatibility = compatibility;
        _binding = binding;
        _presentationBridge = presentation;
        _integrationBridge = bridge;
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
    const char *version = TiktigerGetVersion();
    if (version == NULL || !TiktigerInitialize()) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerHostTestErrorDomain code:10 userInfo:@{NSLocalizedDescriptionKey: @"Public Tiktiger runtime initialization failed in HostTest."}]; }
        return NO;
    }
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
    NSDictionary *dashboardDescriptor = [start[@"dashboard"] isKindOfClass:[NSDictionary class]] ? start[@"dashboard"] : @{};
    BOOL dashboardReady = [dashboardDescriptor[@"surface"] isEqualToString:@"dashboard"] && [dashboardDescriptor[@"state"] isEqualToString:@"ready"];
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
    NSArray<NSString *> *routes = @[
        @"media.download",
        @"privacy.center",
        @"appearance.engine",
        @"chat.center",
        @"profile.center",
        @"system.center",
        @"system.settings"
    ];
    for (NSString *route in routes) {
        NSError *routeError = nil;
        NSDictionary *descriptor = [self.integrationBridge routeHostEventToRoute:route error:&routeError];
        if (descriptor == nil || routeError != nil || ![descriptor[@"navigationExecution"] isEqualToString:@"not-performed"]) {
            if (error != NULL) { *error = routeError ?: [NSError errorWithDomain:TiktigerHostTestErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Route validation failed for %@.", route]}]; }
            return NO;
        }
    }
    NSArray *dashboardCards = [self.binding dashboardFeatureCards];
    NSDictionary *settingsControls = [self.binding settingsFeatureControls];
    NSDictionary *diagnostics = [self.diagnostics snapshot];
    BOOL bindingReady = self.binding != nil && dashboardCards.count > 0 && settingsControls.count > 0;
    BOOL diagnosticsReady = [diagnostics[@"runtimeCount"] unsignedIntegerValue] > 0 && [diagnostics[@"compatibilityCount"] unsignedIntegerValue] > 0;
    if (!bindingReady || !diagnosticsReady) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerHostTestErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Feature Binding status surfaces or integration diagnostics did not expose the expected host-test state."}]; }
        return NO;
    }
    return YES;
}

@end
