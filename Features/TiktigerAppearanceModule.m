#import "TiktigerAppearanceModule.h"
#import "TiktigerFeatureRegistry.h"
#import <UIKit/UIKit.h>

static NSString * const TiktigerAppearanceModuleErrorDomain = @"com.tiktiger.appearance-module";

@interface TiktigerAppearanceModule ()
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *errors;
@property (nonatomic, strong) NSLock *appearanceLock;
@property (nonatomic, assign) NSUInteger migrationVersion;
@property (nonatomic, copy) NSString *lastAction;
@property (nonatomic, strong) NSDate *lastActionDate;
@end

@implementation TiktigerAppearanceModule

+ (NSDictionary<NSString *, id> *)defaultAppearanceConfiguration {
    return @{
        @"schemaVersion": @1,
        @"theme": @"tiger-black",
        @"accent": @"red",
        @"animation": @{ @"enabled": @YES, @"reduceMotion": @(UIAccessibilityIsReduceMotionEnabled()), @"intensity": @0.72 },
        @"ui": @{ @"blurLevel": @0.72, @"cardStyle": @"glass", @"cornerRadius": @20.0, @"glow": @YES }
    };
}

- (instancetype)initWithFeatureID:(NSString *)featureID name:(NSString *)name version:(NSString *)version configuration:(NSDictionary<NSString *,id> *)configuration uiRepresentation:(NSDictionary<NSString *,id> *)uiRepresentation {
    self = [super initWithFeatureID:featureID name:name version:version configuration:configuration uiRepresentation:uiRepresentation];
    if (self) {
        _errors = [[NSMutableArray alloc] init];
        _appearanceLock = [[NSLock alloc] init];
        _migrationVersion = 1;
        _lastAction = @"initialized";
        _lastActionDate = [NSDate date];
    }
    return self;
}

- (NSDictionary<NSString *, id> *)safeFallback {
    return [TiktigerAppearanceModule defaultAppearanceConfiguration];
}

- (BOOL)validateAppearanceConfiguration:(NSDictionary<NSString *, id> *)candidate error:(NSError **)error {
    NSSet *themes = [NSSet setWithObjects:@"tiger-black", @"oled-black", @"glass", nil];
    NSSet *accents = [NSSet setWithObjects:@"red", @"white", nil];
    NSSet *cardStyles = [NSSet setWithObjects:@"glass", @"solid", nil];
    NSString *theme = candidate[@"theme"];
    NSString *accent = candidate[@"accent"];
    NSDictionary *animation = [candidate[@"animation"] isKindOfClass:[NSDictionary class]] ? candidate[@"animation"] : nil;
    NSDictionary *ui = [candidate[@"ui"] isKindOfClass:[NSDictionary class]] ? candidate[@"ui"] : nil;
    NSNumber *intensity = animation[@"intensity"];
    NSNumber *blurLevel = ui[@"blurLevel"];
    NSNumber *cornerRadius = ui[@"cornerRadius"];
    BOOL valid = [candidate[@"schemaVersion"] isKindOfClass:[NSNumber class]] && [candidate[@"schemaVersion"] integerValue] == 1;
    valid = valid && [themes containsObject:theme] && [accents containsObject:accent] && [cardStyles containsObject:ui[@"cardStyle"]];
    valid = valid && [animation[@"enabled"] isKindOfClass:[NSNumber class]] && [animation[@"reduceMotion"] isKindOfClass:[NSNumber class]];
    valid = valid && [intensity isKindOfClass:[NSNumber class]] && intensity.doubleValue >= 0.0 && intensity.doubleValue <= 1.0;
    valid = valid && [blurLevel isKindOfClass:[NSNumber class]] && blurLevel.doubleValue >= 0.0 && blurLevel.doubleValue <= 1.0;
    valid = valid && [cornerRadius isKindOfClass:[NSNumber class]] && cornerRadius.doubleValue >= 0.0 && cornerRadius.doubleValue <= 40.0;
    if (!valid && error != NULL) {
        *error = [NSError errorWithDomain:TiktigerAppearanceModuleErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Appearance configuration failed theme, animation, or UI validation."}];
    }
    return valid;
}

- (BOOL)enable:(NSError **)error {
    NSError *validationError = nil;
    if (![self validateAppearanceConfiguration:self.configuration error:&validationError]) {
        [self applyConfiguration:[self safeFallback] error:nil];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    return [super enable:error];
}

- (BOOL)applyConfiguration:(NSDictionary<NSString *,id> *)configuration error:(NSError **)error {
    NSError *validationError = nil;
    if (![self validateAppearanceConfiguration:configuration error:&validationError]) {
        [self.appearanceLock lock];
        self.configuration = [self safeFallback];
        [self.errors addObject:@{ @"category": @"validation", @"message": TiktigerRedactedDiagnosticString(validationError.localizedDescription ?: @"Invalid appearance configuration.") }];
        if (self.errors.count > 100) { [self.errors removeObjectAtIndex:0]; }
        self.lastAction = @"fallback-applied";
        self.lastActionDate = [NSDate date];
        [self.appearanceLock unlock];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    [self.appearanceLock lock];
    self.configuration = [configuration copy];
    self.lastAction = @"configuration-updated";
    self.lastActionDate = [NSDate date];
    [self.appearanceLock unlock];
    return YES;
}

- (BOOL)updateAppearanceSetting:(NSString *)key value:(id)value error:(NSError **)error {
    NSSet *supportedKeys = [NSSet setWithObjects:@"theme", @"accent", @"animation.enabled", @"animation.reduceMotion", @"animation.intensity", @"ui.blurLevel", @"ui.cardStyle", @"ui.cornerRadius", @"ui.glow", nil];
    if (![supportedKeys containsObject:key]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerAppearanceModuleErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"The requested appearance setting is not supported."}]; }
        return NO;
    }
    [self.appearanceLock lock];
    NSMutableDictionary *candidate = [self.configuration mutableCopy] ?: [[self safeFallback] mutableCopy];
    if ([key containsString:@"."]) {
        NSArray *parts = [key componentsSeparatedByString:@"."];
        NSString *sectionKey = parts.firstObject;
        NSString *valueKey = parts.lastObject;
        NSMutableDictionary *section = [candidate[sectionKey] mutableCopy] ?: [NSMutableDictionary dictionary];
        section[valueKey] = value;
        candidate[sectionKey] = section;
    } else {
        candidate[key] = value;
    }
    [self.appearanceLock unlock];
    return [self applyConfiguration:candidate error:error];
}

