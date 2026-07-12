import { useState } from 'react'

export default function StartScreen({ onStart, onCreateCoop, onJoinCoop, error }) {
  const [handle, setHandle] = useState('')
  const [code, setCode] = useState('')
  const [mode, setMode] = useState('menu') // menu | join

  return (
    <div className="screen center-screen">
      <div className="title-card">
        <h1 className="game-title">AUTO&nbsp;CARD</h1>
        <p className="tagline">A deterministic tactical auto-battler · 10-round PvE run</p>
        <input
          className="handle-input"
          placeholder="Your name (optional)"
          value={handle}
          onChange={(e) => setHandle(e.target.value)}
        />

        {mode === 'menu' && (
          <div className="start-buttons">
            <button className="btn btn-primary btn-lg" onClick={() => onStart(handle)}>
              Single-Player Run
            </button>
            <button className="btn btn-lg" onClick={() => onCreateCoop(handle)}>
              Create Co-op Room
            </button>
            <button className="btn btn-lg" onClick={() => setMode('join')}>
              Join Co-op Room
            </button>
          </div>
        )}

        {mode === 'join' && (
          <div className="start-buttons">
            <input
              className="handle-input code-input"
              placeholder="ROOM CODE"
              maxLength={4}
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
            />
            <button className="btn btn-primary btn-lg" disabled={code.length < 4}
              onClick={() => onJoinCoop(code, handle)}>
              Join Room
            </button>
            <button className="btn btn-ghost" onClick={() => setMode('menu')}>← Back</button>
          </div>
        )}

        {error && <p className="error-text">{error}</p>}
      </div>
    </div>
  )
}
