#import <Foundation/Foundation.h>
#import "TiktigerFeatureBinding.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerPresentationBridge : NSObject

@property (nonatomic, weak, readonly) id<TiktigerFeatureBinding> binding;

- (instancetype)initWithBinding:(id<TiktigerFeatureBinding>)binding;

/// Returns an immutable dashboard entry snapshot for a host presentation layer.
- (NSDictionary<NSString *, id> *)dashboardPresentationEntry;

/// Validates a stable route and returns its host-facing metadata.
- (NSDictionary<NSString *, id> * _Nullable)metadataForRoute:(NSString *)route error:(NSError * _Nullable * _Nullable)error;

/// Maps a validated route to a feature ID without presenting a controller or touching a target app.
- (NSString * _Nullable)featureIDForRoute:(NSString *)route error:(NSError * _Nullable * _Nullable)error;

/// Returns the current center snapshot for a validated route.
- (NSDictionary<NSString *, id> * _Nullable)presentationStateForRoute:(NSString *)route error:(NSError * _Nullable * _Nullable)error;

/// Preparation-only routing descriptor for host navigation handlers.
- (NSDictionary<NSString *, id> * _Nullable)routingDescriptorForRoute:(NSString *)route error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
