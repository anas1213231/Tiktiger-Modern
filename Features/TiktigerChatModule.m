#import "TiktigerChatModule.h"
#import "TiktigerFeatureRegistry.h"

static NSString * const TiktigerChatModuleErrorDomain = @"com.tiktiger.chat-module";

@interface TiktigerChatModule ()
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *errors;
@property (nonatomic, strong) NSLock *chatLock;
@property (nonatomic, assign) NSUInteger migrationVersion;
@property (nonatomic, copy) NSString *lastAction;
@property (nonatomic, strong) NSDate *lastActionDate;
@end

@implementation TiktigerChatModule

+ (NSDictionary<NSString *, id> *)defaultChatConfiguration {
    return @{
        @"schemaVersion": @1,
        @"messagePrivacy": @{ @"enabled": @YES, @"explanation": @"Message privacy preferences are stored safely." },
        @"chatControls": @{ @"enabled": @YES, @"explanation": @"Chat control preferences are ready for host integration." },
        @"conversationSettings": @{ @"enabled": @YES, @"explanation": @"Conversation settings are configuration-only in this foundation." },
        @"userPreferences": @{ @"enabled": @YES, @"explanation": @"Chat-related user preferences are validated before storage." }
    };
}

- (instancetype)initWithFeatureID:(NSString *)featureID name:(NSString *)name version:(NSString *)version configuration:(NSDictionary<NSString *,id> *)configuration uiRepresentation:(NSDictionary<NSString *,id> *)uiRepresentation {
    self = [super initWithFeatureID:featureID name:name version:version configuration:configuration uiRepresentation:uiRepresentation];
    if (self) {
        _errors = [[NSMutableArray alloc] init];
        _chatLock = [[NSLock alloc] init];
        _migrationVersion = 1;
        _lastAction = @"initialized";
        _lastActionDate = [NSDate date];
    }
    return self;
}

- (NSDictionary<NSString *, id> *)safeFallback {
    return [TiktigerChatModule defaultChatConfiguration];
}

- (BOOL)validateChatConfiguration:(NSDictionary<NSString *, id> *)candidate error:(NSError **)error {
    NSArray<NSString *> *sections = @[@"messagePrivacy", @"chatControls", @"conversationSettings", @"userPreferences"];
    BOOL valid = [candidate[@"schemaVersion"] isKindOfClass:[NSNumber class]] && [candidate[@"schemaVersion"] integerValue] == 1;
    for (NSString *section in sections) {
        NSDictionary *value = [candidate[section] isKindOfClass:[NSDictionary class]] ? candidate[section] : nil;
        valid = valid && [value[@"enabled"] isKindOfClass:[NSNumber class]] && [value[@"explanation"] isKindOfClass:[NSString class]];
    }
    if (!valid && error != NULL) {
        *error = [NSError errorWithDomain:TiktigerChatModuleErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Chat configuration failed schema or section validation."}];
    }
    return valid;
}

- (BOOL)enable:(NSError **)error {
    NSError *validationError = nil;
    if (![self validateChatConfiguration:self.configuration error:&validationError]) {
        [self applyConfiguration:[self safeFallback] error:nil];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    return [super enable:error];
}

- (BOOL)applyConfiguration:(NSDictionary<NSString *,id> *)configuration error:(NSError **)error {
    NSError *validationError = nil;
    if (![self validateChatConfiguration:configuration error:&validationError]) {
        [self.chatLock lock];
        self.configuration = [self safeFallback];
        [self.errors addObject:@{ @"category": @"validation", @"message": TiktigerRedactedDiagnosticString(validationError.localizedDescription ?: @"Invalid chat configuration.") }];
        if (self.errors.count > 100) { [self.errors removeObjectAtIndex:0]; }
        self.lastAction = @"fallback-applied";
        self.lastActionDate = [NSDate date];
        [self.chatLock unlock];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    [self.chatLock lock];
    self.configuration = [configuration copy];
    self.lastAction = @"configuration-updated";
    self.lastActionDate = [NSDate date];
    [self.chatLock unlock];
    return YES;
}

- (BOOL)updateChatSetting:(NSString *)key value:(id)value error:(NSError **)error {
    NSArray<NSString *> *sections = @[@"messagePrivacy", @"chatControls", @"conversationSettings", @"userPreferences"];
    if (![sections containsObject:key] || ![value isKindOfClass:[NSNumber class]]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerChatModuleErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"The requested chat setting is not supported."}]; }
        return NO;
    }
    [self.chatLock lock];
    NSMutableDictionary *candidate = [self.configuration mutableCopy] ?: [[self safeFallback] mutableCopy];
    NSMutableDictionary *section = [candidate[key] mutableCopy] ?: [NSMutableDictionary dictionary];
    section[@"enabled"] = @([value boolValue]);
    candidate[key] = section;
    [self.chatLock unlock];
    return [self applyConfiguration:candidate error:error];
}

