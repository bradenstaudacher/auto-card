// Drag payload conventions. Distinct MIME-ish types let a champion token be
// both a placement-drag source AND a card drop target without ambiguity.
export const CHAMPION_DND = 'application/x-champion'
export const CARD_DND = 'application/x-card'

export function startChampionDrag(e, pcId) {
  e.dataTransfer.setData(CHAMPION_DND, String(pcId))
  e.dataTransfer.setData('text/plain', String(pcId))
  e.dataTransfer.effectAllowed = 'move'
}

export function startCardDrag(e, playerCardId) {
  e.dataTransfer.setData(CARD_DND, String(playerCardId))
  e.dataTransfer.setData('text/plain', String(playerCardId))
  e.dataTransfer.effectAllowed = 'copyMove'
}

// True if the current drag carries a card (types are readable during dragover).
export function isCardDrag(e) {
  return Array.from(e.dataTransfer.types).includes(CARD_DND)
}
