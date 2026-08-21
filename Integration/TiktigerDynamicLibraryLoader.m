#import "TiktigerDynamicLibraryLoader.h"
#import "Tiktiger.h"

static NSString * const TiktigerDynamicLibraryLoaderErrorDomain = @"com.tiktiger.integration-loader";

@interface TiktigerDynamicLibraryLoader ()
@property (nonatomic, copy, readwrite) NSString *expectedVersion;
@property (nonatomic, copy, readwrite) NSString *expectedInstallName;
@property (nonatomic, copy, readwrite) NSString *expectedArchitecture;
@property (nonatomic, assign, readwrite) TiktigerDynamicLibraryLoadState loadState;
@property (nonatomic, strong) NSLock *loaderLock;
@property (nonatomic, copy) NSString *lastErrorMessage;
@property (nonatomic, copy) NSDictionary<NSString *, id> *lastMetadata;
@end

@implementation TiktigerDynamicLibraryLoader

- (instancetype)initWithExpectedVersion:(NSString *)version expectedInstallName:(NSString *)installName expectedArchitecture:(NSString *)architecture {
    self = [super init];
    if (self) {
        _expectedVersion = [version copy];
        _expectedInstallName = [installName copy];
        _expectedArchitecture = [architecture copy];
        _loadState = TiktigerDynamicLibraryLoadStateUnvalidated;
        _loaderLock = [[NSLock alloc] init];
        _lastErrorMessage = @"";
        _lastMetadata = @{};
    }
    return self;
}

- (BOOL)validateArtifactMetadata:(NSDictionary<NSString *,id> *)metadata error:(NSError **)error {
    [self.loaderLock lock];
    NSString *version = [metadata[@"version"] isKindOfClass:[NSString class]] ? metadata[@"version"] : @"";
    NSString *installName = [metadata[@"installName"] isKindOfClass:[NSString class]] ? metadata[@"installName"] : @"";
    NSString *architecture = [metadata[@"architecture"] isKindOfClass:[NSString class]] ? metadata[@"architecture"] : @"";
    NSString *product = [metadata[@"product"] isKindOfClass:[NSString class]] ? metadata[@"product"] : @"";
    BOOL signedArtifact = [metadata[@"signed"] isKindOfClass:[NSNumber class]] && [metadata[@"signed"] boolValue];
    BOOL loaded = ![metadata[@"loaded"] isKindOfClass:[NSNumber class]] || [metadata[@"loaded"] boolValue];
    BOOL valid = [version isEqualToString:self.expectedVersion] && [installName isEqualToString:self.expectedInstallName] && [architecture isEqualToString:self.expectedArchitecture] && [product isEqualToString:@"Tiktiger.dylib"] && signedArtifact && loaded;
    if (!valid) {
        self.loadState = TiktigerDynamicLibraryLoadStateFailed;
        self.lastErrorMessage = @"Dynamic library metadata failed product, version, install-name, architecture, signing, or loaded-state validation.";
        NSError *validationError = [NSError errorWithDomain:TiktigerDynamicLibraryLoaderErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: self.lastErrorMessage}];
        [self.loaderLock unlock];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    self.lastMetadata = [metadata copy];
    self.lastErrorMessage = @"";
    self.loadState = TiktigerDynamicLibraryLoadStateValidated;
    [self.loaderLock unlock];
    return YES;
}

- (BOOL)initializeLoadedLibrary:(NSError **)error {
    [self.loaderLock lock];
    if (self.loadState != TiktigerDynamicLibraryLoadStateValidated && self.loadState != TiktigerDynamicLibraryLoadStateInitialized) {
        NSError *validationError = [NSError errorWithDomain:TiktigerDynamicLibraryLoaderErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"Artifact metadata must be validated before public runtime initialization.", @"preparationOnly": @YES}];
        self.loadState = TiktigerDynamicLibraryLoadStateFailed;
        self.lastErrorMessage = validationError.localizedDescription;
        [self.loaderLock unlock];
        if (error != NULL) { *error = validationError; }
        return NO;
    }
    if (self.loadState == TiktigerDynamicLibraryLoadStateInitialized) {
        [self.loaderLock unlock];
        return YES;
    }
    BOOL initialized = TiktigerInitialize();
    if (!initialized) {
        self.loadState = TiktigerDynamicLibraryLoadStateFailed;
        self.lastErrorMessage = @"Public TiktigerInitialize returned failure.";
        NSError *initializationError = [NSError errorWithDomain:TiktigerDynamicLibraryLoaderErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: self.lastErrorMessage}];
        [self.loaderLock unlock];
        if (error != NULL) { *error = initializationError; }
        return NO;
    }
    self.loadState = TiktigerDynamicLibraryLoadStateInitialized;
    self.lastErrorMessage = @"";
    [self.loaderLock unlock];
    return YES;
}

- (TiktigerRuntimeState)runtimeStatus {
    return TiktigerGetStatus();
}

- (void)shutdownLoadedLibrary {
    [self.loaderLock lock];
    if (self.loadState == TiktigerDynamicLibraryLoadStateInitialized) {
        TiktigerShutdown();
        self.loadState = TiktigerDynamicLibraryLoadStateValidated;
    }
    [self.loaderLock unlock];
}

- (NSDictionary<NSString *,id> *)statusSnapshot {
    [self.loaderLock lock];
    NSDictionary *snapshot = @{
        @"loadState": TiktigerStringFromDynamicLibraryLoadState(self.loadState),
        @"expectedVersion": self.expectedVersion ?: @"",
        @"expectedInstallName": self.expectedInstallName ?: @"",
        @"expectedArchitecture": self.expectedArchitecture ?: @"",
        @"runtimeStatus": TiktigerStringFromRuntimeState(TiktigerGetStatus()),
        @"runtimeVersion": [NSString stringWithUTF8String:TiktigerGetVersion()] ?: @"",
        @"metadataValidated": @(self.loadState == TiktigerDynamicLibraryLoadStateValidated || self.loadState == TiktigerDynamicLibraryLoadStateInitialized),
        @"lastMetadata": self.lastMetadata ?: @{},
        @"error": self.lastErrorMessage ?: @{},
        @"preparationOnly": @YES
    };
    [self.loaderLock unlock];
    return [snapshot copy];
}

@end

NSString *TiktigerStringFromDynamicLibraryLoadState(TiktigerDynamicLibraryLoadState state) {
    switch (state) {
        case TiktigerDynamicLibraryLoadStateUnvalidated: return @"unvalidated";
        case TiktigerDynamicLibraryLoadStateValidated: return @"validated";
        case TiktigerDynamicLibraryLoadStateInitialized: return @"initialized";
        case TiktigerDynamicLibraryLoadStateFailed: return @"failed";
    }
    return @"unknown";
}
