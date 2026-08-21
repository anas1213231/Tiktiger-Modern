#import "TiktigerTikTokIntegrationDiagnostics.h"
#import "TiktigerFeatureRegistry.h"

@interface TiktigerTikTokIntegrationDiagnostics ()
@property (nonatomic, strong) NSLock *diagnosticsLock;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *entryPointHistory;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *navigationHistory;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *compatibilityHistory;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *presentationHistory;
@end

@implementation TiktigerTikTokIntegrationDiagnostics

- (instancetype)init {
    self = [super init];
    if (self) {
        _diagnosticsLock = [[NSLock alloc] init];
        _entryPointHistory = [[NSMutableArray alloc] init];
        _navigationHistory = [[NSMutableArray alloc] init];
        _compatibilityHistory = [[NSMutableArray alloc] init];
        _presentationHistory = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)recordEntryPointState:(NSDictionary<NSString *,id> *)state {
    [self record:state kind:@"entry-point" history:self.entryPointHistory];
}

- (void)recordNavigationState:(NSDictionary<NSString *,id> *)state {
    [self record:state kind:@"navigation" history:self.navigationHistory];
}

- (void)recordCompatibilityResult:(NSDictionary<NSString *,id> *)result {
    [self record:result kind:@"compatibility" history:self.compatibilityHistory];
}

- (void)recordPresentationState:(NSDictionary<NSString *,id> *)state {
    [self record:state kind:@"presentation" history:self.presentationHistory];
}

- (void)record:(NSDictionary<NSString *, id> *)payload kind:(NSString *)kind history:(NSMutableArray<NSDictionary<NSString *, id> *> *)history {
    NSDictionary *redacted = TiktigerRedactedDiagnosticCopy(payload ?: @{});
    NSDictionary *event = @{ @"kind": kind ?: @"unknown", @"timestamp": @([[NSDate date] timeIntervalSince1970]), @"payload": redacted ?: @{} };
    [self.diagnosticsLock lock];
    [history addObject:event];
    while (history.count > 32) { [history removeObjectAtIndex:0]; }
    [self.diagnosticsLock unlock];
}

- (NSDictionary<NSString *,id> *)snapshot {
    [self.diagnosticsLock lock];
    NSDictionary *snapshot = @{
        @"entryPointHistory": [self.entryPointHistory copy],
        @"navigationHistory": [self.navigationHistory copy],
        @"compatibilityHistory": [self.compatibilityHistory copy],
        @"presentationHistory": [self.presentationHistory copy],
        @"entryPointCount": @(self.entryPointHistory.count),
        @"navigationCount": @(self.navigationHistory.count),
        @"compatibilityCount": @(self.compatibilityHistory.count),
        @"presentationCount": @(self.presentationHistory.count),
        @"boundedHistory": @YES,
        @"redacted": @YES,
        @"preparationOnly": @YES,
        @"targetAppIntegrated": @NO
    };
    [self.diagnosticsLock unlock];
    return TiktigerRedactedDiagnosticCopy(snapshot);
}

- (void)reset {
    [self.diagnosticsLock lock];
    [self.entryPointHistory removeAllObjects];
    [self.navigationHistory removeAllObjects];
    [self.compatibilityHistory removeAllObjects];
    [self.presentationHistory removeAllObjects];
    [self.diagnosticsLock unlock];
}

@end
