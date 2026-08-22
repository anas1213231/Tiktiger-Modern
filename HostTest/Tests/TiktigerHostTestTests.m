#import <XCTest/XCTest.h>
#import "../TiktigerHostTestRunner.h"

@interface TiktigerHostTestTests : XCTestCase
@property (nonatomic, strong) TiktigerHostTestRunner *runner;
@end

@implementation TiktigerHostTestTests

- (void)setUp {
    [super setUp];
    self.runner = [[TiktigerHostTestRunner alloc] init];
}

- (void)testRuntimeLifecycle {
    NSError *error = nil;
    NSDictionary *result = [self.runner runLifecycleValidation:&error];
    XCTAssertNil(error, @"Runtime lifecycle error: %@", error);
    XCTAssertTrue([result[@"passed"] boolValue], @"Runtime lifecycle result: %@", result);
}

- (void)testCompatibilityRecovery {
    NSError *error = nil;
    NSDictionary *result = [self.runner runCompatibilityRecoveryValidation:&error];
    XCTAssertNil(error, @"Compatibility/recovery error: %@", error);
    XCTAssertTrue([result[@"passed"] boolValue], @"Compatibility/recovery result: %@", result);
}

- (void)testDashboardRoutesBindingAndDiagnostics {
    NSError *error = nil;
    BOOL passed = [self.runner prepareWithError:&error] && [self.runner validateBindingRoutesAndDiagnostics:&error];
    XCTAssertNil(error, @"Binding/route/diagnostics error: %@", error);
    XCTAssertTrue(passed, @"Binding/route/diagnostics validation failed");
    [self.runner.hostCoordinator shutdownHost:NULL];
}

@end
