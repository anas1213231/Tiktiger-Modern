#import "TiktigerMediaProcessingLayer.h"

static NSString * const TiktigerMediaProcessingErrorDomain = @"com.tiktiger.media-processing";

@implementation TiktigerMediaProcessingLayer

- (BOOL)validateSourceURL:(NSURL *)sourceURL mediaType:(NSString *)mediaType error:(NSError **)error {
    NSSet<NSString *> *supportedTypes = [NSSet setWithObjects:@"video", @"audio", @"image", nil];
    BOOL validScheme = [sourceURL.scheme.lowercaseString isEqualToString:@"http"] || [sourceURL.scheme.lowercaseString isEqualToString:@"https"];
    if (sourceURL == nil || !validScheme || ![supportedTypes containsObject:mediaType.lowercaseString]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerMediaProcessingErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"A valid HTTP(S) source URL and supported media type are required."]}];
        }
        return NO;
    }
    NSString *detectedType = [self detectedMediaTypeForURL:sourceURL];
    if (![detectedType isEqualToString:@"unknown"] && ![detectedType isEqualToString:mediaType.lowercaseString]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerMediaProcessingErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: @"The source URL extension does not match the requested media type."]}];
        }
        return NO;
    }
    return YES;
}

- (NSString *)detectedMediaTypeForURL:(NSURL *)sourceURL {
    NSString *extension = sourceURL.pathExtension.lowercaseString;
    NSSet<NSString *> *videoExtensions = [NSSet setWithObjects:@"mp4", @"mov", @"m4v", @"webm", @"mkv", nil];
    NSSet<NSString *> *audioExtensions = [NSSet setWithObjects:@"mp3", @"m4a", @"aac", @"wav", @"ogg", @"flac", nil];
    NSSet<NSString *> *imageExtensions = [NSSet setWithObjects:@"jpg", @"jpeg", @"png", @"gif", @"webp", @"heic", nil];
    if ([videoExtensions containsObject:extension]) { return @"video"; }
    if ([audioExtensions containsObject:extension]) { return @"audio"; }
    if ([imageExtensions containsObject:extension]) { return @"image"; }
    return @"unknown";
}

- (BOOL)processDownloadedFileAtURL:(NSURL *)fileURL mediaType:(NSString *)mediaType outputURL:(NSURL **)outputURL error:(NSError **)error {
    if (fileURL == nil || !fileURL.isFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerMediaProcessingErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"The downloaded media file is unavailable for processing."}];
        }
        return NO;
    }
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fileURL.path error:nil];
    unsigned long long fileSize = [attributes[NSFileSize] unsignedLongLongValue];
    if (fileSize == 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerMediaProcessingErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"The downloaded media file is empty."}];
        }
        return NO;
    }
    NSString *detected = [self detectedMediaTypeForURL:fileURL];
    if (![detected isEqualToString:@"unknown"] && ![detected isEqualToString:mediaType.lowercaseString]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:TiktigerMediaProcessingErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"The downloaded file type does not match the requested media type."}];
        }
        return NO;
    }
    if (outputURL != NULL) { *outputURL = fileURL; }
    return YES;
}

- (NSDictionary<NSString *,id> *)capabilitySnapshot {
    return @{
        @"transport": @"NSURLSession",
        @"validation": @"enabled",
        @"transcoding": @"pass-through",
        @"supportedMediaTypes": @[@"video", @"audio", @"image"]
    };
}

@end
