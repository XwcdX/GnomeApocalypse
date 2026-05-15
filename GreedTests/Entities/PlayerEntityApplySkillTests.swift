import Testing
import SpriteKit

@testable import Greed

@Suite("PlayerEntity.applySkill")
@MainActor
struct PlayerEntityApplySkillTests {
    private func makePlayer(health: Int = 100) -> PlayerEntity {
        PlayerEntity(texture: SKTexture(), health: health)
    }

    private let tome = Skill(id: "ancient_tome", name: "Ancient Tome", type: .powerUp, iconName: "", maxLevel: 3)
    private let fruit = Skill(id: "spirit_fruit", name: "Spirit Fruit", type: .powerUp, iconName: "", maxLevel: 3)
    private let bloom = Skill(id: "life_bloom", name: "Life Bloom", type: .powerUp, iconName: "", maxLevel: 3)

    // MARK: - Ancient Tome

    @Test("Ancient Tome L1 sets attackSpeedMultiplier to config[0]")
    func tomeL1() {
        let player = makePlayer()
        player.applySkill(tome)
        #expect(player.attackSpeedMultiplier == CGFloat(SkillConfig.ancientTomeAttackSpeedMultipliers[0]))
        #expect(player.skillState.level(of: tome.id, type: .powerUp) == 1)
    }

    @Test("Ancient Tome L2 sets attackSpeedMultiplier to config[1]")
    func tomeL2() {
        let player = makePlayer()
        player.applySkill(tome)
        player.applySkill(tome)
        #expect(player.attackSpeedMultiplier == CGFloat(SkillConfig.ancientTomeAttackSpeedMultipliers[1]))
        #expect(player.skillState.level(of: tome.id, type: .powerUp) == 2)
    }

    @Test("Ancient Tome L3 sets attackSpeedMultiplier to config[2]")
    func tomeL3() {
        let player = makePlayer()
        player.applySkill(tome)
        player.applySkill(tome)
        player.applySkill(tome)
        #expect(player.attackSpeedMultiplier == CGFloat(SkillConfig.ancientTomeAttackSpeedMultipliers[2]))
        #expect(player.skillState.level(of: tome.id, type: .powerUp) == 3)
    }

    // MARK: - Spirit Fruit

    @Test("Spirit Fruit L1 sets movementSpeedMultiplier to config[0]")
    func fruitL1() {
        let player = makePlayer()
        player.applySkill(fruit)
        #expect(player.movementSpeedMultiplier == CGFloat(SkillConfig.spiritFruitMovementSpeedMultipliers[0]))
        #expect(player.skillState.level(of: fruit.id, type: .powerUp) == 1)
    }

    @Test("Spirit Fruit L2 sets movementSpeedMultiplier to config[1]")
    func fruitL2() {
        let player = makePlayer()
        player.applySkill(fruit)
        player.applySkill(fruit)
        #expect(player.movementSpeedMultiplier == CGFloat(SkillConfig.spiritFruitMovementSpeedMultipliers[1]))
        #expect(player.skillState.level(of: fruit.id, type: .powerUp) == 2)
    }

    @Test("Spirit Fruit L3 sets movementSpeedMultiplier to config[2]")
    func fruitL3() {
        let player = makePlayer()
        player.applySkill(fruit)
        player.applySkill(fruit)
        player.applySkill(fruit)
        #expect(player.movementSpeedMultiplier == CGFloat(SkillConfig.spiritFruitMovementSpeedMultipliers[2]))
        #expect(player.skillState.level(of: fruit.id, type: .powerUp) == 3)
    }

    // MARK: - Life Bloom (delta math)

    @Test("Life Bloom L1 raises max + current health by config[0]")
    func bloomL1() {
        let base = 100
        let player = makePlayer(health: base)
        player.applySkill(bloom)
        let expected = base + SkillConfig.lifeBloomMaxHealthBonuses[0]
        #expect(player.health.maximum == expected)
        #expect(player.health.current == expected)
        #expect(player.skillState.level(of: bloom.id, type: .powerUp) == 1)
    }

    @Test("Life Bloom L1→L2 lands at config[1] total, not cumulative sum")
    func bloomL1ToL2() {
        let base = 100
        let player = makePlayer(health: base)
        player.applySkill(bloom)
        player.applySkill(bloom)
        let expected = base + SkillConfig.lifeBloomMaxHealthBonuses[1]
        #expect(player.health.maximum == expected)
        #expect(player.health.current == expected)
        #expect(player.skillState.level(of: bloom.id, type: .powerUp) == 2)
    }

    @Test("Life Bloom L1→L2→L3 lands at config[2] total, not cumulative sum")
    func bloomL1ToL3() {
        let base = 100
        let player = makePlayer(health: base)
        player.applySkill(bloom)
        player.applySkill(bloom)
        player.applySkill(bloom)
        let expected = base + SkillConfig.lifeBloomMaxHealthBonuses[2]
        #expect(player.health.maximum == expected)
        #expect(player.health.current == expected)
        #expect(player.skillState.level(of: bloom.id, type: .powerUp) == 3)
    }

    @Test("Life Bloom reapply at max level is ignored")
    func bloomReapplyAtMaxLevelIgnored() {
        let base = 100
        let player = makePlayer(health: base)
        player.applySkill(bloom)
        player.applySkill(bloom)
        player.applySkill(bloom)
        player.applySkill(bloom)

        let expected = base + SkillConfig.lifeBloomMaxHealthBonuses[2]
        #expect(player.health.maximum == expected)
        #expect(player.health.current == expected)
        #expect(player.skillState.level(of: bloom.id, type: .powerUp) == bloom.maxLevel)
    }
}
