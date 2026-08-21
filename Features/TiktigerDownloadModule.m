#import "TiktigerDownloadModule.h"
#import "TiktigerDownloadEngine.h"
#import "TiktigerDownloadStorageManager.h"
#import "TiktigerMediaProcessingLayer.h"
#import "TiktigerDownloadRecoveryManager.h"

static NSString * const TiktigerDownloadModuleErrorDomain = @"com.tiktiger.download-module";
static NSUInteger const TiktigerDownloadHistoryLimit = 100;

@interface TiktigerDownloadModule ()
@property (nonatomic, assign, readwrite) TiktigerDownloadState downloadState;
@property (nonatomic, assign, readwrite) double progress;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *queueState;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, id> *lastError;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary<NSString *, id> *> *queue;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *history;
@property (nonatomic, strong) NSDictionary<NSString *, id> *currentItem;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *errors;
@property (nonatomic, strong) NSLock *downloadLock;
@property (nonatomic, strong) TiktigerDownloadEngine *engine;
@property (nonatomic, strong) TiktigerDownloadStorageManager *storageManager;
@property (nonatomic, copy) TiktigerDownloadModuleEventHandler eventHandler;
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
        _history = [[NSMutableArray alloc] init];
        _errors = [[NSMutableArray alloc] init];
        _downloadLock = [[NSLock alloc] init];
        _engine = [self makeEngine];
        _downloadState = TiktigerDownloadStateIdle;
        _progress = 0.0;
        _queueState = @{ @"queued": @0, @"completed": @0, @"active": @NO, @"state": @"idle", @"items": @[] };
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
    if (![allowedMedia containsObject:mediaType.lowercaseString] || destination.length == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Media type or destination is invalid."}]; }
        return NO;
    }
    return YES;
}

- (BOOL)enable:(NSError **)error {
    if ([self.engine.snapshot[@"engineState"] isEqualToString:@"shutting-down"]) { self.engine = [self makeEngine]; }
    NSNumber *queueLimit = self.configuration[@"queueLimit"];
    if (![queueLimit isKindOfClass:[NSNumber class]] || queueLimit.unsignedIntegerValue == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"Download configuration requires a positive queueLimit."}]; }
        return NO;
    }
    return [super enable:error];
}

- (BOOL)disable:(NSError **)error {
    [self.engine shutdown];
    return [super disable:error];
}

- (BOOL)enqueueMediaType:(NSString *)mediaType destination:(NSString *)destination error:(NSError **)error {
    NSString *configuredSource = [self.configuration[@"sourceURL"] isKindOfClass:[NSString class]] ? self.configuration[@"sourceURL"] : nil;
    NSURL *sourceURL = configuredSource.length > 0 ? [NSURL URLWithString:configuredSource] : nil;
    return [self enqueueMediaType:mediaType destination:destination sourceURL:sourceURL error:error];
}

