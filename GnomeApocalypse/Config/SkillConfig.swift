import Foundation
import CoreGraphics

/// Tunable values for player skills and power-up effects.
enum SkillConfig {
    // MARK: - Warden Thorns
    /// Number of orbiting thorns granted at skill levels 1, 2, and 3.
    static let wardenThornCountByLevel: [Int] = [2, 4, 6]
    /// Orbit speed in radians per second.
    static let wardenThornRotationSpeed: CGFloat = 3.0
    /// Orbit radius from the player's world position.
    static let wardenThornRadius: CGFloat = 90
    /// Damage per thorn contact before per-enemy cooldown is applied.
    static let wardenThornDamage: Int = 30
    /// Minimum seconds before the same thorn can damage the same enemy again.
    static let wardenThornCooldownPerEnemy: TimeInterval = 0.5
    /// Rendered thorn sprite size; collision uses `wardenThornHitRadius`.
    static let wardenThornSize = CGSize(width: 28, height: 38)
    /// Gameplay hit radius around each thorn sprite.
    static let wardenThornHitRadius: CGFloat = 10
    /// Number of frames in the Warden Thorns atlas animation.
    static let wardenThornFrameCount = 5
    /// Seconds per frame for the Warden Thorns loop.
    static let wardenThornAnimFrameTime: TimeInterval = 0.08

    // MARK: - Lightning Strike
    /// Seconds between automatic lightning casts at skill levels 1, 2, and 3.
    static let lightningCooldownByLevel: [TimeInterval] = [3, 2, 1]
    /// Number of targets hit per cast at skill levels 1, 2, and 3.
    static let lightningStrikeCountByLevel: [Int] = [2, 3, 4]
    /// Damage applied to each struck enemy.
    static let lightningBaseDamage: Int = 30
    /// Reserved area-of-effect radius for future chain or splash behavior.
    static let lightningAoERadius: CGFloat = 100
    /// Alpha used for the visible bolt sprite.
    static let lightningBoltAlpha: CGFloat = 0.95
    /// Bolt width multiplier relative to the strike radius.
    static let lightningBoltWidthFactor: CGFloat = 1.3
    /// Minimum bolt width so small targets still read clearly.
    static let lightningBoltMinWidth: CGFloat = 44
    /// Seconds per frame for the lightning bolt animation.
    static let lightningBoltAnimFrameTime: TimeInterval = 0.04
    /// Impact ring radius multiplier relative to the strike radius.
    static let lightningImpactRadiusFactor: CGFloat = 0.22
    /// Minimum impact ring radius for readability.
    static let lightningImpactMinRadius: CGFloat = 18
    /// Scale reached by the impact ring during its fade-out.
    static let lightningImpactScale: CGFloat = 1.5
    /// Lifetime of the impact ring fade-out.
    static let lightningImpactDuration: TimeInterval = 0.12
    /// Lifetime of the whole lightning node before removal.
    static let lightningStrikeLifetime: TimeInterval = 0.20

    // MARK: - Poisonous Mist
    /// Seconds between mist cloud spawns at skill levels 1, 2, and 3.
    static let mistCooldownByLevel: [TimeInterval] = [2.5, 1.5, 1.0]
    /// Maximum concurrent mist clouds at skill levels 1, 2, and 3.
    static let mistCountByLevel: [Int] = [1, 2, 3]
    /// Damage applied on each mist tick.
    static let mistBaseDamage: Int = 15
    /// Lifetime of each mist cloud.
    static let mistBaseDuration: TimeInterval = 6.0
    /// Seconds between damage ticks per cloud.
    static let mistTickInterval: TimeInterval = 0.4
    /// World-space damage radius around each cloud center.
    static let mistRadius: CGFloat = 160
    /// Alpha used for the mist sprite.
    static let mistCloudAlpha: CGFloat = 0.72
    /// Seconds per frame for the mist cloud loop.
    static let mistCloudAnimFrameTime: TimeInterval = 0.14

    // MARK: - Power-ups
    /// Per-level attack-speed bonus rates at L1, L2, L3. A value of 0.10 means +10%.
    static let ancientTomeAttackSpeedBonusRates: [CGFloat] = [0.10, 0.20, 0.30]
    /// Per-level movement-speed bonus rates at L1, L2, L3. A value of 0.10 means +10%.
    static let spiritFruitMovementSpeedBonusRates: [CGFloat] = [0.10, 0.20, 0.30]
    /// Per-level max-health bonus rates at L1, L2, L3. A value of 0.10 means +10%.
    static let lifeBloomMaxHealthBonusRates: [CGFloat] = [0.10, 0.20, 0.30]
}
