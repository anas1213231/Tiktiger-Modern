#import "TiktigerDownloadEngine.h"
#import "TiktigerDownloadStorageManager.h"
#import "TiktigerMediaProcessingLayer.h"
#import "TiktigerDownloadRecoveryManager.h"

static NSString * const TiktigerDownloadEngineErrorDomain = @"com.tiktiger.download-engine";

typedef NS_ENUM(NSInteger, TiktigerDownloadTaskControlState) {
    TiktigerDownloadTaskControlStateQueued = 0,
    TiktigerDownloadTaskControlStateActive,
    TiktigerDownloadTaskControlStatePaused,
    TiktigerDownloadTaskControlStateFailed,
    TiktigerDownloadTaskControlStateCompleted
};

@interface TiktigerDownloadEngineTask : NSObject
@property (nonatomic, copy) NSString *taskID;
@property (nonatomic, strong) NSURL *sourceURL;
@property (nonatomic, copy) NSString *mediaType;
@property (nonatomic, copy) NSString *destination;
@property (nonatomic, strong) NSURL *destinationURL;
@property (nonatomic, strong) NSURLSessionDownloadTask *sessionTask;
@property (nonatomic, strong) NSData *resumeData;
@property (nonatomic, copy) TiktigerDownloadEngineProgressHandler progressHandler;
@property (nonatomic, copy) TiktigerDownloadEngineCompletionHandler completionHandler;
@property (nonatomic, assign) TiktigerDownloadEngineState state;
@property (nonatomic, assign) TiktigerDownloadTaskControlState controlState;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) int64_t bytesWritten;
@property (nonatomic, assign) int64_t totalBytesExpected;
@property (nonatomic, assign) NSUInteger retryCount;
@property (nonatomic, assign) BOOL pauseRequested;
@property (nonatomic, assign) BOOL cancelRequested;
@property (nonatomic, assign) BOOL didFinishDownloading;
@property (nonatomic, strong) NSError *lastError;
@end

@implementation TiktigerDownloadEngineTask

- (NSDictionary<NSString *,id> *)snapshot {
    NSMutableDictionary *snapshot = [@{
        @"id": self.taskID ?: @"",
        @"sourceURL": self.sourceURL.absoluteString ?: @"",
        @"mediaType": self.mediaType ?: @"",
        @"destination": self.destination ?: @"",
        @"destinationURL": self.destinationURL.path ?: @"",
        @"state": TiktigerStringFromDownloadEngineState(self.state),
        @"controlState": @(self.controlState),
        @"progress": @(self.progress),
        @"bytesWritten": @(self.bytesWritten),
        @"totalBytesExpected": @(self.totalBytesExpected),
        @"retryCount": @(self.retryCount),
        @"paused": @(self.controlState == TiktigerDownloadTaskControlStatePaused),
        @"resumable": @(self.resumeData.length > 0),
        @"lastError": self.lastError.localizedDescription ?: @""
    } mutableCopy];
    return [snapshot copy];
}

@end

@interface TiktigerDownloadEngine () <NSURLSessionDownloadDelegate>
@property (nonatomic, assign, readwrite) TiktigerDownloadEngineState state;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *,id> *snapshot;
@property (nonatomic, strong) TiktigerDownloadStorageManager *storageManager;
@property (nonatomic, strong) TiktigerMediaProcessingLayer *processingLayer;
@property (nonatomic, strong) TiktigerDownloadRecoveryManager *recoveryManager;
@property (nonatomic, strong) NSOperationQueue *workerQueue;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSLock *engineLock;
@property (nonatomic, strong) NSMutableDictionary<NSString *, TiktigerDownloadEngineTask *> *tasks;
@property (nonatomic, strong) NSMutableArray<TiktigerDownloadEngineTask *> *pendingTasks;
@property (nonatomic, strong) TiktigerDownloadEngineTask *activeTask;
@property (nonatomic, assign) BOOL shuttingDown;
@end

@implementation TiktigerDownloadEngine

