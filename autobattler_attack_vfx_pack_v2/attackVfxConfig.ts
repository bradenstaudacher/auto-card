export type AttackClass = 'occult' | 'holy' | 'law' | 'fury' | 'death'

export type AttackVfxConfig = {
  className: string
  frameSize: number
  frameCount: number
  durationMs: number
  cssClass: string
  spritesheetPath: string
  defaultDirection: 'east'
}

export const ATTACK_VFX_BY_CLASS: Record<AttackClass, AttackVfxConfig> = {
  occult: {
    className: 'Occult',
    frameSize: 64,
    frameCount: 4,
    durationMs: 360,
    cssClass: 'attack-vfx--occult',
    spritesheetPath: '/assets/vfx/attack-vfx/occult/occult_attack_overlay_spritesheet_4x1.png',
    defaultDirection: 'east',
  },
  holy: {
    className: 'Holy',
    frameSize: 64,
    frameCount: 4,
    durationMs: 360,
    cssClass: 'attack-vfx--holy',
    spritesheetPath: '/assets/vfx/attack-vfx/holy/holy_attack_overlay_spritesheet_4x1.png',
    defaultDirection: 'east',
  },
  law: {
    className: 'Law',
    frameSize: 64,
    frameCount: 4,
    durationMs: 360,
    cssClass: 'attack-vfx--law',
    spritesheetPath: '/assets/vfx/attack-vfx/law/law_attack_overlay_spritesheet_4x1.png',
    defaultDirection: 'east',
  },
  fury: {
    className: 'Fury',
    frameSize: 64,
    frameCount: 4,
    durationMs: 360,
    cssClass: 'attack-vfx--fury',
    spritesheetPath: '/assets/vfx/attack-vfx/fury/fury_attack_overlay_spritesheet_4x1.png',
    defaultDirection: 'east',
  },
  death: {
    className: 'Death',
    frameSize: 64,
    frameCount: 4,
    durationMs: 360,
    cssClass: 'attack-vfx--death',
    spritesheetPath: '/assets/vfx/attack-vfx/death/death_attack_overlay_spritesheet_4x1.png',
    defaultDirection: 'east',
  },
}
