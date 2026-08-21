#import "TiktigerDiagnosticsCenterFeature.h"
#import "TiktigerFeatureRegistry.h"

@interface TiktigerDiagnosticsCenterFeature ()
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *events;
@property (nonatomic, strong) NSLock *eventLock;
@end

@implementation TiktigerDiagnosticsCenterFeature

- (instancetype)initWithFeatureID:(NSString *)featureID name:(NSString *)name version:(NSString *)version configuration:(NSDictionary<NSString *,id> *)configuration uiRepresentation:(NSDictionary<NSString *,id> *)uiRepresentation {
    self = [super initWithFeatureID:featureID name:name version:version configuration:configuration uiRepresentation:uiRepresentation];
    if (self) {
        _events = [[NSMutableArray alloc] init];
        _eventLock = [[NSLock alloc] init];
    }
    return self;
}

- (void)recordEvent:(NSString *)event category:(NSString *)category {
    if (event.length == 0) { return; }
    NSDictionary *entry = @{
        @"event": TiktigerRedactedDiagnosticString(event),
        @"category": TiktigerRedactedDiagnosticString(category ?: @"general")
    };
    [self.eventLock lock];
    [self.events addObject:entry];
    if (self.events.count > 200) { [self.events removeObjectAtIndex:0]; }
    [self.eventLock unlock];
}

- (void)recordError:(NSError *)error category:(NSString *)category {
    if (error == nil) { return; }
    [self.eventLock lock];
    [self.events addObject:TiktigerRedactedErrorDictionary(error, category)];
    if (self.events.count > 200) { [self.events removeObjectAtIndex:0]; }
    [self.eventLock unlock];
}

- (NSDictionary<NSString *,id> *)healthCheck {
    [self.eventLock lock];
    NSArray *events = [self.events copy];
    [self.eventLock unlock];
    return TiktigerDeepImmutableCopy(@{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromFeatureModuleState(self.state),
        @"healthy": @YES,
        @"eventCount": @(events.count),
        @"lastEvent": events.lastObject ?: @{}
    });
}

@end
