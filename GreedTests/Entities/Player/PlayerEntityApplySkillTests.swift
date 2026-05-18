import Testing
import SpriteKit
@testable import Greed

@Suite("PlayerEntity.applySkill")
@MainActor
struct PlayerEntityApplySkillTests {

    private func makePlayer() -> PlayerEntity {
        let texture = SKTexture()
        return PlayerEntity(texture: texture, health: 100)
    }

    private static let orbitingSpell = Skill(id: "orbiting_spell", name: "Orbiting Spell", type: .weapon, iconName: "", maxLevel: 3)
    private static let lightningStrike = Skill(id: "lightning_strike", name: "Lightning Strike", type: .weapon, iconName: "", maxLevel: 3)
    private static let poisonousMist = Skill(id: "poisonous_mist", name: "Poisonous Mist", type: .weapon, iconName: "", maxLevel: 3)
    private static let ancientTome = Skill(id: "ancient_tome", name: "Ancient Tome", type: .powerUp, iconName: "", maxLevel: 3)
    private static let spiritFruit = Skill(id: "spirit_fruit", name: "Spirit Fruit", type: .powerUp, iconName: "", maxLevel: 3)
    private static let lifeBloom = Skill(id: "life_bloom", name: "Life Bloom", type: .powerUp, iconName: "", maxLevel: 3)

    @Test("orbiting_spell sets orbitCount per level")
    func orbitingSpellSetsCount() {
        let player = makePlayer()
        player.applySkill(Self.orbitingSpell)
        #expect(player.orbitCount == SkillConfig.orbitCountByLevel[0])
        player.applySkill(Self.orbitingSpell)
        #expect(player.orbitCount == SkillConfig.orbitCountByLevel[1])
        player.applySkill(Self.orbitingSpell)
        #expect(player.orbitCount == SkillConfig.orbitCountByLevel[2])
    }

    @Test("lightning_strike sets cooldown + strike count per level")
    func lightningSetsProperties() {
        let player = makePlayer()
        player.applySkill(Self.lightningStrike)
        #expect(player.lightningCooldown == SkillConfig.lightningCooldownByLevel[0])
        #expect(player.lightningStrikeCount == SkillConfig.lightningStrikeCountByLevel[0])

        player.applySkill(Self.lightningStrike)
        #expect(player.lightningCooldown == SkillConfig.lightningCooldownByLevel[1])
        #expect(player.lightningStrikeCount == SkillConfig.lightningStrikeCountByLevel[1])

        player.applySkill(Self.lightningStrike)
        #expect(player.lightningCooldown == SkillConfig.lightningCooldownByLevel[2])
        #expect(player.lightningStrikeCount == SkillConfig.lightningStrikeCountByLevel[2])
    }

    @Test("poisonous_mist sets cooldown + cloud count per level")
    func mistSetsProperties() {
        let player = makePlayer()
        player.applySkill(Self.poisonousMist)
        #expect(player.mistCooldown == SkillConfig.mistCooldownByLevel[0])
        #expect(player.mistCloudCount == SkillConfig.mistCountByLevel[0])

        player.applySkill(Self.poisonousMist)
        #expect(player.mistCooldown == SkillConfig.mistCooldownByLevel[1])
        #expect(player.mistCloudCount == SkillConfig.mistCountByLevel[1])

        player.applySkill(Self.poisonousMist)
        #expect(player.mistCooldown == SkillConfig.mistCooldownByLevel[2])
        #expect(player.mistCloudCount == SkillConfig.mistCountByLevel[2])
    }

    @Test("ancient_tome scales attackSpeedMultiplier")
    func attackSpeedScales() {
        let player = makePlayer()
        player.applySkill(Self.ancientTome)
        #expect(abs(player.attackSpeedMultiplier - 1.1) < 0.001)
        player.applySkill(Self.ancientTome)
        #expect(abs(player.attackSpeedMultiplier - 1.2) < 0.001)
        player.applySkill(Self.ancientTome)
        #expect(abs(player.attackSpeedMultiplier - 1.3) < 0.001)
    }

    @Test("spirit_fruit scales movementSpeedMultiplier")
    func movementSpeedScales() {
        let player = makePlayer()
        player.applySkill(Self.spiritFruit)
        #expect(abs(player.movementSpeedMultiplier - 1.1) < 0.001)
        player.applySkill(Self.spiritFruit)
        #expect(abs(player.movementSpeedMultiplier - 1.2) < 0.001)
        player.applySkill(Self.spiritFruit)
        #expect(abs(player.movementSpeedMultiplier - 1.3) < 0.001)
    }

    @Test("life_bloom increases health maximum on first pick")
    func lifeBloomIncreasesMax() {
        let player = makePlayer()
        let startingMax = player.health.maximum
        player.applySkill(Self.lifeBloom)
        #expect(player.health.maximum == startingMax + SkillConfig.healthBoostPerLevel)
    }
}
