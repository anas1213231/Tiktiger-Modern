#import "TiktigerHostCoordinator.h"
#import "TiktigerDynamicLibraryLoader.h"

static NSString * const TiktigerHostCoordinatorErrorDomain = @"com.tiktiger.host-coordinator";

@interface TiktigerHostCoordinator ()
@property (nonatomic, strong) TiktigerDynamicLibraryLoader *loader;
@property (nonatomic, assign, readwrite) TiktigerHostCoordinatorState state;
@property (nonatomic, assign, readwrite) TiktigerRuntimeState runtimeState;
@property (nonatomic, copy, readwrite) NSString *lastErrorMessage;
@property (nonatomic, strong) NSLock *coordinatorLock;
@end

@implementation TiktigerHostCoordinator

- (instancetype)initWithLoader:(TiktigerDynamicLibraryLoader *)loader {
    self = [super init];
    if (self) {
        _loader = loader;
        _state = TiktigerHostCoordinatorStateIdle;
        _runtimeState = TiktigerRuntimeStateStopped;
        _lastErrorMessage = @"";
        _coordinatorLock = [[NSLock alloc] init];
    }
    return self;
}

- (BOOL)initializeHostWithArtifactMetadata:(NSDictionary<NSString *,id> *)metadata error:(NSError **)error {
    if (![self.loader validateArtifactMetadata:metadata error:error]) {
        [self.coordinatorLock lock];
        self.state = TiktigerHostCoordinatorStateFailed;
        self.runtimeState = TiktigerRuntimeStateStopped;
        self.lastErrorMessage = error != NULL && *error != nil ? (*error).localizedDescription : @"Artifact metadata validation failed.";
        [self.coordinatorLock unlock];
        return NO;
    }
    return [self initializeHost:error];
}

- (BOOL)initializeHost:(NSError **)error {
    [self.coordinatorLock lock];
    if (self.state == TiktigerHostCoordinatorStateReady) {
        [self.coordinatorLock unlock];
        return YES;
    }
    if (self.state == TiktigerHostCoordinatorStateInitializing || self.state == TiktigerHostCoordinatorStateShuttingDown) {
        NSError *transitionError = [NSError errorWithDomain:TiktigerHostCoordinatorErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Host lifecycle transition is already in progress."}];
        [self.coordinatorLock unlock];
        if (error != NULL) { *error = transitionError; }
        return NO;
    }
    self.state = TiktigerHostCoordinatorStateInitializing;
    self.lastErrorMessage = @"";
    [self.coordinatorLock unlock];

    NSError *initializationError = nil;
    BOOL initialized = [self.loader initializeLoadedLibrary:&initializationError];
    TiktigerRuntimeState runtimeState = [self.loader runtimeStatus];
    [self.coordinatorLock lock];
    self.runtimeState = runtimeState;
    if (!initialized) {
        self.state = TiktigerHostCoordinatorStateFailed;
        self.lastErrorMessage = initializationError.localizedDescription ?: @"Host initialization failed.";
    } else if (runtimeState == TiktigerRuntimeStateReady) {
        self.state = TiktigerHostCoordinatorStateReady;
        self.lastErrorMessage = @"";
    } else if (runtimeState == TiktigerRuntimeStateDegraded) {
        self.state = TiktigerHostCoordinatorStateDegraded;
        self.lastErrorMessage = @"Runtime initialized in degraded state.";
        if (initializationError == nil) { initializationError = [NSError errorWithDomain:TiktigerHostCoordinatorErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: self.lastErrorMessage}]; }
    } else {
        self.state = TiktigerHostCoordinatorStateFailed;
        self.lastErrorMessage = @"Runtime did not reach ready state after initialization.";
        if (initializationError == nil) { initializationError = [NSError errorWithDomain:TiktigerHostCoordinatorErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: self.lastErrorMessage}]; }
    }
    BOOL success = self.state == TiktigerHostCoordinatorStateReady;
    [self.coordinatorLock unlock];
    if (!success && error != NULL) { *error = initializationError; }
    return success;
}

- (BOOL)shutdownHost:(NSError **)error {
    [self.coordinatorLock lock];
    if (self.state == TiktigerHostCoordinatorStateStopped || self.state == TiktigerHostCoordinatorStateIdle) {
        self.state = TiktigerHostCoordinatorStateStopped;
        self.runtimeState = TiktigerRuntimeStateStopped;
        [self.coordinatorLock unlock];
        return YES;
    }
    if (self.state == TiktigerHostCoordinatorStateInitializing || self.state == TiktigerHostCoordinatorStateShuttingDown) {
        NSError *transitionError = [NSError errorWithDomain:TiktigerHostCoordinatorErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"Host shutdown cannot overlap an active lifecycle transition."}];
        [self.coordinatorLock unlock];
        if (error != NULL) { *error = transitionError; }
        return NO;
    }
    self.state = TiktigerHostCoordinatorStateShuttingDown;
    [self.coordinatorLock unlock];

    [self.loader shutdownLoadedLibrary];
    [self.coordinatorLock lock];
    self.state = TiktigerHostCoordinatorStateStopped;
    self.runtimeState = TiktigerRuntimeStateStopped;
    self.lastErrorMessage = @"";
    [self.coordinatorLock unlock];
    return YES;
}

- (BOOL)recoverHost:(NSError **)error {
    [self.coordinatorLock lock];
    BOOL eligible = self.state == TiktigerHostCoordinatorStateFailed || self.state == TiktigerHostCoordinatorStateDegraded;
    [self.coordinatorLock unlock];
    if (!eligible) {
        [self.coordinatorLock lock];
        BOOL alreadyReady = self.state == TiktigerHostCoordinatorStateReady;
        [self.coordinatorLock unlock];
        if (alreadyReady) { return YES; }
        NSError *recoveryError = [NSError errorWithDomain:TiktigerHostCoordinatorErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: @"Host recovery requires a failed or degraded preparation state."}];
        if (error != NULL) { *error = recoveryError; }
        return NO;
    }
    return [self initializeHost:error];
}

- (NSDictionary<NSString *,id> *)statusSnapshot {
    [self.coordinatorLock lock];
    NSDictionary *snapshot = @{
        @"state": TiktigerStringFromHostCoordinatorState(self.state),
        @"runtimeState": TiktigerStringFromRuntimeState(self.runtimeState),
        @"lastError": self.lastErrorMessage ?: @"",
        @"loader": [self.loader statusSnapshot] ?: @{},
        @"singleLifecycleOwner": @YES,
        @"preparationOnly": @YES,
        @"targetAppIntegrated": @NO
    };
    [self.coordinatorLock unlock];
    return [snapshot copy];
}

@end

NSString *TiktigerStringFromHostCoordinatorState(TiktigerHostCoordinatorState state) {
    switch (state) {
        case TiktigerHostCoordinatorStateIdle: return @"idle";
        case TiktigerHostCoordinatorStateInitializing: return @"initializing";
        case TiktigerHostCoordinatorStateReady: return @"ready";
        case TiktigerHostCoordinatorStateDegraded: return @"degraded";
        case TiktigerHostCoordinatorStateShuttingDown: return @"shutting-down";
        case TiktigerHostCoordinatorStateStopped: return @"stopped";
        case TiktigerHostCoordinatorStateFailed: return @"failed";
    }
    return @"unknown";
}
