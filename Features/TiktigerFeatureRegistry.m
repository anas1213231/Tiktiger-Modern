#import "TiktigerFeatureRegistry.h"

static NSString * const TiktigerFeatureRegistryErrorDomain = @"com.tiktiger.features";

id TiktigerDeepImmutableCopy(id object) {
    if (object == nil || object == [NSNull null]) { return object; }
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:[object count]];
        [object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            id copiedKey = [key conformsToProtocol:@protocol(NSCopying)] ? [key copy] : key;
            id copiedValue = TiktigerDeepImmutableCopy(value);
            if (copiedKey != nil && copiedValue != nil) { result[copiedKey] = copiedValue; }
        }];
        return [result copy];
    }
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:[object count]];
        for (id value in object) { id copiedValue = TiktigerDeepImmutableCopy(value); if (copiedValue != nil) { [result addObject:copiedValue]; } }
        return [result copy];
    }
    if ([object isKindOfClass:[NSSet class]]) {
        NSMutableSet *result = [[NSMutableSet alloc] initWithCapacity:[object count]];
        for (id value in object) { id copiedValue = TiktigerDeepImmutableCopy(value); if (copiedValue != nil) { [result addObject:copiedValue]; } }
        return [result copy];
    }
    return [object conformsToProtocol:@protocol(NSCopying)] ? [object copy] : object;
}

NSString *TiktigerRedactedDiagnosticString(NSString *value) {
    NSString *result = [value isKindOfClass:[NSString class]] ? value : @"";
    NSArray<NSString *> *patterns = @[
        @"https?://[^\\s\\]\\)\\}]+",
        @"(?<![A-Za-z0-9])/(?:Users|private|var|tmp|home)/[^\\s\\]\\)\\}]+"
    ];
    for (NSString *pattern in patterns) {
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
        result = [expression stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:@"[redacted]"];
    }
    return [[result stringByReplacingOccurrencesOfString:@"\r" withString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

id TiktigerRedactedDiagnosticCopy(id object) {
    if (object == nil || object == [NSNull null]) { return object; }
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:[object count]];
        [object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            id copiedKey = [key conformsToProtocol:@protocol(NSCopying)] ? [key copy] : key;
            id copiedValue = TiktigerRedactedDiagnosticCopy(value);
            if (copiedKey != nil && copiedValue != nil) { result[copiedKey] = copiedValue; }
        }];
        return TiktigerDeepImmutableCopy(result);
    }
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:[object count]];
        for (id value in object) { id copiedValue = TiktigerRedactedDiagnosticCopy(value); if (copiedValue != nil) { [result addObject:copiedValue]; } }
        return TiktigerDeepImmutableCopy(result);
    }
    if ([object isKindOfClass:[NSString class]]) { return TiktigerRedactedDiagnosticString(object); }
    return TiktigerDeepImmutableCopy(object);
}

NSDictionary<NSString *, id> *TiktigerRedactedErrorDictionary(NSError *error, NSString *category) {
    if (error == nil) { return @{}; }
    return @{
        @"category": TiktigerRedactedDiagnosticString(category ?: @"general"),
        @"domain": TiktigerRedactedDiagnosticString(error.domain),
        @"code": @(error.code),
        @"message": TiktigerRedactedDiagnosticString(error.localizedDescription),
        @"redacted": @YES
    };
}

@interface TiktigerFeatureRegistry ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<TiktigerFeatureProtocol>> *features;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<TiktigerFeatureModuleProtocol>> *modules;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation TiktigerFeatureRegistry

- (instancetype)init {
    self = [super init];
    if (self) {
        _features = [[NSMutableDictionary alloc] init];
        _modules = [[NSMutableDictionary alloc] init];
        _queue = dispatch_queue_create("com.tiktiger.feature-registry", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (BOOL)registerFeature:(id<TiktigerFeatureProtocol>)feature error:(NSError **)error {
    if (feature.featureID.length == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureRegistryErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Feature ID is required."}]; }
        return NO;
    }
    __block BOOL success = NO;
    dispatch_barrier_sync(self.queue, ^{
        if (self.features[feature.featureID] == nil) { self.features[feature.featureID] = feature; success = YES; }
    });
    if (!success && error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureRegistryErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"A feature with this ID is already registered."}]; }
    return success;
}

- (BOOL)removeFeatureWithID:(NSString *)featureID error:(NSError **)error {
    __block BOOL existed = NO;
    dispatch_barrier_sync(self.queue, ^{ existed = self.features[featureID] != nil; [self.features removeObjectForKey:featureID]; });
    if (!existed && error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureRegistryErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"The requested feature is not registered."}]; }
    return existed;
}

