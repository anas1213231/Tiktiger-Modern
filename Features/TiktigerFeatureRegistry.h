#import <Foundation/Foundation.h>
#import "TiktigerFeatureProtocol.h"
#import "TiktigerFeatureModuleProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerFeatureRegistry : NSObject

- (BOOL)registerFeature:(id<TiktigerFeatureProtocol>)feature error:(NSError * _Nullable * _Nullable)error;
- (BOOL)removeFeatureWithID:(NSString *)featureID error:(NSError * _Nullable * _Nullable)error;
- (id<TiktigerFeatureProtocol> _Nullable)featureWithID:(NSString *)featureID;
- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)statusSnapshot;

- (BOOL)registerModule:(id<TiktigerFeatureModuleProtocol>)module error:(NSError * _Nullable * _Nullable)error;
- (BOOL)removeModuleWithID:(NSString *)featureID error:(NSError * _Nullable * _Nullable)error;
- (BOOL)enableModuleWithID:(NSString *)featureID error:(NSError * _Nullable * _Nullable)error;
- (BOOL)disableModuleWithID:(NSString *)featureID error:(NSError * _Nullable * _Nullable)error;
- (id<TiktigerFeatureModuleProtocol> _Nullable)moduleWithID:(NSString *)featureID;
- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)moduleStatusSnapshot;
- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)moduleHealthSnapshot;

@end

NS_ASSUME_NONNULL_END
