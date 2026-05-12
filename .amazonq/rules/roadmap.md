# Gnome Apocalypse — Development Roadmap

Tasks are grouped by version phase. Within each phase, tasks are ordered by dependency — tasks that block others come first. Assign freely across your team based on current capacity.

---

## V1 — Technical MVP: The Infinite Greed

**Goal:** A working single-player loop on a toroidal map with WASD + mouse/trackpad input, auto-aim, Forest Essence evolution, gnome AI, skill selection, a live Director system, and a time-based Boss stage.

---

### Foundation (Do First — Everything Depends on These)

- [x] **Project setup**
  - Create macOS-only Xcode project, configure Swift strict concurrency, set up Git
  - Add GameController and GameKit framework references
  - Create folder structure per coding guidelines

- [x] **`GameConfig.swift`**
  - Populate all V1 tuning constants: speed, health, XP thresholds, shield timing, orb evolution timers
  - Include all Director constants: `directorPollInterval`, `directorRollingWindowDuration`, `directorMinBudget`, `directorMaxBudget`, `directorBudgetStep`, `directorPassiveStep`, `directorKillRateThreshold`, `directorDamageRateThreshold`
  - Include Boss stage constant: `bossSpawnInterval`
  - Include input constants: `autoAimIdleThreshold`, `stickDeadzone`

- [x] **`PhysicsCategory.swift`**
  - Define all bitmask constants for V1 entities (player, gnome, playerProjectile, gnomeProjectile, forestEssenceOrb, shield)

- [x] **`ToroidalMath.swift`**
  - `toroidalWrap(_:mapSize:)`
  - `toroidalOffset(from:to:mapSize:)`
  - `nearestToroidalTarget(from:to:mapSize:)`
  - Unit test all three functions at edge and corner positions

---

### World & Rendering

- [x] **`FloorTileRenderer.swift` + `MetalRenderer.swift`**
  - Implement `SKRenderer` with Metal-backed GPU instancing
  - Render infinite tiled floor that wraps seamlessly on camera movement
  - Validate 60 FPS on target Mac hardware (not just simulator)

- [~] **`GameScene.swift` — skeleton**
  - Set up scene with 3 z-layers (ground, environment, entities)
  - Integrate `SKCameraNode`, wire to `CameraSystem`
  - Implement main `update(deltaTime:)` dispatch loop — order: players → attacks → projectiles → enemies → AI
  - Own and update `DirectorSystem` each frame
  - ⚠️ `handleLevelUp`, `spawnBossMinions`, `spawnEnemyProjectile` are stubs — not yet implemented
  - ⚠️ Enemy projectile pool does not exist yet

---

### Camera

- [x] **`CameraSystem.swift`**
  - Track a list of player entities (list of one in V1)
  - Compute midpoint, apply to `SKCameraNode` each frame via `toroidalOffset` (shortest path)
  - Camera position is never hard-wrapped — drifts freely in world space to prevent visual snapping at boundaries
  - `cameraZoom` applied via `SKCameraNode.setScale(1/cameraZoom)` — viewport size computed dynamically from `mapSize / cameraZoom`
  - Design the interface to accept additional players with no structural change (readiness for V2)

---

### Input

- [x] **`InputSystem.swift`**
  - **Primary (V1 default):** Keyboard (WASD) for movement; mouse/trackpad cursor position converted to world-space aim vector
  - **Auto-aim:** If mouse/trackpad has not moved for `GameConfig.autoAimIdleThreshold`, resolve aim to nearest gnome via toroidal distance. Disengage immediately on any cursor movement
  - **Controller (secondary in V1, primary in V2):** Detect and register connected `GCController` instances; left stick = movement, right stick = aim; auto-aim engages when right stick magnitude < `GameConfig.stickDeadzone`
  - Handle controller connect/disconnect notifications at runtime
  - Expose `movementVector(for:)` and `aimVector(for:playerWorldPos:gnomes:)` as normalized `CGVector`
  - Expose `confirmPressed(for:)` for skill selection (mouse click or controller button)

---

### Player

