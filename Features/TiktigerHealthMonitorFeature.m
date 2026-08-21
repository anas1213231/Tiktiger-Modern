#import "TiktigerHealthMonitorFeature.h"
#import "TiktigerModuleManager.h"

@interface TiktigerHealthMonitorFeature ()
@property (nonatomic, weak) TiktigerModuleManager *moduleManager;
@end

@implementation TiktigerHealthMonitorFeature

- (instancetype)initWithModuleManager:(TiktigerModuleManager *)moduleManager {
    self = [super initWithFeatureID:@"health.monitor" name:@"Health Monitor" version:@"1.0" configuration:@{@"schemaVersion": @1, @"safeMode": @YES} uiRepresentation:@{@"surface": @"Dashboard", @"category": @"diagnostics"}];
    if (self) { _moduleManager = moduleManager; }
    return self;
}

- (NSDictionary<NSString *,id> *)healthCheck {
    NSDictionary *health = [self.moduleManager healthSnapshot] ?: @{};
    NSUInteger failed = 0;
    for (NSDictionary *value in health.allValues) { if ([value[@"healthy"] respondsToSelector:@selector(boolValue)] && ![value[@"healthy"] boolValue]) { failed += 1; } }
    return @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"healthy": @(failed == 0),
        @"moduleCount": @(health.count),
        @"failedModuleCount": @(failed)
    };
}

@end
