#import "TiktigerProfileModule.h"
#import "TiktigerFeatureRegistry.h"

static NSString * const TiktigerProfileModuleErrorDomain = @"com.tiktiger.profile-module";

@interface TiktigerProfileModule ()
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *errors;
@property (nonatomic, strong) NSLock *profileLock;
@property (nonatomic, assign) NSUInteger migrationVersion;
@property (nonatomic, copy) NSString *lastAction;
@property (nonatomic, strong) NSDate *lastActionDate;
@end

@implementation TiktigerProfileModule

+ (NSDictionary<NSString *, id> *)defaultProfileConfiguration {
    return @{
        @"schemaVersion": @1,
        @"profileTools": @{ @"enabled": @YES, @"explanation": @"Profile tool preferences are stored safely." },
        @"mediaPreferences": @{ @"enabled": @YES, @"explanation": @"Media preference configuration is ready for host integration." },
        @"avatarSettings": @{ @"enabled": @YES, @"explanation": @"Avatar settings are configuration-only in this foundation." },
        @"accountPreferences": @{ @"enabled": @YES, @"explanation": @"Account preference configuration is validated before storage." }
    };
}

- (instancetype)initWithFeatureID:(NSString *)featureID name:(NSString *)name version:(NSString *)version configuration:(NSDictionary<NSString *,id> *)configuration uiRepresentation:(NSDictionary<NSString *,id> *)uiRepresentation {
    self = [super initWithFeatureID:featureID name:name version:version configuration:configuration uiRepresentation:uiRepresentation];
    if (self) {
        _errors = [[NSMutableArray alloc] init];
        _profileLock = [[NSLock alloc] init];
        _migrationVersion = 1;
        _lastAction = @"initialized";
        _lastActionDate = [NSDate date];
    }
    return self;
}

- (NSDictionary<NSString *, id> *)safeFallback {
    return [TiktigerProfileModule defaultProfileConfiguration];
}

- (BOOL)validateProfileConfiguration:(NSDictionary<NSString *, id> *)candidate error:(NSError **)error {
    NSArray<NSString *> *sections = @[@"profileTools", @"mediaPreferences", @"avatarSettings", @"accountPreferences"];
    BOOL valid = [candidate[@"schemaVersion"] isKindOfClass:[NSNumber class]] && [candidate[@"schemaVersion"] integerValue] == 1;
    for (NSString *section in sections) {
        NSDictionary *value = [candidate[section] isKindOfClass:[NSDictionary class]] ? candidate[section] : nil;
        valid = valid && [value[@"enabled"] isKindOfClass:[NSNumber class]] && [value[@"explanation"] isKindOfClass:[NSString class]];
    }
    if (!valid && error != NULL) {
        *error = [NSError errorWithDomain:TiktigerProfileModuleErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Profile configuration failed schema or section validation."}];
    }
    return valid;
}

- (BOOL)enable:(NSError **)error {
    NSError *validationError = nil;
    if (![self validateProfileConfiguration:self.configuration error:&validationError]) {
        [self applyConfiguration:[self safeFallback] error:nil];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    return [super enable:error];
}

- (BOOL)applyConfiguration:(NSDictionary<NSString *,id> *)configuration error:(NSError **)error {
    NSError *validationError = nil;
    if (![self validateProfileConfiguration:configuration error:&validationError]) {
        [self.profileLock lock];
        self.configuration = [self safeFallback];
        [self.errors addObject:@{ @"category": @"validation", @"message": TiktigerRedactedDiagnosticString(validationError.localizedDescription ?: @"Invalid profile configuration.") }];
        if (self.errors.count > 100) { [self.errors removeObjectAtIndex:0]; }
        self.lastAction = @"fallback-applied";
        self.lastActionDate = [NSDate date];
        [self.profileLock unlock];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    [self.profileLock lock];
    self.configuration = [configuration copy];
    self.lastAction = @"configuration-updated";
    self.lastActionDate = [NSDate date];
    [self.profileLock unlock];
    return YES;
}

- (BOOL)updateProfileSetting:(NSString *)key value:(id)value error:(NSError **)error {
    NSArray<NSString *> *sections = @[@"profileTools", @"mediaPreferences", @"avatarSettings", @"accountPreferences"];
    if (![sections containsObject:key] || ![value isKindOfClass:[NSNumber class]]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerProfileModuleErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"The requested profile setting is not supported."}]; }
        return NO;
    }
    [self.profileLock lock];
    NSMutableDictionary *candidate = [self.configuration mutableCopy] ?: [[self safeFallback] mutableCopy];
    NSMutableDictionary *section = [candidate[key] mutableCopy] ?: [NSMutableDictionary dictionary];
    section[@"enabled"] = @([value boolValue]);
    candidate[key] = section;
    [self.profileLock unlock];
    return [self applyConfiguration:candidate error:error];
}

