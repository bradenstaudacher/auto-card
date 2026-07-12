import { typeColor, typeText, TYPE_GLYPH } from '../theme'

// Colored circular token for a champion. Used on the bench and the grid.
export default function ChampionCircle({ champion, size = 46, draggable, onDragStart, onClick, dimmed }) {
  return (
    <div
      className={`champ-circle${dimmed ? ' dimmed' : ''}`}
      style={{
        width: size, height: size,
        background: typeColor(champion.type),
        color: typeText(champion.type),
        borderColor: champion.type === 'Death' ? '#555' : 'rgba(0,0,0,0.35)',
      }}
      draggable={draggable}
      onDragStart={onDragStart}
      onClick={onClick}
      title={`${champion.name} — ${champion.type}${champion.subclass ? ' / ' + champion.subclass : ''}`}
    >
      <span className="champ-glyph">{TYPE_GLYPH[champion.type] || '?'}</span>
    </div>
  )
}
