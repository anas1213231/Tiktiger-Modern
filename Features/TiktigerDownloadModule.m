#import "TiktigerDownloadModule.h"

static NSString * const TiktigerDownloadModuleErrorDomain = @"com.tiktiger.download-module";

@interface TiktigerDownloadModule ()
@property (nonatomic, assign, readwrite) TiktigerDownloadState downloadState;
@property (nonatomic, assign, readwrite) double progress;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *queueState;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *lastError;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *queue;
@property (nonatomic, strong) NSDictionary<NSString *, id> *currentItem;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *errors;
@property (nonatomic, strong) NSLock *downloadLock;
@end

NSString *TiktigerStringFromDownloadState(TiktigerDownloadState state) {
    switch (state) {
        case TiktigerDownloadStateIdle: return @"idle";
        case TiktigerDownloadStatePreparing: return @"preparing";
        case TiktigerDownloadStateLoading: return @"loading";
        case TiktigerDownloadStateProcessing: return @"processing";
        case TiktigerDownloadStateCompleted: return @"completed";
        case TiktigerDownloadStateFailed: return @"failed";
    }
    return @"unknown";
}

@implementation TiktigerDownloadModule

- (instancetype)initWithFeatureID:(NSString *)featureID name:(NSString *)name version:(NSString *)version configuration:(NSDictionary<NSString *,id> *)configuration uiRepresentation:(NSDictionary<NSString *,id> *)uiRepresentation {
    self = [super initWithFeatureID:featureID name:name version:version configuration:configuration uiRepresentation:uiRepresentation];
    if (self) {
        _queue = [[NSMutableArray alloc] init];
        _errors = [[NSMutableArray alloc] init];
        _downloadLock = [[NSLock alloc] init];
        _downloadState = TiktigerDownloadStateIdle;
        _progress = 0.0;
        _queueState = @{ @"queued": @0, @"completed": @0, @"active": @NO };
        _lastError = @{};
    }
    return self;
}

- (NSUInteger)queueLimit {
    NSNumber *limit = self.configuration[@"queueLimit"];
    return limit.unsignedIntegerValue > 0 ? limit.unsignedIntegerValue : 5;
}

- (BOOL)validateMediaType:(NSString *)mediaType destination:(NSString *)destination error:(NSError **)error {
    NSSet *allowedMedia = [NSSet setWithObjects:@"video", @"audio", @"image", nil];
    if (![allowedMedia containsObject:mediaType] || destination.length == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Media type or destination is invalid."}]; }
        return NO;
    }
    return YES;
}

- (BOOL)enable:(NSError **)error {
    NSNumber *queueLimit = self.configuration[@"queueLimit"];
    if (![queueLimit isKindOfClass:[NSNumber class]] || queueLimit.unsignedIntegerValue == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"Download configuration requires a positive queueLimit."}]; }
        return NO;
    }
    return [super enable:error];
}

- (BOOL)enqueueMediaType:(NSString *)mediaType destination:(NSString *)destination error:(NSError **)error {
    [self.downloadLock lock];
    BOOL valid = [self validateMediaType:mediaType destination:destination error:error];
    if (!valid || self.queue.count >= [self queueLimit]) {
        if (!valid) { [self.downloadLock unlock]; return NO; }
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Download queue limit reached."}]; }
        [self.downloadLock unlock];
        return NO;
    }
    NSDictionary *item = @{ @"id": [NSUUID UUID].UUIDString, @"mediaType": mediaType, @"destination": destination, @"state": @"queued", @"progress": @0.0 };
    [self.queue addObject:item];
    self.downloadState = TiktigerDownloadStatePreparing;
    [self refreshQueueState];
    [self.downloadLock unlock];
    return YES;
}

- (BOOL)prepareNext:(NSError **)error {
    [self.downloadLock lock];
    if (self.queue.count == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"No queued download is available."}]; }
        self.downloadState = TiktigerDownloadStateFailed;
        [self.downloadLock unlock];
        return NO;
    }
    self.currentItem = self.queue.firstObject;
    self.downloadState = TiktigerDownloadStateLoading;
    self.progress = 0.0;
    [self refreshQueueState];
    [self.downloadLock unlock];
    return YES;
}

