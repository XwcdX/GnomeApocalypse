import Foundation
import CoreGraphics

enum GameConfig {
    // MARK: - Map
    /// The logical size of the toroidal world. Positions outside this range are wrapped.
    static let mapSize: CGSize = CGSize(width: 2160, height: 1215)


    // MARK: - Player
    static let basePlayerSpeed: CGFloat = 200
    static let basePlayerHealth: Int = 100
    static let basePlayerDamage: Int = 10
    static let baseFireRate: TimeInterval = 1
    static let projectileSpeed: CGFloat = 500
    static var projectileLifeSpan: TimeInterval {
        TimeInterval((cameraViewportSize.width / 2) / projectileSpeed)
    }
    static let playerProjectileSize: CGSize = CGSize(width: 24, height: 20)
    static let playerProjectileSpawnOffset: CGFloat = 24
    static let playerProjectileFrameTime: TimeInterval = 0.06


    // MARK: - Projectile Pool
    /// Pre-allocated pool size at scene start. Never allocates new projectiles during gameplay.
    static let projectilePoolSize: Int = 128


    // MARK: - XP / Levelling
    static let baseXPThreshold: Int = 100
    static let xpThresholdGrowthFactor: Double = 1.4


    // MARK: - Forest Essence Orb Evolution
    static let smallOrbEvolveTime: TimeInterval = 5.0
    static let grownOrbEvolveTime: TimeInterval = 8.0
    static let redOrbEvolveTime: TimeInterval = 5.0
    static let smallOrbEssenceValue: Int = 10
    static let grownOrbEssenceValue: Int = 25
    static let redOrbEssenceValue: Int = 50
    static let orbMagnetRadius: CGFloat = 40
    static let orbMagnetSpeed: CGFloat = 360
    static let orbMagnetActivationDelay: TimeInterval = 0.45


    // MARK: - Shield (Level Up)
    static let shieldExpandDuration: TimeInterval = 1.5
    static let shieldMaxRadius: CGFloat = 180
    static let shieldKnockbackImpulse: CGFloat = 280
    static let shieldPushForce: CGFloat = 120


    // MARK: - Skill System
    static let skillDrawCount: Int = 3
    static let maxWeaponSlots: Int = 3
    static let maxPowerUpSlots: Int = 3
    static let maxLevel3Items: Int = 3


    // MARK: - Camera
    static let cameraFollowSpeed: CGFloat = 0.1
    static let cameraZoom: CGFloat = 2.5
    static var cameraViewportSize: CGSize {
        CGSize(width: mapSize.width / cameraZoom, height: mapSize.height / cameraZoom)
    }
    static let cameraLeashFactor: CGFloat = 0.95


    // MARK: - UI
    /// Fixed reference canvas for HUD and overlay scaling. Keep this independent
    /// from mapSize so changing the world dimensions does not resize UI.
    static let uiReferenceSize: CGSize = CGSize(width: 1440, height: 810)


    // MARK: - Input
    static let autoAimIdleThreshold: TimeInterval = 0.2
    static let stickDeadzone: CGFloat = 0.15
    /// Full viewport diagonal — auto-aim targets any enemy visible on screen
    static var autoAimMaxRange: CGFloat {
        sqrt(pow(cameraViewportSize.width, 2) + pow(cameraViewportSize.height, 2))
    }


    // MARK: - Director System
    /// How often (in seconds) the Director evaluates its rolling-window metrics and steps the budget.
    static let directorPollInterval: TimeInterval = 5.0
    /// Duration of the rolling window used to compute kill rate and damage rate.
    static let directorRollingWindowDuration: TimeInterval = 20.0
    /// The minimum enemy budget.
    static let directorMinBudget: Int = 100
    /// Soft ceiling for the enemy budget.
    static let directorMaxBudget: Int = 300
    /// Normal budget step applied when the Director ramps up or ramps down per poll.
    static let directorBudgetStep: Int = 20
    /// Smaller step applied when the player is being passive (low kill rate + low damage rate).
    static let directorPassiveStep: Int = 10
    /// Kill rate (kills/sec) above which the Director considers the player to be dominating.
    static let directorKillRateThreshold: Double = 2.0
    /// Damage rate (damage/sec) above which the Director considers the player to be struggling.
    static let directorDamageRateThreshold: Double = 5.0


    // MARK: - Boss Stage
    /// Interval (in seconds) between Boss eruptions, regardless of Director budget state.
    static let bossSpawnInterval: TimeInterval = 6.0


    // MARK: - Enemy Spawn
    static let spawnWaveEscalationInterval: TimeInterval = 30.0
    static let baseSpawnInterval: TimeInterval = 2.0
    static let minimumSpawnInterval: TimeInterval = 0.7
    static let spawnIntervalReductionPerWave: TimeInterval = 0.15
    static let baseGnomesPerSpawn: Int = 1
    static let maximumGnomesPerSpawn: Int = 6
    static let gnomesPerSpawnIncreasePerWave: Int = 1
    static let spawnMarginOutsideCamera: CGFloat = 60


    // MARK: - Grove (Small Gnome)
    static let smallGnomeBudgetWeight: Int = 1
    static let smallGnomeHealth: Int = 30
    static let smallGnomeMoveSpeed: CGFloat = 80
    static let smallGnomeAttackInterval: TimeInterval = 1.0
    static let smallGnomeAttackWindup: TimeInterval = 0.28
    static let smallGnomeAttackDamage: Int = 5
    static let smallGnomeAttackRange: CGFloat = 54


    // MARK: - Grumble (Mini-Boss)
    static let grumbleBudgetWeight: Int = 10
    static let miniBossShootInterval: TimeInterval = 2.0
    static let miniBossProjectileDamage: Int = 15
    static let miniBossMoveSpeed: CGFloat = 60
    static let miniBossHealth: Int = 200
    static let miniBossPreferredRange: CGFloat = 180


    // MARK: - Grand (Boss)
    static let swarmBudgetWeight: Int = 20
    static let bossAbilityInterval: TimeInterval = 8.0
    static let bossMoveSpeed: CGFloat = 40
    static let bossHealth: Int = 2000
    static let bossPhase1MinionCount: Int = 3
    static let bossPhase2MinionCount: Int = 6


    // MARK: - Side Quest
    static let sideQuestButtonCount: Int = 4
    static let sideQuestActivationRadius: CGFloat = 80
    static let sideQuestActivationDuration: TimeInterval = 2.0
    static let sideQuestGlobalTimer: TimeInterval = 120.0


    // MARK: - Meta-Progression
    static let maxSpeedUpgradeLevel: Int = 10
    static let maxLuckUpgradeLevel: Int = 10
    static let maxHealthUpgradeLevel: Int = 10
    static let essenceCostPerUpgradeLevel: Int = 100
}
