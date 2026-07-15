# Agent task: integrate attack VFX overlays into the Vite autobattler

We have a Node/Vite autobattler card game. Units are currently rendered as colored circles with a small symbol inside. Add a lightweight attack animation layer using the provided transparent PNG assets.

Asset pack contents:

- Five class folders: `occult`, `holy`, `law`, `fury`, `death`
- Each class has four transparent 64x64 PNG frames
- Each class also has a 4-frame horizontal spritesheet, 256x64
- `manifest.json` describes the frame size, duration, class names, colors, and paths
- `attack-vfx.css` contains starter CSS
- `attackVfxConfig.ts` contains starter TypeScript config

The VFX art is designed as an overlay. It should not replace the unit circle. It should render above the attacking unit and then disappear.

## Desired behavior

When a unit attacks:

1. Determine the attacker and target screen positions.
2. Determine the attacking unit's class type: `occult`, `holy`, `law`, `fury`, or `death`.
3. Render that class's attack VFX centered on the attacking unit.
4. Rotate the VFX so the default left-to-right/east-facing animation points toward the target.
5. Play the 4-frame animation over roughly 360ms.
6. Remove the VFX node/state after the animation finishes.
7. Do not block clicks, drag, hover, targeting, or any gameplay interactions.
8. Do not make the animation authoritative for combat timing; it is visual only.

## Recommended file placement

Copy the asset pack into:

```text
src/assets/vfx/attack-vfx/
```

Suggested final paths:

```text
src/assets/vfx/attack-vfx/occult/occult_attack_overlay_spritesheet_4x1.png
src/assets/vfx/attack-vfx/holy/holy_attack_overlay_spritesheet_4x1.png
src/assets/vfx/attack-vfx/law/law_attack_overlay_spritesheet_4x1.png
src/assets/vfx/attack-vfx/fury/fury_attack_overlay_spritesheet_4x1.png
src/assets/vfx/attack-vfx/death/death_attack_overlay_spritesheet_4x1.png
```

## Suggested API

Create a reusable VFX trigger, something like:

```ts
playAttackVfx({
  attackerId,
  targetId,
  classType,
  durationMs: 360,
})
```

or, if the board already knows screen positions:

```ts
playAttackVfx({
  attackerPosition: { x: attackerX, y: attackerY },
  targetPosition: { x: targetX, y: targetY },
  classType,
})
```

## Rotation logic

The assets are authored to face east, meaning left-to-right. Rotate the wrapper toward the target:

```ts
const dx = targetPosition.x - attackerPosition.x
const dy = targetPosition.y - attackerPosition.y
const angleRad = Math.atan2(dy, dx)
```

Use that angle on the outer wrapper:

```tsx
<div
  className="attack-vfx-wrapper"
  style={{
    left: attackerPosition.x,
    top: attackerPosition.y,
    transform: `translate(-50%, -50%) rotate(${angleRad}rad)`,
  }}
>
  <div className={`attack-vfx-sprite ${config.cssClass}`} />
</div>
```

Use an outer wrapper for position and rotation, and an inner sprite element for the frame animation. This avoids transform conflicts.

## CSS starter

Use the provided `attack-vfx.css`, or implement equivalent CSS:

```css
.board-vfx-layer {
  position: absolute;
  inset: 0;
  pointer-events: none;
  overflow: visible;
  z-index: 50;
}

.attack-vfx-wrapper {
  position: absolute;
  width: 64px;
  height: 64px;
  transform-origin: center center;
  pointer-events: none;
}

.attack-vfx-sprite {
  width: 64px;
  height: 64px;
  background-size: 256px 64px;
  background-repeat: no-repeat;
  animation: attack-vfx-frames 360ms steps(4) forwards;
}

@keyframes attack-vfx-frames {
  from { background-position: 0 0; }
  to { background-position: -256px 0; }
}
```

Add class-specific spritesheet URLs:

```css
.attack-vfx--occult { background-image: url('./occult/occult_attack_overlay_spritesheet_4x1.png'); }
.attack-vfx--holy   { background-image: url('./holy/holy_attack_overlay_spritesheet_4x1.png'); }
.attack-vfx--law    { background-image: url('./law/law_attack_overlay_spritesheet_4x1.png'); }
.attack-vfx--fury   { background-image: url('./fury/fury_attack_overlay_spritesheet_4x1.png'); }
.attack-vfx--death  { background-image: url('./death/death_attack_overlay_spritesheet_4x1.png'); }
```

If Vite does not resolve CSS URLs from this location cleanly, import the spritesheets in TypeScript instead and apply `backgroundImage` inline from the imported asset URL.

## State model suggestion

Maintain a small list of transient VFX instances:

```ts
type AttackVfxInstance = {
  id: string
  classType: AttackClass
  x: number
  y: number
  angleRad: number
  createdAt: number
  durationMs: number
}
```

On attack event:

```ts
setAttackVfxInstances((current) => [
  ...current,
  {
    id: crypto.randomUUID(),
    classType,
    x: attackerPosition.x,
    y: attackerPosition.y,
    angleRad,
    createdAt: performance.now(),
    durationMs: 360,
  },
])
```

Then schedule cleanup:

```ts
window.setTimeout(() => {
  setAttackVfxInstances((current) => current.filter((vfx) => vfx.id !== id))
}, durationMs)
```

## Acceptance criteria

- Every class type can trigger its own attack overlay.
- The animation appears centered on the attacking unit circle.
- The overlay rotates toward the target.
- The animation uses the correct class art and color language.
- The animation plays once and removes itself.
- The VFX layer does not intercept pointer events.
- Multiple attacks can briefly overlap without breaking rendering.
- The implementation remains data-driven so new classes can be added by adding config entries and assets.