- (BOOL)migrateFromVersion:(NSUInteger)sourceVersion toVersion:(NSUInteger)targetVersion error:(NSError **)error {
    if (sourceVersion > targetVersion) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerChatModuleErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Chat configuration downgrade is not supported."}]; }
        [self applyConfiguration:[self safeFallback] error:nil];
        return NO;
    }
    [self.chatLock lock];
    NSMutableDictionary *candidate = [[self safeFallback] mutableCopy];
    [candidate addEntriesFromDictionary:self.configuration ?: @{}];
    candidate[@"schemaVersion"] = @(targetVersion);
    [self.chatLock unlock];
    if (![self applyConfiguration:candidate error:error]) { return NO; }
    self.migrationVersion = targetVersion;
    return YES;
}

- (TiktigerChatConfigurationState)configurationStateLocked {
    NSError *error = nil;
    if (![self validateChatConfiguration:self.configuration error:&error]) { return TiktigerChatConfigurationStateDegraded; }
    for (NSString *section in @[@"messagePrivacy", @"chatControls", @"conversationSettings", @"userPreferences"]) {
        if (![self.configuration[section][@"enabled"] boolValue]) { return TiktigerChatConfigurationStateReviewRequired; }
    }
    return TiktigerChatConfigurationStateConfigured;
}

- (NSDictionary<NSString *,id> *)chatSnapshot {
    [self.chatLock lock];
    TiktigerChatConfigurationState state = [self configurationStateLocked];
    NSDictionary *snapshot = @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"configurationState": TiktigerStringFromChatConfigurationState(state),
        @"configuration": self.configuration ?: [self safeFallback],
        @"behaviorState": @"configuration-only",
        @"lastAction": self.lastAction ?: @"unknown",
        @"lastActionDate": self.lastActionDate ?: [NSDate date],
        @"errorCount": @(self.errors.count),
        @"migrationVersion": @(self.migrationVersion)
    };
    [self.chatLock unlock];
    return TiktigerDeepImmutableCopy(snapshot);
}

- (NSDictionary<NSString *,id> *)chatHealthSnapshot {
    [self.chatLock lock];
    NSError *error = nil;
    BOOL valid = [self validateChatConfiguration:self.configuration error:&error];
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
    [self.chatLock unlock];
    return TiktigerDeepImmutableCopy(health);
}

- (NSDictionary<NSString *,id> *)healthCheck {
    return [self chatHealthSnapshot];
}

@end

NSString *TiktigerStringFromChatConfigurationState(NSInteger state) {
    switch ((TiktigerChatConfigurationState)state) {
        case TiktigerChatConfigurationStateConfigured: return @"configured";
        case TiktigerChatConfigurationStateReviewRequired: return @"review-required";
        case TiktigerChatConfigurationStateDegraded: return @"degraded";
    }
    return @"unknown";
}
