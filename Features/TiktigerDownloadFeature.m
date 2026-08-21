#import "TiktigerDownloadFeature.h"

@implementation TiktigerDownloadFeature

- (NSDictionary<NSString *,id> *)downloadPresentationDefaults {
    return @{
        @"mediaType": self.configuration[@"mediaType"] ?: @"video",
        @"destination": self.configuration[@"destination"] ?: @"files",
        @"queueLimit": self.configuration[@"queueLimit"] ?: @5
    };
}

- (NSDictionary<NSString *,id> *)healthCheck {
    return @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"healthy": @YES,
        @"mode": @"presentation-foundation",
        @"coreNetwork": @"not implemented in Phase 5"
    };
}

@end