- (BOOL)migrateFromVersion:(NSUInteger)sourceVersion toVersion:(NSUInteger)targetVersion error:(NSError **)error {
    if (sourceVersion > targetVersion) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerAppearanceModuleErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Appearance configuration downgrade is not supported."}]; }
        [self applyConfiguration:[self safeFallback] error:nil];
        return NO;
    }
    [self.appearanceLock lock];
    NSMutableDictionary *candidate = [[self safeFallback] mutableCopy];
    [candidate addEntriesFromDictionary:self.configuration ?: @{}];
    candidate[@"schemaVersion"] = @(targetVersion);
    [self.appearanceLock unlock];
    if (![self applyConfiguration:candidate error:error]) { return NO; }
    self.migrationVersion = targetVersion;
    return YES;
}

- (NSDictionary<NSString *, id> *)appearanceSnapshot {
    [self.appearanceLock lock];
    NSDictionary *snapshot = @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"configuration": self.configuration ?: [self safeFallback],
        @"configurationState": @"valid",
        @"previewState": @"configuration-preview",
        @"lastAction": self.lastAction ?: @"unknown",
        @"lastActionDate": self.lastActionDate ?: [NSDate date],
        @"errorCount": @(self.errors.count),
        @"migrationVersion": @(self.migrationVersion)
    };
    [self.appearanceLock unlock];
    return TiktigerDeepImmutableCopy(snapshot);
}

- (NSDictionary<NSString *, id> *)appearanceHealthSnapshot {
    [self.appearanceLock lock];
    NSError *error = nil;
    BOOL valid = [self validateAppearanceConfiguration:self.configuration error:&error];
    NSDictionary *health = @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"healthy": @(valid),
        @"configurationValid": @(valid),
        @"configurationState": valid ? @"valid" : @"fallback",
        @"previewState": @"configuration-preview",
        @"lastAction": self.lastAction ?: @"unknown",
        @"lastActionDate": self.lastActionDate ?: [NSDate date],
        @"errorCount": @(self.errors.count),
        @"error": TiktigerRedactedDiagnosticString(error.localizedDescription ?: @"")
    };
    [self.appearanceLock unlock];
    return TiktigerDeepImmutableCopy(health);
}

- (NSDictionary<NSString *, id> *)healthCheck {
    return [self appearanceHealthSnapshot];
}

@end

NSString *TiktigerStringFromAppearanceConfigurationState(NSInteger state) {
    switch ((TiktigerAppearanceConfigurationState)state) {
        case TiktigerAppearanceConfigurationStateValid: return @"valid";
        case TiktigerAppearanceConfigurationStateReviewRequired: return @"review-required";
        case TiktigerAppearanceConfigurationStateDegraded: return @"degraded";
    }
    return @"unknown";
}
