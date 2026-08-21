#import "TiktigerDownloadRecoveryManager.h"

static NSString * const TiktigerDownloadRecoveryErrorDomain = @"com.tiktiger.download-recovery";

@interface TiktigerDownloadRecoveryManager ()
@property (nonatomic, assign, readwrite) NSUInteger maximumRetryCount;
@property (nonatomic, strong) NSLock *recoveryLock;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *retryCounts;
@property (nonatomic, assign) NSUInteger totalFailures;
@property (nonatomic, assign) NSUInteger totalRetries;
@end

@implementation TiktigerDownloadRecoveryManager

- (instancetype)initWithMaximumRetryCount:(NSUInteger)maximumRetryCount {
    self = [super init];
    if (self) {
        _maximumRetryCount = maximumRetryCount;
        _recoveryLock = [[NSLock alloc] init];
        _retryCounts = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)canRetryTask:(NSDictionary<NSString *,id> *)task error:(NSError **)error {
    NSString *taskID = task[@"id"];
    if (taskID.length == 0) {
        if (error != NULL) { *error = [self recoveryErrorWithCode:1 description:@"Retry requires a task identifier."]; }
        return NO;
    }
    [self.recoveryLock lock];
    NSUInteger retryCount = self.retryCounts[taskID].unsignedIntegerValue;
    BOOL canRetry = retryCount < self.maximumRetryCount;
    if (!canRetry && error != NULL) { *error = [self recoveryErrorWithCode:2 description:@"The maximum retry count for this task has been reached."]; }
    [self.recoveryLock unlock];
    return canRetry;
}

- (BOOL)canResumeTask:(NSDictionary<NSString *,id> *)task error:(NSError **)error {
    NSString *taskID = task[@"id"];
    NSNumber *bytesWritten = task[@"bytesWritten"];
    BOOL resumable = taskID.length > 0 && bytesWritten.unsignedLongLongValue > 0;
    if (!resumable && error != NULL) { *error = [self recoveryErrorWithCode:3 description:@"No resumable partial download is available for this task."]; }
    return resumable;
}

- (NSDictionary<NSString *,id> *)recordFailureForTask:(NSDictionary<NSString *,id> *)task error:(NSError *)error {
    NSString *taskID = task[@"id"] ?: @"unknown";
    NSError *safeError = error ?: [self recoveryErrorWithCode:4 description:@"Unknown download failure."];
    [self.recoveryLock lock];
    self.totalFailures += 1;
    NSUInteger retryCount = self.retryCounts[taskID].unsignedIntegerValue;
    NSDictionary *record = @{
        @"taskID": taskID,
        @"retryCount": @(retryCount),
        @"domain": safeError.domain ?: @"",
        @"code": @(safeError.code),
        @"message": safeError.localizedDescription ?: @"",
        @"resumable": @(task[@"bytesWritten"].unsignedLongLongValue > 0)
    };
    [self.recoveryLock unlock];
    return record;
}

- (NSDictionary<NSString *,id> *)recordRetryForTask:(NSDictionary<NSString *,id> *)task {
    NSString *taskID = task[@"id"] ?: @"unknown";
    [self.recoveryLock lock];
    NSUInteger retryCount = self.retryCounts[taskID].unsignedIntegerValue + 1;
    self.retryCounts[taskID] = @(retryCount);
    self.totalRetries += 1;
    NSDictionary *record = @{ @"taskID": taskID, @"retryCount": @(retryCount), @"resumed": @(task[@"bytesWritten"].unsignedLongLongValue > 0) };
    [self.recoveryLock unlock];
    return record;
}

- (NSDictionary<NSString *,id> *)recoverySnapshot {
    [self.recoveryLock lock];
    NSDictionary *snapshot = @{ @"maximumRetryCount": @(self.maximumRetryCount), @"trackedTasks": @(self.retryCounts.count), @"totalFailures": @(self.totalFailures), @"totalRetries": @(self.totalRetries), @"resumeSupport": @"foundation" };
    [self.recoveryLock unlock];
    return snapshot;
}

- (NSError *)recoveryErrorWithCode:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:TiktigerDownloadRecoveryErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description ?: @"Download recovery operation failed."]}];
}

@end
