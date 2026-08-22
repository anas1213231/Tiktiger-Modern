#import <UIKit/UIKit.h>
#import "TiktigerHostTestRunner.h"

static NSString *TiktigerHostTestDocumentsDirectory(void) {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject ?: NSTemporaryDirectory();
}

static void TiktigerWriteHostTestStage(NSString *stage) {
    NSString *stagePath = [TiktigerHostTestDocumentsDirectory() stringByAppendingPathComponent:@"host-test-stage.log"];
    NSString *line = [NSString stringWithFormat:@"TIKTIGER_HOST_TEST_STAGE %@\n", stage ?: @"unknown"];
    NSError *error = nil;
    [line writeToFile:stagePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    NSLog(@"%@ path=%@ error=%@", [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet], stagePath, error.localizedDescription ?: @"");
}

static void TiktigerWriteHostTestResult(BOOL passed,
                                        NSDictionary *lifecycle,
                                        NSDictionary *compatibility,
                                        BOOL binding,
                                        NSError *lifecycleError,
                                        NSError *compatibilityError,
                                        NSError *bindingError) {
    NSString *marker = [NSString stringWithFormat:@"TIKTIGER_HOST_TEST_RESULT passed=%@ lifecycle=%@ compatibility=%@ binding=%@ errors=%@/%@/%@\n",
                        passed ? @"YES" : @"NO",
                        lifecycle ?: @{},
                        compatibility ?: @{},
                        binding ? @"YES" : @"NO",
                        lifecycleError.localizedDescription ?: @"",
                        compatibilityError.localizedDescription ?: @"",
                        bindingError.localizedDescription ?: @""];
    NSString *resultPath = [TiktigerHostTestDocumentsDirectory() stringByAppendingPathComponent:@"host-test-result.log"];
    NSError *writeError = nil;
    BOOL written = [marker writeToFile:resultPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    NSLog(@"%@ TIKTIGER_HOST_TEST_RESULT_FILE path=%@ written=%@ error=%@", marker, resultPath, written ? @"YES" : @"NO", writeError.localizedDescription ?: @"");
}

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        TiktigerWriteHostTestStage(@"main-start");
        TiktigerHostTestRunner *runner = [[TiktigerHostTestRunner alloc] init];
        TiktigerWriteHostTestStage(runner != nil ? @"runner-init-complete" : @"runner-init-failed");
        NSError *lifecycleError = nil;
        NSDictionary *lifecycle = [runner runLifecycleValidation:&lifecycleError];
        TiktigerWriteHostTestStage(@"lifecycle-complete");
        NSError *compatibilityError = nil;
        NSDictionary *compatibility = [runner runCompatibilityRecoveryValidation:&compatibilityError];
        TiktigerWriteHostTestStage(@"compatibility-complete");
        NSError *bindingError = nil;
        BOOL binding = [runner validateBindingRoutesAndDiagnostics:&bindingError];
        TiktigerWriteHostTestStage(@"binding-complete");
        BOOL passed = [lifecycle[@"passed"] boolValue] && [compatibility[@"passed"] boolValue] && binding;
        TiktigerWriteHostTestResult(passed, lifecycle, compatibility, binding, lifecycleError, compatibilityError, bindingError);
        TiktigerWriteHostTestStage(@"result-written");
        [runner.hostCoordinator shutdownHost:NULL];
        TiktigerShutdown();
        TiktigerWriteHostTestStage(passed ? @"main-complete-passed" : @"main-complete-failed");
        return passed ? EXIT_SUCCESS : EXIT_FAILURE;
    }
}
