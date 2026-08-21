#import "TiktigerPrivacyModule.h"

static NSString * const TiktigerPrivacyModuleErrorDomain = @"com.tiktiger.privacy-module";

@interface TiktigerPrivacyModule ()
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *errors;
@property (nonatomic, strong) NSLock *privacyLock;
@property (nonatomic, assign) NSUInteger migrationVersion;
@property (nonatomic, copy) NSString *lastAction;
@property (nonatomic, strong) NSDate *lastActionDate;
@end

@implementation TiktigerPrivacyModule

- (instancetype)initWithFeatureID:(NSString *)featureID name:(NSString *)name version:(NSString *)version configuration:(NSDictionary<NSString *,id> *)configuration uiRepresentation:(NSDictionary<NSString *,id> *)uiRepresentation {
    self = [super initWithFeatureID:featureID name:name version:version configuration:configuration uiRepresentation:uiRepresentation];
    if (self) {
        _errors = [[NSMutableArray alloc] init];
        _privacyLock = [[NSLock alloc] init];
        _migrationVersion = 1;
        _lastAction = @"initialized";
        _lastActionDate = [NSDate date];
    }
    return self;
}

+ (NSDictionary<NSString *, id> *)defaultPrivacyConfiguration {
    return @{
        @"schemaVersion": @1,
        @"viewingPrivacy": @{ @"enabled": @YES, @"explanation": @"Controls are ready for a host privacy policy." },
        @"chatPrivacy": @{ @"enabled": @YES, @"explanation": @"Chat privacy preferences are stored safely." },
        @"dataControls": @{ @"enabled": @YES, @"explanation": @"Data controls are configured without claiming enforcement." },
        @"historyControls": @{ @"enabled": @YES, @"explanation": @"History controls are available for future host actions." }
    };
}

- (NSDictionary<NSString *, id> *)safeFallback {
    return [TiktigerPrivacyModule defaultPrivacyConfiguration];
}

- (BOOL)validatePrivacyConfiguration:(NSDictionary<NSString *, id> *)candidate error:(NSError **)error {
    NSArray<NSString *> *sections = @[@"viewingPrivacy", @"chatPrivacy", @"dataControls", @"historyControls"];
    BOOL valid = [candidate[@"schemaVersion"] isKindOfClass:[NSNumber class]] && [candidate[@"schemaVersion"] integerValue] == 1;
    for (NSString *section in sections) {
        NSDictionary *value = [candidate[section] isKindOfClass:[NSDictionary class]] ? candidate[section] : nil;
        valid = valid && [value[@"enabled"] isKindOfClass:[NSNumber class]] && [value[@"explanation"] isKindOfClass:[NSString class]];
    }
    if (!valid && error != NULL) {
        *error = [NSError errorWithDomain:TiktigerPrivacyModuleErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Privacy configuration failed schema or section validation."}];
    }
    return valid;
}

- (BOOL)enable:(NSError **)error {
    NSError *validationError = nil;
    if (![self validatePrivacyConfiguration:self.configuration error:&validationError]) {
        [self applyConfiguration:[self safeFallback] error:nil];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    return [super enable:error];
}

- (BOOL)applyConfiguration:(NSDictionary<NSString *,id> *)configuration error:(NSError **)error {
    NSError *validationError = nil;
    if (![self validatePrivacyConfiguration:configuration error:&validationError]) {
        [self.privacyLock lock];
        self.configuration = [self safeFallback];
        [self.errors addObject:@{ @"category": @"validation", @"message": validationError.localizedDescription ?: @"Invalid privacy configuration." }];
        self.lastAction = @"fallback-applied";
        self.lastActionDate = [NSDate date];
        [self.privacyLock unlock];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    [self.privacyLock lock];
    self.configuration = [configuration copy];
    self.lastAction = @"configuration-updated";
    self.lastActionDate = [NSDate date];
    [self.privacyLock unlock];
    return YES;
}

- (BOOL)updatePrivacySetting:(NSString *)key value:(id)value error:(NSError **)error {
    NSArray<NSString *> *sections = @[@"viewingPrivacy", @"chatPrivacy", @"dataControls", @"historyControls"];
    if (![sections containsObject:key] || ![value isKindOfClass:[NSNumber class]]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerPrivacyModuleErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"The requested privacy setting is not supported."}]; }
        return NO;
    }
    [self.privacyLock lock];
    NSMutableDictionary *candidate = [self.configuration mutableCopy] ?: [[self safeFallback] mutableCopy];
    NSMutableDictionary *section = [candidate[key] mutableCopy] ?: [NSMutableDictionary dictionary];
    section[@"enabled"] = @([value boolValue]);
    candidate[key] = section;
    [self.privacyLock unlock];
    return [self applyConfiguration:candidate error:error];
}

