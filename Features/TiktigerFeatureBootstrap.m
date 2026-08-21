#import "TiktigerFeatureBootstrap.h"
#import <UIKit/UIKit.h>
#import "TiktigerModuleManager.h"
#import "TiktigerFeatureModuleDescriptor.h"
#import "TiktigerSecureConfigurationFeature.h"
#import "TiktigerDiagnosticsCenterFeature.h"
#import "TiktigerHealthMonitorFeature.h"
#import "TiktigerDownloadModule.h"
#import "TiktigerPreferencesModule.h"

@implementation TiktigerFeatureBootstrap

+ (NSArray<NSString *> *)registerPriorityModulesIntoManager:(TiktigerModuleManager *)manager error:(NSError **)error {
    NSMutableArray<NSString *> *registered = [[NSMutableArray alloc] init];
    NSDictionary *secureConfig = @{@"schemaVersion": @1, @"safeMode": @YES, @"retentionDays": @30};
    TiktigerSecureConfigurationFeature *secure = [[TiktigerSecureConfigurationFeature alloc] initWithFeatureID:@"platform.secure-configuration" name:@"Secure Configuration" version:@"1.0" configuration:secureConfig uiRepresentation:@{@"surface": @"Settings", @"category": @"platform"}];
    TiktigerDiagnosticsCenterFeature *diagnostics = [[TiktigerDiagnosticsCenterFeature alloc] initWithFeatureID:@"diagnostics.center" name:@"Diagnostics Center" version:@"1.0" configuration:@{@"schemaVersion": @1, @"redaction": @YES} uiRepresentation:@{@"surface": @"Developer", @"category": @"diagnostics"}];
    TiktigerHealthMonitorFeature *health = [[TiktigerHealthMonitorFeature alloc] initWithModuleManager:manager];
    TiktigerDownloadModule *download = [[TiktigerDownloadModule alloc] initWithFeatureID:@"media.download" name:@"Download Module" version:@"1.1" configuration:@{@"schemaVersion": @1, @"mediaType": @"video", @"destination": @"files", @"queueLimit": @5, @"maxRetryCount": @3} uiRepresentation:@{@"surface": @"Download Center", @"category": @"media"}];
    TiktigerPreferencesModule *preferences = [[TiktigerPreferencesModule alloc] initWithFeatureID:@"user.preferences" name:@"User Preferences" version:@"1.1" configuration:@{@"schemaVersion": @1, @"theme": @"black", @"animation": @{@"reduceMotion": @(UIAccessibilityIsReduceMotionEnabled()), @"glow": @YES}, @"interface": @{@"rtl": @YES, @"glassIntensity": @0.72}, @"features": @{@"haptics": @YES, @"downloads": @YES}} uiRepresentation:@{@"surface": @"Settings", @"category": @"preferences"}];
    NSArray *modules = @[secure, diagnostics, health, download, preferences];
    for (id<TiktigerFeatureModuleProtocol> module in modules) {
        NSError *registrationError = nil;
        if (![manager registerModule:module error:&registrationError]) {
            if (error != NULL) { *error = registrationError; }
            return registered;
        }
        [registered addObject:module.featureID];
    }
    // Priority 1 modules are enabled first; Priority 2 modules are registered but remain disabled until their UI flow is ready.
    for (NSString *featureID in @[@"platform.secure-configuration", @"diagnostics.center", @"health.monitor"]) {
        if (![manager enableModuleWithID:featureID error:error]) { return registered; }
    }
    return registered;
}

@end
