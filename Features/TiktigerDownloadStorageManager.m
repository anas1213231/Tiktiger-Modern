#import "TiktigerDownloadStorageManager.h"

static NSString * const TiktigerDownloadStorageErrorDomain = @"com.tiktiger.download-storage";
static NSString * const TiktigerDownloadStorageDuplicateURLKey = @"TiktigerDownloadStorageDuplicateURL";

@interface TiktigerDownloadStorageManager ()
@property (nonatomic, copy, readwrite) NSURL *rootDirectoryURL;
@property (nonatomic, strong) NSLock *storageLock;
@end

@implementation TiktigerDownloadStorageManager

- (instancetype)initWithRootDirectoryURL:(NSURL *)rootDirectoryURL {
    self = [super init];
    if (self) {
        NSURL *defaultRoot = rootDirectoryURL;
        if (defaultRoot == nil) {
            NSArray<NSURL *> *applicationSupport = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
            defaultRoot = applicationSupport.firstObject;
            if (defaultRoot == nil) {
                defaultRoot = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
            }
            if (defaultRoot == nil) { defaultRoot = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]; }
            defaultRoot = [defaultRoot URLByAppendingPathComponent:@"Tiktiger/Downloads" isDirectory:YES];
        }
        _rootDirectoryURL = [defaultRoot URLByStandardizingPath];
        _storageLock = [[NSLock alloc] init];
    }
    return self;
}

- (NSURL *)destinationURLForMediaType:(NSString *)mediaType sourceURL:(NSURL *)sourceURL taskID:(NSString *)taskID error:(NSError **)error {
    return [self destinationURLForMediaType:mediaType sourceURL:sourceURL taskID:taskID destination:@"files" error:error];
}

- (NSURL *)destinationURLForMediaType:(NSString *)mediaType sourceURL:(NSURL *)sourceURL taskID:(NSString *)taskID destination:(NSString *)destination error:(NSError **)error {
    if (mediaType.length == 0 || sourceURL == nil || sourceURL.scheme.length == 0 || taskID.length == 0) {
        if (error != NULL) { *error = [self storageErrorWithCode:1 description:@"Storage destination requires a media type, task ID, and valid source URL."]; }
        return nil;
    }
    NSString *safeMediaType = [self sanitizedComponent:mediaType fallback:@"media"];
    NSString *safeTaskID = [self sanitizedComponent:taskID fallback:@"item"];
    NSString *safeDestination = [self sanitizedComponent:destination fallback:@"files"];
    NSString *extension = sourceURL.pathExtension.lowercaseString;
    if (extension.length == 0) {
        extension = [self defaultExtensionForMediaType:safeMediaType];
    }
    NSString *sourceStem = [sourceURL.lastPathComponent stringByDeletingPathExtension];
    NSString *safeSourceStem = [self sanitizedComponent:sourceStem fallback:safeTaskID];
    NSString *filename = [NSString stringWithFormat:@"tiktiger_%@_%@.%@", safeMediaType, safeSourceStem, extension];
    NSURL *directoryURL = [self.rootDirectoryURL URLByAppendingPathComponent:safeDestination isDirectory:YES];
    return [directoryURL URLByAppendingPathComponent:filename isDirectory:NO];
}

- (BOOL)prepareDestination:(NSURL *)destinationURL error:(NSError **)error {
    if (destinationURL == nil || !destinationURL.isFileURL) {
        if (error != NULL) { *error = [self storageErrorWithCode:2 description:@"Storage destination must be a file URL."]; }
        return NO;
    }
    [self.storageLock lock];
    BOOL created = [[NSFileManager defaultManager] createDirectoryAtURL:[destinationURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:error];
    [self.storageLock unlock];
    return created;
}

- (BOOL)moveDownloadedFile:(NSURL *)temporaryURL toDestination:(NSURL *)destinationURL error:(NSError **)error {
    if (temporaryURL == nil || destinationURL == nil || !temporaryURL.isFileURL || !destinationURL.isFileURL) {
        if (error != NULL) { *error = [self storageErrorWithCode:4 description:@"Downloaded and destination URLs must be file URLs."]; }
        return NO;
    }
    [self.storageLock lock];
    if (![[NSFileManager defaultManager] fileExistsAtPath:temporaryURL.path]) {
        if (error != NULL) { *error = [self storageErrorWithCode:5 description:@"The temporary download file does not exist."]; }
        [self.storageLock unlock];
        return NO;
    }
    if ([self isDuplicateAtURL:destinationURL]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerDownloadStorageErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"A file with the same Tiktiger destination already exists.", TiktigerDownloadStorageDuplicateURLKey: destinationURL}];
        }
        [self.storageLock unlock];
        return NO;
    }
    NSError *directoryError = nil;
    BOOL prepared = [[NSFileManager defaultManager] createDirectoryAtURL:[destinationURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&directoryError];
    if (!prepared) {
        if (error != NULL) { *error = directoryError; }
        [self.storageLock unlock];
        return NO;
    }
    NSError *moveError = nil;
    BOOL moved = [[NSFileManager defaultManager] moveItemAtURL:temporaryURL toURL:destinationURL error:&moveError];
    if (!moved && error != NULL) { *error = moveError; }
    [self.storageLock unlock];
    return moved;
}

- (BOOL)removeFileAtURL:(NSURL *)fileURL error:(NSError **)error {
    if (fileURL == nil || !fileURL.isFileURL) {
        if (error != NULL) { *error = [self storageErrorWithCode:6 description:@"The file URL to remove is invalid."]; }
        return NO;
    }
    [self.storageLock lock];
    NSError *removeError = nil;
    BOOL removed = ![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path] || [[NSFileManager defaultManager] removeItemAtURL:fileURL error:&removeError];
    if (!removed && error != NULL) { *error = removeError; }
    [self.storageLock unlock];
    return removed;
}

- (BOOL)isDuplicateAtURL:(NSURL *)destinationURL {
    if (destinationURL == nil || !destinationURL.isFileURL) { return NO; }
    return [[NSFileManager defaultManager] fileExistsAtPath:destinationURL.path];
}

- (NSDictionary<NSString *,id> *)storageSnapshot {
    [self.storageLock lock];
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:self.rootDirectoryURL.path];
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.rootDirectoryURL includingPropertiesForKeys:@[NSURLIsRegularFileKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSUInteger fileCount = 0;
    for (NSURL *fileURL in files) {
        NSNumber *isRegular = nil;
        [fileURL getResourceValue:&isRegular forKey:NSURLIsRegularFileKey error:nil];
        if (isRegular.boolValue) { fileCount += 1; }
    }
    NSDictionary *snapshot = @{ @"root": self.rootDirectoryURL.path ?: @"", @"exists": @(exists), @"fileCount": @(fileCount) };
    [self.storageLock unlock];
    return snapshot;
}

- (NSError *)storageErrorWithCode:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:TiktigerDownloadStorageErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description ?: @"Storage operation failed."]}];
}

- (NSString *)sanitizedComponent:(NSString *)component fallback:(NSString *)fallback {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" ];
    NSMutableString *result = [[NSMutableString alloc] init];
    for (NSUInteger index = 0; index < component.length; index += 1) {
        unichar character = [component characterAtIndex:index];
        if ([allowed characterIsMember:character]) { [result appendFormat:@"%C", character]; }
    }
    return result.length > 0 ? [result copy] : fallback;
}

- (NSString *)defaultExtensionForMediaType:(NSString *)mediaType {
    if ([mediaType isEqualToString:@"audio"]) { return @"m4a"; }
    if ([mediaType isEqualToString:@"image"]) { return @"jpg"; }
    return @"mp4";
}

@end
