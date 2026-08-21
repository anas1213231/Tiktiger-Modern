#import <Foundation/Foundation.h>
@class TiktigerHostCoordinator;
@class TiktigerPresentationBridge;

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerIntegrationValidation : NSObject

/// Returns immutable, preparation-only test case descriptors.
+ (NSArray<NSDictionary<NSString *, id> *> *)testCaseDescriptors;

/// Runs contract-level checks against injected preparation objects. It does not start a Target App.
+ (NSDictionary<NSString *, id> *)runContractChecksWithCoordinator:(TiktigerHostCoordinator *)coordinator
                                                  presentationBridge:(TiktigerPresentationBridge *)bridge;

@end

NS_ASSUME_NONNULL_END
