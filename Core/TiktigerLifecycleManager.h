#import <Foundation/Foundation.h>
#import "TiktigerRuntimeState.h"

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerLifecycleManager : NSObject

@property (nonatomic, assign, readonly) TiktigerRuntimeState state;
@property (nonatomic, copy, readonly) NSString *version;

- (BOOL)start:(NSError * _Nullable * _Nullable)error;
- (void)shutdown;

@end

NS_ASSUME_NONNULL_END
