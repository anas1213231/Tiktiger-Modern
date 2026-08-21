#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TiktigerDownloadEngine;
@class TiktigerDownloadStorageManager;
@class TiktigerMediaProcessingLayer;
@class TiktigerDownloadRecoveryManager;

typedef NS_ENUM(NSInteger, TiktigerDownloadEngineState) {
    TiktigerDownloadEngineStateIdle = 0,
    TiktigerDownloadEngineStatePreparing,
    TiktigerDownloadEngineStateDownloading,
    TiktigerDownloadEngineStateProcessing,
    TiktigerDownloadEngineStateCompleted,
    TiktigerDownloadEngineStateFailed
};

FOUNDATION_EXPORT NSString *TiktigerStringFromDownloadEngineState(TiktigerDownloadEngineState state);

typedef void (^TiktigerDownloadEngineProgressHandler)(NSString *taskID, double progress, TiktigerDownloadEngineState state);
typedef void (^TiktigerDownloadEngineCompletionHandler)(NSString *taskID, NSURL * _Nullable fileURL, NSError * _Nullable error);

@interface TiktigerDownloadEngine : NSObject

@property (nonatomic, assign, readonly) TiktigerDownloadEngineState state;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *snapshot;

- (instancetype)initWithStorageManager:(TiktigerDownloadStorageManager *)storageManager
                       processingLayer:(TiktigerMediaProcessingLayer *)processingLayer
                      recoveryManager:(TiktigerDownloadRecoveryManager *)recoveryManager;

- (BOOL)enqueueSourceURL:(NSURL *)sourceURL
               mediaType:(NSString *)mediaType
             destination:(NSString *)destination
                    taskID:(NSString * _Nullable)taskID
                progress:(TiktigerDownloadEngineProgressHandler _Nullable)progress
              completion:(TiktigerDownloadEngineCompletionHandler _Nullable)completion
                   error:(NSError * _Nullable * _Nullable)error;

- (BOOL)pauseTaskWithID:(NSString *)taskID error:(NSError * _Nullable * _Nullable)error;
- (BOOL)resumeTaskWithID:(NSString *)taskID error:(NSError * _Nullable * _Nullable)error;
- (BOOL)cancelTaskWithID:(NSString *)taskID error:(NSError * _Nullable * _Nullable)error;
- (BOOL)retryTaskWithID:(NSString *)taskID
              progress:(TiktigerDownloadEngineProgressHandler _Nullable)progress
            completion:(TiktigerDownloadEngineCompletionHandler _Nullable)completion
                 error:(NSError * _Nullable * _Nullable)error;
- (void)shutdown;

@end

NS_ASSUME_NONNULL_END
