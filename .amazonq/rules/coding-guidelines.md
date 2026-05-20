# Gnome Apocalypse — Coding Guidelines

## Language & Platform

- **Language:** Swift (only). No Objective-C, no bridging headers, no third-party packages.
- **Platform:** macOS exclusive. No iOS, tvOS, or multi-platform targets.
- **Frameworks:** SpriteKit, Metal (via `SKRenderer`), GameController, Game Center (GameKit).
- **Swift version:** Latest stable. Enable strict concurrency checking from V1.
- **Architecture:** Protocol-oriented where shared behavior is needed. Inheritance only for SpriteKit node subclasses. No MVVM unless a scene's UI complexity explicitly demands it.

---

## Project Folder Structure

```
Challenge2/                             # Xcode project root
├── Greed/                              # Main app target
│   ├── Entities/
│   │   ├── Player/
│   │   │   ├── PlayerEntity.swift          # Base player class (movement, health, level, death)
│   │   │   ├── PlayerAttack.swift          # Base auto-fire + manual aim logic
│   │   │   └── Characters/
│   │   │       └── [CharacterName].swift   # Subclass per character, overrides attack behavior
│   │   ├── Enemy/
│   │   │   ├── EnemyEntity.swift           # Base gnome class (health, targeting, death)
│   │   │   ├── EnemyAI.swift               # Toroidal shortest-path pathfinding
│   │   │   └── Types/
│   │   │       ├── Grove.swift
│   │   │       ├── Grumble.swift
│   │   │       └── Grand.swift
│   │   └── Projectile/
│   │       ├── Projectile.swift            # Base projectile (direction, speed, damage, lifespan)
│   │       └── ProjectilePool.swift        # Object pool for performance
│   ├── Components/
│   │   ├── HealthComponent.swift           # Shared by Player and Enemy
│   │   ├── LevelComponent.swift            # XP tracking, level-up trigger, skill unlock
│   │   ├── ToroidalRenderingComponent.swift # Ghost node rendering for toroidal boundary visibility
│   │   ├── AnimationComponent.swift        # Directional animation handler with atlas loading and optional mirroring
│   │   ├── ShieldComponent.swift           # Level-up shield radius expansion and collision
│   │   ├── EssenceOrbComponent.swift       # Forest Essence orb entity + evolution state machine (small → grown → MistExplosion → Grumble)
│   │   └── SideQuestComponent.swift        # Button proximity detection, chest spawn trigger (V3)
│   ├── Scenes/
│   │   ├── GameScene.swift                 # Primary game loop scene, owns update cycle
│   │   ├── GameScene.sks                   # SpriteKit scene file
│   │   ├── HomeScene.swift                 # (V4) Focus-driven main menu
│   │   ├── MetaProgressionScene.swift      # (V4) Upgrade shop scene
│   │   └── SceneManager.swift              # Transition logic, fade in/out, scene lifecycle
│   ├── Systems/
│   │   ├── CameraSystem.swift              # Midpoint camera, player list tracking, leash logic
│   │   ├── InputSystem.swift               # WASD + mouse/trackpad (primary), GameController framework (secondary); maps input to actions
│   │   ├── CollisionSystem.swift           # Physics bitmask definitions, collision handler routing
│   │   ├── SpawnSystem.swift               # Gnome wave logic, Forest Essence orb spawning, side quest button placement
│   │   ├── SkillSystem.swift               # Skill pool, randomized 3-card draw, skill application
│   │   └── DirectorSystem.swift            # Dynamic difficulty: monitors kill rate + damage taken rate, adjusts gnome budget; manages time-based Boss stage
│   ├── UI/
│   │   ├── HUD.swift                       # Per-player HUD slots (health, level, essence meter)
│   │   ├── SkillCardOverlay.swift          # 3-card skill selection UI anchored inside shield radius
│   │   └── LeaderboardUI.swift             # (V4) Game Center leaderboard display
│   ├── GameCenter/
│   │   ├── GameCenterManager.swift         # Auth, leaderboard submission, achievement reporting
│   │   └── Achievements.swift              # Achievement ID constants and unlock conditions
│   ├── Persistence/
│   │   └── ForestEssenceStore.swift        # (V4) Read/write Forest Essence via GameKit saved games
│   ├── Rendering/
│   │   ├── MetalRenderer.swift             # SKRenderer + Metal integration for GPU instancing
│   │   ├── FloorTileRenderer.swift         # Infinite toroidal floor tile rendering
│   │   └── ParticleAssets.swift            # SKEmitterNode references (Essence collect, death, shield burst, Mist explosion)
│   ├── Utilities/
│   │   ├── ToroidalMath.swift              # Vector wrap, toroidal distance, 9-sector evaluation
│   │   ├── PhysicsCategory.swift           # UInt32 bitmask constants for all collision categories
│   │   └── Extensions.swift                # CGPoint, CGVector, SKNode convenience extensions
│   ├── Audio/
│   │   └── AudioManager.swift              # Sound effect and music playback (AVFoundation)
│   ├── Config/
│   │   ├── GameConfig.swift                # System-level tuning: map, player, camera, input, director, spawn, gnome stats
│   │   └── SkillConfig.swift               # Skill and power-up tuning: Warden Thorns, lightning, mist, power-ups
│   ├── Assets.xcassets/                    # All sprites, textures, icons
│   ├── GameData.swift                      # Transient run state (current score, active players, run seed)
│   ├── GameManager.swift                   # App entry, bootstraps scene, owns top-level state machine
│   └── AppDelegate.swift
│
├── GreedTests/                             # Unit & integration test target — Swift Testing only
│   ├── Utilities/
│   │   └── ToroidalMathTests.swift
│   ├── Systems/
│   │   ├── DirectorSystemTests.swift
│   │   └── SkillSystemTests.swift
│   ├── Components/
│   │   ├── HealthComponentTests.swift
│   │   ├── LevelComponentTests.swift
│   │   └── EssenceOrbComponentTests.swift
│   └── Entities/
│       └── ProjectilePoolTests.swift
│
└── GreedUITests/                  # UI test target — XCUITest only
    ├── GameLaunch/
    │   └── GameLaunchUITests.swift         # App launch, reaches game screen
    ├── HUD/
    │   └── HUDUITests.swift                # HUD elements present and accessible
    ├── SkillCard/
    │   └── SkillCardUITests.swift          # Skill overlay appears and dismisses
    └── GreedUITestsLaunchTests.swift  # Baseline screenshot capture — do not remove
```