- (id<TiktigerFeatureProtocol>)featureWithID:(NSString *)featureID {
    __block id<TiktigerFeatureProtocol> feature = nil;
    dispatch_sync(self.queue, ^{ feature = self.features[featureID]; });
    return feature;
}

- (NSDictionary<NSString *,NSDictionary<NSString *,id> *> *)statusSnapshot {
    __block NSDictionary *snapshot = nil;
    dispatch_sync(self.queue, ^{
        NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:self.features.count];
        [self.features enumerateKeysAndObjectsUsingBlock:^(NSString *key, id<TiktigerFeatureProtocol> feature, BOOL *stop) {
            result[key] = TiktigerDeepImmutableCopy(@{ @"id": feature.featureID ?: @"", @"name": feature.name ?: @"", @"version": feature.version ?: @"", @"state": @(feature.state), @"configuration": feature.configuration ?: @{} });
        }];
        snapshot = [result copy];
    });
    return snapshot;
}

- (BOOL)registerModule:(id<TiktigerFeatureModuleProtocol>)module error:(NSError **)error {
    if (module.featureID.length == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureRegistryErrorDomain code:10 userInfo:@{NSLocalizedDescriptionKey: @"Module Feature ID is required."}]; }
        return NO;
    }
    __block BOOL success = NO;
    dispatch_barrier_sync(self.queue, ^{
        if (self.modules[module.featureID] == nil) { self.modules[module.featureID] = module; success = YES; }
    });
    if (!success && error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureRegistryErrorDomain code:11 userInfo:@{NSLocalizedDescriptionKey: @"A module with this ID is already registered."}]; }
    return success;
}

- (BOOL)removeModuleWithID:(NSString *)featureID error:(NSError **)error {
    __block BOOL existed = NO;
    dispatch_barrier_sync(self.queue, ^{ existed = self.modules[featureID] != nil; [self.modules removeObjectForKey:featureID]; });
    if (!existed && error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureRegistryErrorDomain code:12 userInfo:@{NSLocalizedDescriptionKey: @"The requested module is not registered."}]; }
    return existed;
}

- (id<TiktigerFeatureModuleProtocol>)moduleWithID:(NSString *)featureID {
    __block id<TiktigerFeatureModuleProtocol> module = nil;
    dispatch_sync(self.queue, ^{ module = self.modules[featureID]; });
    return module;
}

- (BOOL)enableModuleWithID:(NSString *)featureID error:(NSError **)error {
    id<TiktigerFeatureModuleProtocol> module = [self moduleWithID:featureID];
    if (module == nil) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureRegistryErrorDomain code:13 userInfo:@{NSLocalizedDescriptionKey: @"The requested module is not registered."}]; }
        return NO;
    }
    return [module enable:error];
}

- (BOOL)disableModuleWithID:(NSString *)featureID error:(NSError **)error {
    id<TiktigerFeatureModuleProtocol> module = [self moduleWithID:featureID];
    if (module == nil) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureRegistryErrorDomain code:14 userInfo:@{NSLocalizedDescriptionKey: @"The requested module is not registered."}]; }
        return NO;
    }
    return [module disable:error];
}

- (NSDictionary<NSString *,NSDictionary<NSString *,id> *> *)moduleStatusSnapshot {
    __block NSDictionary *snapshot = nil;
    dispatch_sync(self.queue, ^{
        NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:self.modules.count];
        [self.modules enumerateKeysAndObjectsUsingBlock:^(NSString *key, id<TiktigerFeatureModuleProtocol> module, BOOL *stop) {
            result[key] = TiktigerDeepImmutableCopy(@{ @"id": module.featureID ?: @"", @"name": module.name ?: @"", @"version": module.version ?: @"", @"state": TiktigerStringFromFeatureModuleState(module.state), @"configuration": module.configuration ?: @{}, @"diagnostics": module.diagnostics ?: @{}, @"uiRepresentation": module.uiRepresentation ?: @{} });
        }];
        snapshot = [result copy];
    });
    return snapshot;
}

- (NSDictionary<NSString *,NSDictionary<NSString *,id> *> *)moduleHealthSnapshot {
    __block NSDictionary *snapshot = nil;
    dispatch_sync(self.queue, ^{
        NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:self.modules.count];
        [self.modules enumerateKeysAndObjectsUsingBlock:^(NSString *key, id<TiktigerFeatureModuleProtocol> module, BOOL *stop) {
            result[key] = TiktigerDeepImmutableCopy([module healthCheck] ?: @{});
        }];
        snapshot = [result copy];
    });
    return snapshot;
}

@end
