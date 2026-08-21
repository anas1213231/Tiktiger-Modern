#import "TiktigerSystemModule.h"
#import "TiktigerModuleManager.h"
#import "Tiktiger.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const TiktigerSystemModuleErrorDomain = @"com.tiktiger.system-module";
static NSUInteger const TiktigerSystemSchemaVersion = 1;

static NSDictionary<NSString *, id> *TiktigerSystemBackupSecurityPolicy(void) {
    return @{
        @"policyVersion": @1,
        @"issuer": @"Tiktiger",
        @"format": @"tiktiger.configuration-backup",
        @"scope": @"configuration-only",
        @"integrityAlgorithm": @"SHA-256",
        @"signatureRequired": @NO
    };
}

@interface TiktigerSystemModule ()
@property (nonatomic, strong, readwrite) TiktigerModuleManager *moduleManager;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *errors;
@property (nonatomic, strong) NSLock *systemLock;
@property (nonatomic, assign) NSUInteger migrationVersion;
@property (nonatomic, copy) NSString *lastAction;
@property (nonatomic, strong) NSDate *lastActionDate;
@end

@implementation TiktigerSystemModule

- (instancetype)initWithModuleManager:(TiktigerModuleManager *)moduleManager {
    NSDictionary *configuration = @{
        @"schemaVersion": @(TiktigerSystemSchemaVersion),
        @"backupSchemaVersion": @1,
        @"storageMode": @"runtime-observed",
        @"safeResetEnabled": @YES,
        @"backupSecurityPolicy": TiktigerSystemBackupSecurityPolicy(),
        @"managedFeatureIDs": @[@"media.download", @"privacy.center", @"appearance.engine", @"chat.center", @"profile.center"]
    };
    self = [super initWithFeatureID:@"system.center" name:@"System Center" version:@"1.0" configuration:configuration uiRepresentation:@{@"surface": @"System Center", @"category": @"system"}];
    if (self) {
        _moduleManager = moduleManager;
        _errors = [[NSMutableArray alloc] init];
        _systemLock = [[NSLock alloc] init];
        _migrationVersion = TiktigerSystemSchemaVersion;
        _lastAction = @"initialized";
        _lastActionDate = [NSDate date];
    }
    return self;
}

- (NSDictionary<NSString *, id> *)backupSecurityPolicy {
    return TiktigerSystemBackupSecurityPolicy();
}

- (NSString *)backupDigestForConfiguration:(NSDictionary<NSString *, id> *)configuration managedFeatureIDs:(NSArray<NSString *> *)managedFeatureIDs {
    NSDictionary *canonicalPayload = @{
        @"systemConfiguration": configuration ?: @{},
        @"managedFeatureIDs": managedFeatureIDs ?: @[]
    };
    NSData *canonicalData = [NSJSONSerialization dataWithJSONObject:canonicalPayload options:NSJSONWritingSortedKeys error:nil];
    if (canonicalData.length == 0) { return @""; }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(canonicalData.bytes, (CC_LONG)canonicalData.length, digest);
    NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index += 1) { [hex appendFormat:@"%02x", digest[index]]; }
    return [hex copy];
}

- (void)recordSystemErrorCategory:(NSString *)category message:(NSString *)message {
    NSDictionary *entry = @{
        @"category": TiktigerRedactedDiagnosticString(category ?: @"system"),
        @"message": TiktigerRedactedDiagnosticString(message ?: @""),
        @"redacted": @YES
    };
    [self.systemLock lock];
    [self.errors addObject:entry];
    if (self.errors.count > 100) { [self.errors removeObjectAtIndex:0]; }
    [self.systemLock unlock];
}

