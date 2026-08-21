#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const TiktigerNavigationRouteDownload;
FOUNDATION_EXPORT NSString * const TiktigerNavigationRoutePrivacy;
FOUNDATION_EXPORT NSString * const TiktigerNavigationRouteAppearance;
FOUNDATION_EXPORT NSString * const TiktigerNavigationRouteChat;
FOUNDATION_EXPORT NSString * const TiktigerNavigationRouteProfile;
FOUNDATION_EXPORT NSString * const TiktigerNavigationRouteSystem;
FOUNDATION_EXPORT NSString * const TiktigerNavigationRouteSystemSettings;

FOUNDATION_EXPORT NSArray<NSString *> *TiktigerSupportedNavigationRoutes(void);
FOUNDATION_EXPORT BOOL TiktigerIsSupportedNavigationRoute(NSString *route);
FOUNDATION_EXPORT NSString * _Nullable TiktigerNavigationRouteForFeatureID(NSString *featureID);
FOUNDATION_EXPORT NSString * _Nullable TiktigerFeatureIDForNavigationRoute(NSString *route);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *TiktigerNavigationMetadataForRoute(NSString *route);

NS_ASSUME_NONNULL_END
