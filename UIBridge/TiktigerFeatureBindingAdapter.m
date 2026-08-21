#import "TiktigerFeatureBindingAdapter.h"
#import "TiktigerModuleManager.h"
#import "TiktigerDownloadModule.h"
#import "TiktigerPreferencesModule.h"
#import "TiktigerPrivacyModule.h"
#import "TiktigerAppearanceModule.h"
#import "TiktigerChatModule.h"
#import "TiktigerProfileModule.h"
#import "TiktigerSystemModule.h"
#import "TiktigerFeatureModuleDescriptor.h"

NSString * const TiktigerFeatureBindingEventDidChange = @"com.tiktiger.feature-binding.did-change";
static NSString * const TiktigerFeatureBindingErrorDomain = @"com.tiktiger.feature-binding";

@interface TiktigerFeatureBindingAdapter ()
@property (nonatomic, strong) TiktigerModuleManager *moduleManager;
@end

@implementation TiktigerFeatureBindingAdapter

- (instancetype)initWithModuleManager:(TiktigerModuleManager *)moduleManager {
    self = [super init];
    if (self) { _moduleManager = moduleManager; }
    return self;
}

- (NSArray<NSDictionary<NSString *,id> *> *)dashboardFeatureCards {
    NSMutableArray *cards = [[NSMutableArray alloc] init];
    for (NSDictionary *module in self.moduleManager.statusSnapshot.allValues) {
        [cards addObject:@{
            @"id": module[@"id"] ?: @"",
            @"title": module[@"name"] ?: @"Feature",
            @"version": module[@"version"] ?: @"",
            @"state": module[@"state"] ?: @"unknown",
            @"ui": module[@"uiRepresentation"] ?: @{}
        }];
    }
    return [cards copy];
}

- (NSDictionary<NSString *,NSArray<NSDictionary<NSString *,id> *> *> *)settingsFeatureControls {
    return @{
        @"platform": @[@{ @"id": @"platform.secure-configuration", @"title": @"Secure Configuration", @"control": @"status" }],
        @"media": @[@{ @"id": @"media.download", @"title": @"Download Module", @"control": @"quality" }],
        @"theme": @[@{ @"id": @"user.preferences.theme", @"title": @"Theme", @"control": @"selection", @"key": @"theme" }],
        @"animation": @[@{ @"id": @"user.preferences.animation", @"title": @"Animation Settings", @"control": @"toggle", @"key": @"glow" }],
        @"interface": @[@{ @"id": @"user.preferences.interface", @"title": @"Interface Settings", @"control": @"selection", @"key": @"rtl" }],
        @"features": @[@{ @"id": @"user.preferences.features", @"title": @"Feature Preferences", @"control": @"toggle", @"key": @"haptics" }]
    };
}

- (NSDictionary<NSString *,NSDictionary<NSString *,id> *> *)diagnosticsModuleHealth {
    return self.moduleManager.healthSnapshot ?: @{};
}

- (NSDictionary<NSString *,id> *)downloadPresentationState {
    id<TiktigerFeatureModuleProtocol> module = [self.moduleManager.registry moduleWithID:@"media.download"];
    if (![module respondsToSelector:@selector(downloadSnapshot)]) { return @{}; }
    TiktigerDownloadModule *download = (TiktigerDownloadModule *)module;
    __weak typeof(self) weakSelf = self;
    [download setEventHandler:^(NSDictionary<NSString *,id> *snapshot) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf != nil) { [strongSelf postModuleEventForFeatureID:@"media.download" action:@"engineEvent"]; }
        (void)snapshot;
    }];
    return [download downloadSnapshot];
}

- (NSDictionary<NSString *,id> *)privacyPresentationState {
    id<TiktigerFeatureModuleProtocol> module = [self.moduleManager.registry moduleWithID:@"privacy.center"];
    return [module respondsToSelector:@selector(privacySnapshot)] ? [(TiktigerPrivacyModule *)module privacySnapshot] : @{};
}

- (NSDictionary<NSString *,id> *)appearancePresentationState {
    id<TiktigerFeatureModuleProtocol> module = [self.moduleManager.registry moduleWithID:@"appearance.engine"];
    return [module respondsToSelector:@selector(appearanceSnapshot)] ? [(TiktigerAppearanceModule *)module appearanceSnapshot] : @{};
}

