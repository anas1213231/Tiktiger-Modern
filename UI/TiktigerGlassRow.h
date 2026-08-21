#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerGlassRow : UIControl

@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *detailLabel;
@property (nonatomic, strong, readonly) UIImageView *iconView;
@property (nonatomic, assign) BOOL showsDisclosure;

- (instancetype)initWithTitle:(NSString *)title detail:(NSString * _Nullable)detail systemImageName:(NSString * _Nullable)systemImageName;
- (void)setActive:(BOOL)active;

@end

NS_ASSUME_NONNULL_END
