#import <Foundation/Foundation.h>
#import "TiktigerRuntimeState.h"
#import "TiktigerFeatureRegistry.h"
#import "TiktigerConfigurationManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerDiagnosticsManager : NSObject

- (void)updateRuntimeState:(TiktigerRuntimeState)state version:(NSString *)version;
- (void)updateFeatureStatus:(NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)features;
- (void)updateConfigurationStatus:(NSDictionary<NSString *, id> *)configuration;
- (void)recordError:(NSError *)error category:(NSString *)category;
- (NSDictionary<NSString *, id> *)statusSnapshot;

@end

NS_ASSUME_NONNULL_END
