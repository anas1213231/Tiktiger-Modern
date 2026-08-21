#import "TiktigerDiagnosticsManager.h"

@interface TiktigerDiagnosticsManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *status;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *errors;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation TiktigerDiagnosticsManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = [[NSMutableDictionary alloc] init];
        _errors = [[NSMutableArray alloc] init];
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)updateRuntimeState:(TiktigerRuntimeState)state version:(NSString *)version {
    [self.lock lock];
    self.status[@"runtime"] = @{
        @"state": TiktigerStringFromRuntimeState(state),
        @"version": version ?: @""
    };
    [self.lock unlock];
}

- (void)updateFeatureStatus:(NSDictionary<NSString *,NSDictionary<NSString *,id> *> *)features {
    [self.lock lock];
    self.status[@"features"] = TiktigerRedactedDiagnosticCopy(features ?: @{});
    [self.lock unlock];
}

- (void)updateConfigurationStatus:(NSDictionary<NSString *,id> *)configuration {
    [self.lock lock];
    self.status[@"configuration"] = TiktigerRedactedDiagnosticCopy(configuration ?: @{});
    [self.lock unlock];
}

- (void)recordError:(NSError *)error category:(NSString *)category {
    if (error == nil) { return; }
    NSDictionary *redactedError = TiktigerRedactedErrorDictionary(error, category);
    [self.lock lock];
    [self.errors addObject:redactedError];
    if (self.errors.count > 100) { [self.errors removeObjectAtIndex:0]; }
    self.status[@"lastError"] = redactedError;
    self.status[@"errors"] = [self.errors copy];
    self.status[@"errorCount"] = @(self.errors.count);
    [self.lock unlock];
}

- (NSDictionary<NSString *,id> *)statusSnapshot {
    [self.lock lock];
    NSDictionary *snapshot = TiktigerDeepImmutableCopy(self.status ?: @{});
    [self.lock unlock];
    return snapshot ?: @{};
}

@end
