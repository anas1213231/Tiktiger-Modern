#import "TiktigerPresentationBridge.h"
#import "TiktigerNavigationContract.h"
#import "TiktigerFeatureRegistry.h"

static NSString * const TiktigerPresentationBridgeErrorDomain = @"com.tiktiger.presentation-bridge";

@interface TiktigerPresentationBridge ()
@property (nonatomic, weak, readwrite) id<TiktigerFeatureBinding> binding;
@end

@implementation TiktigerPresentationBridge

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding>)binding {
    self = [super init];
    if (self) { _binding = binding; }
    return self;
}

- (NSDictionary<NSString *,id> *)dashboardPresentationEntry {
    NSDictionary *entry = @{
        @"surface": @"dashboard",
        @"state": @"ready",
        @"featureCards": [self.binding dashboardFeatureCards] ?: @[],
        @"supportedRoutes": TiktigerSupportedNavigationRoutes(),
        @"preparationOnly": @YES,
        @"targetAppIntegrated": @NO
    };
    return TiktigerDeepImmutableCopy(entry);
}

- (NSDictionary<NSString *,id> *)metadataForRoute:(NSString *)route error:(NSError **)error {
    NSDictionary *metadata = TiktigerNavigationMetadataForRoute(route);
    if (metadata.count == 0) {
        NSError *routeError = [NSError errorWithDomain:TiktigerPresentationBridgeErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"The requested navigation route is not supported by the Tiktiger preparation contract."}];
        if (error != NULL) { *error = routeError; }
        return nil;
    }
    return TiktigerDeepImmutableCopy(metadata);
}

- (NSString *)featureIDForRoute:(NSString *)route error:(NSError **)error {
    if ([self metadataForRoute:route error:error] == nil) { return nil; }
    return TiktigerFeatureIDForNavigationRoute(route);
}

- (NSDictionary<NSString *,id> *)presentationStateForRoute:(NSString *)route error:(NSError **)error {
    NSString *featureID = [self featureIDForRoute:route error:error];
    if (featureID.length == 0 || self.binding == nil) { return nil; }
    NSDictionary *state = nil;
    if ([featureID isEqualToString:@"media.download"]) {
        state = [self.binding downloadPresentationState];
    } else if ([featureID isEqualToString:@"privacy.center"]) {
        state = [self.binding privacyPresentationState];
    } else if ([featureID isEqualToString:@"appearance.engine"]) {
        state = [self.binding appearancePresentationState];
    } else if ([featureID isEqualToString:@"chat.center"]) {
        state = [self.binding chatPresentationState];
    } else if ([featureID isEqualToString:@"profile.center"]) {
        state = [self.binding profilePresentationState];
    } else if ([featureID isEqualToString:@"system.center"]) {
        state = [self.binding systemPresentationState];
    }
    if (state == nil) {
        NSError *stateError = [NSError errorWithDomain:TiktigerPresentationBridgeErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"No presentation state is registered for the validated route."}];
        if (error != NULL) { *error = stateError; }
        return nil;
    }
    return TiktigerDeepImmutableCopy(state);
}

- (NSDictionary<NSString *,id> *)routingDescriptorForRoute:(NSString *)route error:(NSError **)error {
    NSDictionary *metadata = [self metadataForRoute:route error:error];
    if (metadata == nil) { return nil; }
    NSString *featureID = TiktigerFeatureIDForNavigationRoute(route);
    return TiktigerDeepImmutableCopy(@{
        @"route": route ?: @"",
        @"featureID": featureID ?: @"",
        @"metadata": metadata,
        @"presentationMode": @"host-owned",
        @"navigationExecution": @"not-performed",
        @"preparationOnly": @YES
    });
}

@end