- (BOOL)updateProgress:(double)progress error:(NSError **)error {
    [self.downloadLock lock];
    if (self.currentItem == nil || progress < 0.0 || progress > 1.0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: @"Progress requires an active item and a value between 0 and 1."}]; }
        [self.downloadLock unlock];
        return NO;
    }
    self.progress = progress;
    self.downloadState = progress >= 1.0 ? TiktigerDownloadStateProcessing : TiktigerDownloadStateLoading;
    [self refreshQueueState];
    [self.downloadLock unlock];
    return YES;
}

- (BOOL)completeCurrent:(NSError **)error {
    [self.downloadLock lock];
    if (self.currentItem == nil) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:6 userInfo:@{NSLocalizedDescriptionKey: @"No active download is available to complete."}]; }
        [self.downloadLock unlock];
        return NO;
    }
    NSUInteger completed = [self.queueState[@"completed"] unsignedIntegerValue] + 1;
    self.progress = 1.0;
    self.downloadState = TiktigerDownloadStateCompleted;
    [self.queue removeObjectAtIndex:0];
    self.currentItem = nil;
    self.queueState = @{ @"queued": @(self.queue.count), @"completed": @(completed), @"active": @NO, @"state": TiktigerStringFromDownloadState(self.downloadState) };
    [self.downloadLock unlock];
    return YES;
}

- (BOOL)retryCurrent:(NSError **)error {
    [self.downloadLock lock];
    BOOL canRetry = self.downloadState == TiktigerDownloadStateFailed && self.queue.count > 0;
    if (!canRetry) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:8 userInfo:@{NSLocalizedDescriptionKey: @"No failed download is available to retry."}]; }
        [self.downloadLock unlock];
        return NO;
    }
    self.lastError = @{};
    self.progress = 0.0;
    self.downloadState = TiktigerDownloadStatePreparing;
    [self refreshQueueState];
    [self.downloadLock unlock];
    return [self prepareNext:error];
}

- (BOOL)failCurrentWithError:(NSError *)error {
    [self.downloadLock lock];
    NSError *safeError = error ?: [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:7 userInfo:@{NSLocalizedDescriptionKey: @"Unknown download failure."}];
    self.downloadState = TiktigerDownloadStateFailed;
    self.lastError = @{ @"domain": safeError.domain ?: @"", @"code": @(safeError.code), @"message": safeError.localizedDescription ?: @"" };
    [self.errors addObject:self.lastError];
    [self refreshQueueState];
    [self.downloadLock unlock];
    return YES;
}

- (void)refreshQueueState {
    NSUInteger completed = 0;
    NSNumber *completedValue = self.queueState[@"completed"];
    completed = completedValue.unsignedIntegerValue;
    self.queueState = @{ @"queued": @(self.queue.count), @"completed": @(completed), @"active": @(self.currentItem != nil), @"state": TiktigerStringFromDownloadState(self.downloadState) };
}

- (NSDictionary<NSString *,id> *)downloadSnapshot {
    [self.downloadLock lock];
    NSDictionary *snapshot = @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromDownloadState(self.downloadState),
        @"progress": @(self.progress),
        @"queue": self.queueState ?: @{},
        @"lastError": self.lastError ?: @{}
    };
    [self.downloadLock unlock];
    return snapshot;
}

- (NSDictionary<NSString *,id> *)healthCheck {
    [self.downloadLock lock];
    NSDictionary *snapshot = @{ @"featureID": self.featureID ?: @"", @"name": self.name ?: @"", @"version": self.version ?: @"", @"state": TiktigerStringFromDownloadState(self.downloadState), @"progress": @(self.progress), @"queue": self.queueState ?: @{}, @"lastError": self.lastError ?: @{} };
    NSMutableDictionary *health = [snapshot mutableCopy];
    health[@"healthy"] = @(self.downloadState != TiktigerDownloadStateFailed);
    health[@"errorCount"] = @(self.errors.count);
    health[@"configurationState"] = self.configuration[@"schemaVersion"] ? @"valid" : @"fallback";
    [self.downloadLock unlock];
    return [health copy];
}

@end