- (BOOL)enqueueMediaType:(NSString *)mediaType destination:(NSString *)destination sourceURL:(NSURL *)sourceURL error:(NSError **)error {
    NSError *validationError = nil;
    if (![self validateMediaType:mediaType destination:destination error:&validationError]) {
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    if (![self isValidHTTPSourceURL:sourceURL]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:9 userInfo:@{NSLocalizedDescriptionKey: @"An authorized HTTP(S) sourceURL is required to start a real download."}]; }
        return NO;
    }
    NSString *taskID = [NSUUID UUID].UUIDString;
    NSMutableDictionary *item = [@{
        @"id": taskID,
        @"mediaType": mediaType.lowercaseString,
        @"destination": destination,
        @"sourceURL": sourceURL.absoluteString ?: @"",
        @"state": @"queued",
        @"progress": @0.0,
        @"retryCount": @0
    } mutableCopy];

    [self.downloadLock lock];
    if (self.queue.count >= [self queueLimit]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Download queue limit reached."}]; }
        [self.downloadLock unlock];
        return NO;
    }
    [self.queue addObject:item];
    self.currentItem = [item copy];
    self.downloadState = TiktigerDownloadStatePreparing;
    [self refreshQueueState];
    [self.downloadLock unlock];
    [self emitSnapshotEvent];

    __weak typeof(self) weakSelf = self;
    TiktigerDownloadEngineProgressHandler progressHandler = ^(NSString *engineTaskID, double progress, TiktigerDownloadEngineState state) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf handleEngineProgressForTaskID:engineTaskID progress:progress state:state];
    };
    TiktigerDownloadEngineCompletionHandler completionHandler = ^(NSString *engineTaskID, NSURL *destinationURL, NSError *engineError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf handleEngineCompletionForTaskID:engineTaskID destinationURL:destinationURL error:engineError];
    };
    BOOL accepted = [self.engine enqueueSourceURL:sourceURL mediaType:mediaType destination:destination taskID:taskID progress:progressHandler completion:completionHandler error:&validationError];
    if (!accepted) {
        [self.downloadLock lock];
        [self.queue removeObject:item];
        self.currentItem = nil;
        self.downloadState = TiktigerDownloadStateFailed;
        NSError *safeError = validationError ?: [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:10 userInfo:@{NSLocalizedDescriptionKey: @"Download engine rejected the task."}];
        self.lastError = [self errorSnapshotFromError:safeError];
        [self.errors addObject:self.lastError];
        [self refreshQueueState];
        [self.downloadLock unlock];
        [self emitSnapshotEvent];
        if (error != NULL) { *error = safeError; }
        return NO;
    }
    return YES;
}

- (BOOL)prepareNext:(NSError **)error {
    [self.downloadLock lock];
    if (self.queue.count == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"No queued download is available."}]; }
        self.downloadState = TiktigerDownloadStateFailed;
        [self refreshQueueState];
        [self.downloadLock unlock];
        [self emitSnapshotEvent];
        return NO;
    }
    self.currentItem = [self.queue.firstObject copy];
    self.downloadState = TiktigerDownloadStatePreparing;
    [self refreshQueueState];
    [self.downloadLock unlock];
    [self emitSnapshotEvent];
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
    [self updateCurrentQueueItemWithState:TiktigerStringFromDownloadState(self.downloadState) progress:progress];
    [self refreshQueueState];
    [self.downloadLock unlock];
    [self emitSnapshotEvent];
    return YES;
}

- (BOOL)completeCurrent:(NSError **)error {
    [self.downloadLock lock];
    if (self.currentItem == nil) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:6 userInfo:@{NSLocalizedDescriptionKey: @"No active download is available to complete."}]; }
        [self.downloadLock unlock];
        return NO;
    }
    NSString *destinationPath = [self.currentItem[@"destinationURL"] isKindOfClass:[NSString class]] ? self.currentItem[@"destinationURL"] : nil;
    if (destinationPath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:15 userInfo:@{NSLocalizedDescriptionKey: @"Completion is controlled by the Download Engine after a real file is stored."}]; }
        [self.downloadLock unlock];
        return NO;
    }
    NSUInteger completed = [self.queueState[@"completed"] unsignedIntegerValue] + 1;
    NSMutableDictionary *historyItem = [self.currentItem mutableCopy];
    historyItem[@"state"] = @"completed";
    historyItem[@"progress"] = @1.0;
    historyItem[@"finishedAt"] = @([[NSDate date] timeIntervalSince1970]);
    [self appendHistoryItem:historyItem];
    self.progress = 1.0;
    self.downloadState = TiktigerDownloadStateCompleted;
    [self removeCurrentQueueItem];
    self.currentItem = nil;
    self.queueState = @{ @"queued": @(self.queue.count), @"completed": @(completed), @"active": @NO, @"state": TiktigerStringFromDownloadState(self.downloadState), @"items": [self.queue copy] };
    [self.downloadLock unlock];
    [self emitSnapshotEvent];
    return YES;
}

