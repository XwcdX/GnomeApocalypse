import Foundation

enum SkillType {
    case weapon
    case powerUp
}

enum SkillEffect {
    case orbitingSpell(orbitCount: Int)
    case lightningStrike(chainCount: Int)
    case poisonousMist(damage: Int, duration: TimeInterval)
    case increaseAttackSpeed(multiplier: Float)
    case increaseMovementSpeed(multiplier: Float)
    case increaseMaxHealth(amount: Int)
}

struct Skill {
    let id: String
    let name: String
    let type: SkillType
    let iconName: String
    let maxLevel: Int

    func effect(at level: Int) -> SkillEffect {
        switch id {
        case "orbiting_spell":
            return .orbitingSpell(orbitCount: level)
        case "lightning_strike":
            return .lightningStrike(chainCount: level)
        case "poisonous_mist":
            let baseDamage   = SkillConfig.mistBaseDamage
            let baseDuration = SkillConfig.mistBaseDuration
            let damage       = level == 3 ? baseDamage * 2 : baseDamage
            let duration     = level >= 2 ? baseDuration * 1.5 : baseDuration
            return .poisonousMist(damage: damage, duration: duration)
        case "ancient_tome":
            return .increaseAttackSpeed(multiplier: 1.0 + Float(level) * 0.1)
        case "spirit_fruit":
            return .increaseMovementSpeed(multiplier: 1.0 + Float(level) * 0.1)
        case "life_bloom":
            return .increaseMaxHealth(amount: level * SkillConfig.healthBoostPerLevel)
        default:
            return .increaseAttackSpeed(multiplier: 1.0)
        }
    }
}

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

    func level(of skillId: String, type: SkillType) -> Int {
        switch type {
        case .weapon:  return ownedWeapons[skillId]  ?? 0
        case .powerUp: return ownedPowerUps[skillId] ?? 0
        }
    }

    func isMaxed(_ skill: Skill) -> Bool {
        let currentLevel = level(of: skill.id, type: skill.type)
        if currentLevel >= 3 { return true }
        if currentLevel >= 2 && maxLevelCapReached { return true }
        return false
    }

    func owns(_ skill: Skill) -> Bool {
        level(of: skill.id, type: skill.type) > 0
    }

    mutating func upgrade(_ skill: Skill) {
        switch skill.type {
        case .weapon:  ownedWeapons[skill.id,  default: 0] += 1
        case .powerUp: ownedPowerUps[skill.id, default: 0] += 1
        }
    }
}

final class SkillSystem {
    private let pool: [Skill] = [
        Skill(id: "orbiting_spell",   name: "Orbiting Spell",   type: .weapon,  iconName: "orbiting_placeholder",  maxLevel: 3),
        Skill(id: "lightning_strike", name: "Lightning Strike", type: .weapon,  iconName: "LightningCard",  maxLevel: 3),
        Skill(id: "poisonous_mist",   name: "Poisonous Mist",   type: .weapon,  iconName: "MistCard",       maxLevel: 3),
        Skill(id: "ancient_tome",     name: "Ancient Tome",     type: .powerUp, iconName: "tome_icon",      maxLevel: 3),
        Skill(id: "spirit_fruit",     name: "Spirit Fruit",     type: .powerUp, iconName: "fruit_icon",     maxLevel: 3),
        Skill(id: "life_bloom",       name: "Life Bloom",       type: .powerUp, iconName: "bloom_icon",     maxLevel: 3),
    ]

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
