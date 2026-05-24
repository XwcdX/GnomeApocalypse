import Foundation
import CoreGraphics

/// Central gameplay tuning values shared across systems.
enum GameConfig {
    // MARK: - Map
    /// The logical size of the toroidal world. Positions outside this range are wrapped.
    static let mapSize: CGSize = CGSize(width: 2160, height: 1215)


    // MARK: - Player
    /// Base movement speed in world points per second before power-up multipliers.
    static let basePlayerSpeed: CGFloat = 200
    /// Starting and respawn maximum health for the player.
    static let basePlayerHealth: Int = 100
    /// Base damage for player projectiles before skill effects.
    static let basePlayerDamage: Int = 30
    /// Seconds between auto-fire shots before attack-speed multipliers.
    static let baseFireRate: TimeInterval = 1
    /// Projectile speed in world points per second.
    static let projectileSpeed: CGFloat = 500
    /// Projectile lifetime is sized to roughly half of the current camera viewport.
    static var projectileLifeSpan: TimeInterval {
        TimeInterval((cameraViewportSize.width / 2) / projectileSpeed)
    }
    /// Player projectile render and physics size.
    static let playerProjectileSize: CGSize = CGSize(width: 24, height: 20)
    /// Spawn offset from the player's center along aim direction.
    static let playerProjectileSpawnOffset: CGFloat = 24
    /// Seconds per frame for player projectile animation.
    static let playerProjectileFrameTime: TimeInterval = 0.06


    // MARK: - Projectile Pool
    /// Pre-allocated pool size at scene start. Never allocates new projectiles during gameplay.
    static let projectilePoolSize: Int = 128


    // MARK: - XP / Levelling
    /// XP required to reach level 2.
    static let baseXPThreshold: Int = 100
    /// Multiplier applied to the next XP threshold after each level-up.
    static let xpThresholdGrowthFactor: Double = 1.4


    // MARK: - Forest Essence Orb Evolution
    /// Seconds before a green essence orb upgrades to blue.
    static let smallOrbEvolveTime: TimeInterval = 5.0
    /// Seconds before a blue essence orb upgrades to red.
    static let grownOrbEvolveTime: TimeInterval = 8.0
    /// Seconds before a red essence orb mutates into a mini-boss spawn attempt.
    static let redOrbEvolveTime: TimeInterval = 5.0
    /// XP awarded by a green essence orb.
    static let smallOrbEssenceValue: Int = 10
    /// XP awarded by a blue essence orb.
    static let grownOrbEssenceValue: Int = 25
    /// XP awarded by a red essence orb.
    static let redOrbEssenceValue: Int = 50
    /// World-space distance where an orb begins moving toward a player.
    static let orbMagnetRadius: CGFloat = 40
    /// Orb movement speed while magnetized.
    static let orbMagnetSpeed: CGFloat = 360
    /// Seconds after spawn before magnet behavior can activate.
    static let orbMagnetActivationDelay: TimeInterval = 0.45


    // MARK: - Shield (Level Up)
    /// Reserved duration for level-up shield expansion.
    static let shieldExpandDuration: TimeInterval = 1.5
    /// Reserved maximum radius for level-up shield behavior.
    static let shieldMaxRadius: CGFloat = 180
    /// Reserved impulse value for shield knockback behavior.
    static let shieldKnockbackImpulse: CGFloat = 280
    /// Reserved push force for disabled shield contact handlers.
    static let shieldPushForce: CGFloat = 120


    // MARK: - Skill System
    /// Number of cards offered during a level-up draw.
    static let skillDrawCount: Int = 3
    /// Maximum distinct weapon skills a player can own.
    static let maxWeaponSlots: Int = 3
    /// Maximum distinct power-up skills a player can own.
    static let maxPowerUpSlots: Int = 3
    /// Maximum total skills that may reach level 3.
    static let maxLevel3Items: Int = 3


    // MARK: - Camera
    /// Lerp factor applied each frame when following players.
    static let cameraFollowSpeed: CGFloat = 0.1
    /// SpriteKit camera zoom divisor; larger values show less of the toroidal world.
    static let cameraZoom: CGFloat = 2.5
    /// World-space viewport derived from map size and zoom.
    static var cameraViewportSize: CGSize {
        CGSize(width: mapSize.width / cameraZoom, height: mapSize.height / cameraZoom)
    }
    /// Reserved leash factor for future multiplayer camera constraints.
    static let cameraLeashFactor: CGFloat = 0.95


    // MARK: - UI
    /// Fixed reference canvas for HUD and overlay scaling. Keep this independent
    /// from mapSize so changing the world dimensions does not resize UI.
    static let uiReferenceSize: CGSize = CGSize(width: 1440, height: 810)
    static let fontName = "Pixelade"


    // MARK: - Input
    /// Seconds after mouse movement before keyboard/mouse aim falls back to auto-aim.
    static let autoAimIdleThreshold: TimeInterval = 0.2
    /// Minimum analog-stick magnitude required before controller input counts.
    static let stickDeadzone: CGFloat = 0.15
    /// Full viewport diagonal — auto-aim targets any enemy visible on screen
    static var autoAimMaxRange: CGFloat {
        sqrt(pow(cameraViewportSize.width, 2) + pow(cameraViewportSize.height, 2))
    }


