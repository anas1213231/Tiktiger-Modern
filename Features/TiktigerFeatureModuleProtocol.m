#import "TiktigerFeatureModuleProtocol.h"

NSString *TiktigerStringFromFeatureModuleState(TiktigerFeatureModuleState state) {
    switch (state) {
        case TiktigerFeatureModuleStateRegistered: return @"registered";
        case TiktigerFeatureModuleStateEnabled: return @"enabled";
        case TiktigerFeatureModuleStateDisabled: return @"disabled";
        case TiktigerFeatureModuleStateDegraded: return @"degraded";
        case TiktigerFeatureModuleStateFailed: return @"failed";
    }
    return @"unknown";
}