- (BOOL)validateSystemConfiguration:(NSDictionary<NSString *, id> *)candidate error:(NSError **)error {
    BOOL valid = [candidate[@"schemaVersion"] isKindOfClass:[NSNumber class]] && [candidate[@"schemaVersion"] unsignedIntegerValue] == TiktigerSystemSchemaVersion;
    valid = valid && [candidate[@"backupSchemaVersion"] isKindOfClass:[NSNumber class]] && [candidate[@"backupSchemaVersion"] unsignedIntegerValue] == 1;
    valid = valid && [candidate[@"storageMode"] isKindOfClass:[NSString class]] && [candidate[@"storageMode"] isEqualToString:@"runtime-observed"];
    valid = valid && [candidate[@"safeResetEnabled"] isKindOfClass:[NSNumber class]];
    valid = valid && [candidate[@"backupSecurityPolicy"] isKindOfClass:[NSDictionary class]] && [candidate[@"backupSecurityPolicy"] isEqualToDictionary:[self backupSecurityPolicy]];
    NSArray *managedIDs = [candidate[@"managedFeatureIDs"] isKindOfClass:[NSArray class]] ? candidate[@"managedFeatureIDs"] : nil;
    NSArray *allowedIDs = @[@"media.download", @"privacy.center", @"appearance.engine", @"chat.center", @"profile.center"];
    valid = valid && managedIDs.count == allowedIDs.count;
    for (NSString *featureID in managedIDs) { valid = valid && [featureID isKindOfClass:[NSString class]] && [allowedIDs containsObject:featureID]; }
    if (!valid && error != NULL) {
        *error = [NSError errorWithDomain:TiktigerSystemModuleErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"System configuration failed schema, storage, or managed-module validation."}];
    }
    return valid;
}

- (NSDictionary<NSString *, id> *)safeFallback {
    return @{
        @"schemaVersion": @(TiktigerSystemSchemaVersion),
        @"backupSchemaVersion": @1,
        @"storageMode": @"runtime-observed",
        @"safeResetEnabled": @YES,
        @"backupSecurityPolicy": TiktigerSystemBackupSecurityPolicy(),
        @"managedFeatureIDs": @[@"media.download", @"privacy.center", @"appearance.engine", @"chat.center", @"profile.center"]
    };
}

- (BOOL)enable:(NSError **)error {
    NSError *validationError = nil;
    if (![self validateSystemConfiguration:self.configuration error:&validationError]) {
        [self applyConfiguration:[self safeFallback] error:nil];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    return [super enable:error];
}

- (BOOL)applyConfiguration:(NSDictionary<NSString *,id> *)configuration error:(NSError **)error {
    NSError *validationError = nil;
    if (![self validateSystemConfiguration:configuration error:&validationError]) {
        [self.systemLock lock];
        self.configuration = [self safeFallback];
        self.lastAction = @"fallback-applied";
        self.lastActionDate = [NSDate date];
        [self.systemLock unlock];
        [self recordSystemErrorCategory:@"validation" message:validationError.localizedDescription ?: @"Invalid system configuration."];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    [self.systemLock lock];
    self.configuration = [configuration copy];
    self.lastAction = @"configuration-updated";
    self.lastActionDate = [NSDate date];
    [self.systemLock unlock];
    return YES;
}

- (BOOL)migrateFromVersion:(NSUInteger)sourceVersion toVersion:(NSUInteger)targetVersion error:(NSError **)error {
    if (sourceVersion > targetVersion) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerSystemModuleErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"System configuration downgrade is not supported."}]; }
        [self applyConfiguration:[self safeFallback] error:nil];
        return NO;
    }
    [self.systemLock lock];
    NSMutableDictionary *candidate = [[self safeFallback] mutableCopy];
    [candidate addEntriesFromDictionary:self.configuration ?: @{}];
    candidate[@"schemaVersion"] = @(targetVersion);
    [self.systemLock unlock];
    if (![self applyConfiguration:candidate error:error]) { return NO; }
    self.migrationVersion = targetVersion;
    return YES;
}

- (NSDictionary<NSString *, id> *)storageOverview {
    NSError *fileSystemError = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&fileSystemError];
    NSNumber *total = [attributes[NSFileSystemSize] isKindOfClass:[NSNumber class]] ? attributes[NSFileSystemSize] : @0;
    NSNumber *free = [attributes[NSFileSystemFreeSize] isKindOfClass:[NSNumber class]] ? attributes[NSFileSystemFreeSize] : @0;
    return @{
        @"observed": @(fileSystemError == nil),
        @"totalBytes": total,
        @"freeBytes": free,
        @"error": TiktigerRedactedDiagnosticString(fileSystemError.localizedDescription ?: @"")
    };
}

- (NSArray<NSString *> *)managedFeatureIDs {
    [self.systemLock lock];
    NSArray *ids = [self.configuration[@"managedFeatureIDs"] isKindOfClass:[NSArray class]] ? [self.configuration[@"managedFeatureIDs"] copy] : @[];
    [self.systemLock unlock];
    return ids;
}

