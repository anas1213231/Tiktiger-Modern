#import "Tiktiger.h"
#import "TiktigerLifecycleManager.h"
#import "TiktigerDiagnosticsManager.h"

NSString * const TiktigerVersion = @"0.1.0-foundation";

static TiktigerLifecycleManager *TiktigerSharedLifecycle(void) {
    static TiktigerLifecycleManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[TiktigerLifecycleManager alloc] init];
    });
    return manager;
}

static TiktigerDiagnosticsManager *TiktigerSharedDiagnostics(void) {
    static TiktigerDiagnosticsManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[TiktigerDiagnosticsManager alloc] init];
    });
    return manager;
}

BOOL TiktigerInitialize(void) {
    NSError *error = nil;
    TiktigerLifecycleManager *lifecycle = TiktigerSharedLifecycle();
    BOOL started = [lifecycle start:&error];
    TiktigerDiagnosticsManager *diagnostics = TiktigerSharedDiagnostics();
    [diagnostics updateRuntimeState:lifecycle.state version:lifecycle.version];
    if (!started && error != nil) {
        [diagnostics recordError:error category:@"runtime"];
    }
    return started;
}

const char *TiktigerGetVersion(void) {
    return TiktigerVersion.UTF8String;
}

TiktigerRuntimeState TiktigerGetStatus(void) {
    return TiktigerSharedLifecycle().state;
}

void TiktigerShutdown(void) {
    TiktigerLifecycleManager *lifecycle = TiktigerSharedLifecycle();
    [lifecycle shutdown];
    [TiktigerSharedDiagnostics() updateRuntimeState:lifecycle.state version:lifecycle.version];
}
