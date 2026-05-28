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
