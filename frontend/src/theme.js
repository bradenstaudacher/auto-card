// Locked type palette. Death (black) needs light text; others use dark text.
export const TYPE_COLORS = {
  Occult: '#8b3fd6', // purple
  Holy: '#f4e88a',   // light yellow
  Law: '#7fb2e6',    // light blue
  Fury: '#d63a4a',   // crimson
  Death: '#1c1c22',  // black
}

// Text color that stays readable on each type's fill.
export const TYPE_TEXT = {
  Occult: '#ffffff',
  Holy: '#3a3320',
  Law: '#12314f',
  Fury: '#ffffff',
  Death: '#f2f2f2',
}

// Single-letter glyphs standing in for full art in the MVP.
export const TYPE_GLYPH = {
  Occult: '⚗', // alembic
  Holy: '☀',   // sun
  Law: '⚖',    // scales
  Fury: '⚔',   // swords
  Death: '☠',  // skull
}

// Per-monster glyphs so enemies read as distinct silhouettes at a glance,
// rather than all sharing their type glyph. Falls back to the type glyph.
export const MONSTER_GLYPH = {
  'Lesser Imp': '👺',
  'Ash Hound': '🐺',
  'Bone Wretch': '💀',
  'Oathbound Guard': '🛡',
  'Pale Acolyte': '🕯',
  'Rift Brute': '👹',
}

// Status-effect visual cues: a badge glyph + color for the on-token indicator.
export const STATUS_META = {
  bleed: { glyph: '🩸', color: '#e5484d' },
  poison: { glyph: '☠', color: '#5bd15b' },
  burn: { glyph: '🔥', color: '#ff8a3d' },
}

export function typeColor(type) {
  return TYPE_COLORS[type] || '#666'
}

// Left-edge stripe for a card. Reflects which champion types may use it:
//   0 types  -> neutral grey (freeform, any champion)
//   1 type   -> that type's solid color
//   2+ types -> a vertical split of the first two colors
const NEUTRAL_STRIPE = '#4a4f5e'
export function stripeBackground(validTypes) {
  const types = (validTypes || []).filter(Boolean)
  if (types.length === 0) return NEUTRAL_STRIPE
  if (types.length === 1) return typeColor(types[0])
  const [a, b] = types
  return `linear-gradient(180deg, ${typeColor(a)} 0 50%, ${typeColor(b)} 50% 100%)`
}
export function typeText(type) {
  return TYPE_TEXT[type] || '#fff'
}
