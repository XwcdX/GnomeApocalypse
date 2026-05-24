import Foundation
import CoreGraphics

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

/// Tracks a player's owned skills and enforces slot and max-level caps.
struct PlayerSkillState {
    private var ownedWeapons:  [String: Int] = [:]
    private var ownedPowerUps: [String: Int] = [:]
    
    private var maxedItemCount: Int {
        let maxedWeapons = ownedWeapons.values.filter { $0 >= 3 }.count
        let maxedPowerUps = ownedPowerUps.values.filter { $0 >= 3 }.count
        return maxedWeapons + maxedPowerUps
    }

    var weaponCount: Int   { ownedWeapons.count }
    var powerUpCount: Int  { ownedPowerUps.count }

    var weaponCapReached:  Bool { weaponCount  >= GameConfig.maxWeaponSlots  }
    var powerUpCapReached: Bool { powerUpCount >= GameConfig.maxPowerUpSlots }
    var maxLevelCapReached: Bool { maxedItemCount >= GameConfig.maxLevel3Items }

    /// Returns the current level for an owned skill, or 0 when unowned.
    func level(of skillId: String, type: SkillType) -> Int {
        switch type {
        case .weapon:  return ownedWeapons[skillId]  ?? 0
        case .powerUp: return ownedPowerUps[skillId] ?? 0
        }
    }

    /// Returns whether a skill can no longer be offered by the draw pool.
    func isMaxed(_ skill: Skill) -> Bool {
        let currentLevel = level(of: skill.id, type: skill.type)
        if currentLevel >= skill.maxLevel { return true }
        if currentLevel >= 2 && maxLevelCapReached { return true }
        return false
    }

    /// Returns whether the player has at least level 1 of a skill.
    func owns(_ skill: Skill) -> Bool {
        level(of: skill.id, type: skill.type) > 0
    }

    /// Raises an owned skill by one level, respecting the skill's own maximum.
    mutating func upgrade(_ skill: Skill) {
        let currentLevel = level(of: skill.id, type: skill.type)
        guard currentLevel < skill.maxLevel else { return }

        switch skill.type {
        case .weapon:  ownedWeapons[skill.id]  = currentLevel + 1
        case .powerUp: ownedPowerUps[skill.id] = currentLevel + 1
        }
    }
}

/// Draws upgrade cards from the available skills for a player's current state.
final class SkillSystem {
    private let pool: [Skill] = [
        Skill(id: "warden_thorns",   name: "Warden Thorns",   type: .weapon,  iconName: "icon_warden_thorns",  maxLevel: 3),
        Skill(id: "lightning_strike", name: "Lightning Strike", type: .weapon,  iconName: "icon_lightning_strike", maxLevel: 3),
        Skill(id: "poisonous_mist",   name: "Poisonous Mist",   type: .weapon,  iconName: "icon_poisonous_mist",   maxLevel: 3),
        Skill(id: "ancient_tome",     name: "Ancient Tome",     type: .powerUp, iconName: "icon_ancient_tome",     maxLevel: 3),
        Skill(id: "spirit_fruit",     name: "Spirit Fruit",     type: .powerUp, iconName: "icon_spirit_fruit",     maxLevel: 3),
        Skill(id: "life_bloom",       name: "Life Bloom",       type: .powerUp, iconName: "icon_life_bloom",       maxLevel: 3),
    ]

    /// Draws up to `count` unique skills eligible for the supplied player state.
    func draw(for state: PlayerSkillState, count: Int = GameConfig.skillDrawCount) -> [Skill] {
        let available = availableSkills(for: state)
        guard !available.isEmpty else { return [] }

        var remaining = available
        var drawn: [Skill] = []

        for _ in 0..<min(count, remaining.count) {
            guard let pick = remaining.randomElement() else { break }
            drawn.append(pick)
            remaining.removeAll { $0.id == pick.id }
        }

        return drawn
    }

    private func availableSkills(for state: PlayerSkillState) -> [Skill] {
        pool.filter { skill in
            guard !state.isMaxed(skill) else { return false }

            switch skill.type {
            case .weapon:
                if state.weaponCapReached {
                    return state.owns(skill)
                }
                return true
            case .powerUp:
                if state.powerUpCapReached {
                    return state.owns(skill)
                }
                return true
            }
        }
    }
}
