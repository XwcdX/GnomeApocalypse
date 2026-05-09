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
- `ForestEssenceOrb.swift` — drops on enemy death, ghost rendering, collection via `CollisionSystem`, cleanup on collect

### Entities
- `PlayerEntity.swift` — movement, `clampToroidal`, ghost rendering, `takeDamage`, `addXP`, `applySkill`, skill properties
- `PlayerAttack.swift` — timer-based auto-fire, `isShooting` flag for animation
- `LuminousWisp.swift` — full 8-direction animation, aim-priority facing, shoot/walk/idle states
- `EnemyEntity.swift` — movement toward target, `clampToroidal`, ghost rendering, `die()` with ghost cleanup
- `EnemyAI.swift` — nearest toroidal target, runs post-wrap each frame
- `SmallGnome.swift` — `LuminousWisp` atlas placeholder, mirror animation, `GameConfig` constants
- `MiniBossGnome.swift` — ranged attack stub (fires via `spawnEnemyProjectile` which is a stub)
- `BossGnome.swift` — two-phase ability, minion spawn stub, `handleBossDeath` on die
- `Projectile.swift` — velocity movement, `clampToroidal`, ghost rendering, lifespan, animation
- `ProjectilePool.swift` — pre-allocated pool, `dequeue/enqueue`, `attachAll`

### Systems
- `DirectorSystem.swift` — rolling window, kill/damage rate, budget adjustment, Boss stage timer
- `SkillSystem.swift` — 6-skill pool, unified draw, pool caps, `maxLevel3Items` cap, `PlayerSkillState`
- `SpawnSystem.swift` — budget-gated spawning, outside-camera positions, orb tracking + cleanup
- `CollisionSystem.swift` — projectile→enemy, projectile→player, orb→player, ghost redirect

### Tests
- `ToroidalMathTest.swift` — `toroidalOffset`, `nearestToroidalTarget`, `toroidalDistance`
- `HealthComponentTests.swift` — all boundary conditions
- `LevelComponentTests.swift` — XP accumulation, multi-level-up, threshold growth

---

## ⚠️ Partial (file exists, core done, pieces missing)

| File | What's missing |
|------|---------------|
| `GameScene.swift` | `handleLevelUp` is a stub, `spawnBossMinions` is a stub, `spawnEnemyProjectile` is a stub, no enemy projectile pool |
| `ForestEssenceOrb.swift` | State machine (`small → grown → mistExplosion`) not implemented — orb is static |
| `MiniBossGnome.swift` | Ranged attack calls `spawnEnemyProjectile` stub — does nothing |
| `BossGnome.swift` | `spawnBossMinions` calls `GameScene` stub — minions never spawn |
| `SpawnSystem.swift` | No wave escalation, no orb state machine wiring, no MiniBoss spawn from orb, no Boss stage trigger, `activeBudgetUsed` not passed to Director |

---

## 🔴 Not Started — V1 Remaining

### Must be done in order (each blocks the next)

1. **Enemy projectile pool** — `GameScene.setupSystems`
   - Add a second `ProjectilePool` for enemy projectiles
   - Implement `spawnEnemyProjectile(at:direction:damage:)` in `GameScene`
   - Unblocks: `MiniBossGnome` ranged attack

2. **`ForestEssenceOrb` state machine** — `ForestEssenceOrb.swift`
   - `small → grown` after `GameConfig.orbEvolveTime`
   - `grown → mistExplosion` after `GameConfig.grownOrbEvolveTime`
   - `mistExplosion`: VFX placeholder, notify `SpawnSystem` to spawn `MiniBossGnome`
   - Unblocks: Greed system, MiniBoss natural spawn

3. **`SpawnSystem` — remaining items**
   - Wire orb state machine: `ForestEssenceOrb` notifies `SpawnSystem` on `mistExplosion`
   - MiniBoss spawn from orb explosion (budget-checked, outside camera)
   - Boss stage: when `isBossStageActive`, pause regular spawning, spawn `BossGnome`
   - On Boss death: call `DirectorSystem.recordBossDeath()`
   - Pass `activeBudgetUsed` to `DirectorSystem.update()` each frame

4. **`ShieldComponent.swift`** — new file
   - Triggered by level-up
   - Freeze player, expand `SKShapeNode` radius
   - Physics impulse to entities in radius
   - `isTargetingActive = false` on player during expansion
   - Burst knockback on skill select, then dissolve
   - Unblocks: `SkillCardOverlay`

5. **`SkillCardOverlay.swift`** — new file
   - Full-screen pause (solo V1)
   - 3 skill cards: icon + name
   - Mouse click or controller confirm to select
   - Calls `PlayerEntity.applySkill(_:)`
   - Wire `GameScene.handleLevelUp` to trigger this

6. **`CollisionSystem` — shield handlers**
   - Shield pushes enemies (physics impulse)
   - Shield destroys enemy projectiles

7. **`GameScene` — Boss stage**
   - `spawnBossMinions(count:around:)` — actual implementation using enemy projectile pool + `SpawnSystem`
   - Camera lock when `isBossStageActive`

### Independent (no blocking dependency, assign freely)

- **`HUD.swift`** — new file
  - Health bar (fill based on `health.fraction`)
  - Current level label
  - XP/Essence progress bar
  - Anchored to camera node (screen-space)
  - Reads from `PlayerEntity` each frame

- **`AudioManager.swift`** — new file
  - Background music loop
  - SFX: hit, death, level-up, orb collect, Mist explosion, Boss appear
  - AVFoundation, preloaded at scene start

- **`ParticleAssets.swift`** — new file
  - Preload all `SKEmitterNode` at scene start
  - Effects: orb collect, gnome death, shield expand, shield burst, Mist explosion

- **Placeholder home screen** — `GameScene` or new `HomeScene`
  - Single "Start Game" button
  - Launches into `GameScene`

- **Wave escalation in `SpawnSystem`**
  - Escalating spawn interval / gnome count over time
  - Parameters in `GameConfig`

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