- (NSDictionary<NSString *,id> *)chatPresentationState {
    id<TiktigerFeatureModuleProtocol> module = [self.moduleManager.registry moduleWithID:@"chat.center"];
    return [module respondsToSelector:@selector(chatSnapshot)] ? [(TiktigerChatModule *)module chatSnapshot] : @{};
}

- (NSDictionary<NSString *,id> *)profilePresentationState {
    id<TiktigerFeatureModuleProtocol> module = [self.moduleManager.registry moduleWithID:@"profile.center"];
    return [module respondsToSelector:@selector(profileSnapshot)] ? [(TiktigerProfileModule *)module profileSnapshot] : @{};
}

- (NSDictionary<NSString *,id> *)systemPresentationState {
    id<TiktigerFeatureModuleProtocol> module = [self.moduleManager.registry moduleWithID:@"system.center"];
    if (![module isKindOfClass:[TiktigerSystemModule class]]) { return @{}; }
    TiktigerSystemModule *system = (TiktigerSystemModule *)module;
    NSMutableDictionary *snapshot = [[system systemSnapshot] mutableCopy];
    snapshot[@"featureManager"] = [system featureManagerSnapshot] ?: @{};
    snapshot[@"diagnosticsHub"] = [system diagnosticsHubSnapshot] ?: @{};
    snapshot[@"backup"] = [system backupExportSnapshot] ?: @{};
    return [snapshot copy];
}

- (NSURL *)downloadHistoryFileURLForID:(NSString *)taskID error:(NSError **)error {
    id<TiktigerFeatureModuleProtocol> module = [self.moduleManager.registry moduleWithID:@"media.download"];
    if (![module isKindOfClass:[TiktigerDownloadModule class]]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureBindingErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: @"The Download Module is unavailable."}]; }
        return nil;
    }
    return [(TiktigerDownloadModule *)module historyFileURLForID:taskID error:error];
}

- (NSDictionary<NSString *,id> *)preferencesPresentation {
    id<TiktigerFeatureModuleProtocol> module = [self.moduleManager.registry moduleWithID:@"user.preferences"];
    return [module respondsToSelector:@selector(preferencesSnapshot)] ? [(TiktigerPreferencesModule *)module preferencesSnapshot] : @{};
}

- (BOOL)setFeature:(NSString *)featureID enabled:(BOOL)enabled error:(NSError **)error {
    BOOL result = enabled ? [self.moduleManager enableModuleWithID:featureID error:error] : [self.moduleManager disableModuleWithID:featureID error:error];
    if (result) { [self postModuleEventForFeatureID:featureID action:enabled ? @"enable" : @"disable"]; }
    return result;
}

- (BOOL)updateFeatureConfiguration:(NSString *)featureID configuration:(NSDictionary<NSString *,id> *)configuration error:(NSError **)error {
    id<TiktigerFeatureModuleProtocol> module = [self.moduleManager.registry moduleWithID:featureID];
    if (![module isKindOfClass:[TiktigerFeatureModuleDescriptor class]]) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureBindingErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"The requested module does not accept configuration updates."}]; }
        return NO;
    }
    BOOL result = [(TiktigerFeatureModuleDescriptor *)module applyConfiguration:configuration error:error];
    if (result) { [self postModuleEventForFeatureID:featureID action:@"updateConfiguration"]; }
    return result;
}

