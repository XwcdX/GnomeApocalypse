import CoreGraphics
import Foundation

/// Skill category used for slot caps and upgrade eligibility.
enum SkillType {
    case weapon
    case powerUp
}

/// Concrete gameplay effect produced by a skill at a specific level.
enum SkillEffect {
    case wardenThorns(thornCount: Int)
    case lightningStrike(cooldown: TimeInterval, strikeCount: Int)
    case poisonousMist(cooldown: TimeInterval, cloudCount: Int)
    case increaseAttackSpeed(bonusRate: CGFloat)
    case increaseMovementSpeed(bonusRate: CGFloat)
    case increaseMaxHealth(bonusRate: CGFloat)
}

/// Stable skill definition shown in selection cards and applied to player state.
struct Skill {
    let id: String
    let name: String
    let type: SkillType
    let iconName: String
    let maxLevel: Int

    /// Returns the gameplay effect for a 1-based skill level, clamped to configured values.
    func effect(at level: Int) -> SkillEffect {
        let index = max(0, min(level - 1, 2))
        switch id {
        case "warden_thorns":
            return .wardenThorns(thornCount: SkillConfig.wardenThornCountByLevel[index])
        case "lightning_strike":
            return .lightningStrike(
                cooldown: SkillConfig.lightningCooldownByLevel[index],
                strikeCount: SkillConfig.lightningStrikeCountByLevel[index]
            )
        case "poisonous_mist":
            return .poisonousMist(
                cooldown: SkillConfig.mistCooldownByLevel[index],
                cloudCount: SkillConfig.mistCountByLevel[index]
            )
        case "ancient_tome":
            return .increaseAttackSpeed(
                bonusRate: configuredValue(SkillConfig.ancientTomeAttackSpeedBonusRates, at: level) ?? 0.0
            )
        case "spirit_fruit":
            return .increaseMovementSpeed(
                bonusRate: configuredValue(SkillConfig.spiritFruitMovementSpeedBonusRates, at: level) ?? 0.0
            )
        case "life_bloom":
            return .increaseMaxHealth(
                bonusRate: configuredValue(SkillConfig.lifeBloomMaxHealthBonusRates, at: level) ?? 0.0
            )
        default:
            return .increaseAttackSpeed(bonusRate: 0.0)
        }
    }

    private func configuredValue<T>(_ values: [T], at level: Int) -> T? {
        assert(!values.isEmpty, "\(id) has no configured values")
        assert(values.count == maxLevel, "\(id) config count must match maxLevel")
        guard !values.isEmpty, maxLevel > 0 else { return nil }

        let configuredMaxLevel = min(maxLevel, values.count)
        let clampedLevel = min(max(level, 1), configuredMaxLevel)
        return values[clampedLevel - 1]
    }
}
