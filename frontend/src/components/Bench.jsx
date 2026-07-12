import ChampionCircle from './ChampionCircle'
import { isCardDrag } from '../dnd'

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
                <span className="bench-name">{c.name}{placed && <span className="deployed-tag">deployed</span>}</span>
                <span className="bench-sub">{c.type} / {c.subclass}</span>
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
