//
//  WhiteReplayManager.m
//  AgoraEducation
//
//  Created by SRS on 2020/2/24.
//  Copyright © 2020 yangmoumou. All rights reserved.
//

#import "WhiteReplayManager.h"

@implementation WhiteReplayManager

- (instancetype)initWithWhitePlayer:(WhitePlayer *)whitePlayer {
    
    if (self = [super init]) {
        _whitePlayer = whitePlayer;
        [self updateWhitePlayerPhase:whitePlayer.phase];
    }
    return self;
}

- (void)updateWhitePlayerPhase:(WhitePlayerPhase)phase {
//    AgoraLog(@"first updateWhitePlayerPhase %ld pauseReason:%ld", phase, self.pauseReason);
    // WhitePlay 处于缓冲状态，pauseReson 加上 whitePlayerBuffering
    if (phase == WhitePlayerPhaseBuffering || phase == WhitePlayerPhaseWaitingFirstFrame) {
        [self whitePlayerStartBuffing];
    }
    // 进入暂停状态，whitePlayer 已经完成缓冲，移除 whitePlayerBufferring
    else if (phase == WhitePlayerPhasePause || phase == WhitePlayerPhasePlaying) {
        [self whitePlayerEndBuffering];
    }
//    AgoraLog(@"end updateWhitePlayerPhase %ld pauseReason:%ld", phase, self.pauseReason);
}

- (void)setPlaybackSpeed:(CGFloat)playbackSpeed {
    _playbackSpeed = playbackSpeed;
    self.whitePlayer.playbackSpeed = playbackSpeed;
}

- (void)play {
    [self.whitePlayer play];
}

- (void)pause {
    [self.whitePlayer pause];
}

- (void)seekToScheduleTime:(NSTimeInterval)beginTime {
    [self.whitePlayer seekToScheduleTime:beginTime];
}

#pragma mark - white player buffering
- (void)whitePlayerStartBuffing {
    if ([self.delegate respondsToSelector:@selector(whiteReplayerStartBuffering)]) {
        [self.delegate whiteReplayerStartBuffering];
    }
}

- (void)whitePlayerEndBuffering {
    if ([self.delegate respondsToSelector:@selector(whiteReplayerEndBuffering)]) {
        [self.delegate whiteReplayerEndBuffering];
    }
}


@end