- (BOOL)executeFeatureAction:(NSString *)action featureID:(NSString *)featureID payload:(NSDictionary<NSString *,id> *)payload error:(NSError **)error {
    id<TiktigerFeatureModuleProtocol> module = [self.moduleManager.registry moduleWithID:featureID];
    if (module == nil) {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureBindingErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"The requested feature module is not registered."}]; }
        return NO;
    }
    BOOL result = NO;
    if (([action isEqualToString:@"startDownload"] || [action isEqualToString:@"updateConfiguration"] || [action isEqualToString:@"updateAppearanceSetting"] || [action isEqualToString:@"updateChatSetting"] || [action isEqualToString:@"updateProfileSetting"] || [action isEqualToString:@"setManagedFeature"] || [action isEqualToString:@"importSystemBackup"] || [action isEqualToString:@"resetSystemConfiguration"]) && module.state != TiktigerFeatureModuleStateEnabled) {
        if (![module enable:error]) { return NO; }
    }
    if ([action isEqualToString:@"startDownload"] && [module isKindOfClass:[TiktigerDownloadModule class]]) {
        NSString *mediaType = payload[@"mediaType"] ?: @"video";
        NSString *destination = payload[@"destination"] ?: @"files";
        NSString *sourceString = [payload[@"sourceURL"] isKindOfClass:[NSString class]] ? payload[@"sourceURL"] : nil;
        if (sourceString.length == 0) {
            NSDictionary *configuration = [(TiktigerDownloadModule *)module configuration];
            sourceString = [configuration[@"sourceURL"] isKindOfClass:[NSString class]] ? configuration[@"sourceURL"] : nil;
        }
        NSURL *sourceURL = sourceString.length > 0 ? [NSURL URLWithString:sourceString] : nil;
        result = [(TiktigerDownloadModule *)module enqueueMediaType:mediaType destination:destination sourceURL:sourceURL error:error];
    } else if ([action isEqualToString:@"updateProgress"] && [module isKindOfClass:[TiktigerDownloadModule class]]) {
        result = [(TiktigerDownloadModule *)module updateProgress:[payload[@"progress"] doubleValue] error:error];
    } else if ([action isEqualToString:@"completeDownload"] && [module isKindOfClass:[TiktigerDownloadModule class]]) {
        result = [(TiktigerDownloadModule *)module completeCurrent:error];
    } else if ([action isEqualToString:@"retryDownload"] && [module isKindOfClass:[TiktigerDownloadModule class]]) {
        NSString *taskID = [payload[@"taskID"] isKindOfClass:[NSString class]] ? payload[@"taskID"] : nil;
        result = taskID.length > 0 ? [(TiktigerDownloadModule *)module retryHistoryItemWithID:taskID error:error] : [(TiktigerDownloadModule *)module retryCurrent:error];
    } else if ([action isEqualToString:@"deleteHistoryItem"] && [module isKindOfClass:[TiktigerDownloadModule class]]) {
        result = [(TiktigerDownloadModule *)module deleteHistoryItemWithID:payload[@"taskID"] error:error];
    } else if ([action isEqualToString:@"updatePrivacySetting"] && [module isKindOfClass:[TiktigerPrivacyModule class]]) {
        NSString *key = [payload[@"key"] isKindOfClass:[NSString class]] ? payload[@"key"] : @"";
        result = [(TiktigerPrivacyModule *)module updatePrivacySetting:key value:payload[@"value"] ?: @NO error:error];
    } else if ([action isEqualToString:@"updateAppearanceSetting"] && [module isKindOfClass:[TiktigerAppearanceModule class]]) {
        NSString *key = [payload[@"key"] isKindOfClass:[NSString class]] ? payload[@"key"] : @"";
        result = [(TiktigerAppearanceModule *)module updateAppearanceSetting:key value:payload[@"value"] error:error];
    } else if ([action isEqualToString:@"updateChatSetting"] && [module isKindOfClass:[TiktigerChatModule class]]) {
        NSString *key = [payload[@"key"] isKindOfClass:[NSString class]] ? payload[@"key"] : @"";
        result = [(TiktigerChatModule *)module updateChatSetting:key value:payload[@"value"] ?: @NO error:error];
    } else if ([action isEqualToString:@"updateProfileSetting"] && [module isKindOfClass:[TiktigerProfileModule class]]) {
        NSString *key = [payload[@"key"] isKindOfClass:[NSString class]] ? payload[@"key"] : @"";
        result = [(TiktigerProfileModule *)module updateProfileSetting:key value:payload[@"value"] ?: @NO error:error];
    } else if ([action isEqualToString:@"setManagedFeature"] && [module isKindOfClass:[TiktigerSystemModule class]]) {
        NSString *managedFeatureID = [payload[@"managedFeatureID"] isKindOfClass:[NSString class]] ? payload[@"managedFeatureID"] : @"";
        result = [(TiktigerSystemModule *)module setManagedFeatureID:managedFeatureID enabled:[payload[@"enabled"] boolValue] error:error];
    } else if ([action isEqualToString:@"importSystemBackup"] && [module isKindOfClass:[TiktigerSystemModule class]]) {
        NSDictionary *backup = [payload[@"backup"] isKindOfClass:[NSDictionary class]] ? payload[@"backup"] : payload;
        result = [(TiktigerSystemModule *)module importBackupPayload:backup error:error];
    } else if ([action isEqualToString:@"resetSystemConfiguration"] && [module isKindOfClass:[TiktigerSystemModule class]]) {
        result = [(TiktigerSystemModule *)module resetSystemConfiguration:error];
    } else if ([action isEqualToString:@"pauseDownload"] && [module isKindOfClass:[TiktigerDownloadModule class]]) {
        result = [(TiktigerDownloadModule *)module pauseCurrent:error];
    } else if ([action isEqualToString:@"resumeDownload"] && [module isKindOfClass:[TiktigerDownloadModule class]]) {
        result = [(TiktigerDownloadModule *)module resumeCurrent:error];
    } else if ([action isEqualToString:@"cancelDownload"] && [module isKindOfClass:[TiktigerDownloadModule class]]) {
        result = [(TiktigerDownloadModule *)module cancelCurrent:error];
    } else if ([action isEqualToString:@"updateConfiguration"] && [module isKindOfClass:[TiktigerPreferencesModule class]]) {
        NSString *controlID = payload[@"controlID"] ?: @"";
        NSString *key = payload[@"key"] ?: @"";
        id value = payload[@"value"] ?: @NO;
        TiktigerPreferencesModule *preferences = (TiktigerPreferencesModule *)module;
        NSDictionary *configuration = preferences.preferencesSnapshot[@"configuration"] ?: @{};
        NSMutableDictionary *next = [configuration mutableCopy];
        if ([controlID containsString:@"animation"]) {
            NSMutableDictionary *section = [configuration[@"animation"] mutableCopy] ?: [NSMutableDictionary dictionary]; section[key] = value; next[@"animation"] = section; result = [preferences updateAnimationSettings:section error:error];
        } else if ([controlID containsString:@"interface"]) {
            NSMutableDictionary *section = [configuration[@"interface"] mutableCopy] ?: [NSMutableDictionary dictionary]; section[key] = value; next[@"interface"] = section; result = [preferences updateInterfaceSettings:section error:error];
        } else if ([controlID containsString:@"features"]) {
            NSMutableDictionary *section = [configuration[@"features"] mutableCopy] ?: [NSMutableDictionary dictionary]; section[key] = value; next[@"features"] = section; result = [preferences updateFeaturePreferences:section error:error];
        } else if ([controlID containsString:@"theme"]) {
            result = [preferences updateTheme:[value isKindOfClass:[NSString class]] ? value : @"black" error:error];
        } else {
            if (error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureBindingErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"The preferences control is not mapped to a supported section."}]; }
        }
    } else {
        if (error != NULL) { *error = [NSError errorWithDomain:TiktigerFeatureBindingErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"Unsupported feature action."}]; }
    }
    if (result) { [self postModuleEventForFeatureID:featureID action:action]; }
    return result;
}

- (id)subscribeToModuleEvents:(void (^)(NSDictionary<NSString *,id> *))handler {
    return [[NSNotificationCenter defaultCenter] addObserverForName:TiktigerFeatureBindingEventDidChange object:self queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        if (handler != nil) { handler(note.userInfo ?: @{}); }
    }];
}

- (void)unsubscribeFromModuleEvents:(id)token {
    if (token != nil) { [[NSNotificationCenter defaultCenter] removeObserver:token]; }
}

- (void)postModuleEventForFeatureID:(NSString *)featureID action:(NSString *)action {
    NSDictionary *event = @{
        @"featureID": featureID ?: @"",
        @"action": action ?: @"",
        @"download": [self downloadPresentationState] ?: @{},
        @"privacy": [self privacyPresentationState] ?: @{},
        @"appearance": [self appearancePresentationState] ?: @{},
        @"chat": [self chatPresentationState] ?: @{},
        @"profile": [self profilePresentationState] ?: @{},
        @"system": [self systemPresentationState] ?: @{},
        @"preferences": [self preferencesPresentation] ?: @{},
        @"health": [self diagnosticsModuleHealth] ?: @{}
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:TiktigerFeatureBindingEventDidChange object:self userInfo:event];
}

@end
