#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerGlassCard : UIView

@property (nonatomic, strong, readonly) UIView *contentView;
@property (nonatomic, assign) BOOL elevated;

- (instancetype)initWithTitle:(NSString * _Nullable)title; 
- (void)setTitle:(NSString * _Nullable)title;
- (void)setStatusMessage:(NSString * _Nullable)message;

@end

NS_ASSUME_NONNULL_END