- (NSDictionary<NSString *,id> *)featureManagerSnapshot {
    NSDictionary *status = self.moduleManager.statusSnapshot ?: @{};
    NSMutableDictionary *health = [[NSMutableDictionary alloc] init];
    for (NSString *featureID in [self managedFeatureIDs]) {
        id<TiktigerFeatureModuleProtocol> managedModule = [self.moduleManager.registry moduleWithID:featureID];
        if (managedModule != nil) { health[featureID] = TiktigerDeepImmutableCopy([managedModule healthCheck] ?: @{}); }
    }
    NSMutableArray *modules = [[NSMutableArray alloc] init];
    NSUInteger enabledCount = 0;
    for (NSString *featureID in [self managedFeatureIDs]) {
        NSDictionary *statusEntry = [status[featureID] isKindOfClass:[NSDictionary class]] ? status[featureID] : @{};
        NSDictionary *healthEntry = [health[featureID] isKindOfClass:[NSDictionary class]] ? health[featureID] : @{};
        NSString *state = [statusEntry[@"state"] isKindOfClass:[NSString class]] ? statusEntry[@"state"] : @"unknown";
        if ([state isEqualToString:@"enabled"]) { enabledCount += 1; }
        [modules addObject:@{
            @"id": featureID,
            @"name": statusEntry[@"name"] ?: featureID,
            @"version": statusEntry[@"version"] ?: @"",
            @"state": state,
            @"configuration": statusEntry[@"configuration"] ?: @{},
            @"diagnostics": statusEntry[@"diagnostics"] ?: @{},
            @"healthy": healthEntry[@"healthy"] ?: @NO,
            @"health": healthEntry
        }];
    }
    return TiktigerDeepImmutableCopy(@{
        @"moduleCount": @(modules.count),
        @"enabledCount": @(enabledCount),
        @"modules": [modules copy],
        @"statusSnapshot": status,
        @"healthSnapshot": health
    });
}

- (NSDictionary<NSString *,id> *)diagnosticsHubSnapshot {
    NSDictionary *featureManager = [self featureManagerSnapshot];
    NSDictionary *health = featureManager[@"healthSnapshot"] ?: @{};
    NSMutableArray *errors = [[NSMutableArray alloc] init];
    NSMutableArray *lastActions = [[NSMutableArray alloc] init];
    NSMutableArray *logs = [[NSMutableArray alloc] init];
    for (NSDictionary *module in featureManager[@"modules"] ?: @[]) {
        NSString *featureID = module[@"id"] ?: @"";
        NSDictionary *moduleHealth = module[@"health"] ?: @{};
        NSString *healthError = [moduleHealth[@"error"] isKindOfClass:[NSString class]] ? moduleHealth[@"error"] : @"";
        if (healthError.length > 0) { [errors addObject:@{ @"featureID": featureID, @"message": healthError }]; }
        NSDictionary *diagnostics = module[@"diagnostics"] ?: @{};
        NSString *lastAction = [diagnostics[@"lastAction"] isKindOfClass:[NSString class]] ? diagnostics[@"lastAction"] : ([diagnostics[@"event"] isKindOfClass:[NSString class]] ? diagnostics[@"event"] : @"unknown");
        [lastActions addObject:@{ @"featureID": featureID, @"action": lastAction }];
        [logs addObject:@{ @"featureID": featureID, @"state": module[@"state"] ?: @"unknown", @"healthy": module[@"healthy"] ?: @NO }];
    }
    [self.systemLock lock];
    NSString *systemAction = self.lastAction ?: @"unknown";
    NSArray *systemErrors = [self.errors copy] ?: @[];
    [self.systemLock unlock];
    [lastActions addObject:@{ @"featureID": @"system.center", @"action": systemAction }];
    BOOL healthy = errors.count == 0 && systemErrors.count == 0;
    return TiktigerRedactedDiagnosticCopy(@{
        @"healthy": @(healthy),
        @"moduleCount": featureManager[@"moduleCount"] ?: @0,
        @"enabledCount": featureManager[@"enabledCount"] ?: @0,
        @"logsOverview": [logs copy],
        @"errors": [errors copy],
        @"lastActions": [lastActions copy],
        @"healthChecks": health,
        @"systemErrors": systemErrors
    });
}

