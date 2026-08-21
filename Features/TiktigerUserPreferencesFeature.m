#import "TiktigerUserPreferencesFeature.h"

static NSString * const TiktigerUserPreferencesErrorDomain = @"com.tiktiger.user-preferences";

@implementation TiktigerUserPreferencesFeature

- (BOOL)validatePreferences:(NSDictionary<NSString *,id> *)preferences error:(NSError **)error {
    id reduceMotion = preferences[@"reduceMotion"];
    id haptics = preferences[@"haptics"];
    BOOL valid = [reduceMotion isKindOfClass:[NSNumber class]] && [haptics isKindOfClass:[NSNumber class]];
    if (!valid && error != NULL) { *error = [NSError errorWithDomain:TiktigerUserPreferencesErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Preferences require boolean-like reduceMotion and haptics values."}]; }
    return valid;
}

- (BOOL)enable:(NSError **)error {
    if (![self validatePreferences:self.configuration error:error]) { return NO; }
    return [super enable:error];
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
        @"error": error.localizedDescription ?: @""
    };
}

@end
