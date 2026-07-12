import { useState } from 'react'
import { api } from '../api'
import { stripeBackground } from '../theme'

const RARITY_CLASS = { common: 'rar-common', uncommon: 'rar-uncommon', rare: 'rar-rare' }

export default function RewardScreen({ run, me, onUpdate, onWatchAgain }) {
  const player = me ? run.players.find((p) => p.id === me.player_id) : run.players[0]
  const round = run.current_round_data
  const won = round?.result?.winner === 'allies'
  const offer = run.reward_offers.find((o) => o.player_id === player.id)
  const [picking, setPicking] = useState(null)
  const [error, setError] = useState(null)

  async function choose(cardTemplateId) {
    setPicking(cardTemplateId)
    setError(null)
    try {
      const updated = await api.selectReward(run.id, offer.id, cardTemplateId)
      onUpdate(updated)
    } catch (e) {
      setError(e.message)
      setPicking(null)
    }
  }

  return (
    <div className="screen center-screen">
      <div className="reward-panel">
        <h1 className={`result-banner ${won ? 'win' : 'loss'}`}>
          {won ? 'VICTORY' : 'DEFEAT'}
        </h1>
        <p className="tagline">
          Round {round.round_number} · {won ? 'Choose your reward' : 'A consolation upgrade awaits'}
        </p>

        {!offer && <p className="empty-hint">No reward this round.</p>}

        {offer?.status === 'selected' && (
          <p className="waiting-banner"><span className="pulse-dot" /> Reward chosen — waiting for your ally…</p>
        )}

        {offer && offer.status !== 'selected' && (
          <div className="reward-choices">
            {offer.choices.map((c) => (
              <button
                key={c.card_template_id}
                className={`reward-card card ${RARITY_CLASS[c.rarity] || ''}`}
                disabled={picking != null}
                onClick={() => choose(c.card_template_id)}
              >
                <div className="card-stripe" style={{ background: stripeBackground(c.valid_types) }} />
                <div className="card-body">
                  <div className="card-name">{c.name}</div>
                  <div className="card-meta">{c.category} · {c.rarity}</div>
                  <div className="card-desc">{c.description}</div>
                </div>
              </button>
            ))}
          </div>
        )}

        {error && <p className="error-text">{error}</p>}
        <button className="btn btn-ghost" onClick={onWatchAgain}>◀ Watch battle again</button>
      </div>
    </div>
  )
}