- (NSDictionary<NSString *,id> *)systemSnapshot {
    [self.systemLock lock];
    NSError *configurationError = nil;
    BOOL configurationValid = [self validateSystemConfiguration:self.configuration error:&configurationError];
    NSString *lastAction = self.lastAction ?: @"unknown";
    NSDate *lastActionDate = self.lastActionDate ?: [NSDate date];
    NSUInteger migrationVersion = self.migrationVersion;
    NSDictionary *configuration = self.configuration ?: [self safeFallback];
    [self.systemLock unlock];
    const char *versionCString = TiktigerGetVersion();
    NSString *runtimeVersion = versionCString != NULL ? [NSString stringWithUTF8String:versionCString] : @"unknown";
    TiktigerRuntimeState runtimeState = TiktigerGetStatus();
    NSDictionary *diagnostics = [self diagnosticsHubSnapshot];
    [self.systemLock lock];
    NSUInteger systemErrorCount = self.errors.count;
    [self.systemLock unlock];
    return TiktigerDeepImmutableCopy(@{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"configurationState": configurationValid ? @"ready" : @"degraded",
        @"configurationValid": @(configurationValid),
        @"configuration": configuration,
        @"runtimeStatus": TiktigerStringFromRuntimeState(runtimeState),
        @"runtimeVersion": runtimeVersion,
        @"build": @{
            @"product": @"Tiktiger.dylib",
            @"configuration": @"Release",
            @"architecture": @"arm64",
            @"deployment": @"iOS 14.0+",
            @"installName": @"@rpath/Tiktiger.dylib",
            @"workflow": @"GitHub Actions"
        },
        @"storage": [self storageOverview],
        @"healthSummary": diagnostics,
        @"lastAction": lastAction,
        @"lastActionDate": lastActionDate,
        @"errorCount": @(systemErrorCount + [diagnostics[@"errors"] count]),
        @"migrationVersion": @(migrationVersion),
        @"error": TiktigerRedactedDiagnosticString(configurationError.localizedDescription ?: @"")
    });
}

- (NSDictionary<NSString *,id> *)backupExportSnapshot {
    NSDictionary *system = [self systemSnapshot];
    NSDictionary *configuration = system[@"configuration"] ?: [self safeFallback];
    NSArray *managedFeatureIDs = [self managedFeatureIDs];
    NSString *digest = [self backupDigestForConfiguration:configuration managedFeatureIDs:managedFeatureIDs];
    return TiktigerDeepImmutableCopy(@{
        @"backupSchemaVersion": @1,
        @"format": @"tiktiger.configuration-backup",
        @"mode": @"configuration-export-only",
        @"sourceFeatureID": self.featureID,
        @"createdAt": [NSDate date],
        @"systemConfiguration": configuration,
        @"managedFeatureIDs": managedFeatureIDs,
        @"authenticity": [self backupSecurityPolicy],
        @"integrity": @{ @"algorithm": @"SHA-256", @"digest": digest },
        @"note": @"This structure contains configuration only; it does not export binaries, credentials, or target-app data."
    });
}

- (BOOL)setManagedFeatureID:(NSString *)featureID enabled:(BOOL)enabled error:(NSError **)error {
    if (![[self managedFeatureIDs] containsObject:featureID]) {
        NSError *validationError = [NSError errorWithDomain:TiktigerSystemModuleErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"The requested feature is not managed by System Center."}];
        if (error != NULL) { *error = validationError; }
        [self recordSystemErrorCategory:@"feature-manager" message:validationError.localizedDescription];
        return NO;
    }
    BOOL result = enabled ? [self.moduleManager enableModuleWithID:featureID error:error] : [self.moduleManager disableModuleWithID:featureID error:error];
    if (result) {
        [self.systemLock lock];
        self.lastAction = enabled ? [NSString stringWithFormat:@"enabled:%@", featureID] : [NSString stringWithFormat:@"disabled:%@", featureID];
        self.lastActionDate = [NSDate date];
        [self.systemLock unlock];
    }
    return result;
}

