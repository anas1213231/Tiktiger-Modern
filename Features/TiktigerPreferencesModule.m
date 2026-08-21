#import "TiktigerPreferencesModule.h"

static NSString * const TiktigerPreferencesModuleErrorDomain = @"com.tiktiger.preferences-module";

@interface TiktigerPreferencesModule ()
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *errors;
@property (nonatomic, assign) NSUInteger migrationVersion;
@end

@implementation TiktigerPreferencesModule

- (instancetype)initWithFeatureID:(NSString *)featureID name:(NSString *)name version:(NSString *)version configuration:(NSDictionary<NSString *,id> *)configuration uiRepresentation:(NSDictionary<NSString *,id> *)uiRepresentation {
    self = [super initWithFeatureID:featureID name:name version:version configuration:configuration uiRepresentation:uiRepresentation];
    if (self) { _errors = [[NSMutableArray alloc] init]; _migrationVersion = 1; }
    return self;
}

- (NSDictionary *)fallbackPreferences {
    return @{
        @"schemaVersion": @1,
        @"theme": @"black",
        @"animation": @{ @"reduceMotion": @NO, @"glow": @YES },
        @"interface": @{ @"rtl": @YES, @"glassIntensity": @0.72 },
        @"features": @{ @"haptics": @YES, @"downloads": @YES }
    };
}

- (BOOL)validatePreferences:(NSDictionary *)preferences error:(NSError **)error {
    NSSet *themes = [NSSet setWithObjects:@"black", @"system", nil];
    NSString *theme = preferences[@"theme"];
    NSDictionary *animation = preferences[@"animation"];
    NSDictionary *interfaceSettings = preferences[@"interface"];
    NSDictionary *features = preferences[@"features"];
    BOOL valid = [preferences[@"schemaVersion"] isKindOfClass:[NSNumber class]] && [themes containsObject:theme] && [animation isKindOfClass:[NSDictionary class]] && [interfaceSettings isKindOfClass:[NSDictionary class]] && [features isKindOfClass:[NSDictionary class]];
    if (!valid && error != NULL) { *error = [NSError errorWithDomain:TiktigerPreferencesModuleErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Preferences failed theme, schema, or section validation."}]; }
    return valid;
}

- (BOOL)enable:(NSError **)error {
    if (![self validatePreferences:self.configuration error:error]) {
        [self applyConfiguration:[self fallbackPreferences] error:nil];
        return NO;
    }
    return [super enable:error];
}

- (BOOL)updateTheme:(NSString *)theme error:(NSError **)error {
    NSMutableDictionary *next = [self.configuration mutableCopy];
    next[@"theme"] = theme ?: @"black";
    return [self applyCandidate:next error:error];
}

- (BOOL)updateAnimationSettings:(NSDictionary<NSString *,id> *)settings error:(NSError **)error {
    NSMutableDictionary *next = [self.configuration mutableCopy];
    next[@"animation"] = settings ?: @{};
    return [self applyCandidate:next error:error];
}

- (BOOL)updateInterfaceSettings:(NSDictionary<NSString *,id> *)settings error:(NSError **)error {
    NSMutableDictionary *next = [self.configuration mutableCopy];
    next[@"interface"] = settings ?: @{};
    return [self applyCandidate:next error:error];
}

- (BOOL)updateFeaturePreferences:(NSDictionary<NSString *,id> *)preferences error:(NSError **)error {
    NSMutableDictionary *next = [self.configuration mutableCopy];
    next[@"features"] = preferences ?: @{};
    return [self applyCandidate:next error:error];
}

- (BOOL)applyCandidate:(NSDictionary *)candidate error:(NSError **)error {
    if (![self validatePreferences:candidate error:error]) {
        [self.errors addObject:@{ @"message": error && *error ? (*error).localizedDescription : @"Invalid candidate", @"category": @"validation" }];
        self.configuration = [self fallbackPreferences];
        return NO;
    }
    self.configuration = [candidate copy];
    return YES;
}

- (BOOL)migrateFromVersion:(NSUInteger)sourceVersion toVersion:(NSUInteger)targetVersion error:(NSError **)error {
    if (sourceVersion > targetVersion) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerPreferencesModuleErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"Preference downgrade is not supported."}]; }
        self.configuration = [self fallbackPreferences];
        return NO;
    }
    NSMutableDictionary *next = [[self fallbackPreferences] mutableCopy];
    [next addEntriesFromDictionary:self.configuration];
    next[@"schemaVersion"] = @(targetVersion);
    self.configuration = [next copy];
    self.migrationVersion = targetVersion;
    return YES;
}

- (NSDictionary<NSString *,id> *)preferencesSnapshot {
    return @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"configuration": self.configuration ?: [self fallbackPreferences],
        @"errorCount": @(self.errors.count),
        @"migrationVersion": @(self.migrationVersion)
    };
}

- (NSDictionary<NSString *,id> *)healthCheck {
    NSError *error = nil;
    BOOL valid = [self validatePreferences:self.configuration error:&error];
    return @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"healthy": @(valid),
        @"configurationState": valid ? @"valid" : @"fallback",
        @"errorCount": @(self.errors.count),
        @"error": error.localizedDescription ?: @""
    };
}

@end
