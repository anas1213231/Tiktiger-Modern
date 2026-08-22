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

    TiktigerHostTestRunner *runner = [[TiktigerHostTestRunner alloc] init];
    NSError *lifecycleError = nil;
    NSDictionary *lifecycle = [runner runLifecycleValidation:&lifecycleError];
    NSError *compatibilityError = nil;
    NSDictionary *compatibility = [runner runCompatibilityRecoveryValidation:&compatibilityError];
    NSError *bindingError = nil;
    BOOL binding = [runner validateBindingRoutesAndDiagnostics:&bindingError];
    BOOL passed = [lifecycle[@"passed"] boolValue] && [compatibility[@"passed"] boolValue] && binding;
    NSLog(@"TIKTIGER_HOST_TEST_RESULT passed=%@ lifecycle=%@ compatibility=%@ binding=%@ errors=%@/%@/%@", passed ? @"YES" : @"NO", lifecycle, compatibility, binding ? @"YES" : @"NO", lifecycleError.localizedDescription ?: @"", compatibilityError.localizedDescription ?: @"", bindingError.localizedDescription ?: @"");
    return YES;
}

@end
