#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerTikTokEntryPointKind) {
    TiktigerTikTokEntryPointKindVideoAction = 0,
    TiktigerTikTokEntryPointKindShareMenu,
    TiktigerTikTokEntryPointKindProfileSettings
};

typedef NS_ENUM(NSInteger, TiktigerTikTokEntryPointState) {
    TiktigerTikTokEntryPointStateUnavailable = 0,
    TiktigerTikTokEntryPointStateAvailable,
    TiktigerTikTokEntryPointStatePreparing,
    TiktigerTikTokEntryPointStateFailed
};

FOUNDATION_EXPORT NSString *TiktigerStringFromTikTokEntryPointKind(TiktigerTikTokEntryPointKind kind);
FOUNDATION_EXPORT NSString *TiktigerStringFromTikTokEntryPointState(TiktigerTikTokEntryPointState state);

@interface TiktigerTikTokEntryPointContract : NSObject

+ (NSArray<NSString *> *)supportedEntryPointIdentifiers;
+ (NSString *)identifierForEntryPointKind:(TiktigerTikTokEntryPointKind)kind;
+ (BOOL)entryPointKindForIdentifier:(NSString *)identifier kind:(TiktigerTikTokEntryPointKind *)kind;

/// Returns a host-facing immutable descriptor. It never creates a button or executes an action.
+ (NSDictionary<NSString *, id> *)evaluateEntryPoint:(TiktigerTikTokEntryPointKind)kind
                                             context:(NSDictionary<NSString *, id> *)context
                                  compatibilityProfile:(NSString *)compatibilityProfile
                                  navigationAvailable:(BOOL)navigationAvailable
                                         runtimeReady:(BOOL)runtimeReady
                                               error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