- (BOOL)retryCurrent:(NSError **)error {
    [self.downloadLock lock];
    NSDictionary *item = self.currentItem ?: self.queue.firstObject;
    NSString *taskID = item[@"id"];
    if (taskID.length == 0 || self.downloadState != TiktigerDownloadStateFailed) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:8 userInfo:@{NSLocalizedDescriptionKey: @"No failed download is available to retry."}]; }
        [self.downloadLock unlock];
        return NO;
    }
    self.lastError = @{};
    self.progress = 0.0;
    self.downloadState = TiktigerDownloadStatePreparing;
    [self updateCurrentQueueItemWithState:@"queued" progress:0.0];
    [self refreshQueueState];
    [self.downloadLock unlock];
    [self emitSnapshotEvent];

    NSError *retryError = nil;
    BOOL retried = [self.engine retryTaskWithID:taskID progress:nil completion:nil error:&retryError];
    if (!retried) {
        [self.downloadLock lock];
        self.downloadState = TiktigerDownloadStateFailed;
        NSError *safeRetryError = retryError ?: [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:14 userInfo:@{NSLocalizedDescriptionKey: @"Download retry was rejected."}];
        self.lastError = [self errorSnapshotFromError:safeRetryError];
        [self updateCurrentQueueItemWithState:@"failed" progress:self.progress];
        [self refreshQueueState];
        [self.downloadLock unlock];
        [self emitSnapshotEvent];
        if (error != NULL) { *error = retryError; }
        return NO;
    }
    return YES;
}

- (BOOL)failCurrentWithError:(NSError *)error {
    NSString *taskID = [self currentTaskID];
    if (taskID.length == 0) { return NO; }
    [self handleEngineCompletionForTaskID:taskID destinationURL:nil error:error];
    return YES;
}

- (BOOL)pauseCurrent:(NSError **)error {
    NSString *taskID = [self currentTaskID];
    if (taskID.length == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:11 userInfo:@{NSLocalizedDescriptionKey: @"No active download is available to pause."}]; }
        return NO;
    }
    BOOL result = [self.engine pauseTaskWithID:taskID error:error];
    if (result) {
        [self.downloadLock lock];
        [self updateCurrentQueueItemWithState:@"paused" progress:self.progress];
        self.downloadState = TiktigerDownloadStateIdle;
        [self refreshQueueState];
        [self.downloadLock unlock];
        [self emitSnapshotEvent];
    }
    return result;
}

- (BOOL)resumeCurrent:(NSError **)error {
    NSString *taskID = [self currentTaskID];
    if (taskID.length == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:12 userInfo:@{NSLocalizedDescriptionKey: @"No paused download is available to resume."}]; }
        return NO;
    }
    BOOL result = [self.engine resumeTaskWithID:taskID error:error];
    if (result) {
        [self.downloadLock lock];
        self.downloadState = TiktigerDownloadStatePreparing;
        [self updateCurrentQueueItemWithState:@"queued" progress:self.progress];
        [self refreshQueueState];
        [self.downloadLock unlock];
        [self emitSnapshotEvent];
    }
    return result;
}

- (BOOL)cancelCurrent:(NSError **)error {
    NSString *taskID = [self currentTaskID];
    if (taskID.length == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:13 userInfo:@{NSLocalizedDescriptionKey: @"No active download is available to cancel."}]; }
        return NO;
    }
    return [self.engine cancelTaskWithID:taskID error:error];
}

- (BOOL)retryHistoryItemWithID:(NSString *)taskID error:(NSError **)error {
    [self.downloadLock lock];
    NSDictionary *historyItem = nil;
    for (NSDictionary *item in self.history) {
        if ([item[@"id"] isEqualToString:taskID]) { historyItem = item; break; }
    }
    NSString *sourceString = [historyItem[@"sourceURL"] isKindOfClass:[NSString class]] ? historyItem[@"sourceURL"] : nil;
    NSString *mediaType = [historyItem[@"mediaType"] isKindOfClass:[NSString class]] ? historyItem[@"mediaType"] : @"video";
    NSString *destination = [historyItem[@"destination"] isKindOfClass:[NSString class]] ? historyItem[@"destination"] : @"files";
    BOOL failed = [historyItem[@"state"] isEqualToString:@"failed"];
    [self.downloadLock unlock];
    if (!failed || sourceString.length == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:16 userInfo:@{NSLocalizedDescriptionKey: @"Only failed history items with a retained source URL can be retried."}]; }
        return NO;
    }
    NSURL *sourceURL = [NSURL URLWithString:sourceString];
    return [self enqueueMediaType:mediaType destination:destination sourceURL:sourceURL error:error];
}

