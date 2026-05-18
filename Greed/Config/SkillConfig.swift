import Foundation
import CoreGraphics

enum SkillConfig {
    // MARK: - Orbiting Spell
    static let orbitCountByLevel: [Int] = [2, 4, 6]
    static let orbitRotationSpeed: CGFloat = 3.0
    static let orbitRadius: CGFloat = 90
    static let orbitDamage: Int = 30
    static let orbitCooldownPerEnemy: TimeInterval = 0.5
    static let orbitKnifeSize = CGSize(width: 38, height: 14)
    static let orbitHitRadius: CGFloat = 10

    // MARK: - Lightning Strike
    static let lightningCooldownByLevel: [TimeInterval] = [1.5, 1.0, 0.6]
    static let lightningStrikeCountByLevel: [Int] = [2, 3, 4]
    static let lightningBaseDamage: Int = 80
    static let lightningAoERadius: CGFloat = 100
    static let lightningBoltAlpha: CGFloat = 0.95
    static let lightningBoltWidthFactor: CGFloat = 0.45
    static let lightningBoltMinWidth: CGFloat = 28
    static let lightningBoltAnimFrameTime: TimeInterval = 0.04
    static let lightningImpactRadiusFactor: CGFloat = 0.12
    static let lightningImpactMinRadius: CGFloat = 10
    static let lightningImpactScale: CGFloat = 1.5
    static let lightningImpactDuration: TimeInterval = 0.12
    static let lightningStrikeLifetime: TimeInterval = 0.18
    static let lightningTextureCropRect: CGRect = CGRect(x: 0.14, y: 0.05, width: 0.34, height: 0.90)

    // MARK: - Poisonous Mist
    static let mistCooldownByLevel: [TimeInterval] = [2.5, 1.5, 1.0]
    static let mistCountByLevel: [Int] = [1, 2, 3]
    static let mistBaseDamage: Int = 15
    static let mistBaseDuration: TimeInterval = 6.0
    static let mistTickInterval: TimeInterval = 0.4
    static let mistRadius: CGFloat = 160
    static let mistCloudAlpha: CGFloat = 0.72
    static let mistCloudAnimFrameTime: TimeInterval = 0.14

    // MARK: - Power-ups
    /// Final attack-speed multiplier at L1, L2, L3 (absolute, not cumulative).
    static let ancientTomeAttackSpeedMultipliers: [Float] = [1.1, 1.2, 1.3]
    /// Final movement-speed multiplier at L1, L2, L3 (absolute, not cumulative).
    static let spiritFruitMovementSpeedMultipliers: [Float] = [1.1, 1.2, 1.3]
    /// Total max-health bonus at L1, L2, L3 (absolute, not cumulative).
    static let lifeBloomMaxHealthBonuses: [Int] = [20, 40, 60]
}
