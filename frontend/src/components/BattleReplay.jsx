import { useState, useEffect, useMemo, useRef } from 'react'
import { typeColor, typeText, TYPE_GLYPH } from '../theme'
import { buildInitialUnits, deriveState, logLine } from '../battleState'

const COLS = 8
const ROWS = 6

export default function BattleReplay({ run, round, onComplete }) {
  const events = round.timeline || []
  const maxTick = round.result?.duration_ticks || (events.length ? events[events.length - 1].tick : 0)

  const initial = useMemo(() => buildInitialUnits(run, round), [run, round])

  const [tick, setTick] = useState(0)
  const [playing, setPlaying] = useState(true)
  const [speed, setSpeed] = useState(1)
  const logRef = useRef(null)

  const finished = tick >= maxTick

  useEffect(() => {
    if (!playing || finished) return
    const iv = setInterval(() => setTick((t) => (t >= maxTick ? t : t + 1)), 320 / speed)
    return () => clearInterval(iv)
  }, [playing, finished, speed, maxTick])

  const { units, floaters, casters } = useMemo(
    () => deriveState(initial, events, tick),
    [initial, events, tick]
  )

  const log = useMemo(
    () => events.filter((e) => e.tick <= tick).map((e) => logLine(initial, e)).filter(Boolean),
    [events, initial, tick]
  )

  useEffect(() => { if (logRef.current) logRef.current.scrollTop = logRef.current.scrollHeight }, [log.length])

  const winner = round.result?.winner
  const cells = []
  for (let y = 0; y < ROWS; y++) {
    for (let x = 0; x < COLS; x++) {
      const zone = y >= 4 ? ' ally-zone' : y <= 1 ? ' enemy-zone' : ''
      cells.push(<div key={`${x},${y}`} className={`grid-cell${zone}`} />)
    }
  }

  return (
    <div className="screen replay-screen">
      <header className="topbar">
        <span className="round-pill">Round {round.round_number} · Battle</span>
        <span className="deploy-count">Tick {tick}/{maxTick}</span>
      </header>

      <div className="replay-stage">
        <div className="grid-wrap">
          <div className="battle-grid replay-grid" style={{ gridTemplateColumns: `repeat(${COLS}, 1fr)` }}>
            {cells}
            {Object.values(units).map((u) => (
              <div
                key={u.id}
                className={`replay-unit${u.alive ? '' : ' dead'}${casters.has(u.id) ? ' casting' : ''}`}
                style={{ gridColumn: u.x + 1, gridRow: u.y + 1 }}
              >
                <div
                  className="unit-token"
                  style={{ background: typeColor(u.type), color: typeText(u.type),
                           outline: u.team === 'allies' ? '2px solid #6cf' : '2px solid #f86' }}
                  title={u.name}
                >
                  <span className="champ-glyph">{TYPE_GLYPH[u.type] || '?'}</span>
                </div>
                {u.alive && (
                  <div className="hp-bar">
                    <div className="hp-fill" style={{ width: `${Math.max(0, (u.hp / u.maxHp) * 100)}%` }} />
                  </div>
                )}
                {floaters.filter((f) => f.unitId === u.id).map((f) => (
                  <span key={f.key} className={`floater ${f.kind}`}>{f.text}</span>
                ))}
              </div>
            ))}
          </div>
        </div>

        <aside className="battle-log" ref={logRef}>
          <h3 className="panel-title">Battle Log</h3>
          {log.map((line, i) => <div key={i} className="log-line">{line}</div>)}
        </aside>
      </div>

      <div className="replay-controls">
        <button className="btn btn-ghost" onClick={() => { setTick(0); setPlaying(true) }}>⟲ Restart</button>
        <button className="btn btn-ghost" onClick={() => setPlaying((p) => !p)} disabled={finished}>
          {playing ? '⏸ Pause' : '▶ Play'}
        </button>
        <div className="speed-group">
          {[1, 2, 4].map((s) => (
            <button key={s} className={`btn btn-ghost${speed === s ? ' active' : ''}`} onClick={() => setSpeed(s)}>{s}×</button>
          ))}
        </div>
        <button className="btn btn-ghost" onClick={() => setTick(maxTick)}>⏭ Skip</button>
        {finished && (
          <span className={`replay-result ${winner === 'allies' ? 'win' : 'loss'}`}>
            {winner === 'allies' ? 'Victory!' : winner === 'monsters' ? 'Defeat' : 'Draw'}
          </span>
        )}
        <button className="btn btn-primary" disabled={!finished} onClick={onComplete}>
          Continue →
        </button>
      </div>
    </div>
  )
}