---

## File Splitting Rules

> **Rule:** If a file is only ever imported by one other file, merge them. If a file is imported by two or more, keep it separate.

Examples:
- `ToroidalMath.swift` is used by `EnemyAI`, `ToroidalPositionComponent`, `CameraSystem`, and `FloorTileRenderer` → **separate file, correct**
- A hypothetical `BossSpawnTrigger.swift` used only by `SpawnSystem` → **merge into SpawnSystem**
- `PhysicsCategory.swift` is referenced by every entity and the collision system → **separate file, correct**
- `DirectorSystem.swift` is read by `SpawnSystem` and `GameScene` → **separate file, correct**

---

## Entity Architecture

### Player

`PlayerEntity` is a **class** subclassing `SKSpriteNode`. It owns its components directly as stored properties (not an ECS registry — overkill for this scale).

```swift
class PlayerEntity: SKSpriteNode {
    let health: HealthComponent
    let level: LevelComponent
    let position: ToroidalPositionComponent
    var controllerIndex: Int?              // nil = keyboard/mouse player; set when a GCController is assigned
    var aimDirection: CGVector = .zero     // updated each frame from mouse/trackpad or right stick

    func update(deltaTime: TimeInterval) { }  // called by GameScene update loop
    func die() { }                            // triggers death animation, notifies GameScene
    func applySkill(_ skill: Skill) { }       // called by SkillSystem after selection
}
```

Each character is a **subclass of PlayerEntity** and overrides only what differs — typically the base attack behavior and visual assets.

