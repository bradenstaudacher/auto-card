import ChampionCircle from './ChampionCircle'
import { isCardDrag } from '../dnd'

// XP progress toward the next level; full bar (with a MAX tag) at level cap.
// Drag an XP card onto the champion to fill it.
function xpBar(c) {
  const p = c.xp_progress || {}
  const pct = p.max ? 100 : (p.needed ? Math.min(100, Math.round((p.into_level / p.needed) * 100)) : 0)
  return (
    <div className="xp-row" title={p.max ? 'Max level' : `${p.into_level}/${p.needed} XP to next level`}>
      <div className="xp-track"><div className="xp-fill" style={{ width: `${pct}%` }} /></div>
      <span className="xp-text">{p.max ? 'MAX' : `${p.to_next} XP`}</span>
    </div>
  )
}

// Left panel: roster champions. Drag onto the grid to deploy; drag a tableau
// card onto one to equip it; click to inspect in the modal.
export default function Bench({ roster, placedIds, onDragStart, onInspect, onCardDrop }) {
  return (
    <aside className="bench">
      <h3 className="panel-title">Bench</h3>
      <div className="bench-list">
        {roster.map((c) => {
          const placed = placedIds.has(c.id)
          const equipped = c.equipped || []
          return (
            <div
              key={c.id}
              className="bench-item"
              onDragOver={(e) => { if (isCardDrag(e)) e.preventDefault() }}
              onDrop={(e) => onCardDrop(e, c.id)}
            >
              <ChampionCircle
                champion={c}
                draggable={!placed}
                dimmed={placed}
                onDragStart={(e) => onDragStart(e, c.id)}
                onClick={() => onInspect(c.id)}
              />
              <div className="bench-label">
                <span className="bench-name">
                  <span className="level-badge" title={`Level ${c.level || 1}`}>L{c.level || 1}</span>
                  {c.name}{placed && <span className="deployed-tag">deployed</span>}
                </span>
                <span className="bench-sub">{c.type} / {c.subclass}</span>
                {xpBar(c)}
                {equipped.length > 0 && (
                  <ul className="bench-equips">
                    {equipped.map((e) => <li key={e.player_card_id}>{e.name}</li>)}
                  </ul>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </aside>
  )
}
