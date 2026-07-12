import ChampionCircle from './ChampionCircle'
import { typeColor, typeText, TYPE_GLYPH } from '../theme'
import { isCardDrag } from '../dnd'

const COLS = 8
const ROWS = 6
const ALLY_MIN_ROW = 4   // bottom two rows are the deployment zone
const ENEMY_MAX_ROW = 1  // top two rows are the enemy zone

// Center panel during preparation: shows the enemy formation and lets the
// player drop bench champions onto the left-side deployment zone.
export default function PlacementGrid({ enemies, placements, lockedAllies = [], rosterById, onDrop, onDragStartPlaced, onInspectPlaced, onUnplace, onCardDrop }) {
  const allyAt = {}
  Object.entries(placements).forEach(([pcId, pos]) => { allyAt[`${pos.x},${pos.y}`] = Number(pcId) })
  const lockedAt = {}
  lockedAllies.forEach((a) => { lockedAt[`${a.x},${a.y}`] = a.pcId })
  const enemyAt = {}
  enemies.forEach((e) => { enemyAt[`${e.position.x},${e.position.y}`] = e })

  const cells = []
  for (let y = 0; y < ROWS; y++) {
    for (let x = 0; x < COLS; x++) {
      const key = `${x},${y}`
      const isAlly = y >= ALLY_MIN_ROW
      const isEnemyZone = y <= ENEMY_MAX_ROW
      const pcId = allyAt[key]
      const lockedPc = lockedAt[key]
      const enemy = enemyAt[key]
      cells.push(
        <div
          key={key}
          className={`grid-cell${isAlly ? ' ally-zone' : ''}${isEnemyZone ? ' enemy-zone' : ''}`}
          onDragOver={(e) => { if (isAlly && !pcId) e.preventDefault() }}
          onDrop={(e) => { if (isAlly) onDrop(e, x, y) }}
        >
          {pcId != null && (
            <div
              className="cell-token"
              onDragOver={(e) => e.preventDefault()}
              onDrop={(e) => (isCardDrag(e) ? onCardDrop(e, pcId) : onDrop(e, x, y))}
            >
              <ChampionCircle
                champion={rosterById[pcId]}
                size={40}
                draggable
                onDragStart={(e) => onDragStartPlaced(e, pcId)}
                onClick={() => onInspectPlaced(pcId)}
              />
              <button className="unplace-btn" title="Return to bench"
                onClick={(e) => { e.stopPropagation(); onUnplace(pcId) }}>×</button>
            </div>
          )}
          {lockedPc != null && rosterById[lockedPc] && (
            <div className="cell-token" title={`${rosterById[lockedPc].name} (ally)`}>
              <ChampionCircle champion={rosterById[lockedPc]} size={40} dimmed />
              <span className="ally-lock-badge" title="Ally, locked in">🤝</span>
            </div>
          )}
          {enemy && (
            <div className="cell-token enemy-token"
              style={{ background: typeColor(enemy.type), color: typeText(enemy.type) }}
              title={`${enemy.name} — ${enemy.type}`}>
              <span className="champ-glyph">{TYPE_GLYPH[enemy.type] || '?'}</span>
            </div>
          )}
        </div>
      )
    }
  }

  return (
    <div className="grid-wrap">
      <div className="grid-legend">
        <span className="legend-enemy">▲ Enemy formation (top)</span>
        <span className="legend-ally">Your deployment zone (bottom) ▼</span>
      </div>
      <div className="battle-grid" style={{ gridTemplateColumns: `repeat(${COLS}, 1fr)` }}>
        {cells}
      </div>
    </div>
  )
}
