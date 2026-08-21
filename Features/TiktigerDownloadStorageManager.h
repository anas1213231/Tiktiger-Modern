#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TiktigerDownloadStorageManager : NSObject

@property (nonatomic, copy, readonly) NSURL *rootDirectoryURL;

- (instancetype)initWithRootDirectoryURL:(NSURL * _Nullable)rootDirectoryURL;
- (NSURL * _Nullable)destinationURLForMediaType:(NSString *)mediaType
                                       sourceURL:(NSURL *)sourceURL
                                         taskID:(NSString *)taskID
                                           error:(NSError * _Nullable * _Nullable)error;
- (NSURL * _Nullable)destinationURLForMediaType:(NSString *)mediaType
                                       sourceURL:(NSURL *)sourceURL
                                         taskID:(NSString *)taskID
                                    destination:(NSString *)destination
                                           error:(NSError * _Nullable * _Nullable)error;
- (BOOL)prepareDestination:(NSURL *)destinationURL error:(NSError * _Nullable * _Nullable)error;
- (BOOL)moveDownloadedFile:(NSURL *)temporaryURL
              toDestination:(NSURL *)destinationURL
                      error:(NSError * _Nullable * _Nullable)error;
- (BOOL)removeFileAtURL:(NSURL *)fileURL error:(NSError * _Nullable * _Nullable)error;
- (BOOL)isDuplicateAtURL:(NSURL *)destinationURL;
- (NSDictionary<NSString *, id> *)storageSnapshot;

@end

NS_ASSUME_NONNULL_END