```swift
class WarriorCharacter: PlayerEntity {
    override func fireProjectile() {
        // character-specific attack pattern
    }
}
```

### Enemy

`EnemyEntity` is a **class** subclassing `SKSpriteNode`. Specific enemy types subclass it.

```swift
class EnemyEntity: SKSpriteNode {
    let health: HealthComponent
    var targetPosition: CGPoint = .zero       // updated each frame by EnemyAI
    var isTargetingActive: Bool = true        // set to false during a player's shield state
    var budgetWeight: Int { 1 }               // overridden by subclasses, used by DirectorSystem

    func update(deltaTime: TimeInterval) { }
    func die() { }
}

class Grove: EnemyEntity {
    override var budgetWeight: Int { 1 }
}
class Grumble: EnemyEntity {
    override var budgetWeight: Int { 10 }
}
class Grand: EnemyEntity {
    // Operates outside the Director budget — triggered by time interval, not budget logic
    // May spawn its own mini gnomes independently; those spawns are also budget-exempt
}
```

### Shared Components

Components are **structs** where state is simple and value semantics are fine. Use **classes** only when the component holds a reference to a node or needs shared mutation.

```swift
struct HealthComponent {
    var current: Int
    var maximum: Int
    mutating func takeDamage(_ amount: Int) { }
    var isDead: Bool { current <= 0 }
}

struct LevelComponent {
    var currentXP: Int
    var currentLevel: Int
    var xpThreshold: Int
    mutating func addXP(_ amount: Int) -> Bool  // returns true if leveled up
}
```

---

## Director System

`DirectorSystem.swift` is a standalone system owned by `GameScene`. It does not spawn enemies directly — it exposes a read-only `currentBudget: Int` that `SpawnSystem` queries each frame before any spawn decision.

```swift
class DirectorSystem {
    private(set) var currentBudget: Int

    // Called by GameScene every frame with current live enemy budget consumption
    func update(deltaTime: TimeInterval, activeBudgetUsed: Int)

    // Called by CollisionSystem or EnemyEntity.die() on every kill
    func recordKill()

    // Called by CollisionSystem on every player damage event
    func recordDamageTaken(_ amount: Int)

    // Internal — fires every GameConfig.directorPollInterval seconds
    private func evaluateAndAdjust()
}
```

**Rolling window:** The Director maintains a fixed-duration circular buffer of kill events and damage events. On each poll it computes kill/sec and damage/sec from the buffer only — older events outside the window are discarded. This prevents early-run data from distorting mid-run difficulty.

**Budget adjustment rules (evaluated each poll):**

| Kill Rate | Damage Rate | Action |
|---|---|---|
| High | Low | Step budget up by `directorBudgetStep` |
| Low | High | Step budget down by `directorBudgetStep` |
| Low | Low | Step budget up by `directorPassiveStep` (smaller — gentle pressure) |
| High | High | Hold. Do not change budget. |

"High" and "low" thresholds are defined in `GameConfig` as `directorKillRateThreshold` and `directorDamageRateThreshold`.

**Hard bounds:** Budget never goes below `GameConfig.directorMinBudget`. The ceiling `GameConfig.directorMaxBudget` is a soft target — the Director slows its upward steps as it approaches the cap rather than hard-clamping, keeping the difficulty curve smooth.

---

## Toroidal Rendering (Ghost Nodes)

Entities near map boundaries must be visible from the opposite side. `ToroidalRenderingComponent` handles this by creating temporary "ghost" copies at wrapped positions.

### How It Works

```swift
final class ToroidalRenderingComponent {
    func update(cameraPosition: CGPoint, viewportSize: CGSize) {
        // Find the wrapped copy of the entity closest to the camera center
        // Check its 8 neighbours for visibility in the camera viewport
        // Create ghost SKSpriteNode copies at any visible wrapped positions
    }
}
```

**Entity position strategy — no hard wrap:**
Entities are NOT wrapped to `[-mapSize/2, +mapSize/2]` every frame. Instead, each entity keeps its position within one map-width of the camera. This prevents the one-frame visual snap that occurs when a position jumps by `mapSize`. The camera also never wraps — it drifts freely in world space following the player via `toroidalOffset`.

