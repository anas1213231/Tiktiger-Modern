#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerTikTokIntegrationDiagnostics : NSObject

- (void)recordEntryPointState:(NSDictionary<NSString *, id> *)state;
- (void)recordNavigationState:(NSDictionary<NSString *, id> *)state;
- (void)recordCompatibilityResult:(NSDictionary<NSString *, id> *)result;
- (void)recordPresentationState:(NSDictionary<NSString *, id> *)state;
- (void)recordDownloadFlowState:(NSDictionary<NSString *, id> *)state;

- (NSDictionary<NSString *, id> *)snapshot;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
