#import <Foundation/Foundation.h>
#import "TiktigerFeatureModuleProtocol.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSDictionary<NSString *, id> * _Nonnull (^TiktigerFeatureHealthProvider)(void);

@interface TiktigerFeatureModuleDescriptor : NSObject <TiktigerFeatureModuleProtocol>

- (instancetype)initWithFeatureID:(NSString *)featureID
                              name:(NSString *)name
                           version:(NSString *)version
                     configuration:(NSDictionary<NSString *, id> *)configuration
                  uiRepresentation:(NSDictionary<NSString *, id> *)uiRepresentation;

@property (nonatomic, copy, readonly) NSString *featureID;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *version;
@property (nonatomic, assign, readonly) TiktigerFeatureModuleState state;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *diagnostics;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *uiRepresentation;
@property (nonatomic, copy) TiktigerFeatureHealthProvider healthProvider;

- (BOOL)applyConfiguration:(NSDictionary<NSString *, id> *)configuration error:(NSError * _Nullable * _Nullable)error;
- (BOOL)migrateFromVersion:(NSUInteger)sourceVersion toVersion:(NSUInteger)targetVersion error:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)safeFallback;

@end

NS_ASSUME_NONNULL_END