- (instancetype)initWithStorageManager:(TiktigerDownloadStorageManager *)storageManager processingLayer:(TiktigerMediaProcessingLayer *)processingLayer recoveryManager:(TiktigerDownloadRecoveryManager *)recoveryManager {
    self = [super init];
    if (self) {
        _storageManager = storageManager ?: [[TiktigerDownloadStorageManager alloc] initWithRootDirectoryURL:nil];
        _processingLayer = processingLayer ?: [[TiktigerMediaProcessingLayer alloc] init];
        _recoveryManager = recoveryManager ?: [[TiktigerDownloadRecoveryManager alloc] initWithMaximumRetryCount:3];
        _engineLock = [[NSLock alloc] init];
        _tasks = [[NSMutableDictionary alloc] init];
        _pendingTasks = [[NSMutableArray alloc] init];
        _workerQueue = [[NSOperationQueue alloc] init];
        _workerQueue.name = @"com.tiktiger.download-engine.worker";
        _workerQueue.maxConcurrentOperationCount = 1;
        _workerQueue.qualityOfService = NSQualityOfServiceUtility;
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPMaximumConnectionsPerHost = 2;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:_workerQueue];
        _state = TiktigerDownloadEngineStateIdle;
        _snapshot = @{};
        [self refreshSnapshotLocked:NO];
    }
    return self;
}

