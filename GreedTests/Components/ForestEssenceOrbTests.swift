import SpriteKit
import Testing

@testable import Greed

@MainActor
@Suite("ForestEssenceOrb")
struct ForestEssenceOrbTests {
    @Test("orb stays small before evolve time")
    func orbStaysSmallBeforeEvolveTime() {
        let orb = ForestEssenceOrb(essenceValue: GameConfig.orbBaseEssenceValue)
        let cameraSystem = makeCameraSystem()

        let didExplode = orb.update(
            deltaTime: GameConfig.orbEvolveTime - 0.1,
            cameraSystem: cameraSystem
        )

        #expect(didExplode == false)
        #expect(orb.state == .small)
        #expect(orb.essenceValue == GameConfig.orbBaseEssenceValue)
        #expect(orb.size == CGSize(width: 16, height: 16))
        #expect(orb.physicsBody?.categoryBitMask == PhysicsCategory.forestEssenceOrb)
    }

    @Test("orb grows at evolve time")
    func orbGrowsAtEvolveTime() {
        let orb = ForestEssenceOrb(essenceValue: GameConfig.orbBaseEssenceValue)
        let cameraSystem = makeCameraSystem()

        let didExplode = orb.update(
            deltaTime: GameConfig.orbEvolveTime,
            cameraSystem: cameraSystem
        )

        #expect(didExplode == false)
        #expect(orb.state == .grown)
        #expect(orb.essenceValue == GameConfig.grownOrbEssenceValue)
        #expect(orb.size == CGSize(width: 24, height: 24))
        #expect(orb.physicsBody?.categoryBitMask == PhysicsCategory.forestEssenceOrb)
        #expect(orb.physicsBody?.contactTestBitMask == PhysicsCategory.player)
    }

    @Test("grown orb becomes mist explosion and emits placeholder VFX")
    func grownOrbBecomesMistExplosion() throws {
        let parent = SKNode()
        let orb = ForestEssenceOrb(essenceValue: GameConfig.orbBaseEssenceValue)
        let cameraSystem = makeCameraSystem()
        parent.addChild(orb)

        _ = orb.update(deltaTime: GameConfig.orbEvolveTime, cameraSystem: cameraSystem)
        let didExplodeEarly = orb.update(
            deltaTime: GameConfig.grownOrbEvolveTime - 0.1,
            cameraSystem: cameraSystem
        )

        #expect(didExplodeEarly == false)
        #expect(orb.state == .grown)

        let didExplode = orb.update(deltaTime: 0.1, cameraSystem: cameraSystem)
        let mistBurst = try #require(parent.children.compactMap { $0 as? SKShapeNode }.first)

        #expect(didExplode == true)
        #expect(orb.state == .mistExplosion)
        #expect(orb.isHidden)
        #expect(orb.physicsBody == nil)
        #expect(mistBurst.position == orb.position)
        #expect(mistBurst.parent === parent)
    }

    private func makeCameraSystem() -> CameraSystem {
        CameraSystem(cameraNode: SKCameraNode(), viewportSize: GameConfig.cameraViewportSize)
    }
}
