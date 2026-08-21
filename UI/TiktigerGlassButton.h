#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerGlassButton : UIButton

@property (nonatomic, assign) BOOL usesRedAccent;

+ (instancetype)buttonWithTitle:(NSString *)title redAccent:(BOOL)redAccent;

@end

NS_ASSUME_NONNULL_END