- (BOOL)migrateFromVersion:(NSUInteger)sourceVersion toVersion:(NSUInteger)targetVersion error:(NSError **)error {
    if (sourceVersion > targetVersion) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerProfileModuleErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Profile configuration downgrade is not supported."}]; }
        [self applyConfiguration:[self safeFallback] error:nil];
        return NO;
    }
    [self.profileLock lock];
    NSMutableDictionary *candidate = [[self safeFallback] mutableCopy];
    [candidate addEntriesFromDictionary:self.configuration ?: @{}];
    candidate[@"schemaVersion"] = @(targetVersion);
    [self.profileLock unlock];
    if (![self applyConfiguration:candidate error:error]) { return NO; }
    self.migrationVersion = targetVersion;
    return YES;
}

- (TiktigerProfileConfigurationState)configurationStateLocked {
    NSError *error = nil;
    if (![self validateProfileConfiguration:self.configuration error:&error]) { return TiktigerProfileConfigurationStateDegraded; }
    for (NSString *section in @[@"profileTools", @"mediaPreferences", @"avatarSettings", @"accountPreferences"]) {
        if (![self.configuration[section][@"enabled"] boolValue]) { return TiktigerProfileConfigurationStateReviewRequired; }
    }
    return TiktigerProfileConfigurationStateConfigured;
}

- (NSDictionary<NSString *,id> *)profileSnapshot {
    [self.profileLock lock];
    TiktigerProfileConfigurationState state = [self configurationStateLocked];
    NSDictionary *snapshot = @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"configurationState": TiktigerStringFromProfileConfigurationState(state),
        @"configuration": self.configuration ?: [self safeFallback],
        @"behaviorState": @"configuration-only",
        @"lastAction": self.lastAction ?: @"unknown",
        @"lastActionDate": self.lastActionDate ?: [NSDate date],
        @"errorCount": @(self.errors.count),
        @"migrationVersion": @(self.migrationVersion)
    };
    [self.profileLock unlock];
    return TiktigerDeepImmutableCopy(snapshot);
}

- (NSDictionary<NSString *,id> *)profileHealthSnapshot {
    [self.profileLock lock];
    NSError *error = nil;
    BOOL valid = [self validateProfileConfiguration:self.configuration error:&error];
    NSDictionary *health = @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"healthy": @(valid),
        @"configurationValid": @(valid),
        @"configurationState": valid ? @"valid" : @"fallback",
        @"behaviorState": @"configuration-only",
        @"lastAction": self.lastAction ?: @"unknown",
        @"lastActionDate": self.lastActionDate ?: [NSDate date],
        @"errorCount": @(self.errors.count),
        @"error": TiktigerRedactedDiagnosticString(error.localizedDescription ?: @"")
    };
    [self.profileLock unlock];
    return TiktigerDeepImmutableCopy(health);
}

- (NSDictionary<NSString *,id> *)healthCheck {
    return [self profileHealthSnapshot];
}

@end

NSString *TiktigerStringFromProfileConfigurationState(NSInteger state) {
    switch ((TiktigerProfileConfigurationState)state) {
        case TiktigerProfileConfigurationStateConfigured: return @"configured";
        case TiktigerProfileConfigurationStateReviewRequired: return @"review-required";
        case TiktigerProfileConfigurationStateDegraded: return @"degraded";
    }
    return @"unknown";
}
