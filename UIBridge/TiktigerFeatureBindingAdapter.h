#import <Foundation/Foundation.h>
#import "TiktigerFeatureBinding.h"
@class TiktigerModuleManager;

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerFeatureBindingAdapter : NSObject <TiktigerFeatureBinding>

- (instancetype)initWithModuleManager:(TiktigerModuleManager *)moduleManager;

@end

NS_ASSUME_NONNULL_END
