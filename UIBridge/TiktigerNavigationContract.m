#import "TiktigerNavigationContract.h"

NSString * const TiktigerNavigationRouteDownload = @"media.download";
NSString * const TiktigerNavigationRoutePrivacy = @"privacy.center";
NSString * const TiktigerNavigationRouteAppearance = @"appearance.engine";
NSString * const TiktigerNavigationRouteChat = @"chat.center";
NSString * const TiktigerNavigationRouteProfile = @"profile.center";
NSString * const TiktigerNavigationRouteSystem = @"system.center";
NSString * const TiktigerNavigationRouteSystemSettings = @"system.settings";

static NSDictionary<NSString *, NSDictionary<NSString *, id> *> *TiktigerNavigationDefinitions(void) {
    static NSDictionary<NSString *, NSDictionary<NSString *, id> *> *definitions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        definitions = @{
            TiktigerNavigationRouteDownload: @{@"route": TiktigerNavigationRouteDownload, @"featureID": TiktigerNavigationRouteDownload, @"surface": @"Download Center", @"category": @"media"},
            TiktigerNavigationRoutePrivacy: @{@"route": TiktigerNavigationRoutePrivacy, @"featureID": TiktigerNavigationRoutePrivacy, @"surface": @"Privacy Center", @"category": @"privacy"},
            TiktigerNavigationRouteAppearance: @{@"route": TiktigerNavigationRouteAppearance, @"featureID": TiktigerNavigationRouteAppearance, @"surface": @"Appearance Engine", @"category": @"appearance"},
            TiktigerNavigationRouteChat: @{@"route": TiktigerNavigationRouteChat, @"featureID": TiktigerNavigationRouteChat, @"surface": @"Chat Center", @"category": @"chat"},
            TiktigerNavigationRouteProfile: @{@"route": TiktigerNavigationRouteProfile, @"featureID": TiktigerNavigationRouteProfile, @"surface": @"Profile Center", @"category": @"profile"},
            TiktigerNavigationRouteSystem: @{@"route": TiktigerNavigationRouteSystem, @"featureID": TiktigerNavigationRouteSystem, @"surface": @"System Center", @"category": @"system"},
            TiktigerNavigationRouteSystemSettings: @{@"route": TiktigerNavigationRouteSystemSettings, @"featureID": TiktigerNavigationRouteSystem, @"surface": @"System Settings", @"category": @"system", @"parentRoute": TiktigerNavigationRouteSystem}
        };
    });
    return definitions;
}

NSArray<NSString *> *TiktigerSupportedNavigationRoutes(void) {
    return [TiktigerNavigationDefinitions().allKeys sortedArrayUsingSelector:@selector(compare:)];
}

BOOL TiktigerIsSupportedNavigationRoute(NSString *route) {
    return route.length > 0 && TiktigerNavigationDefinitions()[route] != nil;
}

NSString *TiktigerNavigationRouteForFeatureID(NSString *featureID) {
    if ([featureID isEqualToString:TiktigerNavigationRouteDownload]) { return TiktigerNavigationRouteDownload; }
    if ([featureID isEqualToString:TiktigerNavigationRoutePrivacy]) { return TiktigerNavigationRoutePrivacy; }
    if ([featureID isEqualToString:TiktigerNavigationRouteAppearance]) { return TiktigerNavigationRouteAppearance; }
    if ([featureID isEqualToString:TiktigerNavigationRouteChat]) { return TiktigerNavigationRouteChat; }
    if ([featureID isEqualToString:TiktigerNavigationRouteProfile]) { return TiktigerNavigationRouteProfile; }
    if ([featureID isEqualToString:TiktigerNavigationRouteSystem]) { return TiktigerNavigationRouteSystem; }
    return nil;
}

NSString *TiktigerFeatureIDForNavigationRoute(NSString *route) {
    return TiktigerNavigationDefinitions()[route][@"featureID"];
}

NSDictionary<NSString *, id> *TiktigerNavigationMetadataForRoute(NSString *route) {
    NSDictionary *metadata = TiktigerNavigationDefinitions()[route];
    return metadata != nil ? [metadata copy] : @{};
}