- (BOOL)enqueueSourceURL:(NSURL *)sourceURL mediaType:(NSString *)mediaType destination:(NSString *)destination taskID:(NSString *)taskID progress:(TiktigerDownloadEngineProgressHandler)progress completion:(TiktigerDownloadEngineCompletionHandler)completion error:(NSError **)error {
    NSError *validationError = nil;
    if (![self.processingLayer validateSourceURL:sourceURL mediaType:mediaType error:&validationError]) {
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    NSString *safeTaskID = taskID.length > 0 ? taskID : [NSUUID UUID].UUIDString;
    NSURL *destinationURL = [self.storageManager destinationURLForMediaType:mediaType sourceURL:sourceURL taskID:safeTaskID destination:destination ?: @"files" error:&validationError];
    if (destinationURL == nil || ![self.storageManager prepareDestination:destinationURL error:&validationError]) {
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    if ([self.storageManager isDuplicateAtURL:destinationURL]) {
        if (error != NULL) { *error = [self engineErrorWithCode:3 description:@"A matching destination file already exists."]; }
        return NO;
    }
    TiktigerDownloadEngineTask *task = [[TiktigerDownloadEngineTask alloc] init];
    task.taskID = safeTaskID;
    task.sourceURL = sourceURL;
    task.mediaType = mediaType.lowercaseString;
    task.destination = destination ?: @"files";
    task.destinationURL = destinationURL;
    task.progressHandler = progress;
    task.completionHandler = completion;
    task.state = TiktigerDownloadEngineStatePreparing;
    task.controlState = TiktigerDownloadTaskControlStateQueued;
    task.totalBytesExpected = NSURLSessionTransferSizeUnknown;

    [self.engineLock lock];
    if (self.shuttingDown || self.tasks[task.taskID] != nil) {
        [self.engineLock unlock];
        if (error != NULL) { *error = [self engineErrorWithCode:4 description:self.shuttingDown ? @"Download engine is shutting down." : @"A task with this identifier already exists."]; }
        return NO;
    }
    self.tasks[task.taskID] = task;
    [self.pendingTasks addObject:task];
    [self refreshSnapshotLocked:YES];
    [self.engineLock unlock];
    [self startNextTaskIfNeeded];
    return YES;
}

- (BOOL)pauseTaskWithID:(NSString *)taskID error:(NSError **)error {
    [self.engineLock lock];
    TiktigerDownloadEngineTask *task = self.tasks[taskID];
    if (task == nil || task != self.activeTask || task.sessionTask == nil) {
        [self.engineLock unlock];
        if (error != NULL) { *error = [self engineErrorWithCode:5 description:@"Only the active download task can be paused."]; }
        return NO;
    }
    task.pauseRequested = YES;
    NSURLSessionDownloadTask *sessionTask = task.sessionTask;
    [self.engineLock unlock];
    [sessionTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        [self.engineLock lock];
        TiktigerDownloadEngineTask *current = self.tasks[taskID];
        if (current != nil && current.pauseRequested && !current.cancelRequested) {
            current.resumeData = resumeData;
            current.controlState = TiktigerDownloadTaskControlStatePaused;
            current.state = TiktigerDownloadEngineStateIdle;
            current.sessionTask = nil;
            self.activeTask = nil;
            self.state = TiktigerDownloadEngineStateIdle;
            [self refreshSnapshotLocked:YES];
        }
        [self.engineLock unlock];
        [self startNextTaskIfNeeded];
    }];
    return YES;
}

- (BOOL)resumeTaskWithID:(NSString *)taskID error:(NSError **)error {
    [self.engineLock lock];
    TiktigerDownloadEngineTask *task = self.tasks[taskID];
    BOOL valid = task != nil && task.controlState == TiktigerDownloadTaskControlStatePaused;
    if (!valid) {
        [self.engineLock unlock];
        if (error != NULL) { *error = [self engineErrorWithCode:6 description:@"Only a paused download task can be resumed."]; }
        return NO;
    }
    task.pauseRequested = NO;
    task.controlState = TiktigerDownloadTaskControlStateQueued;
    task.state = TiktigerDownloadEngineStatePreparing;
    [self.pendingTasks addObject:task];
    [self refreshSnapshotLocked:YES];
    [self.engineLock unlock];
    [self startNextTaskIfNeeded];
    return YES;
}

- (BOOL)cancelTaskWithID:(NSString *)taskID error:(NSError **)error {
    [self.engineLock lock];
    TiktigerDownloadEngineTask *task = self.tasks[taskID];
    if (task == nil) {
        [self.engineLock unlock];
        if (error != NULL) { *error = [self engineErrorWithCode:7 description:@"The requested download task was not found."]; }
        return NO;
    }
    task.cancelRequested = YES;
    [self.pendingTasks removeObject:task];
    NSURLSessionDownloadTask *sessionTask = task.sessionTask;
    BOOL active = (task == self.activeTask && sessionTask != nil);
    [self.engineLock unlock];
    if (active) {
        [sessionTask cancel];
    } else {
        NSError *cancelError = [self engineErrorWithCode:NSURLErrorCancelled description:@"Download task cancelled by the user."];
        [self finishTask:task fileURL:nil error:cancelError terminalState:TiktigerDownloadEngineStateFailed];
    }
    return YES;
}

- (BOOL)retryTaskWithID:(NSString *)taskID progress:(TiktigerDownloadEngineProgressHandler)progress completion:(TiktigerDownloadEngineCompletionHandler)completion error:(NSError **)error {
    [self.engineLock lock];
    TiktigerDownloadEngineTask *task = self.tasks[taskID];
    NSDictionary *taskSnapshot = [task snapshot];
    [self.engineLock unlock];
    if (task == nil) {
        if (error != NULL) { *error = [self engineErrorWithCode:8 description:@"The requested failed task was not found."]; }
        return NO;
    }
    NSError *recoveryError = nil;
    if (![self.recoveryManager canRetryTask:taskSnapshot error:&recoveryError]) {
        if (error != NULL) { *error = recoveryError; }
        return NO;
    }
    NSDictionary *retryRecord = [self.recoveryManager recordRetryForTask:taskSnapshot];
    [self.engineLock lock];
    task.retryCount = [retryRecord[@"retryCount"] unsignedIntegerValue];
    task.progressHandler = progress ?: task.progressHandler;
    task.completionHandler = completion ?: task.completionHandler;
    task.lastError = nil;
    task.pauseRequested = NO;
    task.cancelRequested = NO;
    task.didFinishDownloading = NO;
    task.controlState = TiktigerDownloadTaskControlStateQueued;
    task.state = TiktigerDownloadEngineStatePreparing;
    task.progress = 0.0;
    [self.pendingTasks removeObject:task];
    [self.pendingTasks addObject:task];
    [self refreshSnapshotLocked:YES];
    [self.engineLock unlock];
    [self startNextTaskIfNeeded];
    return YES;
}

- (void)shutdown {
    [self.engineLock lock];
    if (self.shuttingDown) {
        [self.engineLock unlock];
        return;
    }
    self.shuttingDown = YES;
    NSArray<TiktigerDownloadEngineTask *> *tasks = [self.tasks.allValues copy];
    [self.pendingTasks removeAllObjects];
    NSURLSession *session = self.session;
    self.activeTask = nil;
    self.state = TiktigerDownloadEngineStateIdle;
    [self refreshSnapshotLocked:YES];
    [self.engineLock unlock];
    for (TiktigerDownloadEngineTask *task in tasks) { [task.sessionTask cancel]; }
    [session invalidateAndCancel];
    [self.workerQueue cancelAllOperations];
}

- (void)startNextTaskIfNeeded {
    [self.engineLock lock];
    if (self.shuttingDown || self.activeTask != nil || self.pendingTasks.count == 0) {
        [self.engineLock unlock];
        return;
    }
    TiktigerDownloadEngineTask *task = self.pendingTasks.firstObject;
    [self.pendingTasks removeObjectAtIndex:0];
    task.controlState = TiktigerDownloadTaskControlStateActive;
    task.state = TiktigerDownloadEngineStatePreparing;
    self.activeTask = task;
    self.state = TiktigerDownloadEngineStatePreparing;

    NSURLSessionDownloadTask *sessionTask = nil;
    if (task.resumeData.length > 0) {
        sessionTask = [self.session downloadTaskWithResumeData:task.resumeData];
        task.resumeData = nil;
    } else {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:task.sourceURL];
        request.HTTPMethod = @"GET";
        request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        sessionTask = [self.session downloadTaskWithRequest:request];
    }
    task.sessionTask = sessionTask;
    [self refreshSnapshotLocked:YES];
    [self.engineLock unlock];
    [self emitProgressForTask:task];
    [sessionTask resume];
}