- [x] **`HealthComponent.swift`**
  - `takeDamage`, `heal`, `isDead`, observer callback for death event

- [x] **`LevelComponent.swift`**
  - XP accumulation, threshold check, level-up event emission
  - Returns `Bool` from `addXP` to signal level-up to caller

- [x] **`ToroidalPositionComponent.swift`** — removed. Replaced by `CameraSystem.clampToroidal(_:)` which keeps entities within one map-width of the camera without hard-wrapping. All entities call this directly.

- [x] **`PlayerEntity.swift`**
  - Owns `HealthComponent`, `LevelComponent`, `ToroidalPositionComponent`
  - Movement from WASD (or left stick) via `InputSystem`
  - Aim direction from mouse/trackpad or right stick via `InputSystem`, stored as `aimDirection: CGVector`
  - Auto-fire at fixed rate in `aimDirection`
  - Calls `die()` on health zero, triggers `GameScene` game-over flow

- [x] **`PlayerAttack.swift`**
  - Auto-fire logic: timer-based, fires into `aimDirection`
  - Requests projectile from `ProjectilePool`

- [x] **First forest spirit character** (LuminousWisp)
  - Load animations from `LuminousWisp.spriteatlas`
  - Override `fireProjectile()` with character-specific pattern
  - Set `filteringMode = .nearest` on all atlas textures
  - Implement animation state machine (idle, walking, shooting)

---

### Projectiles

- [x] **`Projectile.swift`**
  - Direction, speed, damage, lifespan
  - Applies `ToroidalPositionComponent` for wrap
  - Returns to pool on contact or lifespan expiry

- [x] **`ProjectilePool.swift`**
  - Pre-allocate pool at scene start (size from `GameConfig`)
  - `dequeue()` and `enqueue()` interface
  - Never allocates during gameplay

---

### Forest Essence & Greed System

- [x] **`EssenceOrbComponent.swift`** (basic implementation)
  - Drops at enemy death position, collectable by player contact
  - Toroidal ghost rendering via `ToroidalRenderingComponent`
  - Position kept within one map-width of camera (no hard wrap)
  - Collection: player contact → add Essence to `LevelComponent`, cleanup ghosts, remove from scene
  - ⚠️ State machine (`small → grown → mistExplosion`) not yet implemented — orb is static

---

### Gnomes

- [x] **`EnemyEntity.swift`**
  - `HealthComponent`, toroidal position (camera-relative, no hard wrap)
  - `isTargetingActive` flag (false = ignore for AI targeting)
  - `budgetWeight: Int` computed property (default 1, overridden by subclasses)
  - `die()` → clears ghosts, drops Forest Essence orb, notifies `DirectorSystem`, deregisters from scene

- [x] **`EnemyAI.swift`**
  - Runs after enemies move and wrap each frame — ensures `targetPosition` is always computed from correct post-wrap positions
  - Filters dead players from target list
  - Output: sets `targetPosition` on each enemy toward shortest toroidal path

- [x] **`Grove.swift`**
  - Basic melee/contact gnome, low health, `budgetWeight = 1`
  - Load animations from `Grove.spriteatlas` when available

- [~] **`Grumble.swift`**
  - Spawned by Forest Essence Mist explosion
  - Ranged attack pattern, moderate health, `budgetWeight = 10`
  - Load animations from `Grumble.spriteatlas` when available
  - ⚠️ Ranged attack broken — depends on `GameScene.spawnEnemyProjectile` which is a stub

- [~] **`Grand.swift`**
  - Triggered by `DirectorSystem` on `GameConfig.bossSpawnInterval` timer — not by wave or budget logic
  - Multi-phase attack pattern, high health, no budget weight (exempt from Director budget)
  - May independently spawn mini gnomes as a Boss ability — those spawns are also budget-exempt
  - On Boss trigger: `SpawnSystem` pauses all regular gnome spawning; `CameraSystem` locks camera position; player leash tightens to enforce no escape from current view
  - Boss remains until killed — no time limit. Camera lock and spawn pause persist for the Boss's entire lifetime
  - On Boss death: camera lock releases, regular spawning resumes, Director recalibrates from current rolling window
  - Load animations from `Grand.spriteatlas` when available
  - ⚠️ `spawnBossMinions` delegates to `GameScene` which only logs a debug message — actual minion spawning is a stub

