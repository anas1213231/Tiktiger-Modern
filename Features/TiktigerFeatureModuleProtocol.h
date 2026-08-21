#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerFeatureModuleState) {
    TiktigerFeatureModuleStateRegistered = 0,
    TiktigerFeatureModuleStateEnabled,
    TiktigerFeatureModuleStateDisabled,
    TiktigerFeatureModuleStateDegraded,
    TiktigerFeatureModuleStateFailed
};

FOUNDATION_EXPORT NSString *TiktigerStringFromFeatureModuleState(TiktigerFeatureModuleState state);

@protocol TiktigerFeatureModuleProtocol <NSObject>

@property (nonatomic, copy, readonly) NSString *featureID;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *version;
@property (nonatomic, assign, readonly) TiktigerFeatureModuleState state;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *diagnostics;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *uiRepresentation;

- (BOOL)enable:(NSError * _Nullable * _Nullable)error;
- (BOOL)disable:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)healthCheck;

@end

NS_ASSUME_NONNULL_END
