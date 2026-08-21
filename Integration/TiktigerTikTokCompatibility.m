#import "TiktigerTikTokCompatibility.h"
#import "TiktigerFeatureRegistry.h"

static NSString * const TiktigerTikTokCompatibilityErrorDomain = @"com.tiktiger.tiktok-compatibility";

@interface TiktigerTikTokCompatibility ()
@property (nonatomic, copy, readwrite) NSString *approvedProductIdentifier;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *approvedVersions;
@property (nonatomic, strong) NSLock *compatibilityLock;
@property (nonatomic, copy) NSDictionary<NSString *, id> *lastResult;
@end

@implementation TiktigerTikTokCompatibility

- (instancetype)initWithApprovedProductIdentifier:(NSString *)productIdentifier approvedVersions:(NSArray<NSString *> *)versions {
    self = [super init];
    if (self) {
        _approvedProductIdentifier = [productIdentifier copy];
        _approvedVersions = [versions copy];
        _compatibilityLock = [[NSLock alloc] init];
        _lastResult = @{};
    }
    return self;
}

- (TiktigerTikTokCompatibilityProfile)evaluateMetadata:(NSDictionary<NSString *,id> *)metadata result:(NSDictionary<NSString *,id> **)result error:(NSError **)error {
    [self.compatibilityLock lock];
    NSString *product = [metadata[@"productIdentifier"] isKindOfClass:[NSString class]] ? metadata[@"productIdentifier"] : @"";
    NSString *version = [metadata[@"version"] isKindOfClass:[NSString class]] ? metadata[@"version"] : @"";
    NSString *build = [metadata[@"build"] isKindOfClass:[NSString class]] ? metadata[@"build"] : @"";
    NSDictionary *capabilities = [metadata[@"capabilitySnapshot"] isKindOfClass:[NSDictionary class]] ? metadata[@"capabilitySnapshot"] : nil;
    BOOL metadataAvailable = ![metadata[@"metadataAvailable"] isKindOfClass:[NSNumber class]] || [metadata[@"metadataAvailable"] boolValue];
    TiktigerTikTokCompatibilityProfile profile = TiktigerTikTokCompatibilityProfileError;
    NSString *reason = @"metadata-invalid";
    if (!metadataAvailable || product.length == 0 || version.length == 0 || capabilities == nil) {
        profile = metadataAvailable ? TiktigerTikTokCompatibilityProfileUnknown : TiktigerTikTokCompatibilityProfileError;
        reason = metadataAvailable ? @"version-or-capability-metadata-missing" : @"host-metadata-unavailable";
    } else if (![product isEqualToString:self.approvedProductIdentifier]) {
        profile = TiktigerTikTokCompatibilityProfileUnsupported;
        reason = @"host-product-not-approved";
    } else if (![self.approvedVersions containsObject:version]) {
        profile = TiktigerTikTokCompatibilityProfileUnsupported;
        reason = @"host-version-not-approved";
    } else {
        BOOL navigation = [capabilities[@"navigation"] isKindOfClass:[NSNumber class]] && [capabilities[@"navigation"] boolValue];
        BOOL dashboard = [capabilities[@"dashboard"] isKindOfClass:[NSNumber class]] && [capabilities[@"dashboard"] boolValue];
        BOOL media = [capabilities[@"media"] isKindOfClass:[NSNumber class]] && [capabilities[@"media"] boolValue];
        if (navigation && dashboard && media) {
            profile = TiktigerTikTokCompatibilityProfileSupported;
            reason = @"approved-host-and-capabilities";
        } else {
            profile = TiktigerTikTokCompatibilityProfileSupportedLimited;
            reason = @"approved-host-with-limited-capabilities";
        }
    }
    NSDictionary *snapshot = @{
        @"compatibilityProfile": TiktigerStringFromTikTokCompatibilityProfile(profile),
        @"productIdentifier": product,
        @"version": version,
        @"build": build,
        @"reason": reason,
        @"capabilitySnapshot": capabilities ?: @{},
        @"safeFallback": profile == TiktigerTikTokCompatibilityProfileSupported ? @"full-entry-points" : (profile == TiktigerTikTokCompatibilityProfileSupportedLimited ? @"limited-entry-points" : (profile == TiktigerTikTokCompatibilityProfileUnknown ? @"read-only-dashboard-or-hidden-entry" : @"no-entry-points")),
        @"privateHostIntrospection": @NO,
        @"targetAppIntegrated": @NO
    };
    self.lastResult = TiktigerDeepImmutableCopy(snapshot);
    NSDictionary *immutableResult = TiktigerDeepImmutableCopy(snapshot);
    [self.compatibilityLock unlock];
    if (result != NULL) { *result = immutableResult; }
    if (profile == TiktigerTikTokCompatibilityProfileError && error != NULL) {
        *error = [NSError errorWithDomain:TiktigerTikTokCompatibilityErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: reason}];
    }
    return profile;
}

- (NSDictionary<NSString *,id> *)compatibilitySnapshot {
    [self.compatibilityLock lock];
    NSDictionary *snapshot = @{
        @"approvedProductIdentifier": self.approvedProductIdentifier ?: @"",
        @"approvedVersions": self.approvedVersions ?: @[],
        @"lastResult": self.lastResult ?: @{},
        @"preparationOnly": @YES,
        @"targetAppIntegrated": @NO
    };
    [self.compatibilityLock unlock];
    return TiktigerDeepImmutableCopy(snapshot);
}

@end

NSString *TiktigerStringFromTikTokCompatibilityProfile(TiktigerTikTokCompatibilityProfile profile) {
    switch (profile) {
        case TiktigerTikTokCompatibilityProfileSupported: return @"supported";
        case TiktigerTikTokCompatibilityProfileSupportedLimited: return @"supported-limited";
        case TiktigerTikTokCompatibilityProfileUnknown: return @"unknown";
        case TiktigerTikTokCompatibilityProfileUnsupported: return @"unsupported";
        case TiktigerTikTokCompatibilityProfileError: return @"error";
    }
    return @"error";
}
