#import "TiktigerTikTokEntryPoint.h"
#import "TiktigerFeatureRegistry.h"

static NSString * const TiktigerTikTokEntryPointErrorDomain = @"com.tiktiger.tiktok-entry-point";

@implementation TiktigerTikTokEntryPointContract

+ (NSArray<NSString *> *)supportedEntryPointIdentifiers {
    return @[ @"video.action", @"share.menu", @"profile.settings" ];
}

+ (NSString *)identifierForEntryPointKind:(TiktigerTikTokEntryPointKind)kind {
    switch (kind) {
        case TiktigerTikTokEntryPointKindVideoAction: return @"video.action";
        case TiktigerTikTokEntryPointKindShareMenu: return @"share.menu";
        case TiktigerTikTokEntryPointKindProfileSettings: return @"profile.settings";
    }
    return @"unknown";
}

+ (BOOL)entryPointKindForIdentifier:(NSString *)identifier kind:(TiktigerTikTokEntryPointKind *)kind {
    if ([identifier isEqualToString:@"video.action"]) {
        if (kind != NULL) { *kind = TiktigerTikTokEntryPointKindVideoAction; }
        return YES;
    }
    if ([identifier isEqualToString:@"share.menu"]) {
        if (kind != NULL) { *kind = TiktigerTikTokEntryPointKindShareMenu; }
        return YES;
    }
    if ([identifier isEqualToString:@"profile.settings"]) {
        if (kind != NULL) { *kind = TiktigerTikTokEntryPointKindProfileSettings; }
        return YES;
    }
    return NO;
}

+ (NSDictionary<NSString *,id> *)evaluateEntryPoint:(TiktigerTikTokEntryPointKind)kind context:(NSDictionary<NSString *,id> *)context compatibilityProfile:(NSString *)compatibilityProfile navigationAvailable:(BOOL)navigationAvailable runtimeReady:(BOOL)runtimeReady error:(NSError **)error {
    NSString *identifier = [self identifierForEntryPointKind:kind];
    if ([identifier isEqualToString:@"unknown"]) {
        NSError *kindError = [NSError errorWithDomain:TiktigerTikTokEntryPointErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Unknown TikTok entry point kind."}];
        if (error != NULL) { *error = kindError; }
        return @{};
    }
    NSString *profile = [compatibilityProfile isKindOfClass:[NSString class]] ? compatibilityProfile : @"error";
    BOOL sourceAvailable = ![context[@"sourceAvailable"] isKindOfClass:[NSNumber class]] || [context[@"sourceAvailable"] boolValue];
    BOOL permissionGranted = ![context[@"permissionGranted"] isKindOfClass:[NSNumber class]] || [context[@"permissionGranted"] boolValue];
    BOOL preparing = [context[@"preparing"] isKindOfClass:[NSNumber class]] && [context[@"preparing"] boolValue];
    BOOL mediaEntry = kind == TiktigerTikTokEntryPointKindVideoAction || kind == TiktigerTikTokEntryPointKindShareMenu;
    NSString *state = @"available";
    NSString *reason = @"ready-for-user-confirmation";
    BOOL available = YES;
    if (!runtimeReady) {
        available = NO; state = @"unavailable"; reason = @"runtime-not-ready";
    } else if (!navigationAvailable) {
        available = NO; state = @"unavailable"; reason = @"host-navigation-unavailable";
    } else if ([profile isEqualToString:@"unsupported"] || [profile isEqualToString:@"unknown"] || [profile isEqualToString:@"error"]) {
        available = NO; state = @"unavailable"; reason = [profile isEqualToString:@"unsupported"] ? @"host-version-unsupported" : @"host-compatibility-unknown";
    } else if (mediaEntry && !sourceAvailable) {
        available = NO; state = @"unavailable"; reason = @"source-metadata-unavailable";
    } else if (mediaEntry && !permissionGranted) {
        available = NO; state = @"unavailable"; reason = @"host-permission-unavailable";
    } else if (preparing) {
        state = @"preparing"; reason = @"host-context-preparing";
    } else if ([profile isEqualToString:@"supported-limited"] && mediaEntry && ![context[@"mediaCapability"] boolValue]) {
        available = NO; state = @"unavailable"; reason = @"media-capability-limited";
    }
    NSString *surface = mediaEntry ? @"download-sheet" : @"dashboard";
    NSDictionary *descriptor = @{
        @"entryPoint": identifier,
        @"entryPointState": state,
        @"available": @(available),
        @"reason": reason,
        @"compatibilityProfile": profile,
        @"presentationSurface": surface,
        @"navigationRequired": @YES,
        @"userAction": @"not-executed",
        @"fakeButton": @NO,
        @"targetAppIntegrated": @NO,
        @"hostContext": context ?: @{}
    };
    return TiktigerDeepImmutableCopy(descriptor);
}

@end

NSString *TiktigerStringFromTikTokEntryPointKind(TiktigerTikTokEntryPointKind kind) {
    switch (kind) {
        case TiktigerTikTokEntryPointKindVideoAction: return @"video-action";
        case TiktigerTikTokEntryPointKindShareMenu: return @"share-menu";
        case TiktigerTikTokEntryPointKindProfileSettings: return @"profile-settings";
    }
    return @"unknown";
}

NSString *TiktigerStringFromTikTokEntryPointState(TiktigerTikTokEntryPointState state) {
    switch (state) {
        case TiktigerTikTokEntryPointStateUnavailable: return @"unavailable";
        case TiktigerTikTokEntryPointStateAvailable: return @"available";
        case TiktigerTikTokEntryPointStatePreparing: return @"preparing";
        case TiktigerTikTokEntryPointStateFailed: return @"failed";
    }
    return @"unknown";
}
