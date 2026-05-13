import SpriteKit
import Testing

@testable import Greed

@MainActor
@Suite("EssenceOrbComponent")
struct EssenceOrbComponentTests {
    @Test("orb stays small before evolve time")
    func orbStaysSmallBeforeEvolveTime() {
        let orb = EssenceOrbComponent()
        let cameraSystem = makeCameraSystem()

        let didExplode = orb.update(
            deltaTime: GameConfig.smallOrbEvolveTime - 0.1,
            cameraSystem: cameraSystem
        )

        #expect(didExplode == false)
        #expect(orb.state == .small)
        #expect(orb.essenceValue == GameConfig.smallOrbEssenceValue)
        #expect(orb.size.height > 0)
        #expect(orb.physicsBody?.categoryBitMask == PhysicsCategory.forestEssenceOrb)
    }

    @Test("orb grows at evolve time")
    func orbGrowsAtEvolveTime() {
        let orb = EssenceOrbComponent()
        let cameraSystem = makeCameraSystem()
        let smallSize = orb.size

        let didExplode = orb.update(
            deltaTime: GameConfig.smallOrbEvolveTime,
            cameraSystem: cameraSystem
        )

        #expect(didExplode == false)
        #expect(orb.state == .grown)
        #expect(orb.essenceValue == GameConfig.grownOrbEssenceValue)
        #expect(orb.size.height > smallSize.height)
        #expect(orb.physicsBody?.categoryBitMask == PhysicsCategory.forestEssenceOrb)
        #expect(orb.physicsBody?.contactTestBitMask == PhysicsCategory.player)
    }

    @Test("grown orb becomes red high-value tier")
    func grownOrbBecomesRedHighValueTier() {
        let orb = EssenceOrbComponent()
        let cameraSystem = makeCameraSystem()

        _ = orb.update(deltaTime: GameConfig.smallOrbEvolveTime, cameraSystem: cameraSystem)
        let grownSize = orb.size

        let didExplode = orb.update(
            deltaTime: GameConfig.grownOrbEvolveTime,
            cameraSystem: cameraSystem
        )

        #expect(didExplode == false)
        #expect(orb.state == .red)
        #expect(orb.essenceValue == GameConfig.redOrbEssenceValue)
        #expect(orb.size.height > grownSize.height)
        #expect(orb.physicsBody?.categoryBitMask == PhysicsCategory.forestEssenceOrb)
    }

    @Test("red orb becomes mist explosion and emits VFX node")
    func redOrbBecomesMistExplosion() throws {
        let parent = SKNode()
        let orb = EssenceOrbComponent()
        let cameraSystem = makeCameraSystem()
        parent.addChild(orb)

        _ = orb.update(deltaTime: GameConfig.smallOrbEvolveTime, cameraSystem: cameraSystem)
        let didExplodeEarly = orb.update(
            deltaTime: GameConfig.grownOrbEvolveTime - 0.1,
            cameraSystem: cameraSystem
        )

        #expect(didExplodeEarly == false)
        #expect(orb.state == .grown)

        let didExplodeAtRedTier = orb.update(deltaTime: 0.1, cameraSystem: cameraSystem)
        #expect(didExplodeAtRedTier == false)
        #expect(orb.state == .red)

        let didExplodeFromRedEarly = orb.update(
            deltaTime: GameConfig.redOrbEvolveTime - 0.1,
            cameraSystem: cameraSystem
        )
        #expect(didExplodeFromRedEarly == false)
        #expect(orb.state == .red)

        let didExplode = orb.update(deltaTime: 0.1, cameraSystem: cameraSystem)
        let mistBurst = try #require(parent.children.compactMap { $0 as? SKSpriteNode }.filter { $0 !== orb }.first)

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