```swift
// Applied in PlayerEntity, EnemyEntity, ForestEssenceOrb each frame:
let hw = GameConfig.mapSize.width / 2
let hh = GameConfig.mapSize.height / 2
if position.x - camPos.x >  hw { position.x -= GameConfig.mapSize.width }
if position.x - camPos.x < -hw { position.x += GameConfig.mapSize.width }
if position.y - camPos.y >  hh { position.y -= GameConfig.mapSize.height }
if position.y - camPos.y < -hh { position.y += GameConfig.mapSize.height }
```

**Ghost node visibility** uses the camera's absolute (unwrapped) position. The ghost renderer finds the nearest wrapped copy of the entity relative to the camera, then checks its 8 neighbours — this handles the camera drifting outside `[-mapSize/2, +mapSize/2]` correctly.

**Ghost nodes are:**
- Visual copies only - texture, size, position, alpha, scale
- Named `"ghost"` for identification
- Have physics bodies copied from owner with `isDynamic = false` and `collisionBitMask = none`
- Store reference to real entity in `userData["ghostOf"]`
- Recreated every frame (cleared and rebuilt)

### Collision Handling

Ghost nodes can be hit by projectiles. `CollisionSystem` redirects damage to the real entity:

```swift
private func handlePlayerProjectileHitsEnemy(_ contact: SKPhysicsContact) {
    var enemyNode = (contact.bodyA.node as? EnemyEntity) ?? (contact.bodyB.node as? EnemyEntity)
    
    // Check if hit a ghost instead
    if enemyNode == nil {
        let ghostNode = contact.bodyA.node?.name == "ghost" ? contact.bodyA.node : contact.bodyB.node
        if let realEnemy = ghostNode?.userData["ghostOf"] as? EnemyEntity {
            enemyNode = realEnemy  // Redirect to real entity
        }
    }
    
    guard let enemy = enemyNode else { return }
    enemy.health.takeDamage(projectile.damage)  // Only real entity takes damage once
}
```

**Critical:** Ghost nodes do NOT:
- Count toward Director budget (only real entity counts)
- Have their own health/stats (damage redirects to real entity)
- Run update loops (only real entity updates)
- Trigger multiple death events (only real entity can die)