- (BOOL)importBackupPayload:(NSDictionary<NSString *,id> *)payload error:(NSError **)error {
    NSDictionary *configuration = [payload[@"systemConfiguration"] isKindOfClass:[NSDictionary class]] ? payload[@"systemConfiguration"] : nil;
    NSArray *managedFeatureIDs = [payload[@"managedFeatureIDs"] isKindOfClass:[NSArray class]] ? payload[@"managedFeatureIDs"] : nil;
    NSDictionary *authenticity = [payload[@"authenticity"] isKindOfClass:[NSDictionary class]] ? payload[@"authenticity"] : nil;
    NSDictionary *integrity = [payload[@"integrity"] isKindOfClass:[NSDictionary class]] ? payload[@"integrity"] : nil;
    NSString *expectedDigest = configuration != nil && managedFeatureIDs != nil ? [self backupDigestForConfiguration:configuration managedFeatureIDs:managedFeatureIDs] : @"";
    BOOL integrityValid = [integrity[@"algorithm"] isEqualToString:@"SHA-256"] && [integrity[@"digest"] isKindOfClass:[NSString class]] && [integrity[@"digest"] isEqualToString:expectedDigest] && expectedDigest.length > 0;
    BOOL valid = [payload[@"backupSchemaVersion"] isKindOfClass:[NSNumber class]] && [payload[@"backupSchemaVersion"] unsignedIntegerValue] == 1 && [payload[@"format"] isKindOfClass:[NSString class]] && [payload[@"format"] isEqualToString:@"tiktiger.configuration-backup"] && [payload[@"sourceFeatureID"] isEqualToString:self.featureID] && [authenticity isEqualToDictionary:[self backupSecurityPolicy]] && managedFeatureIDs != nil && [managedFeatureIDs isEqualToArray:[self managedFeatureIDs]] && configuration != nil && [self validateSystemConfiguration:configuration error:nil] && integrityValid;
    if (!valid) {
        NSError *validationError = [NSError errorWithDomain:TiktigerSystemModuleErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: @"The backup payload failed authenticity, integrity, or safe import validation."}];
        if (error != NULL) { *error = validationError; }
        [self.systemLock lock];
        self.lastAction = @"backup-import-rejected";
        self.lastActionDate = [NSDate date];
        [self.systemLock unlock];
        [self recordSystemErrorCategory:@"backup-import" message:validationError.localizedDescription];
        return NO;
    }
    BOOL result = [self applyConfiguration:configuration error:error];
    if (result) {
        [self.systemLock lock];
        self.lastAction = @"backup-imported";
        self.lastActionDate = [NSDate date];
        [self.systemLock unlock];
    }
    return result;
}

- (BOOL)resetSystemConfiguration:(NSError **)error {
    [self.systemLock lock];
    BOOL enabled = [self.configuration[@"safeResetEnabled"] boolValue];
    [self.systemLock unlock];
    if (!enabled) {
        NSError *validationError = [NSError errorWithDomain:TiktigerSystemModuleErrorDomain code:6 userInfo:@{NSLocalizedDescriptionKey: @"Safe reset is disabled by system configuration."}];
        if (error != NULL) { *error = validationError; }
        [self recordSystemErrorCategory:@"safe-reset" message:validationError.localizedDescription];
        return NO;
    }
    BOOL result = [self applyConfiguration:[self safeFallback] error:error];
    if (result) {
        [self.systemLock lock];
        self.lastAction = @"safe-reset";
        self.lastActionDate = [NSDate date];
        [self.systemLock unlock];
    }
    return result;
}

- (NSDictionary<NSString *,id> *)healthCheck {
    NSDictionary *snapshot = [self systemSnapshot];
    return @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": snapshot[@"state"] ?: @"unknown",
        @"healthy": @([snapshot[@"configurationValid"] boolValue] && [snapshot[@"healthSummary"][@"healthy"] boolValue]),
        @"configurationState": snapshot[@"configurationState"] ?: @"unknown",
        @"behaviorState": @"configuration-only",
        @"errorCount": snapshot[@"errorCount"] ?: @0,
        @"lastAction": snapshot[@"lastAction"] ?: @"unknown"
    };
}

@end

NSString *TiktigerStringFromSystemConfigurationState(NSInteger state) {
    switch ((TiktigerSystemConfigurationState)state) {
        case TiktigerSystemConfigurationStateReady: return @"ready";
        case TiktigerSystemConfigurationStateReviewRequired: return @"review-required";
        case TiktigerSystemConfigurationStateDegraded: return @"degraded";
    }
    return @"unknown";
}
