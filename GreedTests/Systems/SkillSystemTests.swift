import Testing
@testable import Greed

@Suite("SkillSystem")
struct SkillSystemTests {
    private let system = SkillSystem()

    @Test("draw returns exactly skillDrawCount skills from empty state")
    func drawReturnsCorrectCount() {
        let drawn = system.draw(for: PlayerSkillState())
        #expect(drawn.count == GameConfig.skillDrawCount)
    }

    @Test("draw returns no duplicates")
    func drawReturnsNoDuplicates() {
        let drawn = system.draw(for: PlayerSkillState())
        let ids = drawn.map { $0.id }
        #expect(Set(ids).count == ids.count)
    }

    @Test("draw returns empty when all skills are maxed")
    func drawReturnsEmptyWhenAllMaxed() {
        var state = PlayerSkillState()
        let allSkills = system.draw(for: state, count: 99)
        for skill in allSkills {
            state.upgrade(skill)
            state.upgrade(skill)
            state.upgrade(skill)
        }
        let drawn = system.draw(for: state)
        #expect(drawn.isEmpty)
    }

    @Test("draw does not offer new weapons when weapon cap is reached")
    func drawNoNewWeaponsAtCap() {
        var state = PlayerSkillState()
        let weapons = system.draw(for: state).filter { $0.type == .weapon }
        for w in weapons.prefix(GameConfig.maxWeaponSlots) { state.upgrade(w) }

        for _ in 0..<20 {
            let drawn = system.draw(for: state)
            let newWeapons = drawn.filter { $0.type == .weapon && !state.owns($0) }
            #expect(newWeapons.isEmpty)
        }
    }

    @Test("draw still offers weapon upgrades when weapon cap is reached")
    func drawOffersWeaponUpgradesAtCap() {
        var state = PlayerSkillState()
        let weapons = system.draw(for: state).filter { $0.type == .weapon }
        for w in weapons.prefix(GameConfig.maxWeaponSlots) { state.upgrade(w) }

        let drawn = system.draw(for: state)
        let ownedWeaponUpgrades = drawn.filter { $0.type == .weapon && state.owns($0) }
        #expect(!ownedWeaponUpgrades.isEmpty)
    }

    @Test("draw does not offer new power-ups when power-up cap is reached")
    func drawNoNewPowerUpsAtCap() {
        var state = PlayerSkillState()
        let powerUps = system.draw(for: state).filter { $0.type == .powerUp }
        for p in powerUps.prefix(GameConfig.maxPowerUpSlots) { state.upgrade(p) }

        for _ in 0..<20 {
            let drawn = system.draw(for: state)
            let newPowerUps = drawn.filter { $0.type == .powerUp && !state.owns($0) }
            #expect(newPowerUps.isEmpty)
        }
    }

    @Test("draw does not offer level-3 upgrade when maxLevel3Items cap is reached")
    func drawNoLevel3WhenCapReached() {
        var state = PlayerSkillState()
        let allSkills = system.draw(for: state, count: 99)
        for skill in allSkills.prefix(GameConfig.maxLevel3Items) {
            state.upgrade(skill)
            state.upgrade(skill)
            state.upgrade(skill)
        }

        if let nextSkill = allSkills.dropFirst(GameConfig.maxLevel3Items).first {
            state.upgrade(nextSkill)
            state.upgrade(nextSkill)
            #expect(state.isMaxed(nextSkill))
        }
    }

    @Test("draw never offers a skill already at level 3")
    func drawNeverOffersMaxedSkill() {
        var state = PlayerSkillState()
        let allSkills = system.draw(for: state, count: 99)
        guard let skill = allSkills.first else { return }
        state.upgrade(skill)
        state.upgrade(skill)
        state.upgrade(skill)

        for _ in 0..<30 {
            let drawn = system.draw(for: state)
            #expect(!drawn.contains(where: { $0.id == skill.id }))
        }
    }
}

@Suite("PlayerSkillState")
struct PlayerSkillStateTests {

    @Test("level returns 0 for unowned skill")
    func levelZeroForUnowned() {
        let state = PlayerSkillState()
        let skill = makeSkill(id: "test", type: .weapon)
        #expect(state.level(of: skill.id, type: skill.type) == 0)
    }

    @Test("upgrade increments level")
    func upgradeIncrementsLevel() {
        var state = PlayerSkillState()
        let skill = makeSkill(id: "test", type: .weapon)
        state.upgrade(skill)
        #expect(state.level(of: skill.id, type: skill.type) == 1)
        state.upgrade(skill)
        #expect(state.level(of: skill.id, type: skill.type) == 2)
    }

    @Test("owns returns false before upgrade")
    func ownsReturnsFalseBeforeUpgrade() {
        let state = PlayerSkillState()
        let skill = makeSkill(id: "test", type: .weapon)
        #expect(state.owns(skill) == false)
    }

    @Test("owns returns true after upgrade")
    func ownsReturnsTrueAfterUpgrade() {
        var state = PlayerSkillState()
        let skill = makeSkill(id: "test", type: .weapon)
        state.upgrade(skill)
        #expect(state.owns(skill) == true)
    }

    @Test("weaponCapReached is true at maxWeaponSlots distinct weapons")
    func weaponCapReachedAtMax() {
        var state = PlayerSkillState()
        for i in 0..<GameConfig.maxWeaponSlots {
            state.upgrade(makeSkill(id: "w\(i)", type: .weapon))
        }
        #expect(state.weaponCapReached == true)
    }

    @Test("powerUpCapReached is true at maxPowerUpSlots distinct power-ups")
    func powerUpCapReachedAtMax() {
        var state = PlayerSkillState()
        for i in 0..<GameConfig.maxPowerUpSlots {
            state.upgrade(makeSkill(id: "p\(i)", type: .powerUp))
        }
        #expect(state.powerUpCapReached == true)
    }

    @Test("isMaxed returns true at level 3")
    func isMaxedAtLevel3() {
        var state = PlayerSkillState()
        let skill = makeSkill(id: "test", type: .weapon)
        state.upgrade(skill); state.upgrade(skill); state.upgrade(skill)
        #expect(state.isMaxed(skill) == true)
    }

    @Test("isMaxed returns true at level 2 when maxLevel3Items cap is reached")
    func isMaxedAtLevel2WhenCapReached() {
        var state = PlayerSkillState()
        for i in 0..<GameConfig.maxLevel3Items {
            let s = makeSkill(id: "cap\(i)", type: .weapon)
            state.upgrade(s); state.upgrade(s); state.upgrade(s)
        }
        let skill = makeSkill(id: "level2", type: .powerUp)
        state.upgrade(skill); state.upgrade(skill)
        #expect(state.isMaxed(skill) == true)
    }

    private func makeSkill(id: String, type: SkillType) -> Skill {
        Skill(id: id, name: id, type: type, iconName: "", maxLevel: 3)
    }
}
