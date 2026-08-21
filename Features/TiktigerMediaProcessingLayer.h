#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerMediaProcessingLayer : NSObject

- (BOOL)validateSourceURL:(NSURL *)sourceURL mediaType:(NSString *)mediaType error:(NSError * _Nullable * _Nullable)error;
- (NSString *)detectedMediaTypeForURL:(NSURL *)sourceURL;
- (BOOL)processDownloadedFileAtURL:(NSURL *)fileURL mediaType:(NSString *)mediaType outputURL:(NSURL * _Nullable * _Nullable)outputURL error:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)capabilitySnapshot;

@end

NS_ASSUME_NONNULL_END
