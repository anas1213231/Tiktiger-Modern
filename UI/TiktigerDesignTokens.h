#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The single source of truth for Tiktiger VIP UI values.
@interface TiktigerDesignTokens : NSObject

+ (UIColor *)vipBlack;
+ (UIColor *)vipSurface;
+ (UIColor *)vipSurfaceElevated;
+ (UIColor *)vipWhite;
+ (UIColor *)vipWhiteSecondary;
+ (UIColor *)vipRed;
+ (UIColor *)vipSuccess;
+ (UIColor *)vipGlassBorder;
+ (UIColor *)vipDivider;
+ (UIColor *)vipGlassContent;
+ (UIColor *)vipClear;

+ (UIFont *)titleFont;
+ (UIFont *)subtitleFont;
+ (UIFont *)bodyFont;
+ (UIFont *)statusFont;
+ (UIFont *)developerFont;
+ (UIFont *)numericFont;

+ (CGFloat)screenMargin;
+ (CGFloat)sectionGap;
+ (CGFloat)cardPadding;
+ (CGFloat)rowHeight;
+ (CGFloat)controlHeight;
+ (CGFloat)cornerRadiusCard;
+ (CGFloat)cornerRadiusRow;
+ (CGFloat)cornerRadiusBadge;
+ (CGFloat)glassAlpha;
+ (CGFloat)glassBorderWidth;

+ (NSTimeInterval)motionFast;
+ (NSTimeInterval)motionStandard;
+ (NSTimeInterval)motionSlow;
+ (CGFloat)springDamping;
+ (CGFloat)springVelocity;
+ (CGFloat)glowRadius;
+ (CGFloat)glowOpacity;
+ (UIBlurEffectStyle)glassBlurStyle;
+ (UIEdgeInsets)screenInsets;

@end

NS_ASSUME_NONNULL_END
