// Pure helpers to reconstruct battle visuals from the deterministic timeline.
// deriveState replays all events up to a tick — no incremental mutation bugs.

export function buildInitialUnits(run, round) {
  const units = {}
  const rosterByPc = {}
  run.players.forEach((p) => p.roster.forEach((c) => { rosterByPc[c.id] = c }))

  Object.values(round.placement_data || {}).flat().forEach((pl) => {
    const champ = rosterByPc[pl.player_character_id]
    if (!champ) return
    const id = `pc_${pl.player_character_id}`
    units[id] = {
      id, name: champ.name, type: champ.type, team: 'allies',
      x: pl.x, y: pl.y, maxHp: champ.base_stats.health,
      manaCap: champ.base_stats.mana_cap || 0, manaRegen: champ.base_stats.mana_regen || 0,
    }
  })

  ;(round.encounter?.units || []).forEach((u) => {
    units[u.id] = {
      id: u.id, name: u.name, type: u.type, team: 'monsters',
      x: u.position.x, y: u.position.y, maxHp: u.stats.health,
      manaCap: u.stats.mana_cap || 0, manaRegen: u.stats.mana_regen || 0,
    }
  })
  return units
}

// Returns { units, floaters, casters } for a given tick.
export function deriveState(initial, events, tick) {
  const units = {}
  Object.values(initial).forEach((u) => { units[u.id] = { ...u, hp: u.maxHp, shield: 0, alive: true } })

  const floaters = []
  const casters = new Set()
  const lastCast = {}   // unitId -> tick of its most recent cast (mana reset point)
  const applied = {}    // unitId -> { kind -> tick applied }
  const ticked = {}     // unitId -> { kind -> tick of most recent DoT tick }

  for (const e of events) {
    if (e.tick > tick) break
    if (e.type === 'cast') lastCast[e.source_id] = e.tick
    if (e.type === 'status_applied') {
      ;(applied[e.unit_id] ||= {})[e.effect] = e.tick
    } else if (e.type === 'status') {
      ;(ticked[e.unit_id] ||= {})[e.effect] = e.tick
    } else if (e.type === 'cleanse') {
      applied[e.unit_id] = {}; ticked[e.unit_id] = {} // any heal clears all statuses
    }
    switch (e.type) {
      case 'move': {
        const u = units[e.unit_id]
        if (u) { u.x = e.to.x; u.y = e.to.y }
        break
      }
      case 'attack': {
        const t = units[e.target_id]
        if (t) {
          t.hp = e.target_health_after
          if (e.target_shield_after != null) t.shield = e.target_shield_after
        }
        break
      }
      case 'cast': {
        const t = units[e.target_id]
        if (t) {
          t.hp = e.target_health_after
          if (e.target_shield_after != null) t.shield = e.target_shield_after
        }
        if (e.source_health_after != null && units[e.source_id]) {
          units[e.source_id].hp = e.source_health_after
        }
        break
      }
      case 'status': {
        const u = units[e.unit_id]
        if (u) {
          u.hp = e.target_health_after
          if (e.target_shield_after != null) u.shield = e.target_shield_after
        }
        break
      }
      case 'death': {
        const u = units[e.unit_id]
        if (u) u.alive = false
        break
      }
    }

    // Floating numbers + cast flashes only for the CURRENT tick.
    if (e.tick === tick) {
      if (e.type === 'attack') {
        floaters.push({ key: `${e.tick}-${e.target_id}-a`, unitId: e.target_id, text: `-${e.damage}`, kind: 'dmg' })
      } else if (e.type === 'cast') {
        casters.add(e.source_id)
        if (e.damage > 0) {
          floaters.push({ key: `${e.tick}-${e.target_id}-c`, unitId: e.target_id, text: `-${e.damage}`, kind: 'dmg' })
        }
        if (e.healing > 0) {
          // Self-heal (e.g. Vampiric Drain) sets source_health_after; ally heals
          // (e.g. Shield Pulse) land on the target instead. Ward grants an absorb
          // shield rather than health — show it grey.
          const healed = e.source_health_after != null ? e.source_id : e.target_id
          const kind = e.damage_type === 'shield' ? 'shield' : 'heal'
          floaters.push({ key: `${e.tick}-${healed}-h`, unitId: healed, text: `+${e.healing}`, kind })
        }
      } else if (e.type === 'status') {
        floaters.push({ key: `${e.tick}-${e.unit_id}-s`, unitId: e.unit_id, text: `-${e.damage}`, kind: e.effect })
      } else if (e.type === 'cleanse') {
        floaters.push({ key: `${e.tick}-${e.unit_id}-cl`, unitId: e.unit_id, text: 'cleansed', kind: 'cleanse' })
      }
    }
  }

  // Reconstruct mana (charges +manaRegen/tick from battle start, reset on cast)
  // and active statuses (applied & still ticking, not cleansed) for each unit.
  Object.values(units).forEach((u) => {
    if (u.manaCap > 0 && u.manaRegen > 0) {
      const since = tick - (lastCast[u.id] || 0)
      u.mana = Math.max(0, Math.min(u.manaCap, u.manaRegen * since))
    } else {
      u.mana = 0
    }
    const active = []
    const app = applied[u.id] || {}
    const tk = ticked[u.id] || {}
    Object.keys(app).forEach((kind) => {
      // Active if applied this very tick, or it has ticked within the last tick.
      if (app[kind] === tick || (tk[kind] != null && tick - tk[kind] <= 1)) active.push(kind)
    })
    u.statuses = active
  })

  return { units, floaters, casters }
}

export function logLine(initial, e) {
  const name = (id) => initial[id]?.name || id
  switch (e.type) {
    case 'move': return null // movement is visual only; keep the log readable
    case 'attack': return `${name(e.source_id)} hits ${name(e.target_id)} for ${e.damage}`
    case 'cast': {
      if (e.damage === 0 && e.healing > 0) {
        const verb = e.damage_type === 'shield' ? 'shields' : 'heals'
        return `${name(e.source_id)} casts ${e.ability_name} on ${name(e.target_id)} (${verb} ${e.healing})`
      }
      const heal = e.healing > 0 ? `, heals ${e.healing}` : ''
      return `${name(e.source_id)} casts ${e.ability_name} on ${name(e.target_id)} (${e.damage} dmg${heal})`
    }
    case 'status_applied': return `${name(e.source_id)} afflicts ${name(e.unit_id)} with ${e.effect}`
    case 'status': return `${name(e.unit_id)} suffers ${e.damage} ${e.effect}`
    case 'cleanse': return `✦ ${name(e.unit_id)} is cleansed (${(e.effects || []).join(', ')})`
    case 'death': return `☠ ${name(e.unit_id)} is defeated`
    default: return null
  }
}
