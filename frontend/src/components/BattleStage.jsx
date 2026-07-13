import { useState, useEffect, useMemo, useRef } from 'react'
import { typeColor, typeText, TYPE_GLYPH, MONSTER_GLYPH, STATUS_META } from '../theme'
import { buildInitialUnits, deriveState, logLine } from '../battleState'

const COLS = 8
const ROWS = 6

// The battle animation, rendered INSIDE the preparation shell's .stage so the
// board never shifts on Lock In. Owns only playback state; the surrounding
// header/bench/tableau stay mounted and in place. The log floats as a fixed,
// collapsible overlay so it adds nothing to the layout flow.
export default function BattleStage({ run, round, onComplete }) {
  const events = round.timeline || []
  const maxTick = round.result?.duration_ticks || (events.length ? events[events.length - 1].tick : 0)
  const initial = useMemo(() => buildInitialUnits(run, round), [run, round])

  const [tick, setTick] = useState(0)
  const [playing, setPlaying] = useState(true)
  const [speed, setSpeed] = useState(1)
  const [logOpen, setLogOpen] = useState(true)
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
    <>
      <div className="grid-wrap">
        <div className="grid-legend">
          <span className="legend-enemy">▲ Enemy formation</span>
          <span className={`battle-status ${finished ? (winner === 'allies' ? 'win' : 'loss') : ''}`}>
            {finished
              ? (winner === 'allies' ? 'Victory!' : winner === 'monsters' ? 'Defeat' : 'Draw')
              : `Tick ${tick}/${maxTick}`}
          </span>
          <span className="legend-ally">Your champions ▼</span>
        </div>
        <div className="battle-grid replay-grid" style={{ gridTemplateColumns: `repeat(${COLS}, 1fr)` }}>
          {cells}
          {Object.values(units).map((u) => {
            const isMonster = u.team === 'monsters'
            const glyph = (isMonster && MONSTER_GLYPH[u.name]) || TYPE_GLYPH[u.type] || '?'
            const manaPct = u.manaCap > 0 ? Math.round((u.mana / u.manaCap) * 100) : 0
            const casting = casters.has(u.id)
            return (
              <div
                key={u.id}
                className={`replay-unit${u.alive ? '' : ' dead'}${casting ? ' casting' : ''}${isMonster ? ' enemy' : ' ally'}`}
                style={{ gridColumn: u.x + 1, gridRow: u.y + 1 }}
              >
                {casting && <span className="cast-burst" style={{ borderColor: typeColor(u.type) }} />}
                <div
                  className="unit-token"
                  style={{ background: typeColor(u.type), color: typeText(u.type),
                           outline: u.team === 'allies' ? '2px solid #6cf' : '2px solid #f86' }}
                  title={u.name}
                >
                  <span className="champ-glyph">{glyph}</span>
                </div>
                {u.alive && u.manaCap > 0 && (
                  <div className="mana-orb" title={`Mana ${Math.floor(u.mana)}/${u.manaCap}`}
                    style={{ background: `conic-gradient(#4aa3ff ${manaPct}%, #1b2740 0)` }}>
                    <span className="mana-orb-dot" />
                  </div>
                )}
                {u.alive && u.statuses.length > 0 && (
                  <div className="status-badges">
                    {u.statuses.map((k) => (
                      <span key={k} className="status-badge" title={k}
                        style={{ background: STATUS_META[k]?.color || '#888' }}>
                        {STATUS_META[k]?.glyph || '?'}
                      </span>
                    ))}
                  </div>
                )}
                {u.alive && (
                  <div className="hp-bar">
                    <div className="hp-fill" style={{ width: `${Math.max(0, (u.hp / u.maxHp) * 100)}%` }} />
                  </div>
                )}
                {floaters.filter((f) => f.unitId === u.id).map((f) => (
                  <span key={f.key} className={`floater ${f.kind}`}>{f.text}</span>
                ))}
              </div>
            )
          })}
        </div>
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
        <button className="btn btn-primary" disabled={!finished} onClick={onComplete}>Continue →</button>
      </div>

      <aside className={`battle-log-float${logOpen ? '' : ' collapsed'}`}>
        <button className="log-float-head" onClick={() => setLogOpen((o) => !o)}>
          Battle Log <span className="log-caret">{logOpen ? '▾' : '▸'}</span>
        </button>
        {logOpen && (
          <div className="log-float-body" ref={logRef}>
            {log.map((line, i) => <div key={i} className="log-line">{line}</div>)}
          </div>
        )}
      </aside>
    </>
  )
}