    // MARK: - Director System
    /// How often (in seconds) the Director evaluates its rolling-window metrics and steps the budget.
    static let directorPollInterval: TimeInterval = 5.0
    /// Seconds between unconditional time-pressure budget increases.
    static let directorTimePressureInterval: TimeInterval = 30.0
    /// Duration of the rolling window used to compute kill rate and damage rate.
    static let directorRollingWindowDuration: TimeInterval = 20.0
    /// The minimum enemy budget.
    static let directorMinBudget: Int = 50
    /// Soft ceiling for the enemy budget.
    static let directorMaxBudget: Int = 300
    /// Budget added on each time-pressure interval.
    static let directorTimePressureStep: Int = 5
    /// Normal budget step applied when the Director ramps up or ramps down per poll.
    static let directorBudgetStep: Int = 20
    /// Smaller step applied when the player is being passive (low kill rate + low damage rate).
    static let directorPassiveStep: Int = 1
    /// Kill rate (kills/sec) above which the Director considers the player to be dominating.
    static let directorKillRateThreshold: Double = 2.0
    /// Average health fraction below which the Director treats the player as under pressure.
    static let directorHealthThreshold: Double = 0.5
    

    // MARK: - Boss Stage
    /// Interval (in seconds) between Boss eruptions, regardless of Director budget state.
    static let bossSpawnInterval: TimeInterval = 150.0


    // MARK: - Enemy Spawn
    /// Seconds per escalation tier for regular wave spawning.
    static let spawnWaveEscalationInterval: TimeInterval = 30.0
    /// Initial seconds between regular wave spawn attempts.
    static let baseSpawnInterval: TimeInterval = 2.0
    /// Lower bound on regular wave spawn interval after escalation.
    static let minimumSpawnInterval: TimeInterval = 0.7
    /// Seconds removed from spawn interval per wave tier.
    static let spawnIntervalReductionPerWave: TimeInterval = 0.15
    /// Initial number of regular gnomes attempted per wave.
    static let baseGnomesPerSpawn: Int = 1
    /// Upper bound on regular gnomes attempted per wave.
    static let maximumGnomesPerSpawn: Int = 6
    /// Additional gnomes attempted per wave tier.
    static let gnomesPerSpawnIncreasePerWave: Int = 1
    /// Distance outside the camera viewport used for offscreen spawns.
    static let spawnMarginOutsideCamera: CGFloat = 60


    // MARK: - Grove (Small Gnome)
    /// Director budget cost for one Grove.
    static let smallGnomeBudgetWeight: Int = 1
    /// Maximum health for Grove enemies.
    static let smallGnomeHealth: Int = 30
    /// Grove movement speed in world points per second.
    static let smallGnomeMoveSpeed: CGFloat = 80
    /// Seconds between Grove attack attempts.
    static let smallGnomeAttackInterval: TimeInterval = 1.0
    /// Seconds between Grove attack start and projectile launch.
    static let smallGnomeAttackWindup: TimeInterval = 0.28
    /// Damage dealt by Grove projectiles.
    static let smallGnomeAttackDamage: Int = 5
    /// World-space distance where Grove starts its short-range attack.
    static let smallGnomeAttackRange: CGFloat = 54


    // MARK: - Grumble (Mini-Boss)
    /// Director budget cost for one Grumble.
    static let grumbleBudgetWeight: Int = 10
    /// Seconds between Grumble ranged attacks.
    static let miniBossShootInterval: TimeInterval = 2.0
    /// Seconds between Grumble attack start and projectile launch.
    static let miniBossAttackWindup: TimeInterval = 0.4
    /// Damage dealt by Grumble projectiles.
    static let miniBossProjectileDamage: Int = 15
    /// Grumble movement speed in world points per second.
    static let miniBossMoveSpeed: CGFloat = 60
    /// Maximum health for Grumble enemies.
    static let miniBossHealth: Int = 180
    /// World-space distance Grumble tries to preserve from its target.
    static let miniBossPreferredRange: CGFloat = 200


    // MARK: - Grand (Boss)
    /// Reserved budget weight for future swarm units.
    static let swarmBudgetWeight: Int = 20
    /// Seconds between Grand minion-spawn abilities in phase one.
    static let bossAbilityInterval: TimeInterval = 8.0
    /// Grand movement speed in world points per second.
    static let bossMoveSpeed: CGFloat = 40
    /// Maximum health for the Grand boss.
    static let bossHealth: Int = 900
    /// Minions spawned by Grand abilities above half health.
    static let bossPhase1MinionCount: Int = 3
    /// Minions spawned by Grand abilities at half health or below.
    static let bossPhase2MinionCount: Int = 6
    /// World-space distance where Grand can start a melee attack.
    static let bossMeleeRange: CGFloat = 80
    /// Seconds between Grand melee attack attempts.
    static let bossMeleeAttackInterval: TimeInterval = 1.5
    /// Seconds between Grand melee windup start and damage.
    static let bossMeleeWindup: TimeInterval = 0.5
    /// Damage dealt by Grand melee attacks.
    static let bossMeleeDamage: Int = 30


    // MARK: - Side Quest
    /// Reserved number of side-quest buttons for the environmental strategy loop.
    static let sideQuestButtonCount: Int = 4
    /// Reserved radius where players can activate a side-quest button.
    static let sideQuestActivationRadius: CGFloat = 80
    /// Reserved hold duration for side-quest button activation.
    static let sideQuestActivationDuration: TimeInterval = 2.0
    /// Reserved global timer for side-quest availability.
    static let sideQuestGlobalTimer: TimeInterval = 120.0


    // MARK: - Meta-Progression
    /// Reserved maximum account-level speed upgrade.
    static let maxSpeedUpgradeLevel: Int = 10
    /// Reserved maximum account-level luck upgrade.
    static let maxLuckUpgradeLevel: Int = 10
    /// Reserved maximum account-level health upgrade.
    static let maxHealthUpgradeLevel: Int = 10
    /// Reserved essence cost per account-level upgrade.
    static let essenceCostPerUpgradeLevel: Int = 100
}
