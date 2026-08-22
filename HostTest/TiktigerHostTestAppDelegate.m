#import "TiktigerHostTestAppDelegate.h"
#import "TiktigerHostTestRunner.h"

@implementation TiktigerHostTestAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view.backgroundColor = UIColor.blackColor;
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];

    NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT launch-ready");
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT runner-init-start");
        TiktigerHostTestRunner *runner = [[TiktigerHostTestRunner alloc] init];
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT runner-init-complete runner=%@", runner);
        NSError *lifecycleError = nil;
        NSDictionary *lifecycle = [runner runLifecycleValidation:&lifecycleError];
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT lifecycle-complete result=%@ error=%@", lifecycle, lifecycleError);
        NSError *compatibilityError = nil;
        NSDictionary *compatibility = [runner runCompatibilityRecoveryValidation:&compatibilityError];
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT compatibility-complete result=%@ error=%@", compatibility, compatibilityError);
        NSError *bindingError = nil;
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT binding-prepare-start");
        BOOL bindingPrepared = [runner prepareWithError:&bindingError];
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT binding-prepare-complete prepared=%@ error=%@", bindingPrepared ? @"YES" : @"NO", bindingError);
        BOOL binding = bindingPrepared ? [runner validateBindingRoutesAndDiagnostics:&bindingError] : NO;
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT binding-validate-complete binding=%@ error=%@", binding ? @"YES" : @"NO", bindingError);
        BOOL passed = [lifecycle[@"passed"] boolValue] && [compatibility[@"passed"] boolValue] && binding;
        NSLog(@"TIKTIGER_HOST_TEST_RESULT passed=%@ lifecycle=%@ compatibility=%@ binding=%@ errors=%@/%@/%@", passed ? @"YES" : @"NO", lifecycle, compatibility, binding ? @"YES" : @"NO", lifecycleError.localizedDescription ?: @"", compatibilityError.localizedDescription ?: @"", bindingError.localizedDescription ?: @"");
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT shutdown-start");
        [runner.hostCoordinator shutdownHost:NULL];
        TiktigerShutdown();
        NSLog(@"TIKTIGER_HOST_TEST_CHECKPOINT shutdown-complete");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(passed ? EXIT_SUCCESS : EXIT_FAILURE);
        });
    });
    return YES;
}

@end
