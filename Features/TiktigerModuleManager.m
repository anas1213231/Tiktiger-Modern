#import "TiktigerModuleManager.h"

@implementation TiktigerModuleManager

- (instancetype)init {
    self = [super init];
    if (self) { _registry = [[TiktigerFeatureRegistry alloc] init]; }
    return self;
}

- (BOOL)registerModule:(id<TiktigerFeatureModuleProtocol>)module error:(NSError **)error { return [self.registry registerModule:module error:error]; }
- (BOOL)enableModuleWithID:(NSString *)featureID error:(NSError **)error { return [self.registry enableModuleWithID:featureID error:error]; }
- (BOOL)disableModuleWithID:(NSString *)featureID error:(NSError **)error { return [self.registry disableModuleWithID:featureID error:error]; }
- (NSDictionary<NSString *,NSDictionary<NSString *,id> *> *)statusSnapshot { return [self.registry moduleStatusSnapshot]; }
- (NSDictionary<NSString *,NSDictionary<NSString *,id> *> *)healthSnapshot { return [self.registry moduleHealthSnapshot]; }

@end
