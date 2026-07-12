import { useState } from 'react'
import { typeColor } from '../theme'
import { isCardDrag } from '../dnd'

const STAT_ROWS = [
  ['health', 'Health'], ['attack_damage', 'Attack'], ['magic_power', 'Magic'],
  ['armor', 'Armor'], ['shield', 'Shield'], ['mana_cap', 'Mana'],
  ['mana_regen', 'Mana Regen'], ['movement_speed', 'Move'],
  ['attack_range', 'Range'], ['attack_speed', 'Atk Speed'],
]

const SLOT_DEFS = [
  ['weapon', 'weapon_slots', 'Weapons'],
  ['equipment', 'equipment_slots', 'Equipment'],
  ['passive', 'passive_slots', 'Passives'],
  ['ability', 'ability_slots', 'Abilities'],
]

// Renders equipped cards + empty slots for one slot type.
function SlotRow({ label, slotType, capacity, equipped, onUnequip }) {
  if (!capacity) return null
  const filled = equipped.filter((c) => c.slot_type === slotType)
  const empties = Math.max(0, capacity - filled.length)
  return (
    <div className="slot-row">
      <span className="slot-label">{label}</span>
      <div className="slot-boxes">
        {filled.map((c) => (
          <div key={c.player_card_id} className="slot-box filled">
            {c.name}
            <button className="slot-remove" title="Unequip" onClick={() => onUnequip(c.player_card_id)}>×</button>
          </div>
        ))}
        {Array.from({ length: empties }).map((_, i) => (
          <div key={`e${i}`} className="slot-box empty">empty</div>
        ))}
      </div>
    </div>
  )
}

export default function CharacterModal({ champion, placed, onClose, onUnplace, onUnequip, onCardDrop, onReorder }) {
  const [dragIdx, setDragIdx] = useState(null)
  if (!champion) return null

  const stats = champion.effective_stats || champion.base_stats
  const base = champion.base_stats
  const cfg = champion.slot_config || {}
  const equipped = champion.equipped || []
  const abilities = champion.abilities || []

  function reorder(from, to) {
    if (from === to || from == null) return
    const next = abilities.map((a) => a.name)
    const [moved] = next.splice(from, 1)
    next.splice(to, 0, moved)
    onReorder(next)
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div
        className="modal"
        onClick={(e) => e.stopPropagation()}
        onDragOver={(e) => { if (isCardDrag(e)) e.preventDefault() }}
        onDrop={(e) => { if (isCardDrag(e)) onCardDrop(e) }}
      >
        <div className="modal-head" style={{ borderColor: typeColor(champion.type) }}>
          <div className="modal-badge" style={{ background: typeColor(champion.type) }} />
          <div>
            <h2 className="modal-name">{champion.name}</h2>
            <p className="modal-sub">{champion.type} / {champion.subclass} · {champion.role}</p>
          </div>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>

        <div className="modal-body">
          <div className="stat-grid">
            {STAT_ROWS.map(([k, label]) => {
              const boosted = stats[k] !== base[k]
              return (
                <div key={k} className="stat-cell">
                  <span className="stat-label">{label}</span>
                  <span className={`stat-value${boosted ? ' boosted' : ''}`}>{stats[k]}</span>
                </div>
              )
            })}
          </div>

          <p className="drop-hint">Drag cards here (or onto the champion) to equip</p>

          <div className="slots">
            {SLOT_DEFS.filter(([t]) => t !== 'ability').map(([slotType, key, label]) => (
              <SlotRow key={slotType} label={label} slotType={slotType}
                capacity={cfg[key]} equipped={equipped} onUnequip={onUnequip} />
            ))}

            {/* Abilities — cast in this order; drag to re-prioritize */}
            <div className="slot-row abilities-row">
              <span className="slot-label">Abilities</span>
              <div className="ability-order">
                {abilities.length === 0 && <span className="empty-hint">No abilities — this champion only basic-attacks.</span>}
                {abilities.map((a, i) => (
                  <div
                    key={a.name}
                    className={`ability-chip${dragIdx === i ? ' dragging' : ''}${a.implemented ? '' : ' unimpl'}`}
                    draggable={abilities.length > 1}
                    onDragStart={() => setDragIdx(i)}
                    onDragEnd={() => setDragIdx(null)}
                    onDragOver={(e) => e.preventDefault()}
                    onDrop={() => { reorder(dragIdx, i); setDragIdx(null) }}
                    title={abilities.length > 1 ? 'Drag to change cast priority' : ''}
                  >
                    <div className="ability-head">
                      <span className="ability-num">{i + 1}</span>
                      <span className="ability-name">{a.name}</span>
                      {a.mana_cost != null && <span className="ability-cost">{a.mana_cost} mana</span>}
                      {a.is_default && <span className="ability-badge">signature</span>}
                      {!a.implemented && <span className="ability-badge soon">coming soon</span>}
                    </div>
                    {a.description && <div className="ability-desc">{a.description}</div>}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        {placed && (
          <div className="modal-foot">
            <button className="btn btn-danger" onClick={() => { onUnplace(); onClose() }}>
              Return to Bench
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
