#import <Foundation/Foundation.h>
#import "TiktigerRuntimeState.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const TiktigerVersion;

FOUNDATION_EXPORT BOOL TiktigerInitialize(void);
FOUNDATION_EXPORT const char *TiktigerGetVersion(void);
FOUNDATION_EXPORT TiktigerRuntimeState TiktigerGetStatus(void);
FOUNDATION_EXPORT void TiktigerShutdown(void);

NS_ASSUME_NONNULL_END
