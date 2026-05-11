import SpriteKit
import Testing

@testable import Greed

@MainActor
@Suite("ForestEssenceOrb")
struct ForestEssenceOrbTests {
    @Test("orb stays small before evolve time")
    func orbStaysSmallBeforeEvolveTime() {
        let orb = ForestEssenceOrb()
        let cameraSystem = makeCameraSystem()

        let didExplode = orb.update(
            deltaTime: GameConfig.smallOrbEvolveTime - 0.1,
            cameraSystem: cameraSystem
        )

        #expect(didExplode == false)
        #expect(orb.state == .small)
        #expect(orb.essenceValue == GameConfig.smallOrbEssenceValue)
        #expect(orb.size == CGSize(width: 16, height: 16))
        #expect(orb.physicsBody?.categoryBitMask == PhysicsCategory.forestEssenceOrb)
    }

    @Test("orb grows at evolve time")
    func orbGrowsAtEvolveTime() {
        let orb = ForestEssenceOrb()
        let cameraSystem = makeCameraSystem()

        let didExplode = orb.update(
            deltaTime: GameConfig.smallOrbEvolveTime,
            cameraSystem: cameraSystem
        )

        #expect(didExplode == false)
        #expect(orb.state == .grown)
        #expect(orb.essenceValue == GameConfig.grownOrbEssenceValue)
        #expect(orb.size == CGSize(width: 24, height: 24))
        #expect(orb.physicsBody?.categoryBitMask == PhysicsCategory.forestEssenceOrb)
        #expect(orb.physicsBody?.contactTestBitMask == PhysicsCategory.player)
    }

    @Test("grown orb becomes red high-value tier")
    func grownOrbBecomesRedHighValueTier() throws {
        let orb = ForestEssenceOrb()
        let cameraSystem = makeCameraSystem()

        _ = orb.update(deltaTime: GameConfig.smallOrbEvolveTime, cameraSystem: cameraSystem)
        let didExplode = orb.update(
            deltaTime: GameConfig.grownOrbEvolveTime,
            cameraSystem: cameraSystem
        )

        #expect(didExplode == false)
        #expect(orb.state == .red)
        #expect(orb.essenceValue == GameConfig.redOrbEssenceValue)
        let color = try #require(orb.color.usingColorSpace(.deviceRGB))
        #expect(color.redComponent == 1)
        #expect(color.greenComponent == 0)
        #expect(color.blueComponent == 0)
        #expect(orb.size == CGSize(width: 32, height: 32))
        #expect(orb.physicsBody?.categoryBitMask == PhysicsCategory.forestEssenceOrb)
    }

    @Test("red orb becomes mist explosion and emits placeholder VFX")
    func redOrbBecomesMistExplosion() throws {
        let parent = SKNode()
        let orb = ForestEssenceOrb()
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
