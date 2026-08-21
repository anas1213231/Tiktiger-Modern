#import "TiktigerSecureConfigurationFeature.h"

static NSString * const TiktigerSecureConfigurationErrorDomain = @"com.tiktiger.secure-configuration";

@implementation TiktigerSecureConfigurationFeature

- (BOOL)validateConfiguration:(NSDictionary<NSString *,id> *)configuration error:(NSError **)error {
    id schema = configuration[@"schemaVersion"];
    id safeMode = configuration[@"safeMode"];
    id retentionDays = configuration[@"retentionDays"];
    BOOL valid = [schema isKindOfClass:[NSNumber class]] && [safeMode isKindOfClass:[NSNumber class]] && [retentionDays isKindOfClass:[NSNumber class]] && [retentionDays integerValue] >= 1 && [retentionDays integerValue] <= 365;
    if (!valid) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerSecureConfigurationErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Secure configuration failed schema or retention validation."}]; }
        return NO;
    }
    return YES;
}

- (BOOL)enable:(NSError **)error {
    NSDictionary *settings = self.configuration;
    if (![self validateConfiguration:settings error:error]) { return NO; }
    return [super enable:error];
}

- (NSDictionary<NSString *,id> *)healthCheck {
    NSError *error = nil;
    BOOL valid = [self validateConfiguration:self.configuration error:&error];
    return @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"healthy": @(valid),
        @"configurationValid": @(valid),
        @"error": error.localizedDescription ?: @""
    };
}

@end
