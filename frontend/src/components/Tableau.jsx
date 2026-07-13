import { useState } from 'react'
import { stripeBackground } from '../theme'
import { startCardDrag, isCardDrag, CARD_DND } from '../dnd'

const RARITY_CLASS = { common: 'rar-common', uncommon: 'rar-uncommon', rare: 'rar-rare' }
const ROMAN = { 2: 'II', 3: 'III', 4: 'IV', 5: 'V' }
const COMBINE_AT = 3

// Bottom panel: the player's owned upgrade cards. Drag a card onto a champion
// (bench or grid) to equip it, or drop it onto another card here to reorder the
// tableau. Roster-wide modifiers aren't equipped to one champion (not draggable
// to a champion) but can still be reordered.
export default function Tableau({ cards, rosterById, onDiscard, onReorder }) {
  const [dragOverId, setDragOverId] = useState(null)

  // Drop a dragged card onto another card here → move it before the target.
  function onReorderDrop(e, targetId) {
    if (!isCardDrag(e) || !onReorder) return
    e.preventDefault()
    e.stopPropagation()
    setDragOverId(null)
    const draggedId = Number(e.dataTransfer.getData(CARD_DND))
    if (!draggedId || draggedId === targetId) return
    const ids = cards.map((c) => c.id)
    const from = ids.indexOf(draggedId)
    if (from < 0) return
    ids.splice(from, 1)
    ids.splice(ids.indexOf(targetId), 0, draggedId)
    onReorder(ids)
  }

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
          // Upgrade path + fusion progress from the server (counts all copies,
          // equipped or not). `copies` toward `combine_threshold` (default 3).
          const canUpgrade = c.upgrades
          const threshold = c.combine_threshold || COMBINE_AT
          const copies = c.copies || 1
          const nearly = copies >= threshold - 1
          return (
            <div
              key={c.id}
              className={`card ${RARITY_CLASS[c.rarity] || ''}${equipped ? ' equipped' : ''}${rosterWide ? ' roster-wide' : ''}${dragOverId === c.id ? ' drag-over' : ''}`}
              draggable={draggable}
              onDragStart={(e) => draggable && startCardDrag(e, c.id)}
              onDragOver={(e) => { if (isCardDrag(e) && onReorder) { e.preventDefault(); setDragOverId(c.id) } }}
              onDragLeave={() => setDragOverId((cur) => (cur === c.id ? null : cur))}
              onDrop={(e) => onReorderDrop(e, c.id)}
              title={draggable ? 'Drag onto a champion to equip · drop on another card to reorder' : 'Applies to your whole roster'}
            >
              <div className="card-stripe" style={{ background: stripeBackground(c.valid_types) }} />
              {onDiscard && (
                <button className="card-discard" title="Discard card"
                  onClick={() => onDiscard(c.id)}>×</button>
              )}
              <div className="card-body">
                <div className="card-name">
                  {canUpgrade && (
                    <span className="upgrade-badge" title={`Upgradeable — collect ${threshold} copies to fuse into the next tier`}>↑</span>
                  )}
                  {c.name}
                  {tier > 1 && <span className="card-tier">{ROMAN[tier] || tier}</span>}
                </div>
                <div className="card-meta">{c.category} · {c.rarity}</div>
                <div className="card-desc">{c.description}</div>
                {onChampion && <div className="card-tag">on {onChampion}</div>}
                {rosterWide && <div className="card-tag">roster-wide</div>}
                {canUpgrade && (
                  <div className={`combine-progress${nearly ? ' nearly' : ''}`}>
                    <div className="combine-bar">
                      <div className="combine-fill" style={{ width: `${Math.min(100, (copies / threshold) * 100)}%` }} />
                    </div>
                    <span className="combine-text">{copies}/{threshold}{nearly ? ' → upgrades!' : ' to upgrade'}</span>
                  </div>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