- (BOOL)deleteHistoryItemWithID:(NSString *)taskID error:(NSError **)error {
    [self.downloadLock lock];
    NSDictionary *historyItem = nil;
    NSUInteger historyIndex = NSNotFound;
    for (NSUInteger index = 0; index < self.history.count; index += 1) {
        NSDictionary *item = self.history[index];
        if ([item[@"id"] isEqualToString:taskID]) { historyItem = item; historyIndex = index; break; }
    }
    [self.downloadLock unlock];
    if (historyItem == nil || historyIndex == NSNotFound) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:17 userInfo:@{NSLocalizedDescriptionKey: @"The requested history item was not found."}]; }
        return NO;
    }
    NSString *path = [historyItem[@"destinationURL"] isKindOfClass:[NSString class]] ? historyItem[@"destinationURL"] : nil;
    if (path.length > 0) {
        NSError *storageError = nil;
        if (![self.storageManager removeFileAtURL:[NSURL fileURLWithPath:path] error:&storageError]) {
            if (error != NULL) { *error = storageError; }
            return NO;
        }
    }
    [self.downloadLock lock];
    if (historyIndex < self.history.count && [self.history[historyIndex][@"id"] isEqualToString:taskID]) { [self.history removeObjectAtIndex:historyIndex]; }
    [self.downloadLock unlock];
    [self emitSnapshotEvent];
    return YES;
}

- (NSURL *)historyFileURLForID:(NSString *)taskID error:(NSError **)error {
    [self.downloadLock lock];
    NSString *path = nil;
    for (NSDictionary *item in self.history) {
        if ([item[@"id"] isEqualToString:taskID]) { path = [item[@"destinationURL"] isKindOfClass:[NSString class]] ? item[@"destinationURL"] : nil; break; }
    }
    [self.downloadLock unlock];
    if (path.length == 0) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:18 userInfo:@{NSLocalizedDescriptionKey: @"The history item has no stored file URL."}]; }
        return nil;
    }
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerDownloadModuleErrorDomain code:19 userInfo:@{NSLocalizedDescriptionKey: @"The stored history file is no longer available."}]; }
        return nil;
    }
    return fileURL;
}

- (NSDictionary<NSString *, id> *)downloadSnapshot {
    [self.downloadLock lock];
    NSDictionary *snapshot = @{
        @"featureID": self.featureID,
        @"name": self.name,
        @"version": self.version,
        @"state": TiktigerStringFromDownloadState(self.downloadState),
        @"progress": @(self.progress),
        @"queue": self.queueState ?: @{},
        @"currentItem": self.currentItem ?: @{},
        @"history": [self.history copy],
        @"configuration": self.configuration ?: @{},
        @"lastError": self.lastError ?: @{},
        @"engine": self.engine.snapshot ?: @{},
        @"engineState": self.engine.snapshot[@"engineState"] ?: @"ready"
    };
    [self.downloadLock unlock];
    return snapshot;
}

- (NSDictionary<NSString *,id> *)healthCheck {
    [self.downloadLock lock];
    NSDictionary *snapshot = @{ @"featureID": self.featureID ?: @"", @"name": self.name ?: @"", @"version": self.version ?: @"", @"state": TiktigerStringFromDownloadState(self.downloadState), @"progress": @(self.progress), @"queue": self.queueState ?: @{}, @"currentItem": self.currentItem ?: @{}, @"lastError": self.lastError ?: @{} };
    NSMutableDictionary *health = [snapshot mutableCopy];
    health[@"healthy"] = @(self.downloadState != TiktigerDownloadStateFailed);
    health[@"errorCount"] = @(self.errors.count);
    health[@"historyCount"] = @(self.history.count);
    health[@"engine"] = self.engine.snapshot ?: @{};
    health[@"engineState"] = self.engine.snapshot[@"engineState"] ?: @"ready";
    health[@"configurationState"] = self.configuration[@"schemaVersion"] ? @"valid" : @"fallback";
    [self.downloadLock unlock];
    return [health copy];
}