- [x] **Gnome spawn positioning rule**
  - All gnomes (regular and Mini-Boss) must spawn outside the current camera view bounds
  - `SpawnSystem` must query `CameraSystem` for the visible rect before choosing a spawn position and reject any position that falls within it

---

### Director System

- [x] **`DirectorSystem.swift`**
  - Maintain a rolling window circular buffer of kill timestamps and damage events (window duration from `GameConfig.directorRollingWindowDuration`)
  - `recordKill()` — appends timestamp to kill buffer
  - `recordDamageTaken(_ amount: Int)` — appends damage event to damage buffer
  - `update(deltaTime:, activeBudgetUsed:)` — advances internal timer, fires `evaluateAndAdjust()` every `GameConfig.directorPollInterval`; advances Boss stage timer
  - `evaluateAndAdjust()` — computes kill/sec and damage/sec from rolling window, applies budget adjustment per the rules below
  - `currentBudget: Int` — read-only, queried by `SpawnSystem` each frame
  - `isBossStageActive: Bool` — read-only; true while a Boss is alive; `SpawnSystem` pauses regular spawning when true

  **Adjustment logic inside `evaluateAndAdjust()`:**
  - High kill rate + low damage rate → `currentBudget += directorBudgetStep`
  - Low kill rate + high damage rate → `currentBudget -= directorBudgetStep`
  - Low kill rate + low damage rate → `currentBudget += directorPassiveStep`
  - High kill rate + high damage rate → no change
  - Floor clamp: `currentBudget = max(directorMinBudget, currentBudget)`
  - Soft ceiling: if `currentBudget` is within one step of `directorMaxBudget`, halve the upward step; never exceed `directorMaxBudget`

  **Boss stage logic:**
  - Internal `timeSinceLastBoss` accumulator increments each `update()` call
  - When `timeSinceLastBoss >= GameConfig.bossSpawnInterval`, set `isBossStageActive = true`, notify `SpawnSystem` and `CameraSystem`, reset accumulator
  - `isBossStageActive` is set back to false only when `SpawnSystem` reports Boss death via `recordBossDeath()`

  **Notes for implementation:**
  - "High" kill rate = kills/sec > `GameConfig.directorKillRateThreshold`
  - "High" damage rate = damage/sec > `GameConfig.directorDamageRateThreshold`
  - Budget changes are additive steps per poll — not instant snaps to a target value
  - Expect this system to require multiple tuning passes during playtesting. All constants are in `GameConfig`; do not hardcode any threshold or step value

---

### Spawn System

- [x] **`SpawnSystem.swift`**
  - Before every spawn decision, read `DirectorSystem.currentBudget`
  - Only spawn if budget allows
  - All gnome spawn positions fall outside current camera view rect
  - Tracks `ForestEssenceOrb` instances, updates their toroidal position each frame
  - `removeOrb(_:)` cleans up ghosts before removing orb from scene
  - ⚠️ `spawnForestEssenceOrb` spawns a basic colored orb — full `EssenceOrbComponent` state machine not yet wired
  - [ ] Wave-based gnome spawning with escalating difficulty (wave parameters in `GameConfig`)
  - [ ] Forest Essence orb drop logic — orb evolution state machine (`small → grown → mistExplosion`)
  - [ ] MiniBoss spawn request from `EssenceOrbComponent` Mist explosion — subject to budget check; spawns outside camera
  - [ ] Boss stage: when `DirectorSystem.isBossStageActive` becomes true, pause regular spawning and trigger `Grand` spawn outside budget
  - [ ] On Boss death: call `DirectorSystem.recordBossDeath()` to end Boss stage
  - [ ] Pass `activeBudgetUsed` to `DirectorSystem.update()` each frame

---

### Skill System

