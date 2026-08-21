#import "TiktigerFeatureModuleDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerDiagnosticsCenterFeature : TiktigerFeatureModuleDescriptor

- (void)recordEvent:(NSString *)event category:(NSString *)category;
- (void)recordError:(NSError *)error category:(NSString *)category;

@end

NS_ASSUME_NONNULL_END
