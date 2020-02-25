//
//  CombineReplayManager.h
//  AgoraEducation
//
//  Created by SRS on 2020/2/24.
//  Copyright © 2020 yangmoumou. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Whiteboard/Whiteboard.h>

@protocol CombineReplayDelegate <NSObject>

@required
- (void)combinePlayTimeChanged:(NSTimeInterval)time;
- (void)combinePlayStartBuffering;
- (void)combinePlayEndBuffering;
- (void)combinePlayDidFinish;
- (void)combineReplayError:(NSError * _Nullable)error;

@end

NS_ASSUME_NONNULL_BEGIN

#pragma mark - CombineSyncManagerPauseReason

typedef NS_OPTIONS(NSUInteger, CombineSyncManagerPauseReason) {
    //正常播放
    CombineSyncManagerPauseReasonNone                           = 0,
    //暂停，暂停原因：白板缓冲
    CombineSyncManagerPauseReasonWaitingWhitePlayerBuffering    = 1 << 0,
    //暂停，暂停原因：音视频缓冲
    CombineSyncManagerPauseReasonWaitingRTCPlayerBuffering      = 1 << 1,
    //暂停，暂停原因：主动暂停
    CombineSyncManagerWaitingPauseReasonPlayerPause             = 1 << 2,
    //初始状态，暂停，全缓冲
    CombineSyncManagerPauseReasonInit                           = CombineSyncManagerPauseReasonWaitingWhitePlayerBuffering | CombineSyncManagerPauseReasonWaitingRTCPlayerBuffering | CombineSyncManagerWaitingPauseReasonPlayerPause,
};


#pragma mark - CombineReplayManager
@interface CombineReplayManager : NSObject

@property (nonatomic, weak, nullable) id<CombineReplayDelegate> delegate;

/** 播放时，播放速率。即使暂停，该值也不会变为 0 */
@property (nonatomic, assign) CGFloat playbackSpeed;

/** 暂停原因，默认所有 buffer + 主动暂停 */
@property (nonatomic, assign, readonly) NSUInteger pauseReason;

- (void)initWithRTCUrl:(NSURL *)mediaUrl;
- (void)initWithWhitePlayer:(WhitePlayer *)whitePlayer;

// 毫秒级时间戳， 13位
- (void)replayWithClassStartTime:(NSString *)classStartTime classEndTime:(NSString *)classEndTime;
- (void)play;
- (void)pause;
- (void)seekToTime:(CMTime)time completionHandler:(void (^)(BOOL finished))completionHandler;

@end

NS_ASSUME_NONNULL_END