- [x] **`SkillSystem.swift`**
  - Define V1 skill pool (minimum 9 skills to guarantee 3 non-duplicate draws)
  - `draw(excluding:)` → returns 3 unique `Skill` values
  - Seeded random for reproducibility

- [ ] **`ShieldComponent.swift`**
  - Triggered by `LevelComponent` level-up event
  - Freeze player movement
  - Expand `SKShapeNode` radius over `GameConfig.shieldExpandDuration`
  - Apply physics impulse to all entities within radius each frame during expansion
  - Set `isTargetingActive = false` on owning player for AI
  - On skill selection: burst knockback pulse, then remove shield, restore movement and AI targeting

- [ ] **`SkillCardOverlay.swift`**
  - Full-screen pause overlay (solo V1)
  - Renders 3 skill cards: large icon + short name
  - Navigable via controller confirm, dismiss on selection
  - Calls `PlayerEntity.applySkill()` with selected skill

---

### Collision

- [x] **`CollisionSystem.swift`**
  - Implement `SKPhysicsContactDelegate`
  - Route all contact pairs to correct handlers using `PhysicsCategory` bitmasks
  - Handlers: player takes damage, gnome takes damage, Forest Essence collect
  - Ghost node hits redirect damage to real entity via `userData["ghostOf"]`
  - On gnome death: call `DirectorSystem.recordKill()`
  - On player damage: call `DirectorSystem.recordDamageTaken(_ amount:)`
  - ⚠️ Shield push and shield destroys enemy projectile handlers are missing

---

### HUD & Polish

- [ ] **`HUD.swift` (V1 single-player)**
  - Health bar, current level, Essence progress
  - Positioned in screen-space (child of camera node)

- [ ] **`AudioManager.swift`**
  - Load and play: background music, hit SFX, death SFX, level-up SFX, Essence collect SFX, Mist explosion SFX, Boss appear SFX

- [ ] **`ParticleAssets.swift`**
  - Pre-load all `SKEmitterNode` assets at scene start
  - Effects needed for V1: Essence collect, gnome death (purification), shield expand, shield burst, Mist explosion
  - Load particle textures from dedicated `Effects.spriteatlas` if using custom particles

- [ ] **Placeholder home screen**
  - Single "Start Game" button, no meta-progression yet
  - Sufficient to launch into `GameScene`

---

## V2 — Shared-Screen Multiplayer

**Goal:** Up to 4 players on one screen with correct camera, leashing, and per-player skill UI.

- [ ] Extend `InputSystem` to manage up to 4 simultaneous `GCController` slots as the primary input method for all multiplayer players
- [ ] Extend `GameScene` to spawn and track up to 4 `PlayerEntity` instances
- [ ] Update `CameraSystem` midpoint calculation for 2–4 players
- [ ] Implement **leash logic** in `CameraSystem`: prevent any player from crossing a world boundary until all players are within leash distance of the boundary edge. When triggered, wrap all players simultaneously
- [ ] Update `SkillCardOverlay.swift` for multiplayer:
  - Remove full-screen pause behavior
  - Anchor card overlay inside player's shield radius (world-space, not screen-space)
  - Each leveling player gets independent 3-card draw
  - Simultaneous level-ups: independent shield radii, push each other apart
- [ ] Update `HUD.swift`: add per-player HUD slots (4 slots across top of screen, each tied to a controller index)
- [ ] Update `DirectorSystem` metrics to aggregate across all active players:
  - `recordDamageTaken` must accept a `playerIndex` — sum damage across all players for rate calculation
  - Kill rate remains global (any player purification counts)
- [ ] Validate `EnemyAI` multi-target logic: AI must target nearest player, re-evaluate each frame as positions change
- [ ] Confirm `ShieldComponent` interaction with other player entities (push, cover from projectiles)
- [ ] Controller hot-plug: decide before implementing whether players join on first input mid-game or only in a pre-game lobby

---

## V3 — Environmental Strategy: The Side Quest Loop

**Goal:** Add the button-and-chest side quest event to Layer 2 of the game world. Add Swarm enemy type.