- (void)setEventHandler:(TiktigerDownloadModuleEventHandler)eventHandler {
    [self.downloadLock lock];
    _eventHandler = [eventHandler copy];
    [self.downloadLock unlock];
}

- (void)handleEngineProgressForTaskID:(NSString *)taskID progress:(double)progress state:(TiktigerDownloadEngineState)engineState {
    [self.downloadLock lock];
    NSMutableDictionary *item = [self mutableQueueItemWithID:taskID];
    if (item == nil) {
        [self.downloadLock unlock];
        return;
    }
    TiktigerDownloadState moduleState = [self moduleStateFromEngineState:engineState];
    NSString *stateString = TiktigerStringFromDownloadState(moduleState);
    item[@"state"] = stateString;
    item[@"progress"] = @(progress);
    NSDictionary *activeEngineItem = [self.engine.snapshot[@"activeTask"] isKindOfClass:[NSDictionary class]] ? self.engine.snapshot[@"activeTask"] : @{};
    if (activeEngineItem[@"bytesWritten"] != nil) { item[@"bytesWritten"] = activeEngineItem[@"bytesWritten"]; }
    if (activeEngineItem[@"totalBytesExpected"] != nil) { item[@"totalBytesExpected"] = activeEngineItem[@"totalBytesExpected"]; }
    self.currentItem = [item copy];
    self.progress = progress;
    self.downloadState = moduleState;
    [self refreshQueueState];
    [self.downloadLock unlock];
    [self emitSnapshotEvent];
}

- (void)handleEngineCompletionForTaskID:(NSString *)taskID destinationURL:(NSURL *)destinationURL error:(NSError *)error {
    [self.downloadLock lock];
    NSMutableDictionary *item = [self mutableQueueItemWithID:taskID];
    if (item == nil) {
        [self.downloadLock unlock];
        return;
    }
    if (error != nil && error.code == NSURLErrorCancelled) {
        [self removeQueueItemWithID:taskID];
        self.currentItem = nil;
        self.progress = 0.0;
        self.downloadState = TiktigerDownloadStateIdle;
        self.lastError = @{};
        [self refreshQueueState];
        [self.downloadLock unlock];
        [self emitSnapshotEvent];
        return;
    }
    if (error == nil) {
        item[@"state"] = @"completed";
        item[@"progress"] = @1.0;
        item[@"destinationURL"] = destinationURL.path ?: @"";
        item[@"finishedAt"] = @([[NSDate date] timeIntervalSince1970]);
        [self appendHistoryItem:item];
        NSUInteger completed = [self.queueState[@"completed"] unsignedIntegerValue] + 1;
        [self removeQueueItemWithID:taskID];
        self.currentItem = nil;
        self.progress = 1.0;
        self.downloadState = TiktigerDownloadStateCompleted;
        self.lastError = @{};
        self.queueState = @{ @"queued": @(self.queue.count), @"completed": @(completed), @"active": @NO, @"state": TiktigerStringFromDownloadState(self.downloadState), @"items": [self.queue copy] };
    } else {
        item[@"state"] = @"failed";
        item[@"progress"] = @(self.progress);
        item[@"error"] = [self errorSnapshotFromError:error];
        item[@"finishedAt"] = @([[NSDate date] timeIntervalSince1970]);
        self.currentItem = [item copy];
        self.downloadState = TiktigerDownloadStateFailed;
        self.lastError = item[@"error"];
        [self.errors addObject:self.lastError];
        [self appendHistoryItem:item];
        [self refreshQueueState];
    }
    [self.downloadLock unlock];
    [self emitSnapshotEvent];
}

- (void)emitSnapshotEvent {
    TiktigerDownloadModuleEventHandler handler = nil;
    NSDictionary *snapshot = [self downloadSnapshot];
    [self.downloadLock lock];
    handler = [self.eventHandler copy];
    [self.downloadLock unlock];
    if (handler != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{ handler(snapshot); });
    }
}

