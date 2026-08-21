#import "TiktigerFeatureModuleDescriptor.h"

static NSString * const TiktigerFeatureModuleErrorDomain = @"com.tiktiger.module";

@interface TiktigerFeatureModuleDescriptor ()
@property (nonatomic, copy, readwrite) NSString *featureID;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSString *version;
@property (nonatomic, assign, readwrite) TiktigerFeatureModuleState state;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *diagnostics;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *uiRepresentation;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation TiktigerFeatureModuleDescriptor

- (instancetype)initWithFeatureID:(NSString *)featureID name:(NSString *)name version:(NSString *)version configuration:(NSDictionary<NSString *,id> *)configuration uiRepresentation:(NSDictionary<NSString *,id> *)uiRepresentation {
    self = [super init];
    if (self) {
        _featureID = [featureID copy];
        _name = [name copy];
        _version = [version copy];
        _configuration = [configuration copy] ?: @{};
        _uiRepresentation = [uiRepresentation copy] ?: @{};
        _diagnostics = @{};
        _state = TiktigerFeatureModuleStateRegistered;
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (BOOL)enable:(NSError **)error {
    [self.lock lock];
    if (self.state == TiktigerFeatureModuleStateFailed) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerFeatureModuleErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"A failed module must be recovered before enable."}];
        }
        [self.lock unlock];
        return NO;
    }
    self.state = TiktigerFeatureModuleStateEnabled;
    self.diagnostics = @{ @"event": @"enabled", @"state": TiktigerStringFromFeatureModuleState(self.state) };
    [self.lock unlock];
    return YES;
}

- (BOOL)disable:(NSError **)error {
    [self.lock lock];
    self.state = TiktigerFeatureModuleStateDisabled;
    self.diagnostics = @{ @"event": @"disabled", @"state": TiktigerStringFromFeatureModuleState(self.state) };
    [self.lock unlock];
    return YES;
}

- (NSDictionary<NSString *,id> *)healthCheck {
    TiktigerFeatureHealthProvider provider = self.healthProvider;
    if (provider != nil) {
        NSDictionary *provided = provider();
        if (provided != nil) { return provided; }
    }
    return @{
        @"featureID": self.featureID ?: @"",
        @"name": self.name ?: @"",
        @"version": self.version ?: @"",
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"healthy": @(self.state == TiktigerFeatureModuleStateEnabled || self.state == TiktigerFeatureModuleStateRegistered)
    };
}

- (NSDictionary<NSString *,id> *)safeFallback {
    return @{
        @"schemaVersion": @1,
        @"enabled": @NO,
        @"safeMode": @YES
    };
}

- (BOOL)applyConfiguration:(NSDictionary<NSString *,id> *)configuration error:(NSError **)error {
    id schema = configuration[@"schemaVersion"];
    if (![schema isKindOfClass:[NSNumber class]]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerFeatureModuleErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"Module configuration requires numeric schemaVersion."}];
        }
        self.configuration = [self safeFallback];
        self.state = TiktigerFeatureModuleStateDegraded;
        return NO;
    }
    self.configuration = [configuration copy];
    return YES;
}

- (BOOL)migrateFromVersion:(NSUInteger)sourceVersion toVersion:(NSUInteger)targetVersion error:(NSError **)error {
    if (sourceVersion > targetVersion) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerFeatureModuleErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Module configuration downgrade is not supported."}];
        }
        self.configuration = [self safeFallback];
        self.state = TiktigerFeatureModuleStateDegraded;
        return NO;
    }
    NSMutableDictionary *migrated = [self.configuration mutableCopy];
    migrated[@"schemaVersion"] = @(targetVersion);
    self.configuration = [migrated copy];
    return YES;
}

@end