- [ ] **`SideQuestComponent.swift`**
  - Triggered by a game event or timer defined in `GameConfig`
  - Spawn N proximity buttons scattered at random toroidal map positions (N from `GameConfig`)
  - Per-button state: inactive / active
  - Activation: any player within proximity radius for X seconds (duration from `GameConfig`)
  - On all buttons active: notify `SpawnSystem` to spawn chest at random position
  - Global quest timer: if timer expires before all buttons activated or chest collected, despawn all buttons and chest — no reward
  - On quest conclusion (reward or timeout): reset, wait for next trigger
  - Enemies have zero interaction with buttons — no collision, no blocking, no deactivation

- [ ] **Button and chest visuals**
  - Button: `SKSpriteNode` with inactive/active states
  - Chest: `SKSpriteNode` with open animation on collection
  - Proximity indicator: subtle radius ring around button that fills as player approaches

- [ ] **Chest reward logic**
  - On collection: call `SkillSystem.draw(excluding:)` for a guaranteed rare skill, or award Forest Essence (V4 currency, store locally for now)
  - Display reward using existing `SkillCardOverlay` flow

- [ ] Add `sideQuestButton` bitmask to `PhysicsCategory` for proximity detection
- [ ] Add Layer 2 node group to `GameScene` for all environment objects
- [ ] Validate toroidal button positions — ensure buttons near map boundary edges remain visually and physically consistent

- [ ] **`SwarmGnome` (V3 spawn unit)**
  - Spawns as a group of ~20 `Grove` instances
  - Treated as a single Director budget unit costing 20
  - `SpawnSystem` handles the group spawn; individual `Grove` entities behave independently after spawn
  - All spawn positions must still fall outside the current camera view
  - Add `swarmBudgetWeight` constant to `GameConfig`

---

## V4 — Home Loop & Persistence

**Goal:** Full game loop with home menu, meta-progression, and Game Center.

- [ ] **`HomeScene.swift`**
  - Standard macOS menu navigation (mouse/trackpad + controller)
  - Options: Start Game, Upgrades, Leaderboard, Achievements

- [ ] **`MetaProgressionScene.swift`**
  - Display available upgrades: Speed, Luck, Health (expandable)
  - Show current Forest Essence balance
  - Spend Essence to increment upgrade levels
  - Cap per upgrade defined in `GameConfig`

- [ ] **`ForestEssenceStore.swift`**
  - Read/write Forest Essence and upgrade levels using `GKSavedGame` (Game Center cloud save)
  - Local fallback using `UserDefaults` if Game Center unavailable

- [ ] **`GameCenterManager.swift`**
  - Authenticate local player on app launch
  - Submit score on run end (Survival Score and Greed Score as separate leaderboards)
  - Report achievements on trigger events (first Boss purified, first Mist explosion, first max evolved orb collected, etc.)

- [ ] **`Achievements.swift`**
  - Define all achievement IDs as constants
  - Define unlock conditions as closures or event-based triggers hooked into `GameScene`

- [ ] **`LeaderboardUI.swift`**
  - Fetch and display top entries from Game Center
  - Show local player rank if not in top N

- [ ] Apply purchased upgrades in `PlayerEntity` initialization — read from `GreedEssenceStore` at scene start, apply stat modifiers before first frame

- [ ] **SceneManager transitions**
  - Home → Game (fade out/in)
  - Game over → Essence award screen → Home
  - All transitions handled by `SceneManager.swift`

---

## Cross-Version Tasks (Ongoing)

- [ ] Maintain `GameConfig.swift` as the single source of truth for all tuning values — no magic numbers ever enter entity or system files. This includes all Director thresholds and steps
- [ ] Run on physical Mac hardware at each phase milestone. Simulator does not represent GPU load or controller latency accurately
- [ ] Profile with Instruments (Metal System Trace, Time Profiler) before marking any version complete
- [ ] Keep `Log.swift` wrapper updated — all debug output goes through it, silent in release builds
- [ ] Playtest Director tuning each milestone. The Director is the most subjective system in the game — budget step sizes, poll interval, and rate thresholds will all need adjustment based on real play feel, not estimates
- [ ] Update `project-context.md` if any design decision changes during implementation