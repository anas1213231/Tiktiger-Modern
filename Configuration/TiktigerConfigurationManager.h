#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerConfigurationManager : NSObject

@property (nonatomic, assign, readonly) NSUInteger schemaVersion;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *currentConfiguration;

- (void)loadDefaults;
- (BOOL)applyConfiguration:(NSDictionary<NSString *, id> *)configuration error:(NSError * _Nullable * _Nullable)error;
- (BOOL)migrateFromVersion:(NSUInteger)sourceVersion toVersion:(NSUInteger)targetVersion error:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)safeFallback;
- (BOOL)validateConfiguration:(NSDictionary<NSString *, id> *)configuration error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
