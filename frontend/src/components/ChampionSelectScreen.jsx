import { useState } from 'react'
import { api } from '../api'
import { typeColor, typeText, TYPE_GLYPH } from '../theme'

const PICK = 3

// Run start: choose PICK champions from the pool of 5 before the first battle.
export default function ChampionSelectScreen({ run, onUpdate, onAbandon }) {
  const pool = run.available_champions || []
  const [chosen, setChosen] = useState([]) // champion keys
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState(null)

  function toggle(key) {
    setError(null)
    setChosen((prev) => {
      if (prev.includes(key)) return prev.filter((k) => k !== key)
      if (prev.length >= PICK) return prev // full — ignore extra picks
      return [...prev, key]
    })
  }

  async function confirm() {
    setSubmitting(true)
    setError(null)
    try {
      onUpdate(await api.selectChampions(run.id, chosen))
    } catch (e) {
      setError((e.errors || [e.message]).join(' · '))
      setSubmitting(false)
    }
  }

  return (
    <div className="screen select-screen">
      <header className="topbar">
        <span className="round-pill">Choose Your Champions</span>
        <span className="deploy-count">Selected {chosen.length}/{PICK}</span>
        <button className="btn btn-ghost" onClick={onAbandon}>Cancel</button>
      </header>

      <p className="select-hint">Pick {PICK} champions to take into this run. Choose a mix of types to cover enemy weaknesses.</p>

      <div className="select-grid">
        {pool.map((c) => {
          const picked = chosen.includes(c.key)
          const bs = c.base_stats || {}
          return (
            <button
              key={c.key}
              className={`select-card${picked ? ' picked' : ''}`}
              onClick={() => toggle(c.key)}
              style={{ borderColor: picked ? typeColor(c.type) : undefined }}
            >
              <div className="select-card-head">
                <span className="glyph" style={{ background: typeColor(c.type), color: typeText(c.type) }}>
                  {TYPE_GLYPH[c.type] || '?'}
                </span>
                <div>
                  <div className="select-name">{c.name}</div>
                  <div className="select-sub">{c.type} · {c.subclass}</div>
                </div>
                {picked && <span className="select-check">✓</span>}
              </div>
              <div className="select-role">{c.role}</div>
              <div className="select-stats">
                <span>❤ {bs.health}</span>
                <span>⚔ {bs.attack_damage}</span>
                <span>✨ {bs.magic_power}</span>
                <span>🛡 {bs.armor}</span>
              </div>
              <div className="select-abilities">
                {(c.default_abilities || []).map((a) => <span key={a} className="tag">★ {a}</span>)}
              </div>
            </button>
          )
        })}
      </div>

      {error && <p className="error-text">{error}</p>}
      <div className="select-actions">
        <button className="btn btn-primary btn-lg" disabled={chosen.length !== PICK || submitting} onClick={confirm}>
          {submitting ? 'Starting…' : `Start Run (${chosen.length}/${PICK})`}
        </button>
      </div>
    </div>
  )
}
