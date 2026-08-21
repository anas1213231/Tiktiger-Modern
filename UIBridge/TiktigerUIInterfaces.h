#import <Foundation/Foundation.h>
#import "TiktigerPresentationContracts.h"

NS_ASSUME_NONNULL_BEGIN

@protocol TiktigerUIInterface <NSObject>

- (void)presentState:(TiktigerPresentationState)state message:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