- (TiktigerDownloadEngineTask *)taskForSessionTask:(NSURLSessionTask *)sessionTask {
    [self.engineLock lock];
    TiktigerDownloadEngineTask *result = nil;
    for (TiktigerDownloadEngineTask *task in self.tasks.allValues) {
        if (task.sessionTask.taskIdentifier == sessionTask.taskIdentifier) { result = task; break; }
    }
    [self.engineLock unlock];
    return result;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    (void)session;
    TiktigerDownloadEngineTask *task = [self taskForSessionTask:downloadTask];
    if (task == nil) { return; }
    [self.engineLock lock];
    task.bytesWritten = totalBytesWritten;
    task.totalBytesExpected = totalBytesExpectedToWrite;
    task.progress = totalBytesExpectedToWrite > 0 ? MIN(MAX((double)totalBytesWritten / (double)totalBytesExpectedToWrite, 0.0), 1.0) : task.progress;
    task.state = TiktigerDownloadEngineStateDownloading;
    self.state = TiktigerDownloadEngineStateDownloading;
    [self refreshSnapshotLocked:YES];
    [self.engineLock unlock];
    [self emitProgressForTask:task];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    (void)session;
    TiktigerDownloadEngineTask *task = [self taskForSessionTask:downloadTask];
    if (task == nil || task.cancelRequested || task.pauseRequested) { return; }
    [self.engineLock lock];
    task.didFinishDownloading = YES;
    task.state = TiktigerDownloadEngineStateProcessing;
    task.progress = 1.0;
    self.state = TiktigerDownloadEngineStateProcessing;
    [self refreshSnapshotLocked:YES];
    [self.engineLock unlock];
    [self emitProgressForTask:task];

    NSError *processingError = nil;
    NSURL *processedURL = nil;
    BOOL processed = [self.processingLayer processDownloadedFileAtURL:location mediaType:task.mediaType outputURL:&processedURL error:&processingError];
    if (!processed) {
        [self finishTask:task fileURL:nil error:processingError terminalState:TiktigerDownloadEngineStateFailed];
        return;
    }
    NSError *storageError = nil;
    BOOL stored = [self.storageManager moveDownloadedFile:processedURL toDestination:task.destinationURL error:&storageError];
    if (!stored) {
        [self finishTask:task fileURL:nil error:storageError terminalState:TiktigerDownloadEngineStateFailed];
        return;
    }
    [self finishTask:task fileURL:task.destinationURL error:nil terminalState:TiktigerDownloadEngineStateCompleted];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)sessionTask didCompleteWithError:(NSError *)error {
    (void)session;
    TiktigerDownloadEngineTask *task = [self taskForSessionTask:sessionTask];
    if (task == nil) { return; }
    if (task.pauseRequested && !task.cancelRequested) { return; }
    if (error == nil && task.didFinishDownloading) { return; }
    if (error == nil) { return; }
    NSError *safeError = error;
    NSData *resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
    [self.engineLock lock];
    task.resumeData = resumeData;
    [self.engineLock unlock];
    [self finishTask:task fileURL:nil error:safeError terminalState:TiktigerDownloadEngineStateFailed];
}

