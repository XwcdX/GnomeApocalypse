import Testing
import SpriteKit
@testable import GnomeApocalypse

@Suite("PlayerEntity.applySkill")
@MainActor
struct PlayerEntityApplySkillTests {

    private func makePlayer(health: Int = 100) -> PlayerEntity {
        PlayerEntity(texture: SKTexture(), health: health)
    }

    private let wardenThorns = Skill(id: "warden_thorns", name: "Warden Thorns", type: .weapon, iconName: "", maxLevel: 3)
    private let lightningStrike = Skill(id: "lightning_strike", name: "Lightning Strike", type: .weapon, iconName: "", maxLevel: 3)
    private let poisonousMist = Skill(id: "poisonous_mist", name: "Poisonous Mist", type: .weapon, iconName: "", maxLevel: 3)
    private let tome = Skill(id: "ancient_tome", name: "Ancient Tome", type: .powerUp, iconName: "", maxLevel: 3)
    private let fruit = Skill(id: "spirit_fruit", name: "Spirit Fruit", type: .powerUp, iconName: "", maxLevel: 3)
    private let bloom = Skill(id: "life_bloom", name: "Life Bloom", type: .powerUp, iconName: "", maxLevel: 3)

    private func compoundedMultiplier(_ rates: [CGFloat], through level: Int) -> CGFloat {
        rates.prefix(level).reduce(1.0) { $0 * (1.0 + $1) }
    }

    // MARK: - Warden Thorns

    @Test("warden_thorns sets wardenThornCount per level")
    func wardenThornsSetsCount() {
        let player = makePlayer()
        player.applySkill(wardenThorns)
        #expect(player.wardenThornCount == SkillConfig.wardenThornCountByLevel[0])
        player.applySkill(wardenThorns)
        #expect(player.wardenThornCount == SkillConfig.wardenThornCountByLevel[1])
        player.applySkill(wardenThorns)
        #expect(player.wardenThornCount == SkillConfig.wardenThornCountByLevel[2])
    }

    // MARK: - Lightning Strike

    @Test("lightning_strike sets cooldown and strike count per level")
    func lightningSetsProperties() {
        let player = makePlayer()
        player.applySkill(lightningStrike)
        #expect(player.lightningCooldown == SkillConfig.lightningCooldownByLevel[0])
        #expect(player.lightningStrikeCount == SkillConfig.lightningStrikeCountByLevel[0])
        player.applySkill(lightningStrike)
        #expect(player.lightningCooldown == SkillConfig.lightningCooldownByLevel[1])
        #expect(player.lightningStrikeCount == SkillConfig.lightningStrikeCountByLevel[1])
        player.applySkill(lightningStrike)
        #expect(player.lightningCooldown == SkillConfig.lightningCooldownByLevel[2])
        #expect(player.lightningStrikeCount == SkillConfig.lightningStrikeCountByLevel[2])
    }

    // MARK: - Poisonous Mist

    @Test("poisonous_mist sets cooldown and cloud count per level")
    func mistSetsProperties() {
        let player = makePlayer()
        player.applySkill(poisonousMist)
        #expect(player.mistCooldown == SkillConfig.mistCooldownByLevel[0])
        #expect(player.mistCloudCount == SkillConfig.mistCountByLevel[0])
        player.applySkill(poisonousMist)
        #expect(player.mistCooldown == SkillConfig.mistCooldownByLevel[1])
        #expect(player.mistCloudCount == SkillConfig.mistCountByLevel[1])
        player.applySkill(poisonousMist)
        #expect(player.mistCooldown == SkillConfig.mistCooldownByLevel[2])
        #expect(player.mistCloudCount == SkillConfig.mistCountByLevel[2])
    }

    // MARK: - Ancient Tome

    @Test("Ancient Tome L1 compounds configured attack-speed rate")
    func tomeL1() {
        let player = makePlayer()
        player.applySkill(tome)
        #expect(player.attackSpeedMultiplier == compoundedMultiplier(SkillConfig.ancientTomeAttackSpeedBonusRates, through: 1))
        #expect(player.skillState.level(of: tome.id, type: .powerUp) == 1)
    }

    @Test("Ancient Tome L2 compounds configured attack-speed rates")
    func tomeL2() {
        let player = makePlayer()
        player.applySkill(tome); player.applySkill(tome)
        #expect(player.attackSpeedMultiplier == compoundedMultiplier(SkillConfig.ancientTomeAttackSpeedBonusRates, through: 2))
        #expect(player.skillState.level(of: tome.id, type: .powerUp) == 2)
    }

