import Foundation
import CoreGraphics

enum SkillConfig {
    // MARK: - Warden Thorns
    static let wardenThornCountByLevel: [Int] = [2, 4, 6]
    static let wardenThornRotationSpeed: CGFloat = 3.0
    static let wardenThornRadius: CGFloat = 90
    static let wardenThornDamage: Int = 30
    static let wardenThornCooldownPerEnemy: TimeInterval = 0.5
    static let wardenThornSize = CGSize(width: 38, height: 14)
    static let wardenThornHitRadius: CGFloat = 10

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
    /// Per-level attack-speed bonus rates at L1, L2, L3. A value of 0.10 means +10%.
    static let ancientTomeAttackSpeedBonusRates: [CGFloat] = [0.10, 0.20, 0.30]
    /// Per-level movement-speed bonus rates at L1, L2, L3. A value of 0.10 means +10%.
    static let spiritFruitMovementSpeedBonusRates: [CGFloat] = [0.10, 0.20, 0.30]
    /// Per-level max-health bonus rates at L1, L2, L3. A value of 0.10 means +10%.
    static let lifeBloomMaxHealthBonusRates: [CGFloat] = [0.10, 0.20, 0.30]
}
