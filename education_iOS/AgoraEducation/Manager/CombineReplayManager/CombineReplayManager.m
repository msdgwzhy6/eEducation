//
//  CombineReplayManager.m
//  AgoraEducation
//
//  Created by SRS on 2020/2/24.
//  Copyright © 2020 yangmoumou. All rights reserved.
//

#import "CombineReplayManager.h"
#import "RTCReplayManager.h"
#import "WhiteReplayManager.h"

@interface CombineReplayManager ()<RTCReplayProtocol, WhiteReplayProtocol> {
    CADisplayLink *_displayLink;
    NSInteger _frameInterval;
    NSTimeInterval displayStartTime;
}

@property (nonatomic, assign, readwrite) NSUInteger pauseReason;

@property (nonatomic, strong) RTCReplayManager *rtcReplayManager;
@property (nonatomic, assign) BOOL rtcReplayFinished;

@property (nonatomic, strong) WhiteReplayManager *whiteReplayManagaer;
@property (nonatomic, assign) BOOL whiteReplayFinished;

@property (nonatomic, copy) NSString *classStartTime;
@property (nonatomic, copy) NSString *classEndTime;

@end

@implementation CombineReplayManager

- (instancetype)init {
    if(self = [super init]){
        self.rtcReplayFinished = NO;
        self.whiteReplayFinished = NO;
        
        _frameInterval = 15;
        
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLink:)];
        _displayLink.preferredFramesPerSecond =_frameInterval;
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        _displayLink.paused = YES;
    }
    return self;
}

- (void)initWithRTCUrl:(NSURL *)mediaUrl {
    self.rtcReplayManager = [[RTCReplayManager alloc] initWithMediaUrl:mediaUrl];
}

- (void)initWithWhitePlayer:(WhitePlayer *)whitePlayer {
    self.whiteReplayManagaer = [[WhiteReplayManager alloc] initWithWhitePlayer:whitePlayer];
}

- (void)replayWithClassStartTime:(NSString *)classStartTime classEndTime:(NSString *)classEndTime {
    
    NSAssert(classStartTime && classStartTime.length == 13, @"classStartTime must be millisecond unit");
    NSAssert(classEndTime && classEndTime.length == 13, @"classEndTime must be millisecond unit");
    
    self.classStartTime = classStartTime;
    self.classEndTime = classEndTime;
}

- (void)onDisplayLink: (CADisplayLink *)displayLink {
    
    NSTimeInterval classDurationTime = self.classEndTime.floatValue - self.classStartTime.floatValue;
    
    // 当前时间
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970] * 1000;
    NSTimeInterval displayDurationTime = currentTime - displayStartTime;

    if(displayDurationTime > classDurationTime) {
        [self finish];
        return;
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(combinePlayTimeChanged:)]) {
        [_delegate combinePlayTimeChanged:displayDurationTime];
    }
}

- (void)stopDisplayLink {
    if (_displayLink){
        [_displayLink invalidate];
        _displayLink = nil;
    }
}

#pragma mark - Play Control
- (void)setPlaybackSpeed:(CGFloat)playbackSpeed {
    _playbackSpeed = playbackSpeed;
    [self.rtcReplayManager setPlaybackSpeed:playbackSpeed];
    [self.whiteReplayManagaer setPlaybackSpeed:playbackSpeed];
}

#pragma mark - Public Methods
- (void)play {
    self.pauseReason = self.pauseReason & ~CombineSyncManagerWaitingPauseReasonPlayerPause;
    [self.rtcReplayManager play];
    
    // video 将直接播放，whitePlayer 也直接播放
    if ([self.rtcReplayManager hasEnoughBuffer]) {
        AgoraLog(@"play directly");
        [self.whiteReplayManagaer play];
        
        _displayLink.paused = NO;
    }
}

- (void)pause {
    self.pauseReason = self.pauseReason | CombineSyncManagerWaitingPauseReasonPlayerPause;
    
    _displayLink.paused = YES;
    [self.rtcReplayManager pause];
    [self.whiteReplayManagaer pause];;
}

- (void)finish {

    if (self.rtcReplayFinished && self.whiteReplayFinished) {
        _displayLink.paused = YES;
        if ([self.delegate respondsToSelector:@selector(combinePlayDidFinish)]) {
            [self.delegate combinePlayDidFinish];
        }
    }
}

- (void)seekToTime:(CMTime)time completionHandler:(void (^)(BOOL finished))completionHandler {
    
    NSTimeInterval seekTime = CMTimeGetSeconds(time);
    if(seekTime == 0){
        // reset
        displayStartTime = [[NSDate date] timeIntervalSince1970] * 1000;
    }
    
    [self.whiteReplayManagaer seekToScheduleTime:seekTime];
    AgoraLog(@"seekTime: %f", seekTime);
    
    __weak typeof(self)weakSelf = self;
    [self.rtcReplayManager seekToTime:time completionHandler:^(NSTimeInterval realTime, BOOL finished) {
        if (finished) {
            AgoraLog(@"realTime: %f", realTime);
            // AVPlayer 的 seek 不完全准确, seek 完以后，根据 native 的真实时间，重新 seek
            [weakSelf.whiteReplayManagaer seekToScheduleTime:seekTime];
            
            completionHandler(finished);
        }
    }];
}

