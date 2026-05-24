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