- (BOOL)migrateFromVersion:(NSUInteger)sourceVersion toVersion:(NSUInteger)targetVersion error:(NSError **)error {
    if (sourceVersion > targetVersion) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerPrivacyModuleErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Privacy configuration downgrade is not supported."}]; }
        [self applyConfiguration:[self safeFallback] error:nil];
        return NO;
    }
    [self.privacyLock lock];
    NSMutableDictionary *candidate = [[self safeFallback] mutableCopy];
    [candidate addEntriesFromDictionary:self.configuration ?: @{}];
    candidate[@"schemaVersion"] = @(targetVersion);
    [self.privacyLock unlock];
    if (![self applyConfiguration:candidate error:error]) { return NO; }
    self.migrationVersion = targetVersion;
    return YES;
}

- (TiktigerPrivacyProtectionState)protectionStateLocked {
    NSArray<NSString *> *sections = @[@"viewingPrivacy", @"chatPrivacy", @"dataControls", @"historyControls"];
    NSError *error = nil;
    if (![self validatePrivacyConfiguration:self.configuration error:&error]) { return TiktigerPrivacyProtectionStateDegraded; }
    for (NSString *section in sections) {
        if (![self.configuration[section][@"enabled"] boolValue]) { return TiktigerPrivacyProtectionStateReviewRequired; }
    }
    return TiktigerPrivacyProtectionStateProtected;
}

- (NSDictionary<NSString *,id> *)privacySnapshot {
    [self.privacyLock lock];
    TiktigerPrivacyProtectionState state = [self protectionStateLocked];
    NSDictionary *snapshot = @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"protectionState": TiktigerStringFromPrivacyProtectionState(state),
        @"configuration": self.configuration ?: [self safeFallback],
        @"configurationState": state == TiktigerPrivacyProtectionStateDegraded ? @"fallback" : @"valid",
        @"enforcementState": @"configuration-only",
        @"lastAction": self.lastAction ?: @"unknown",
        @"lastActionDate": self.lastActionDate ?: [NSDate date],
        @"errorCount": @(self.errors.count),
        @"migrationVersion": @(self.migrationVersion)
    };
    [self.privacyLock unlock];
    return snapshot;
}

- (NSDictionary<NSString *,id> *)privacyHealthSnapshot {
    [self.privacyLock lock];
    NSError *error = nil;
    BOOL valid = [self validatePrivacyConfiguration:self.configuration error:&error];
    NSDictionary *health = @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"healthy": @(valid),
        @"configurationValid": @(valid),
        @"configurationState": valid ? @"valid" : @"fallback",
        @"enforcementState": @"configuration-only",
        @"lastAction": self.lastAction ?: @"unknown",
        @"lastActionDate": self.lastActionDate ?: [NSDate date],
        @"errorCount": @(self.errors.count),
        @"error": error.localizedDescription ?: @""
    };
    [self.privacyLock unlock];
    return health;
}

- (NSDictionary<NSString *,id> *)healthCheck {
    return [self privacyHealthSnapshot];
}

@end

NSString *TiktigerStringFromPrivacyProtectionState(NSInteger state) {
    switch ((TiktigerPrivacyProtectionState)state) {
        case TiktigerPrivacyProtectionStateProtected: return @"protected";
        case TiktigerPrivacyProtectionStateReviewRequired: return @"review-required";
        case TiktigerPrivacyProtectionStateDegraded: return @"degraded";
    }
    return @"unknown";
}
