#import <Foundation/Foundation.h>
#import "TiktigerFeatureRegistry.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerModuleManager : NSObject

@property (nonatomic, strong, readonly) TiktigerFeatureRegistry *registry;

- (BOOL)registerModule:(id<TiktigerFeatureModuleProtocol>)module error:(NSError * _Nullable * _Nullable)error;
- (BOOL)enableModuleWithID:(NSString *)featureID error:(NSError * _Nullable * _Nullable)error;
- (BOOL)disableModuleWithID:(NSString *)featureID error:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)statusSnapshot;
- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)healthSnapshot;

@end

NS_ASSUME_NONNULL_END
