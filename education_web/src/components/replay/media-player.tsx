import React, { useState, useEffect, useRef } from 'react'

const MediaPlayer: React.FC<any> = ({
  domId,
  player
}) => {

  const ref = useRef<any>(null)

  useEffect(() => {
    if (ref.current) {
      player.mounted(ref.current.id)
      return () => {
        player.destroy()
      }
    }
  }, [ref.current])

//@ts-ignore
// window.Scheduler = Scheduler

  return (
    <div ref={ref} id={domId} style={{"width": "300px", "height": "400px"}}></div>
  )
}

export default React.memo(MediaPlayer)