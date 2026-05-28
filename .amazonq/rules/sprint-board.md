# Gnome Apocalypse — Sprint Board

> Reflects current codebase state. Updated after each session.
> **Independent** = can be worked on in parallel without blocking others.

---

## ✅ Done

### Foundation
- `GameConfig.swift` — all V1 constants, dynamic `cameraViewportSize`, `projectileLifeSpan`, `autoAimMaxRange`, wave escalation constants, orb state machine timers
- `PhysicsCategory.swift` — all V1 bitmasks
- `ToroidalMath.swift` — `toroidalOffset`, `nearestToroidalTarget`, `toroidalDistance`
- `Layer.swift` — scene layers + entity sub-layers
- `Log.swift` — debug wrapper, silent in release

### Rendering
- `MetalRenderer.swift` — `SKRenderer` + Metal, stencil buffer, cached command queue, viewport resize
- `FloorTileRenderer.swift` — infinite tiled floor, dynamic viewport rebuild
- `ParticleAssets.swift` — preloaded `SKEmitterNode` pool, `emit(_:at:in:)` helper
- `ViewController.swift` — delegates to `MetalRenderer`, `HomeScene` entry point, mouse input routing

### Camera
- `CameraSystem.swift` — midpoint follow, no-wrap drift, `clampToroidal`, zoom via `setScale`, `isLocked` for Boss stage

### Input
- `InputSystem.swift` — WASD + mouse/trackpad aim, auto-aim with idle threshold, controller connect/disconnect

### Components
- `HealthComponent.swift` — `takeDamage` (returns Bool), `heal`, `increaseMaximum`, `isDead`, `fraction`
- `LevelComponent.swift` — `addXP` (returns Bool), threshold growth, `xpFraction`
- `AnimationComponent.swift` — atlas loading, 8-direction, optional mirror, `play/stop`
- `ToroidalRenderingComponent.swift` — ghost nodes, camera-drift-aware nearest-sector logic, color fallback
- `EssenceOrbComponent.swift` — full state machine (`small → grown → red → mistExplosion`), ghost rendering, collection

### Entities
- `PlayerEntity.swift` — movement, `clampToroidal`, ghost rendering, `takeDamage`, `addXP`, `applySkill`, `equippedWeapons/equippedPowerUps`
- `PlayerAttack.swift` — timer-based auto-fire, `isShooting` flag for animation
- `LuminousWisp.swift` — full 8-direction animation, aim-priority facing, shoot/walk/idle states
- `EnemyEntity.swift` — movement toward target, `clampToroidal`, ghost rendering, `die()` with ghost cleanup
- `EnemyAI.swift` — nearest toroidal target, runs post-wrap each frame
- `Grove.swift` — placeholder atlas, mirror animation, `GameConfig` constants
- `Grumble.swift` — ranged attack via enemy projectile pool (functional)
- `Grand.swift` — two-phase ability, minion spawn via `SpawnSystem`
- `Projectile.swift` — velocity movement, `clampToroidal`, ghost rendering, lifespan, animation
- `ProjectilePool.swift` — pre-allocated pool, `dequeue/enqueue`, `attachAll`

### Systems
- `DirectorSystem.swift` — rolling kill window, average player health pressure, budget adjustment, Boss stage timer
- `SkillSystem.swift` / `Skill.swift` / `PlayerSkillState.swift` — 6-skill pool, unified draw, pool caps, `maxLevel3Items` cap
- `SpawnSystem.swift` — budget-gated wave spawning, wave escalation, orb state machine wiring, MiniBoss from orb explosion, Boss stage, `activeBudgetUsed` passed to Director
- `CollisionSystem.swift` — projectile→enemy, projectile→player, orb→player, ghost redirect

### UI
- `HUD.swift` — health bar, XP/essence bar, level label, timer, weapon + power-up item slots
- `SkillCardOverlay.swift` — 3-card pause overlay, mouse click selection, calls `applySkill`
- `GameOverOverlay.swift` — survived time display, replay button
- `HomeScene.swift` — placeholder start screen, `onStart` callback

### Audio
- `AudioManager.swift` — preloaded music + SFX players, `play(_:)`, `playBackgroundMusic()`

### Tests
- `ToroidalMathTests.swift` — `toroidalOffset`, `nearestToroidalTarget`, `toroidalDistance`
- `HealthComponentTests.swift` — all boundary conditions
- `LevelComponentTests.swift` — XP accumulation, multi-level-up, threshold growth
- `EssenceOrbComponentTests.swift` — full state machine transitions, timer thresholds
- `EnemyProjectilePoolTests.swift` — enemy projectile spawns active with correct bitmasks
- `CameraSystemTests.swift` — locked camera does not follow players
- `SpawnSystemTests.swift` — orb explosion → MiniBoss, Boss stage, wave escalation, budget respect

---

## ⚠️ Partial (file exists, core done, pieces missing)

| File | What's missing |
|------|---------------|
| `ShieldComponent.swift` | Stub only — no expansion animation, no physics impulse, no `isTargetingActive` toggle |
| `GameScene.swift` | `handleLevelUp` triggers `SkillCardOverlay` but does not freeze player or trigger `ShieldComponent` |

---

## 🔴 Not Started — V1 Remaining

### Must be done in order

1. **`ShieldComponent.swift`** — full implementation
   - Freeze player movement on level-up
   - Expand `SKShapeNode` radius over `GameConfig.shieldExpandDuration`
   - Physics impulse to entities in radius each frame
   - `isTargetingActive = false` on player during expansion
   - Burst knockback on skill select, then dissolve
   - Wire into `GameScene.handleLevelUp`

2. **`CollisionSystem` — shield handlers**
   - Shield pushes enemies (physics impulse)
   - Shield destroys enemy projectiles

### Independent (assign freely)

- **Grove atlas** — replace `LuminousWisp` placeholder with actual `Grove.spriteatlas`
- **Audio wiring** — call `AudioManager.shared.play(...)` at hit, death, level-up, orb collect, Mist explosion, Boss appear in `GameScene` and `CollisionSystem`
- **Particle wiring** — call `ParticleAssets.shared.emit(...)` at gnome death, orb collect, shield expand/burst, Mist explosion
- **`HomeScene` polish** — currently placeholder; improve visuals before milestone

---

## 🔵 V2 — Shared-Screen Multiplayer (not started)

- Up to 4 `GCController` slots in `InputSystem`
- Spawn/track up to 4 `PlayerEntity` in `GameScene`
- `CameraSystem` midpoint for 2–4 players
- Leash logic in `CameraSystem`
- `SkillCardOverlay` anchored to shield radius (world-space, not screen-space)
- Per-player HUD slots in `HUD.swift`
- `DirectorSystem.updatePlayerHealthFraction(_:)` reports average active-player health fraction
- Controller hot-plug decision

---

## 🟣 V3 — Environmental Strategy (not started)

- `SideQuestComponent.swift`
- Button + chest visuals
- Chest reward logic
- `SwarmGnome` spawn unit

---

## 🟡 V4 — Home Loop & Persistence (not started)

- `HomeScene.swift` full implementation (currently placeholder)
- `MetaProgressionScene.swift`
- `ForestEssenceStore.swift`
- `GameCenterManager.swift`
- `Achievements.swift`
- `LeaderboardUI.swift`
- `SceneManager.swift`
