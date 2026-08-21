#import "TiktigerDiagnosticsCenterFeature.h"

@interface TiktigerDiagnosticsCenterFeature ()
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *events;
@end

@implementation TiktigerDiagnosticsCenterFeature

- (instancetype)initWithFeatureID:(NSString *)featureID name:(NSString *)name version:(NSString *)version configuration:(NSDictionary<NSString *,id> *)configuration uiRepresentation:(NSDictionary<NSString *,id> *)uiRepresentation {
    self = [super initWithFeatureID:featureID name:name version:version configuration:configuration uiRepresentation:uiRepresentation];
    if (self) { _events = [[NSMutableArray alloc] init]; }
    return self;
}

- (void)recordEvent:(NSString *)event category:(NSString *)category {
    if (event.length == 0) { return; }
    [self.events addObject:@{ @"event": event, @"category": category ?: @"general" }];
}

- (void)recordError:(NSError *)error category:(NSString *)category {
    if (error == nil) { return; }
    [self.events addObject:@{ @"event": @"error", @"category": category ?: @"general", @"domain": error.domain ?: @"", @"code": @(error.code), @"message": error.localizedDescription ?: @"" }];
}

- (NSDictionary<NSString *,id> *)healthCheck {
    return @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"healthy": @YES,
        @"eventCount": @(self.events.count),
        @"lastEvent": self.events.lastObject ?: @{}
    };
}

@end
