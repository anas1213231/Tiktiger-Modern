#import "TiktigerLifecycleManager.h"

static NSString * const TiktigerLifecycleErrorDomain = @"com.tiktiger.lifecycle";

@interface TiktigerLifecycleManager ()
@property (nonatomic, assign, readwrite) TiktigerRuntimeState state;
@property (nonatomic, copy, readwrite) NSString *version;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation TiktigerLifecycleManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = TiktigerRuntimeStateStopped;
        _version = @"0.1.0-foundation";
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (BOOL)start:(NSError **)error {
    [self.lock lock];
    @try {
        if (self.state == TiktigerRuntimeStateReady) {
            return YES;
        }
        if (self.state == TiktigerRuntimeStateBootstrapping || self.state == TiktigerRuntimeStateShuttingDown) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:TiktigerLifecycleErrorDomain
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Lifecycle transition is already in progress."}];
            }
            return NO;
        }
        self.state = TiktigerRuntimeStateBootstrapping;
        // Foundation-only startup: no target-specific work, hooks, or feature execution.
        self.state = TiktigerRuntimeStateReady;
        return YES;
    } @finally {
        [self.lock unlock];
    }
}

- (void)shutdown {
    [self.lock lock];
    @try {
        if (self.state == TiktigerRuntimeStateStopped) {
            return;
        }
        self.state = TiktigerRuntimeStateShuttingDown;
        self.state = TiktigerRuntimeStateStopped;
    } @finally {
        [self.lock unlock];
    }
}

@end