    @Test("Ancient Tome L3 compounds configured attack-speed rates")
    func tomeL3() {
        let player = makePlayer()
        player.applySkill(tome); player.applySkill(tome); player.applySkill(tome)
        #expect(player.attackSpeedMultiplier == compoundedMultiplier(SkillConfig.ancientTomeAttackSpeedBonusRates, through: 3))
        #expect(player.skillState.level(of: tome.id, type: .powerUp) == 3)
    }

    @Test("Ancient Tome reapply at max level is ignored")
    func tomeReapplyAtMaxLevelIgnored() {
        let player = makePlayer()
        player.applySkill(tome); player.applySkill(tome); player.applySkill(tome); player.applySkill(tome)
        #expect(player.attackSpeedMultiplier == compoundedMultiplier(SkillConfig.ancientTomeAttackSpeedBonusRates, through: 3))
        #expect(player.skillState.level(of: tome.id, type: .powerUp) == tome.maxLevel)
    }

    // MARK: - Spirit Fruit

    @Test("Spirit Fruit L1 compounds configured movement-speed rate")
    func fruitL1() {
        let player = makePlayer()
        player.applySkill(fruit)
        #expect(player.movementSpeedMultiplier == compoundedMultiplier(SkillConfig.spiritFruitMovementSpeedBonusRates, through: 1))
        #expect(player.skillState.level(of: fruit.id, type: .powerUp) == 1)
    }

    @Test("Spirit Fruit L2 compounds configured movement-speed rates")
    func fruitL2() {
        let player = makePlayer()
        player.applySkill(fruit); player.applySkill(fruit)
        #expect(player.movementSpeedMultiplier == compoundedMultiplier(SkillConfig.spiritFruitMovementSpeedBonusRates, through: 2))
        #expect(player.skillState.level(of: fruit.id, type: .powerUp) == 2)
    }

    @Test("Spirit Fruit L3 compounds configured movement-speed rates")
    func fruitL3() {
        let player = makePlayer()
        player.applySkill(fruit); player.applySkill(fruit); player.applySkill(fruit)
        #expect(player.movementSpeedMultiplier == compoundedMultiplier(SkillConfig.spiritFruitMovementSpeedBonusRates, through: 3))
        #expect(player.skillState.level(of: fruit.id, type: .powerUp) == 3)
    }

    @Test("Spirit Fruit reapply at max level is ignored")
    func fruitReapplyAtMaxLevelIgnored() {
        let player = makePlayer()
        player.applySkill(fruit); player.applySkill(fruit); player.applySkill(fruit); player.applySkill(fruit)
        #expect(player.movementSpeedMultiplier == compoundedMultiplier(SkillConfig.spiritFruitMovementSpeedBonusRates, through: 3))
        #expect(player.skillState.level(of: fruit.id, type: .powerUp) == fruit.maxLevel)
    }

    // MARK: - Life Bloom

    @Test("Life Bloom L1 raises max and current health")
    func bloomL1() {
        let player = makePlayer(health: 100)
        player.applySkill(bloom)
        #expect(player.health.maximum == 110)
        #expect(player.health.current == 110)
        #expect(player.skillState.level(of: bloom.id, type: .powerUp) == 1)
    }

    @Test("Life Bloom L2 compounds from current max health")
    func bloomL1ToL2() {
        let player = makePlayer(health: 100)
        player.applySkill(bloom); player.applySkill(bloom)
        #expect(player.health.maximum == 132)
        #expect(player.health.current == 132)
        #expect(player.skillState.level(of: bloom.id, type: .powerUp) == 2)
    }

    @Test("Life Bloom L3 compounds and rounds nearest after each upgrade")
    func bloomL1ToL3() {
        let player = makePlayer(health: 100)
        player.applySkill(bloom); player.applySkill(bloom); player.applySkill(bloom)
        #expect(player.health.maximum == 172)
        #expect(player.health.current == 172)
        #expect(player.skillState.level(of: bloom.id, type: .powerUp) == 3)
    }

    @Test("Life Bloom reapply at max level is ignored")
    func bloomReapplyAtMaxLevelIgnored() {
        let player = makePlayer(health: 100)
        player.applySkill(bloom); player.applySkill(bloom); player.applySkill(bloom); player.applySkill(bloom)
        #expect(player.health.maximum == 172)
        #expect(player.health.current == 172)
        #expect(player.skillState.level(of: bloom.id, type: .powerUp) == bloom.maxLevel)
    }
}
