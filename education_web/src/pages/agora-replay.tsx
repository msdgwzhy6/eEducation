import React, { useEffect, useMemo, useRef, useCallback, useState } from 'react';
import "video.js/dist/video-js.css";
import './replay.scss';
import Slider from '@material-ui/core/Slider';
import { Subject, Scheduler } from 'rxjs';
import { useParams, useLocation, Redirect } from 'react-router';
import moment from 'moment';
import { Progress } from '../components/progress/progress';
import { getOSSUrl } from '../utils/helper';
import { t } from '../i18n';
import {AgoraPlayer, PhaseState, TimelineScheduler} from '../utils/agora-web-player/agora-player';


export interface IPlayerState {
  beginTimestamp: number
  duration: number
  roomToken: string
  mediaURL: string
  isPlaying: boolean
  progress: number
  player: any

  currentTime: number
  phase: any
  isFirstScreenReady: boolean
  isPlayerSeeking: boolean
  seenMessagesLength: number
  isChatOpen: boolean
  isVisible: boolean
  replayFail: boolean
}

export const defaultState: IPlayerState = {
  beginTimestamp: 0,
  duration: 0,
  roomToken: '',
  mediaURL: '',
  isPlaying: false,
  progress: 0,
  player: null,

  currentTime: 0,
  phase: 'init',
  isFirstScreenReady: false,
  isPlayerSeeking: false,
  seenMessagesLength: 0,
  isChatOpen: false,
  isVisible: false,
  replayFail: false,
}

class ReplayStore {
  public subject: Subject<IPlayerState> | null;
  public state: IPlayerState | null;

  constructor() {
    this.subject = null;
    this.state = null;
  }

  initialize() {
    this.subject = new Subject<IPlayerState>();
    this.state = defaultState;
    this.subject.next(this.state);
  }

  subscribe(setState: any) {
    this.initialize();
    this.subject && this.subject.subscribe(setState);
  }

  unsubscribe() {
    this.subject && this.subject.unsubscribe();
    this.state = null;
    this.subject = null;
  }

  commit(state: IPlayerState) {
    this.subject && this.subject.next(state);
  }

  updatePhase(phase: any) {
    if (!this.state) return

    this.state = {
      ...this.state,
      phase,
    }
    
    this.commit(this.state);
  }

  setCurrentTime(scheduleTime: number) {
    if (!this.state) return;
    this.state = {
      ...this.state,
      currentTime: scheduleTime
    }
    this.commit(this.state);
  }

  updateProgress(progress: number) {
    if (!this.state) return
    this.state = {
      ...this.state,
      progress
    }
    this.commit(this.state);
  }
}

const store = new ReplayStore();

const ReplayContext = React.createContext({} as IPlayerState);

const useReplayContext = () => React.useContext(ReplayContext);

const ReplayContainer: React.FC<{}> = () => {
  const [state, setState] = React.useState<IPlayerState>(defaultState)

  const location = useLocation()
  const {startTime, endTime} = useParams()
  const searchParams = new URLSearchParams(location.search)
  const url = searchParams.get("url") as string

  React.useEffect(() => {
    store.subscribe((state: any) => {
      setState(state);
    });
    return () => {
      store.unsubscribe();
    }
  }, []);

  if (!startTime || !endTime || !url) {
    return <Redirect to="/404"></Redirect>
  }

  const value = state;

  return (
    <ReplayContext.Provider value={value}>
      <TimelineReplay
        startTime={+startTime}
        endTime={+endTime}
        mediaUrl={url}
      />
    </ReplayContext.Provider>
  )
}

export default ReplayContainer;

export type TimelineReplayProps = {
  startTime: number
  endTime: number
  mediaUrl: string
}

