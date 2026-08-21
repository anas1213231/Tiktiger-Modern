#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerTikTokCompatibilityProfile) {
    TiktigerTikTokCompatibilityProfileSupported = 0,
    TiktigerTikTokCompatibilityProfileSupportedLimited,
    TiktigerTikTokCompatibilityProfileUnknown,
    TiktigerTikTokCompatibilityProfileUnsupported,
    TiktigerTikTokCompatibilityProfileError
};

FOUNDATION_EXPORT NSString *TiktigerStringFromTikTokCompatibilityProfile(TiktigerTikTokCompatibilityProfile profile);

@interface TiktigerTikTokCompatibility : NSObject

@property (nonatomic, copy, readonly) NSString *approvedProductIdentifier;
@property (nonatomic, copy, readonly) NSArray<NSString *> *approvedVersions;

- (instancetype)initWithApprovedProductIdentifier:(NSString *)productIdentifier
                                  approvedVersions:(NSArray<NSString *> *)versions;

/// Evaluates host-provided metadata only; it never inspects private host internals.
- (TiktigerTikTokCompatibilityProfile)evaluateMetadata:(NSDictionary<NSString *, id> *)metadata
                                                result:(NSDictionary<NSString *, id> * _Nullable * _Nullable)result
                                                 error:(NSError * _Nullable * _Nullable)error;

- (NSDictionary<NSString *, id> *)compatibilitySnapshot;

@end

NS_ASSUME_NONNULL_END