**Why this works:**
- Ghost physics bodies are non-dynamic (don't move)
- Ghosts have no collision (only contact detection)
- `userData["ghostOf"]` ensures damage applies to real entity exactly once
- Ghosts are cleared every frame before recreation (no accumulation)

---

## Toroidal Math (Critical System)

All spatial logic involving wrap must go through `ToroidalMath.swift`. Never compute wrapped positions inline in entity or scene code.

```swift
// Find shortest toroidal distance vector from a to b
func toroidalOffset(from a: CGPoint, to b: CGPoint, mapSize: CGSize) -> CGVector

// Evaluate all 9 sectors and return the closest target position
func nearestToroidalTarget(from origin: CGPoint, to target: CGPoint, mapSize: CGSize) -> CGPoint
```

**Note:** Entities never call `toroidalWrap` directly. Position clamping is handled by `CameraSystem.clampToroidal(_:)` which keeps each entity within one map-width of the camera — no hard snap, no visual pop.

---

## Physics Bitmasks

All bitmask constants live in `PhysicsCategory.swift`. Never hardcode bitmask values anywhere else.

```swift
struct PhysicsCategory {
    static let none:            UInt32 = 0
    static let player:          UInt32 = 0b00000001   // 1
    static let enemy:           UInt32 = 0b00000010   // 2
    static let playerProjectile:UInt32 = 0b00000100   // 4
    static let enemyProjectile: UInt32 = 0b00001000   // 8
    static let xpOrb:           UInt32 = 0b00010000   // 16
    static let shield:          UInt32 = 0b00100000   // 32
    static let sideQuestButton: UInt32 = 0b01000000   // 64
}
```

Collision matrix intent:
- `playerProjectile` contacts `enemy` → damage enemy
- `enemyProjectile` contacts `player` → damage player (shield blocks this)
- `player` contacts `xpOrb` → collect
- `shield` contacts `enemy` → push enemy (physics impulse)
- `shield` contacts `player` (other players) → push player (physics impulse)
- `shield` contacts `enemyProjectile` → destroy projectile
- `sideQuestButton` contacts `player` → begin proximity activation timer (V3)
- Enemies have no collision interaction with `sideQuestButton`

---

## Input System

All input is handled in `InputSystem.swift`. GameScene never reads `GCController` or keyboard/mouse events directly.

Primary input (V1 default — keyboard + mouse/trackpad):
- **WASD** → movement
- **Mouse/trackpad cursor position** → aim direction (converted to world-space vector from player position)
- **Auto-aim** → if the mouse/trackpad has not moved for a threshold duration (`GameConfig.autoAimIdleThreshold`), `InputSystem` resolves aim direction to the nearest gnome using toroidal distance. Auto-aim disengages immediately on any mouse/trackpad movement.

Controller input (supported in V1 as secondary, primary in V2 for multiplayer):
- **Left stick** → movement
- **Right stick** → aim direction
- Auto-aim same rule applies: if right stick magnitude is below `GameConfig.stickDeadzone`, aim resolves to nearest gnome

```swift
class InputSystem {
    private var controllers: [GCController] = []

    func setup()                                           // register connect/disconnect notifications; also begin keyboard/mouse event monitoring
    func movementVector(for playerIndex: Int) -> CGVector  // WASD or left stick, normalized
    func aimVector(for playerIndex: Int, playerWorldPos: CGPoint, gnomes: [EnemyEntity]) -> CGVector  // mouse/trackpad or right stick; auto-aims if idle
    func confirmPressed(for playerIndex: Int) -> Bool      // skill selection confirm (mouse click or controller button)
}
```

Supports: keyboard + mouse/trackpad (macOS native), Xbox, PlayStation (DualShock/DualSense), MFi controllers on macOS.

---

## Skill System

Skills are value types. The pool is defined statically in `SkillSystem`. No skill has side effects outside of `PlayerEntity.applySkill()`.

```swift
enum SkillEffect {
    case increaseFireRate(multiplier: Float)
    case addProjectile(count: Int)
    case increaseSpeed(multiplier: Float)
    case addHealthRegen(perSecond: Int)
    case expandShieldDuration(seconds: TimeInterval)
    // extend freely
}

struct Skill {
    let id: String
    let name: String          // max 3 words
    let iconName: String      // asset catalog name
    let effect: SkillEffect
}
```

`SkillSystem.draw()` returns 3 non-duplicate skills from the pool at random, seeded by run seed for reproducibility.

---

## Forest Essence Orb Evolution State Machine

Managed inside `EssenceOrbComponent.swift`. The orb is a self-contained entity that runs its own timer.

```swift
enum OrbState {
    case small          // base drop, small visual
    case grown          // larger visual, larger hitbox, more Essence value
    case mistExplosion  // triggers Grumble spawn at orb position via Mist burst VFX, orb is consumed
}
```

Evolution timer thresholds are read from `GameConfig.swift`, not hardcoded.

---

## Asset Management

**All visual assets use SKTextureAtlas, never individual SKTexture files.**

### Why Texture Atlases

- GPU batching: Multiple sprites from the same atlas render in a single draw call
- Memory efficiency: Atlas textures are loaded once and shared
- Cache coherency: Related frames stored contiguously in GPU memory
- Automatic optimization: Xcode packs atlases at build time

### Atlas Structure

```
Assets.xcassets/
├── CharacterName.spriteatlas/
│   ├── walk_000.imageset/
│   ├── walk_001.imageset/
│   ├── attack_000.imageset/
│   └── Contents.json
├── EnemyName.spriteatlas/
│   ├── idle_000.imageset/
│   └── Contents.json
└── Effects.spriteatlas/
    ├── explosion_000.imageset/
    └── Contents.json
```

### Loading Atlases

```swift
let atlas = SKTextureAtlas(named: "LuminousWisp")
let walkFrames = (0...7).map { atlas.textureNamed("walk_\(String(format: "%03d", $0))") }
walkFrames.forEach { $0.filteringMode = .nearest }
```

### AnimationComponent

For characters with directional animations, use `AnimationComponent` to handle atlas loading and direction switching:

```swift
final class LuminousWisp: PlayerEntity {
    private var animator: AnimationComponent!
    
    init(inputIndex: Int) {
        let atlas = SKTextureAtlas(named: "LuminousWisp")
        let firstFrame = atlas.textureNamed("down_idle_000")
        super.init(texture: firstFrame, health: GameConfig.basePlayerHealth)
        setupAnimations()
    }
    
    private func setupAnimations() {
        animator = AnimationComponent(atlasName: "LuminousWisp", owner: self, canMirror: false)
        
        let directions = ["up", "down", "left", "right", "up_left", "up_right", "down_left", "down_right"]
        
        for direction in directions {
            animator.loadAnimation(name: "\(direction)_idle", frameCount: 6)
            animator.loadAnimation(name: "\(direction)_walk", frameCount: 6)
            animator.loadAnimation(name: "\(direction)_shoot", frameCount: 10)
        }
    }
    
    private func updateAnimation() {
        let movement = scene.inputSystem.movementVector(for: controllerIndex ?? 0)
        let isMoving = movement.dx != 0 || movement.dy != 0
        
        if isMoving {
            lastDirection = animator.setDirection(dx: movement.dx, dy: movement.dy)
        }
        
        let animationName = "\(lastDirection)_\(isMoving ? "walk" : "idle")"
        animator.play(animation: animationName, timePerFrame: 0.1, repeat: true)
    }
}
```

**AnimationComponent features:**
- Loads animations from atlas with configurable frame counts per action
- Calculates 8-directional facing from movement vector
- Optional mirroring: set `canMirror: true` to flip right-side animations from left-side frames
- Handles animation state transitions automatically

### Atlas Naming Rules

- Atlas name = entity/effect name (UpperCamelCase)
- Frame names = `action_###` where ### is zero-padded 3-digit index
- Actions: `walk`, `attack`, `idle`, `death`, `hit`, `cast`
- Effects: `explosion`, `collect`, `burst`, `trail`

### When NOT to Use Atlases

- UI elements that never animate (single-frame icons, buttons)
- Procedurally generated textures (noise, gradients)
- Floor tiles rendered via GPU instancing (use single texture + Metal shader)

---

## Rendering

- Use `SKRenderer` with Metal for the ground floor tile layer. Tile rendering uses GPU instancing.
- Projectiles are pooled via `ProjectilePool.swift`. Never instantiate a new `SKSpriteNode` per shot.
- SKEmitterNode assets are pre-loaded in `ParticleAssets.swift` at scene start. Never load from disk mid-gameplay. Assets needed for V1: Essence collect, gnome death, shield expand, shield burst, Mist explosion.
- Target: **120 FPS minimum on all supported Mac hardware.**

---

## Game Center

All Game Center calls go through `GameCenterManager.swift`. No scene calls GameKit directly.

```swift
class GameCenterManager {
    static let shared = GameCenterManager()
    func authenticateLocalPlayer(completion: @escaping (Bool) -> Void)
    func submitScore(_ score: Int, leaderboardID: String)
    func reportAchievement(id: String, percentComplete: Double)
    func loadLeaderboard(id: String, completion: @escaping ([GKLeaderboard.Entry]) -> Void)
}
```

Leaderboard IDs and achievement IDs are string constants in `Achievements.swift`. Never inline ID strings.

---

## Config Files

Tuning constants are split across two config files and private file-level constants.

### GameConfig.swift — system-level balance tuning

Contains values that a designer touches during balance and playtesting. Read by multiple systems.

```
Map, Player stats, Projectile, XP/Levelling, Orb evolution timers + essence values,
Shield, Skill draw caps, Camera, Input, Director, Spawn waves, Grove/Grumble/Grand stats
```

### SkillConfig.swift — skill and power-up tuning

Contains all weapon and power-up balance values. Read by `SkillSystem` and `GameScene`.

```
Warden Thorns, Lightning Strike, Poisonous Mist, Power-ups
```

### Private file-level constants — visual set-and-forget values

Values that are fixed once and never tuned during balance live as `private let` constants at the top of the file that uses them. Never go in a config file.

Examples:
- Orb bob animation timing, physics radii, sprite target heights → top of `EssenceOrbComponent.swift`
- Gnome sprite target heights → top of `Grove.swift`, `Grumble.swift`, `Grand.swift`
- Lightning visual sizing factors → top of `GameScene.swift`
- Boss minion spawn radius → top of `SpawnSystem.swift`

### Decision rule

| Value type | Where it lives |
|---|---|
| Balance/gameplay tuning — tweaked during playtesting | `GameConfig` or `SkillConfig` |
| Skill weapon/powerup tuning | `SkillConfig` |
| Visual polish — set once, never tuned | `private let` at top of the file that uses it |
| UI layout constants | `private` inside the UI file (e.g. `HUD.Metrics`) |

---

## GameConfig.swift (Central Tuning)

All magic numbers live here. Nothing is hardcoded in entity or system files.

```swift
enum GameConfig {
    // Map
    static let mapSize: CGSize = CGSize(width: 2160, height: 1215)

    // Player
    static let basePlayerSpeed: CGFloat = 200
    static let basePlayerHealth: Int = 100

    // Forest Essence Orb Evolution
    static let smallOrbEvolveTime: TimeInterval = 5.0
    static let grownOrbEvolveTime: TimeInterval = 8.0

    // Shield
    static let shieldExpandDuration: TimeInterval = 1.5
    static let shieldMaxRadius: CGFloat = 180

    // Camera
    static let cameraFollowSpeed: CGFloat = 0.1
    static let cameraZoom: CGFloat = 2.5
    static var cameraViewportSize: CGSize {
        CGSize(width: mapSize.width / cameraZoom, height: mapSize.height / cameraZoom)
    }
    static let cameraLeashFactor: CGFloat = 0.95

    // Skill Draw
    static let skillDrawCount: Int = 3
    static let maxWeaponSlots: Int = 3
    static let maxPowerUpSlots: Int = 3
    static let maxLevel3Items: Int = 3

    // Input
    static let autoAimIdleThreshold: TimeInterval = 0.2
    static let stickDeadzone: CGFloat = 0.15

    // Director
    static let directorPollInterval: TimeInterval = 5.0
    static let directorRollingWindowDuration: TimeInterval = 20.0
    static let directorMinBudget: Int = 100
    static let directorMaxBudget: Int = 300
    static let directorBudgetStep: Int = 20
    static let directorPassiveStep: Int = 10
    static let directorKillRateThreshold: Double = 2.0
    static let directorDamageRateThreshold: Double = 5.0

    // Boss Stage
    static let bossSpawnInterval: TimeInterval = 600.0

    // Grove (Small Gnome)
    static let smallGnomeBudgetWeight: Int = 1
    static let smallGnomeHealth: Int = 30
    static let smallGnomeMoveSpeed: CGFloat = 80

    // Grumble (Mini-Boss)
    static let grumbleBudgetWeight: Int = 10
    static let miniBossHealth: Int = 200
    static let miniBossMoveSpeed: CGFloat = 60

    // Grand (Boss)
    static let bossHealth: Int = 2000
    static let bossMoveSpeed: CGFloat = 40
}
```

---

## Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| Classes | UpperCamelCase | `PlayerEntity`, `EnemyAI`, `DirectorSystem` |
| Structs | UpperCamelCase | `HealthComponent`, `Skill` |
| Enums | UpperCamelCase, cases lowerCamelCase | `OrbState.evolved` |
| Functions | lowerCamelCase | `toroidalWrap(_:mapSize:)` |
| Constants | lowerCamelCase inside `enum` namespace | `GameConfig.directorMaxBudget` |
| Files | Match primary type name exactly | `DirectorSystem.swift` |
| Physics bitmasks | lowerCamelCase inside enum | `PhysicsCategory.shield` |
| Texture atlases | UpperCamelCase | `LuminousOrb.spriteatlas` |
| Atlas frames | `action_###` format | `walk_000`, `attack_012` |

---

## Code Rules

- No `print()` in production paths. Use a `Log.swift` debug wrapper that strips in release builds.
- No force unwraps (`!`) except in `@IBOutlet` / `@IBAction` if ever used. Use `guard let` or `if let`.
- No magic numbers. Balance/gameplay values go in `GameConfig` or `SkillConfig`. Visual set-and-forget values go as `private let` constants at the top of the file that uses them.
- All `update(deltaTime:)` methods must be O(n) or better. No nested loops over full entity lists in the update cycle.
- Object pooling is mandatory for projectiles and XP orbs. Both are high-frequency spawn/despawn objects.
- `SKAction` sequences are acceptable for one-off animations. Never use `SKAction` for game logic that needs to be queryable or cancellable at runtime — use explicit state machines instead.
- `DirectorSystem` is read-only from outside. Only `GameScene` calls `update()` on it. Only `CollisionSystem` calls `recordKill()` and `recordDamageTaken()`. `SpawnSystem` reads `currentBudget` and `isBossStageActive` but never writes to the Director.

---

## Testing

### Unit & Integration Tests — Swift Testing

Use **Swift Testing** (`import Testing`) for all unit and integration tests. XCTest is only permitted for UI tests (see below).

**What to test:**
- `ToroidalMath` — all three functions at normal, edge, and corner positions (mandatory per roadmap)
- `DirectorSystem` — rolling window eviction, budget adjustment logic for all 4 signal combinations, hard-bound clamping
- `HealthComponent` — `takeDamage`, `heal`, `isDead` boundary conditions
- `LevelComponent` — XP accumulation, threshold crossing, level-up return value
- `ProjectilePool` — dequeue/enqueue cycle, pool exhaustion behavior
- `SkillSystem` — draw returns exactly 3 non-duplicate skills, seeded reproducibility
- `EssenceOrbComponent` — state machine transitions (`small → grown → mistExplosion`), timer thresholds

**Naming convention:** Test files live in `GreedTests/` and mirror the source file name. See the full folder structure above.

**Swift Testing style:**

```swift
import Testing
@testable import Greed

@Suite("ToroidalMath")
struct ToroidalMathTests {
    @Test("wrap position at east boundary")
    func wrapEastBoundary() {
        let result = toroidalWrap(CGPoint(x: 1100, y: 0), mapSize: CGSize(width: 1000, height: 1000))
        #expect(result.x == 100)
    }
}
```

- Use `@Suite` to group tests by system/component.
- Use `@Test` with a descriptive string label.
- Use `#expect` and `#require` — never `XCTAssert` in Swift Testing files.
- Parameterize edge cases with `@Test(arguments:)` where applicable.

### UI Tests — XCUITest

Use **XCTest + XCUITest** (`import XCTest`) for UI-layer tests only. These live in `GreedUITests/`.

**What to test:**
- App launches and reaches the home/game screen without crashing
- Skill card overlay appears and can be dismissed (simulated input)
- HUD elements are present and accessible on screen

**XCUITest style:**

```swift
import XCTest

final class GameLaunchUITests: XCTestCase {
    func testAppLaunchesSuccessfully() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
}
```

- One `XCTestCase` subclass per UI flow.
- Use `XCTAssert` family only in XCUITest files — never in Swift Testing files.
- Launch tests (`GreedUITestsLaunchTests.swift`) capture baseline screenshots; keep them.

### Rules

- Never mix `import Testing` and `import XCTest` in the same file.
- All pure logic (math, components, systems) → Swift Testing.
- All UI interaction and app-launch verification → XCUITest.
- Test targets must compile and pass before any version milestone is marked complete.
