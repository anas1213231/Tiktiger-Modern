#import "TiktigerFeatureModuleDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TiktigerDownloadState) {
    TiktigerDownloadStateIdle = 0,
    TiktigerDownloadStatePreparing,
    TiktigerDownloadStateLoading,
    TiktigerDownloadStateProcessing,
    TiktigerDownloadStateCompleted,
    TiktigerDownloadStateFailed
};

FOUNDATION_EXPORT NSString *TiktigerStringFromDownloadState(TiktigerDownloadState state);

typedef void (^TiktigerDownloadModuleEventHandler)(NSDictionary<NSString *, id> *snapshot);

@interface TiktigerDownloadModule : TiktigerFeatureModuleDescriptor

@property (nonatomic, assign, readonly) TiktigerDownloadState downloadState;
@property (nonatomic, assign, readonly) double progress;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *queueState;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *lastError;

- (BOOL)enqueueMediaType:(NSString *)mediaType destination:(NSString *)destination sourceURL:(NSString * _Nullable)sourceURL error:(NSError * _Nullable * _Nullable)error;
- (BOOL)enqueueMediaType:(NSString *)mediaType destination:(NSString *)destination error:(NSError * _Nullable * _Nullable)error;
- (BOOL)prepareNext:(NSError * _Nullable * _Nullable)error;
- (BOOL)updateProgress:(double)progress error:(NSError * _Nullable * _Nullable)error;
- (BOOL)completeCurrent:(NSError * _Nullable * _Nullable)error;
- (BOOL)failCurrentWithError:(NSError *)error;
- (BOOL)retryCurrent:(NSError * _Nullable * _Nullable)error;
- (BOOL)pauseCurrent:(NSError * _Nullable * _Nullable)error;
- (BOOL)resumeCurrent:(NSError * _Nullable * _Nullable)error;
- (BOOL)cancelCurrent:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, id> *)downloadSnapshot;
- (void)setEventHandler:(TiktigerDownloadModuleEventHandler _Nullable)eventHandler;

@end

NS_ASSUME_NONNULL_END
