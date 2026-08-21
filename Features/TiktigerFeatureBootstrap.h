#import <Foundation/Foundation.h>
@class TiktigerModuleManager;

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerFeatureBootstrap : NSObject

+ (NSArray<NSString *> *)registerPriorityModulesIntoManager:(TiktigerModuleManager *)manager error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
