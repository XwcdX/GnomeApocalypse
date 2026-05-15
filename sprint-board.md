# Gnome Apocalypse — Sprint Board

> Reflects current codebase state. Updated after each session.
> **Independent** = can be worked on in parallel without blocking others.

---

## ✅ Done

### Foundation
- `GameConfig.swift` — all V1 constants, dynamic `cameraViewportSize`, `projectileLifeSpan`, `autoAimMaxRange`
- `PhysicsCategory.swift` — all V1 bitmasks
- `ToroidalMath.swift` — `toroidalOffset`, `nearestToroidalTarget`, `toroidalDistance`
- `Layer.swift` — scene layers + entity sub-layers
- `Log.swift` — debug wrapper, silent in release

### Rendering
- `MetalRenderer.swift` — `SKRenderer` + Metal, stencil buffer, cached command queue, viewport resize
- `FloorTileRenderer.swift` — infinite tiled floor, dynamic viewport rebuild
- `ViewController.swift` — delegates fully to `MetalRenderer`

### Camera
- `CameraSystem.swift` — midpoint follow, no-wrap drift, `clampToroidal`, zoom via `setScale`

### Input
- `InputSystem.swift` — WASD + mouse/trackpad aim, auto-aim with idle threshold, controller connect/disconnect

### Components
- `HealthComponent.swift` — `takeDamage` (returns Bool), `heal`, `increaseMaximum`, `isDead`, `fraction`
- `LevelComponent.swift` — `addXP` (returns Bool), threshold growth, `xpFraction`
- `AnimationComponent.swift` — atlas loading, 8-direction, optional mirror, `play/stop`
- `ToroidalRenderingComponent.swift` — ghost nodes, camera-drift-aware nearest-sector logic, color fallback for texture-less nodes
- `ForestEssenceOrb.swift` — drops on enemy death, ghost rendering, collection via `CollisionSystem`, cleanup on collect, evolution state machine

### Entities
- `PlayerEntity.swift` — movement, `clampToroidal`, ghost rendering, `takeDamage`, `addXP`, `applySkill`, skill properties
- `PlayerAttack.swift` — timer-based auto-fire, `isShooting` flag for animation
- `LuminousWisp.swift` — full 8-direction animation, aim-priority facing, shoot/walk/idle states
- `EnemyEntity.swift` — movement toward target, `clampToroidal`, ghost rendering, `die()` with ghost cleanup
- `EnemyAI.swift` — nearest toroidal target, runs post-wrap each frame
- `SmallGnome.swift` — `LuminousWisp` atlas placeholder, mirror animation, `GameConfig` constants
- `MiniBossGnome.swift` — ranged attack through enemy projectile pool
- `BossGnome.swift` — two-phase ability, budget-exempt minion spawn, `handleBossDeath` on die
- `Projectile.swift` — velocity movement, `clampToroidal`, ghost rendering, lifespan, animation
- `ProjectilePool.swift` — pre-allocated pool, `dequeue/enqueue`, `attachAll`

### Systems
- `DirectorSystem.swift` — rolling window, kill/damage rate, budget adjustment, Boss stage timer
- `SkillSystem.swift` — 6-skill pool, unified draw, pool caps, `maxLevel3Items` cap, `PlayerSkillState`
- `SpawnSystem.swift` — budget-gated spawning, outside-camera positions, orb tracking + cleanup, MiniBoss/Boss spawning, wave escalation
- `CollisionSystem.swift` — projectile→enemy, projectile→player, orb→player, ghost redirect