- (BOOL)isValidHTTPSourceURL:(NSURL *)sourceURL {
    NSString *scheme = sourceURL.scheme.lowercaseString;
    return sourceURL != nil && sourceURL.host.length > 0 && ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]);
}

- (TiktigerDownloadState)moduleStateFromEngineState:(TiktigerDownloadEngineState)state {
    switch (state) {
        case TiktigerDownloadEngineStateIdle: return TiktigerDownloadStateIdle;
        case TiktigerDownloadEngineStatePreparing: return TiktigerDownloadStatePreparing;
        case TiktigerDownloadEngineStateDownloading: return TiktigerDownloadStateLoading;
        case TiktigerDownloadEngineStateProcessing: return TiktigerDownloadStateProcessing;
        case TiktigerDownloadEngineStateCompleted: return TiktigerDownloadStateCompleted;
        case TiktigerDownloadEngineStateFailed: return TiktigerDownloadStateFailed;
    }
    return TiktigerDownloadStateFailed;
}

- (NSMutableDictionary<NSString *, id> *)mutableQueueItemWithID:(NSString *)taskID {
    for (NSMutableDictionary *item in self.queue) {
        if ([item[@"id"] isEqualToString:taskID]) { return item; }
    }
    return nil;
}

- (void)updateCurrentQueueItemWithState:(NSString *)state progress:(double)progress {
    NSString *taskID = self.currentItem[@"id"];
    NSMutableDictionary *item = [self mutableQueueItemWithID:taskID];
    if (item != nil) {
        item[@"state"] = state ?: @"unknown";
        item[@"progress"] = @(progress);
        self.currentItem = [item copy];
    }
}

- (void)removeCurrentQueueItem {
    NSString *taskID = self.currentItem[@"id"];
    [self removeQueueItemWithID:taskID];
}

- (void)removeQueueItemWithID:(NSString *)taskID {
    if (taskID.length == 0) { return; }
    NSMutableDictionary *item = [self mutableQueueItemWithID:taskID];
    if (item != nil) { [self.queue removeObject:item]; }
}

- (NSString *)currentTaskID {
    [self.downloadLock lock];
    NSString *taskID = [self.currentItem[@"id"] copy];
    [self.downloadLock unlock];
    return taskID;
}

- (void)appendHistoryItem:(NSDictionary<NSString *, id> *)item {
    if (item == nil) { return; }
    [self.history addObject:[item copy]];
    while (self.history.count > TiktigerDownloadHistoryLimit) { [self.history removeObjectAtIndex:0]; }
}

- (void)refreshQueueState {
    NSUInteger completed = [self.queueState[@"completed"] unsignedIntegerValue];
    self.queueState = @{ @"queued": @(self.queue.count), @"completed": @(completed), @"active": @(self.currentItem != nil), @"state": TiktigerStringFromDownloadState(self.downloadState), @"items": [self.queue copy] };
}

- (NSDictionary<NSString *, id> *)errorSnapshotFromError:(NSError *)error {
    return @{ @"domain": error.domain ?: @"", @"code": @(error.code), @"message": error.localizedDescription ?: @"" };
}

- (TiktigerDownloadEngine *)makeEngine {
    if (self.storageManager == nil) { self.storageManager = [[TiktigerDownloadStorageManager alloc] initWithRootDirectoryURL:nil]; }
    TiktigerMediaProcessingLayer *processingLayer = [[TiktigerMediaProcessingLayer alloc] init];
    NSUInteger retryCount = [self.configuration[@"maxRetryCount"] unsignedIntegerValue];
    TiktigerDownloadRecoveryManager *recoveryManager = [[TiktigerDownloadRecoveryManager alloc] initWithMaximumRetryCount:retryCount > 0 ? retryCount : 3];
    return [[TiktigerDownloadEngine alloc] initWithStorageManager:self.storageManager processingLayer:processingLayer recoveryManager:recoveryManager];
}

- (void)dealloc {
    [self.engine shutdown];
}

@end
