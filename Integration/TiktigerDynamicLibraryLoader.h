#import <Foundation/Foundation.h>
#import "TiktigerRuntimeState.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerDynamicLibraryLoadState) {
    TiktigerDynamicLibraryLoadStateUnvalidated = 0,
    TiktigerDynamicLibraryLoadStateValidated,
    TiktigerDynamicLibraryLoadStateInitialized,
    TiktigerDynamicLibraryLoadStateFailed
};

FOUNDATION_EXPORT NSString *TiktigerStringFromDynamicLibraryLoadState(TiktigerDynamicLibraryLoadState state);

@interface TiktigerDynamicLibraryLoader : NSObject

@property (nonatomic, copy, readonly) NSString *expectedVersion;
@property (nonatomic, copy, readonly) NSString *expectedInstallName;
@property (nonatomic, copy, readonly) NSString *expectedArchitecture;
@property (nonatomic, assign, readonly) TiktigerDynamicLibraryLoadState loadState;

- (instancetype)initWithExpectedVersion:(NSString *)version
                         expectedInstallName:(NSString *)installName
                         expectedArchitecture:(NSString *)architecture;

/// Validates host-provided artifact metadata only. It never performs runtime library loading or injection.
- (BOOL)validateArtifactMetadata:(NSDictionary<NSString *, id> *)metadata error:(NSError * _Nullable * _Nullable)error;

/// Initializes an already loaded, signed library through the public lifecycle API.
- (BOOL)initializeLoadedLibrary:(NSError * _Nullable * _Nullable)error;

/// Reads the public runtime status after initialization.
- (TiktigerRuntimeState)runtimeStatus;

/// Shuts down the process-local runtime; it does not unload a host bundle.
- (void)shutdownLoadedLibrary;

- (NSDictionary<NSString *, id> *)statusSnapshot;

@end

NS_ASSUME_NONNULL_END
