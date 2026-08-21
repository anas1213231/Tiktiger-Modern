#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerDownloadRecoveryManager : NSObject

@property (nonatomic, assign, readonly) NSUInteger maximumRetryCount;

- (instancetype)initWithMaximumRetryCount:(NSUInteger)maximumRetryCount;
- (BOOL)canRetryTask:(NSDictionary<NSString *, id> *)task error:(NSError * _Nullable * _Nullable)error;
- (BOOL)canResumeTask:(NSDictionary<NSString *, id> *)task error:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)recordFailureForTask:(NSDictionary<NSString *, id> *)task error:(NSError *)error;
- (NSDictionary<NSString *, id> *)recordRetryForTask:(NSDictionary<NSString *, id> *)task;
- (NSDictionary<NSString *, id> *)recoverySnapshot;

@end

NS_ASSUME_NONNULL_END