- (void)finishTask:(TiktigerDownloadEngineTask *)task fileURL:(NSURL *)fileURL error:(NSError *)error terminalState:(TiktigerDownloadEngineState)terminalState {
    if (task == nil) { return; }
    TiktigerDownloadEngineCompletionHandler completion = task.completionHandler;
    [self.engineLock lock];
    task.state = terminalState;
    task.controlState = terminalState == TiktigerDownloadEngineStateCompleted ? TiktigerDownloadTaskControlStateCompleted : TiktigerDownloadTaskControlStateFailed;
    task.lastError = error;
    task.sessionTask = nil;
    if (self.activeTask == task) { self.activeTask = nil; }
    self.state = self.pendingTasks.count > 0 ? TiktigerDownloadEngineStatePreparing : TiktigerDownloadEngineStateIdle;
    if (terminalState == TiktigerDownloadEngineStateCompleted || error.code == NSURLErrorCancelled) { [self.tasks removeObjectForKey:task.taskID]; }
    [self refreshSnapshotLocked:YES];
    [self.engineLock unlock];

    if (error != nil && error.code != NSURLErrorCancelled) { [self.recoveryManager recordFailureForTask:[task snapshot] error:error]; }
    if (completion != nil) { completion(task.taskID, fileURL, error); }
    [self startNextTaskIfNeeded];
}

- (void)emitProgressForTask:(TiktigerDownloadEngineTask *)task {
    TiktigerDownloadEngineProgressHandler handler = task.progressHandler;
    if (handler != nil) { handler(task.taskID, task.progress, task.state); }
}

- (void)refreshSnapshotLocked:(BOOL)locked {
    if (!locked) { [self.engineLock lock]; }
    NSMutableArray *queueSnapshots = [[NSMutableArray alloc] initWithCapacity:self.pendingTasks.count];
    for (TiktigerDownloadEngineTask *task in self.pendingTasks) { [queueSnapshots addObject:[task snapshot]]; }
    NSMutableArray *taskSnapshots = [[NSMutableArray alloc] initWithCapacity:self.tasks.count];
    for (TiktigerDownloadEngineTask *task in self.tasks.allValues) { [taskSnapshots addObject:[task snapshot]]; }
    self.snapshot = @{
        @"state": TiktigerStringFromDownloadEngineState(self.state),
        @"activeTask": self.activeTask ? [self.activeTask snapshot] : @{},
        @"queue": [queueSnapshots copy],
        @"tasks": [taskSnapshots copy],
        @"taskCount": @(self.tasks.count),
        @"storage": [self.storageManager storageSnapshot] ?: @{},
        @"processing": [self.processingLayer capabilitySnapshot] ?: @{},
        @"recovery": [self.recoveryManager recoverySnapshot] ?: @{},
        @"engineState": self.shuttingDown ? @"shutting-down" : @"ready"
    };
    if (!locked) { [self.engineLock unlock]; }
}

- (NSError *)engineErrorWithCode:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:TiktigerDownloadEngineErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description ?: @"Download engine operation failed."}];
}

- (void)dealloc {
    [self shutdown];
}

@end