### V1 Gameplay Completion
- **GNAP-136 — Player Weapon Ancient Cards** — Orbiting Spell, Lightning Strike, Poisonous Mist live as picks. Lightning per-level cooldown + multi-strike (no chaining); Mist per-level cooldown + multi-cloud; Orbit new (orbits player, per-orb-per-enemy cooldown). `SkillConfig.*ByLevel` arrays drive per-level tuning. `AudioManager` migrated to `NSDataAsset`; 8 placeholder mp3s added under `Greed/Assets.xcassets/Sounds/`. `ParticleAssets` now has code-built emitter fallback for all 7 effect cases (`orbCollect`, `gnomeDeath`, `shieldExpand`, `shieldBurst`, `mistExplosion`, `orbitingSpellHit`, `lightningImpact`) — every existing call site now produces a visible burst until real `.sks` art lands. New `OrbitingSpellCard.imageset` + `OrbitingSpell.spriteatlas/orbiting_orb_000.imageset` ship as CoreGraphics placeholders. Orb ghost-rendering deferred (80px orbit radius makes the seam negligible). `Music.background` still silent (out of ticket scope).
- `GameScene.setupSystems` — enemy projectile pool added; `spawnEnemyProjectile(at:direction:damage:)` implemented
- `ForestEssenceOrb.swift` — state machine implemented (`small → grown → red → mistExplosion`), placeholder Mist VFX, high-value red tier
- `SpawnSystem.swift` — orb Mist explosion wiring, budget-checked MiniBoss spawn, Boss stage spawn pause, `BossGnome` spawn, wave escalation
- `GameScene.swift` — Boss death records `DirectorSystem.recordBossDeath()`, active budget passed to Director each frame
- `GameScene.swift` / `CameraSystem.swift` — Boss stage camera lock and player leash
- `SpawnSystem.swift` — `spawnBossMinions(count:around:)` implemented for Boss ability minions
- `SkillCardOverlay.swift` — level-up skill card overlay, 3 cards, mouse click/controller confirm, applies selected skill
- `HUD.swift` — health, level, XP/Essence progress, item/power-up slots, camera-anchored responsive layout, timer HUD
- `AudioManager.swift` — AVFoundation manager with preloaded placeholder music/SFX hooks
- `ParticleAssets.swift` — preloaded placeholder emitter infrastructure for VFX
- `HomeScene.swift` — placeholder title screen, press anywhere or any key to start
- `GameOverOverlay.swift` — game-over screen with survival time and replay button

### Tests
- `ToroidalMathTest.swift` — `toroidalOffset`, `nearestToroidalTarget`, `toroidalDistance`
- `HealthComponentTests.swift` — all boundary conditions
- `LevelComponentTests.swift` — XP accumulation, multi-level-up, threshold growth
- `EnemyProjectilePoolTests.swift` — enemy projectile activation
- `ForestEssenceOrbTests.swift` — orb evolution through grown/red/Mist states
- `SpawnSystemTests.swift` — MiniBoss orb spawn, Boss spawn, Boss minions, wave escalation
- `CameraSystemTests.swift` — locked camera behavior

---

## ⚠️ Partial (file exists, core done, pieces missing)

| File | What's missing |
|------|---------------|
| `ShieldComponent.swift` | File kept, but active shield behavior is intentionally disabled because physics is currently unstable |
| `CollisionSystem.swift` | Shield push / enemy projectile destroy handlers exist only as disabled infrastructure until shield behavior is re-enabled |
| `MiniBossGnome.swift` / `BossGnome.swift` | Uses placeholder/missing final art assets for some enemy sprites |

---

## 🔴 Not Started — V1 Remaining

### Must be done in order (each blocks the next)

- _None currently active._
- Shield physics and shield collision handlers are intentionally held in **Partial** until the physics behavior is fixed.

### Independent (no blocking dependency, assign freely)

- **SmallGnome atlas** — art task
  - Replace `LuminousWisp` placeholder with actual `SmallGnome.spriteatlas`

---

## 🔵 V2 — Shared-Screen Multiplayer (not started)

- Up to 4 `GCController` slots in `InputSystem`
- Spawn/track up to 4 `PlayerEntity` in `GameScene`
- `CameraSystem` midpoint for 2–4 players
- Leash logic in `CameraSystem`
- `SkillCardOverlay` anchored to shield radius (world-space, not screen-space)
- Per-player HUD slots in `HUD.swift`
- `DirectorSystem.recordDamageTaken` aggregated across players
- Controller hot-plug decision

---

## 🟣 V3 — Environmental Strategy (not started)

- `SideQuestComponent.swift`
- Button + chest visuals
- Chest reward logic
- `SwarmGnome` spawn unit

---

## 🟡 V4 — Home Loop & Persistence (not started)

- `HomeScene.swift`
- `MetaProgressionScene.swift`
- `ForestEssenceStore.swift`
- `GameCenterManager.swift`
- `Achievements.swift`
- `LeaderboardUI.swift`
- `SceneManager.swift`
