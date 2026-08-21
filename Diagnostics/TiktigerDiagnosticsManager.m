#import "TiktigerDiagnosticsManager.h"

@interface TiktigerDiagnosticsManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *status;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation TiktigerDiagnosticsManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = [[NSMutableDictionary alloc] init];
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
    self.status[@"features"] = [features copy] ?: @{};
    [self.lock unlock];
}

- (void)updateConfigurationStatus:(NSDictionary<NSString *,id> *)configuration {
    [self.lock lock];
    self.status[@"configuration"] = [configuration copy] ?: @{};
    [self.lock unlock];
}

- (void)recordError:(NSError *)error category:(NSString *)category {
    [self.lock lock];
    self.status[@"lastError"] = @{
        @"category": category ?: @"general",
        @"domain": error.domain ?: @"",
        @"code": @(error.code),
        @"message": error.localizedDescription ?: @""
    };
    [self.lock unlock];
}

- (NSDictionary<NSString *,id> *)statusSnapshot {
    [self.lock lock];
    NSDictionary *snapshot = [self.status copy];
    [self.lock unlock];
    return snapshot;
}

@end
