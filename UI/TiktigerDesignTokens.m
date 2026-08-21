#import "TiktigerDesignTokens.h"

@implementation TiktigerDesignTokens

+ (UIColor *)vipBlack { return [UIColor colorWithRed:8.0/255.0 green:9.0/255.0 blue:11.0/255.0 alpha:1.0]; }
+ (UIColor *)vipSurface { return [UIColor colorWithRed:18.0/255.0 green:19.0/255.0 blue:22.0/255.0 alpha:1.0]; }
+ (UIColor *)vipSurfaceElevated { return [UIColor colorWithRed:26.0/255.0 green:27.0/255.0 blue:31.0/255.0 alpha:1.0]; }
+ (UIColor *)vipWhite { return [UIColor colorWithRed:247.0/255.0 green:247.0/255.0 blue:248.0/255.0 alpha:1.0]; }
+ (UIColor *)vipWhiteSecondary { return [UIColor colorWithWhite:0.78 alpha:1.0]; }
+ (UIColor *)vipRed { return [UIColor colorWithRed:227.0/255.0 green:27.0/255.0 blue:35.0/255.0 alpha:1.0]; }
+ (UIColor *)vipSuccess { return [UIColor colorWithRed:110.0/255.0 green:215.0/255.0 blue:155.0/255.0 alpha:1.0]; }
+ (UIColor *)vipGlassBorder { return [UIColor colorWithWhite:1.0 alpha:0.16]; }
+ (UIColor *)vipDivider { return [UIColor colorWithWhite:1.0 alpha:0.10]; }
+ (UIColor *)vipGlassContent { return [UIColor colorWithWhite:0.0 alpha:0.10]; }
+ (UIColor *)vipClear { return [UIColor clearColor]; }

+ (UIFont *)titleFont { return [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2]; }
+ (UIFont *)subtitleFont { return [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]; }
+ (UIFont *)bodyFont { return [UIFont preferredFontForTextStyle:UIFontTextStyleBody]; }
+ (UIFont *)statusFont { return [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]; }
+ (UIFont *)developerFont { return [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]; }
+ (UIFont *)numericFont { return [UIFont monospacedDigitSystemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleTitle3].pointSize weight:UIFontWeightSemibold]; }

+ (CGFloat)screenMargin { return 20.0; }
+ (CGFloat)sectionGap { return 16.0; }
+ (CGFloat)cardPadding { return 18.0; }
+ (CGFloat)rowHeight { return 56.0; }
+ (CGFloat)controlHeight { return 48.0; }
+ (CGFloat)cornerRadiusCard { return 24.0; }
+ (CGFloat)cornerRadiusRow { return 18.0; }
+ (CGFloat)cornerRadiusBadge { return 999.0; }
+ (CGFloat)glassAlpha { return 0.72; }
+ (CGFloat)glassBorderWidth { return 1.0; }

+ (NSTimeInterval)motionFast { return 0.18; }
+ (NSTimeInterval)motionStandard { return 0.25; }
+ (NSTimeInterval)motionSlow { return 0.42; }
+ (CGFloat)springDamping { return 0.82; }
+ (CGFloat)springVelocity { return 0.15; }
+ (CGFloat)glowRadius { return 14.0; }
+ (CGFloat)glowOpacity { return 0.32; }

+ (UIBlurEffectStyle)glassBlurStyle { return UIBlurEffectStyleSystemMaterialDark; }
+ (UIEdgeInsets)screenInsets { return UIEdgeInsetsMake(0.0, [self screenMargin], 0.0, [self screenMargin]); }

@end