export const TimelineReplay: React.FC<TimelineReplayProps> = ({
  startTime,
  endTime,
  mediaUrl
}) => {
  const state = useReplayContext()

  const videoPlayer = useState<AgoraPlayer>(() => new AgoraPlayer(mediaUrl, {
    onPhaseChanged: state => {
      console.log("video phaseState", state)
      // updatePhase(state)
      store.updatePhase(state);
    }
  }))[0]

  const timeLinePlayer = useState<TimelineScheduler>(() => {
    const timeline = new TimelineScheduler(30, (args: any) => {
      store.setCurrentTime(args.duration)
      store.updateProgress(args.progress)
    }, startTime, endTime)

    timeline.on('seek-changed', (duration: number) => {
      if (duration / 1000 < videoPlayer?.player.duration()) {
        videoPlayer?.seekTo(duration / 1000)
      }
    })

    timeline.on("state-changed", async (state: any) => {
      if (state === 'started' ) {
        videoPlayer?.play()
      } else {
        videoPlayer?.pause()
      }
    })

    //@ts-ignore DEBUG ONLY
    window.timeline = timeline
    return timeline;
  })[0]

  const playerElementRef = useRef<any>(null)

  useEffect(() => {
    if (playerElementRef.current && videoPlayer) {
      videoPlayer.initVideo(playerElementRef.current.id)
      return () => {
        videoPlayer.destroy()
      }
    }
  }, [playerElementRef, videoPlayer])

  const [playState, updatePlayState] = useState<string>('paused')

  const handlePlayerClick = () => {
    if (!store.state || !videoPlayer) return;

    if (timeLinePlayer.state === 'paused') {
      timeLinePlayer.start()
      updatePlayState('start')
      return
    }

    if (timeLinePlayer.state === 'started') {
      timeLinePlayer.stop()
      updatePlayState('paused')
      return
    }

    if (timeLinePlayer.state === 'ended') {
      timeLinePlayer.seekTo(0)
      timeLinePlayer.start()
      updatePlayState('start')
      return
    }
  }

  const handleChange = (event: any, newValue: any) => {
    store.setCurrentTime(newValue);
    store.updateProgress(newValue);
  }

  const duration = useMemo(() => {
    if (!startTime || !endTime) return 0;
    const _duration = Math.abs(+startTime - +endTime);
    return _duration;
  }, [startTime, endTime]);

  const totalTime = useMemo(() => {
    return moment(duration).format("mm:ss")
  }, [duration]);

  const time = useMemo(() => {
    return moment(state.currentTime).format("mm:ss");
  }, [state.currentTime]);

  const PlayerCover = useCallback(() => {
    if (!videoPlayer) {
      return (<Progress title={t("replay.loading")} />)
    }

    if (playState === 'start') return null;

    return (
      <div className="player-cover">
        {videoPlayer.phaseState === 'loading' ? <Progress title={t("replay.loading")} />: null}
        {videoPlayer.phaseState === 'paused' || 'ended' || 'waiting' ? 
          <div className="play-btn" onClick={handlePlayerClick}></div> : null}
      </div>
    )
  }, [videoPlayer, playState]);

  return (
    <div className="replay">
      <div className={`player-container`} >
        <PlayerCover />
        <div className="player">
          <div className="agora-logo"></div>
          <div id="whiteboard" className="whiteboard"></div>
          <div className="video-menu">
            <div className="control-btn">
              <div className={`btn ${playState === 'start' ? 'paused' : 'play'}`} onClick={handlePlayerClick}></div>
            </div>
            <div className="progress">
              <Slider
                className='custom-video-progress'
                value={state.currentTime}
                onMouseDown={() => {
                  timeLinePlayer.stop()
                  updatePlayState('paused')
                }}
                onMouseUp={() => {
                  timeLinePlayer.seekTo(state.currentTime)
                  timeLinePlayer.start()
                  updatePlayState('start')
                }}
                onChange={handleChange}
                min={0}
                max={duration}
                aria-labelledby="continuous-slider"
              />
              <div className="time">
                <div className="current_duration">{time}</div>
                  /
                <div className="video_duration">{totalTime}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div className="video-container">
        <div className="video-player">
          <div ref={playerElementRef} id="player" style={{width: "100%", height: "100%", objectFit: "cover"}}></div>
        </div>
      </div>
    </div>
  )
}