#pragma mark RTCReplayProtocol
- (void)rtcReplayerStartBuffering {
    if ([self.delegate respondsToSelector:@selector(combinePlayStartBuffering)]) {
        [self.delegate combinePlayStartBuffering];
    }
    
    AgoraLog(@"startNativeBuffering");
    
    //加上 native 缓冲标识
    self.pauseReason = self.pauseReason | CombineSyncManagerPauseReasonWaitingRTCPlayerBuffering;
    
    //whitePlayer 加载 buffering 的行为，一旦开始，不会停止。所以直接暂停播放即可。
    [self.whiteReplayManagaer pause];;
}

- (void)rtcReplayerEndBuffering {
    
    BOOL isBuffering  = (self.pauseReason & CombineSyncManagerPauseReasonWaitingWhitePlayerBuffering) || (self.pauseReason & CombineSyncManagerPauseReasonWaitingRTCPlayerBuffering);

    self.pauseReason = self.pauseReason & ~CombineSyncManagerPauseReasonWaitingRTCPlayerBuffering;
    
    AgoraLog(@"nativeEndBuffering %lu", (unsigned long)self.pauseReason);
    
    /**
     1. WhitePlayer 还在缓冲(01)，暂停
     2. WhitePlayer 不在缓冲(00)，结束缓冲
     */
    if (self.pauseReason & CombineSyncManagerPauseReasonWaitingWhitePlayerBuffering) {
        [self.rtcReplayManager pause];
    } else if (isBuffering && [self.delegate respondsToSelector:@selector(combinePlayEndBuffering)]) {
        [self.delegate combinePlayEndBuffering];
    }
    
    /**
     1. 目前是播放状态（100），没有任何一个播放器，处于缓冲，调用两端播放API
     2. 目前是主动暂停（000），暂停白板
     3. whitePlayer 还在缓存（101、110），已经在处理缓冲回调的位置，处理完毕
     */
    if (self.pauseReason == CombineSyncManagerPauseReasonNone) {
        [self.rtcReplayManager play];
        [self.whiteReplayManagaer play];
    } else if (self.pauseReason & CombineSyncManagerWaitingPauseReasonPlayerPause) {
        [self.rtcReplayManager pause];
        [self.whiteReplayManagaer pause];
    }
}
- (void)rtcReplayerDidFinish {
    self.rtcReplayFinished = YES;
    [self finish];
}
- (void)rtcReplayerError:(NSError * _Nullable)error {
    
    [self pause];
    if ([self.delegate respondsToSelector:@selector(combineReplayError:)]) {
        [self.delegate combineReplayError:error];
    }
}

#pragma mark WhiteReplayProtocol
- (void)whiteReplayerStartBuffering {
    self.pauseReason = self.pauseReason | CombineSyncManagerPauseReasonWaitingWhitePlayerBuffering;
    
    [self.rtcReplayManager pause];
    
    if ([self.delegate respondsToSelector:@selector(combinePlayStartBuffering)]) {
        [self.delegate combinePlayStartBuffering];
    }
}
- (void)whiteReplayerEndBuffering {
    BOOL isBuffering  = (self.pauseReason & CombineSyncManagerPauseReasonWaitingWhitePlayerBuffering) || (self.pauseReason & CombineSyncManagerPauseReasonWaitingRTCPlayerBuffering);
    
    self.pauseReason = self.pauseReason & ~CombineSyncManagerPauseReasonWaitingWhitePlayerBuffering;
    
    AgoraLog(@"playerEndBuffering %lu", (unsigned long)self.pauseReason);
    
    /**
     1. native 还在缓存(10)，主动暂停 whitePlayer
     2. native 不在缓存(00)，缓冲结束
     */
    if (self.pauseReason & CombineSyncManagerPauseReasonWaitingRTCPlayerBuffering) {
        [self.whiteReplayManagaer pause];;
    } else if (isBuffering && [self.delegate respondsToSelector:@selector(combinePlayEndBuffering)]) {
        [self.delegate combinePlayEndBuffering];
    }
    
    /**
     1. 目前是播放状态（100），没有任何一个播放器，处于缓冲，调用两端播放API
     2. 目前是主动暂停（000），暂停白板
     3. native 还在缓存（110、010），已经在处理缓冲回调的位置，处理完毕
     */
    if (self.pauseReason == CombineSyncManagerPauseReasonNone) {
        [self.rtcReplayManager play];
        [self.whiteReplayManagaer play];
    } else if (self.pauseReason & CombineSyncManagerWaitingPauseReasonPlayerPause) {
        [self.rtcReplayManager pause];
        [self.whiteReplayManagaer pause];;
    }
}
- (void)whiteReplayerDidFinish {
    self.whiteReplayFinished = YES;
    [self finish];
}
- (void)whiteReplayerError:(NSError * _Nullable)error {
    [self pause];
    if ([self.delegate respondsToSelector:@selector(combineReplayError:)]) {
        [self.delegate combineReplayError:error];
    }
}

- (void)dealloc {
    [self stopDisplayLink];
}
@end

