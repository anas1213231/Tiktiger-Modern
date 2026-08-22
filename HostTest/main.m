#import <UIKit/UIKit.h>
#import "TiktigerHostTestRunner.h"

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
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *resultPath = [documents stringByAppendingPathComponent:@"host-test-result.log"];
    NSError *writeError = nil;
    BOOL written = [marker writeToFile:resultPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    NSLog(@"%@ TIKTIGER_HOST_TEST_RESULT_FILE path=%@ written=%@ error=%@", marker, resultPath, written ? @"YES" : @"NO", writeError.localizedDescription ?: @"");
}

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT main-start");
        TiktigerHostTestRunner *runner = [[TiktigerHostTestRunner alloc] init];
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT runner-init-complete runner=%@", runner);
        NSError *lifecycleError = nil;
        NSDictionary *lifecycle = [runner runLifecycleValidation:&lifecycleError];
        NSError *compatibilityError = nil;
        NSDictionary *compatibility = [runner runCompatibilityRecoveryValidation:&compatibilityError];
        NSError *bindingError = nil;
        BOOL bindingPrepared = [runner prepareWithError:&bindingError];
        BOOL binding = bindingPrepared ? [runner validateBindingRoutesAndDiagnostics:&bindingError] : NO;
        BOOL passed = [lifecycle[@"passed"] boolValue] && [compatibility[@"passed"] boolValue] && binding;
        TiktigerWriteHostTestResult(passed, lifecycle, compatibility, binding, lifecycleError, compatibilityError, bindingError);
        [runner.hostCoordinator shutdownHost:NULL];
        TiktigerShutdown();
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT main-complete passed=%@", passed ? @"YES" : @"NO");
        return passed ? EXIT_SUCCESS : EXIT_FAILURE;
    }
}
