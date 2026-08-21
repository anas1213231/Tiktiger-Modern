#import "TiktigerConfigurationManager.h"

static NSString * const TiktigerConfigurationErrorDomain = @"com.tiktiger.configuration";
static NSUInteger const TiktigerCurrentSchemaVersion = 1;

@interface TiktigerConfigurationManager ()
@property (nonatomic, assign, readwrite) NSUInteger schemaVersion;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *currentConfiguration;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation TiktigerConfigurationManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _schemaVersion = TiktigerCurrentSchemaVersion;
        _lock = [[NSLock alloc] init];
        [self loadDefaults];
    }
    return self;
}

- (NSDictionary<NSString *, id> *)safeFallback {
    return @{
        @"schemaVersion": @(TiktigerCurrentSchemaVersion),
        @"diagnosticsEnabled": @YES,
        @"allowRemoteOverrides": @NO
    };
}

- (void)loadDefaults {
    [self.lock lock];
    self.currentConfiguration = [self safeFallback];
    self.schemaVersion = TiktigerCurrentSchemaVersion;
    [self.lock unlock];
}

- (BOOL)validateConfiguration:(NSDictionary<NSString *, id> *)configuration error:(NSError **)error {
    id schema = configuration[@"schemaVersion"];
    if (![schema isKindOfClass:[NSNumber class]]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerConfigurationErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Configuration schemaVersion must be numeric."}];
        }
        return NO;
    }
    if (configuration[@"diagnosticsEnabled"] != nil && ![configuration[@"diagnosticsEnabled"] isKindOfClass:[NSNumber class]]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerConfigurationErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"diagnosticsEnabled must be boolean-like."}];
        }
        return NO;
    }
    return YES;
}

- (BOOL)applyConfiguration:(NSDictionary<NSString *, id> *)configuration error:(NSError **)error {
    if (![self validateConfiguration:configuration error:error]) {
        [self loadDefaults];
        return NO;
    }
    [self.lock lock];
    self.currentConfiguration = [configuration copy];
    self.schemaVersion = [configuration[@"schemaVersion"] unsignedIntegerValue];
    [self.lock unlock];
    return YES;
}

- (BOOL)migrateFromVersion:(NSUInteger)sourceVersion toVersion:(NSUInteger)targetVersion error:(NSError **)error {
    if (sourceVersion > targetVersion) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerConfigurationErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Downgrade migration is not supported by the foundation."}];
        }
        [self loadDefaults];
        return NO;
    }
    [self.lock lock];
    NSMutableDictionary *migrated = [self.currentConfiguration mutableCopy];
    migrated[@"schemaVersion"] = @(targetVersion);
    self.currentConfiguration = [migrated copy];
    self.schemaVersion = targetVersion;
    [self.lock unlock];
    return YES;
}

@end
