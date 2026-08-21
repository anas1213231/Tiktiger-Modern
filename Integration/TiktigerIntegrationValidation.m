#import "TiktigerIntegrationValidation.h"
#import "TiktigerHostCoordinator.h"
#import "TiktigerPresentationBridge.h"
#import "TiktigerNavigationContract.h"
#import "TiktigerFeatureRegistry.h"

@implementation TiktigerIntegrationValidation

+ (NSArray<NSDictionary<NSString *,id> *> *)testCaseDescriptors {
    return TiktigerDeepImmutableCopy(@[
        @{ @"id": @"lifecycle.initialize", @"category": @"lifecycle", @"expectation": @"Single coordinator performs metadata preflight then public initialization." },
        @{ @"id": @"lifecycle.shutdown", @"category": @"lifecycle", @"expectation": @"Observers stop before one idempotent public shutdown." },
        @{ @"id": @"lifecycle.recovery", @"category": @"recovery", @"expectation": @"Failed or degraded preparation state has one bounded recovery attempt." },
        @{ @"id": @"navigation.supported-routes", @"category": @"navigation", @"expectation": @"Every stable route maps to metadata and a feature ID." },
        @{ @"id": @"navigation.unknown-route", @"category": @"navigation", @"expectation": @"Unknown routes are rejected without presentation." },
        @{ @"id": @"binding.dashboard", @"category": @"binding", @"expectation": @"Dashboard entry is read-only and immutable." },
        @{ @"id": @"binding.module-routing", @"category": @"binding", @"expectation": @"Validated routes resolve center state only through Feature Binding." },
        @{ @"id": @"failure.invalid-metadata", @"category": @"recovery", @"expectation": @"Loader rejects product/version/install-name/architecture/signing mismatch." },
        @{ @"id": @"failure.backup-boundary", @"category": @"security", @"expectation": @"Host treats System backup as validated configuration-only data." }
    ]);
}

+ (NSDictionary<NSString *,id> *)runContractChecksWithCoordinator:(TiktigerHostCoordinator *)coordinator presentationBridge:(TiktigerPresentationBridge *)bridge {
    NSMutableArray<NSDictionary<NSString *, id> *> *results = [[NSMutableArray alloc] init];
    BOOL lifecycleReady = coordinator != nil && [coordinator statusSnapshot][@"preparationOnly"] != nil;
    [results addObject:@{ @"id": @"lifecycle.contract", @"status": lifecycleReady ? @"pass" : @"fail", @"executed": @NO }];

    BOOL navigationReady = YES;
    for (NSString *route in TiktigerSupportedNavigationRoutes()) {
        NSDictionary *metadata = TiktigerNavigationMetadataForRoute(route);
        NSString *featureID = TiktigerFeatureIDForNavigationRoute(route);
        if (metadata.count == 0 || featureID.length == 0) { navigationReady = NO; break; }
    }
    [results addObject:@{ @"id": @"navigation.contract", @"status": navigationReady ? @"pass" : @"fail", @"routeCount": @(TiktigerSupportedNavigationRoutes().count), @"executed": @NO }];

    NSError *invalidRouteError = nil;
    NSDictionary *invalidDescriptor = [bridge routingDescriptorForRoute:@"unsupported.route" error:&invalidRouteError];
    BOOL invalidRouteRejected = invalidDescriptor == nil && invalidRouteError != nil;
    [results addObject:@{ @"id": @"navigation.failure-rejection", @"status": invalidRouteRejected ? @"pass" : @"fail", @"executed": @NO }];

    NSDictionary *dashboard = [bridge dashboardPresentationEntry];
    BOOL bindingReady = bridge != nil && [dashboard[@"preparationOnly"] boolValue] && [dashboard[@"targetAppIntegrated"] boolValue] == NO;
    [results addObject:@{ @"id": @"binding.contract", @"status": bindingReady ? @"pass" : @"fail", @"executed": @NO }];

    BOOL allPass = YES;
    for (NSDictionary *result in results) { allPass = allPass && [result[@"status"] isEqualToString:@"pass"]; }
    return TiktigerDeepImmutableCopy(@{
        @"validationMode": @"preparation-only",
        @"targetAppIntegrated": @NO,
        @"runtimeActionsExecuted": @NO,
        @"contractChecksPassed": @(allPass),
        @"results": results,
        @"testCaseDescriptors": [self testCaseDescriptors]
    });
}

@end
