import { stripeBackground } from '../theme'
import { startCardDrag } from '../dnd'

const RARITY_CLASS = { common: 'rar-common', uncommon: 'rar-uncommon', rare: 'rar-rare' }
const ROMAN = { 2: 'II', 3: 'III', 4: 'IV', 5: 'V' }
const COMBINE_AT = 3

// Bottom panel: the player's owned upgrade cards. Drag a card onto a champion
// (bench or grid) to equip it. Roster-wide modifiers aren't equipped to one
// champion, so they're shown but not draggable.
export default function Tableau({ cards, rosterById, onDiscard }) {
  // Count ALL copies per template (equipped or not) for the "2/3 → upgrades" hint.
  const copyCounts = {}
  cards.forEach((c) => {
    copyCounts[c.card_template_id] = (copyCounts[c.card_template_id] || 0) + 1
  })

  return (
    <div className="tableau">
      <h3 className="panel-title">
        Tableau {cards.length > 0 && <span className="count-pill">{cards.length}</span>}
        <span className="tableau-hint">drag a card onto a champion to equip</span>
      </h3>
      <div className="tableau-list">
        {cards.length === 0 && <p className="empty-hint">Win battles to earn upgrade cards.</p>}
        {cards.map((c) => {
          const equipped = c.assigned_to_player_character_id != null
          const onChampion = equipped && rosterById?.[c.assigned_to_player_character_id]?.name
          const rosterWide = c.slot_type === 'roster_modifier'
          const draggable = !rosterWide
          const tier = c.tier || 1
          // Progress toward the next fusion (counts all copies, equipped or not).
          const copies = copyCounts[c.card_template_id] || 0
          const showProgress = c.upgrades && copies >= 2
          return (
            <div
              key={c.id}
              className={`card ${RARITY_CLASS[c.rarity] || ''}${equipped ? ' equipped' : ''}${rosterWide ? ' roster-wide' : ''}`}
              draggable={draggable}
              onDragStart={(e) => draggable && startCardDrag(e, c.id)}
              title={draggable ? 'Drag onto a champion to equip' : 'Applies to your whole roster'}
            >
              <div className="card-stripe" style={{ background: stripeBackground(c.valid_types) }} />
              {onDiscard && (
                <button className="card-discard" title="Discard card"
                  onClick={() => onDiscard(c.id)}>×</button>
              )}
              <div className="card-body">
                <div className="card-name">
                  {c.name}
                  {tier > 1 && <span className="card-tier">{ROMAN[tier] || tier}</span>}
                </div>
                <div className="card-meta">{c.category} · {c.rarity}</div>
                <div className="card-desc">{c.description}</div>
                {onChampion && <div className="card-tag">on {onChampion}</div>}
                {rosterWide && <div className="card-tag">roster-wide</div>}
                {showProgress && (
                  <div className="combine-progress">{copies}/{COMBINE_AT} → upgrades</div>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
