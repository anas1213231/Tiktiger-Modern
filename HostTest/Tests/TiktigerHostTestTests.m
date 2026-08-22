#import <XCTest/XCTest.h>
#import <objc/message.h>

static id TiktigerHostTestCallDictionary(id target, SEL selector, NSError **error) {
    id (*message)(id, SEL, NSError **) = (void *)objc_msgSend;
    return message(target, selector, error);
}

static BOOL TiktigerHostTestCallBool(id target, SEL selector, NSError **error) {
    BOOL (*message)(id, SEL, NSError **) = (void *)objc_msgSend;
    return message(target, selector, error);
}

@interface TiktigerHostTestTests : XCTestCase
@property (nonatomic, strong) id runner;
@end

@implementation TiktigerHostTestTests

- (void)setUp {
    [super setUp];
    Class runnerClass = NSClassFromString(@"TiktigerHostTestRunner");
    XCTAssertNotNil(runnerClass, @"HostTest runner class must be present in the host application.");
    self.runner = [runnerClass new];
}

- (void)testRuntimeLifecycle {
    NSError *error = nil;
    NSDictionary *result = TiktigerHostTestCallDictionary(self.runner, @selector(runLifecycleValidation:), &error);
    XCTAssertNil(error, @"Runtime lifecycle error: %@", error);
    XCTAssertTrue([result[@"passed"] boolValue], @"Runtime lifecycle result: %@", result);
}

- (void)testCompatibilityRecovery {
    NSError *error = nil;
    NSDictionary *result = TiktigerHostTestCallDictionary(self.runner, @selector(runCompatibilityRecoveryValidation:), &error);
    XCTAssertNil(error, @"Compatibility/recovery error: %@", error);
    XCTAssertTrue([result[@"passed"] boolValue], @"Compatibility/recovery result: %@", result);
}

- (void)testDashboardRoutesBindingAndDiagnostics {
    NSError *error = nil;
    BOOL prepared = TiktigerHostTestCallBool(self.runner, @selector(prepareWithError:), &error);
    BOOL routes = prepared && TiktigerHostTestCallBool(self.runner, @selector(validateBindingRoutesAndDiagnostics:), &error);
    XCTAssertNil(error, @"Binding/route/diagnostics error: %@", error);
    XCTAssertTrue(routes, @"Binding/route/diagnostics validation failed");
}

@end
