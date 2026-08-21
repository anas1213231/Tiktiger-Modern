#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TiktigerFeatureBinding <NSObject>

- (NSArray<NSDictionary<NSString *, id> *> *)dashboardFeatureCards;
- (NSDictionary<NSString *, NSArray<NSDictionary<NSString *, id> *> *> *)settingsFeatureControls;
- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)diagnosticsModuleHealth;
- (NSDictionary<NSString *, id> *)downloadPresentationState;
- (NSDictionary<NSString *, id> *)preferencesPresentation;

- (BOOL)setFeature:(NSString *)featureID enabled:(BOOL)enabled error:(NSError * _Nullable * _Nullable)error;
- (BOOL)executeFeatureAction:(NSString *)action featureID:(NSString *)featureID payload:(NSDictionary<NSString *, id> * _Nullable)payload error:(NSError * _Nullable * _Nullable)error;
- (BOOL)updateFeatureConfiguration:(NSString *)featureID configuration:(NSDictionary<NSString *, id> *)configuration error:(NSError * _Nullable * _Nullable)error;
- (id)subscribeToModuleEvents:(void (^ _Nonnull)(NSDictionary<NSString *, id> *event))handler;
- (void)unsubscribeFromModuleEvents:(id)token;

@end

NS_ASSUME_NONNULL_END
