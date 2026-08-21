#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerFeatureState) {
    TiktigerFeatureStateRegistered = 0,
    TiktigerFeatureStateInitializing,
    TiktigerFeatureStateReady,
    TiktigerFeatureStateDisabled,
    TiktigerFeatureStateDegraded,
    TiktigerFeatureStateFailed
};

@protocol TiktigerFeatureProtocol <NSObject>

@property (nonatomic, copy, readonly) NSString *featureID;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *version;
@property (nonatomic, assign, readonly) TiktigerFeatureState state;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *configuration;

@end

NS_ASSUME_NONNULL_END
