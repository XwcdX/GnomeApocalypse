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
        #expect(orb.essenceTier == .green)
        #expect(orb.visualPhase == .collectible)
        #expect(orb.essenceValue == GameConfig.smallOrbEssenceValue)
        #expect(orb.currentTextureName == "forest_essence_green")
        #expect(orb.size.height > 0)
        #expect(orb.physicsBody?.categoryBitMask == PhysicsCategory.forestEssenceOrb)
    }

    @Test("orb sorts behind Grove standing on same position")
    func orbSortsBehindGroveStandingOnSamePosition() {
        let orb = EssenceOrbComponent()
        let enemy = Grove()

        let orbZ = worldZPosition(for: orb)
        let enemyZ = worldZPosition(for: enemy)

        #expect(orbZ < enemyZ)
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
        #expect(orb.essenceTier == .blue)
        #expect(orb.visualPhase == .collectible)
        #expect(orb.essenceValue == GameConfig.grownOrbEssenceValue)
        #expect(orb.currentTextureName == "forest_essence_blue")
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
        #expect(orb.essenceTier == .red)
        #expect(orb.visualPhase == .collectible)
        #expect(orb.essenceValue == GameConfig.redOrbEssenceValue)
        #expect(orb.currentTextureName == "forest_essence_red")
        #expect(orb.size.height > grownSize.height)
        #expect(orb.physicsBody?.categoryBitMask == PhysicsCategory.forestEssenceOrb)
    }

    @Test("red expiry starts mutation without completing collection")
    func redExpiryStartsMutationWithoutCompletingCollection() {
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
        #expect(orb.essenceTier == .blue)
        #expect(orb.visualPhase == .collectible)

        let didExplodeAtRedTier = orb.update(deltaTime: 0.1, cameraSystem: cameraSystem)
        #expect(didExplodeAtRedTier == false)
        #expect(orb.essenceTier == .red)
        #expect(orb.visualPhase == .collectible)

        let didExplodeFromRedEarly = orb.update(
            deltaTime: GameConfig.redOrbEvolveTime - 0.1,
            cameraSystem: cameraSystem
        )
        #expect(didExplodeFromRedEarly == false)
        #expect(orb.essenceTier == .red)
        #expect(orb.visualPhase == .collectible)

        let didCompleteMutation = orb.update(deltaTime: 0.1, cameraSystem: cameraSystem)

        #expect(didCompleteMutation == false)
        #expect(orb.essenceTier == .red)
        #expect(orb.visualPhase == .mutating)
        #expect(orb.currentTextureName == "vfx_forest_essence_mutation_000")
        #expect(orb.parent === parent)
        #expect(orb.isHidden == false)
        #expect(orb.physicsBody == nil)
        #expect(orb.action(forKey: "idleBob") == nil)
    }

    @Test("mutation completes after final VFX frame")
    func mutationCompletesAfterFinalVFXFrame() {
        let orb = EssenceOrbComponent()
        let cameraSystem = makeCameraSystem()

        _ = orb.update(deltaTime: GameConfig.smallOrbEvolveTime, cameraSystem: cameraSystem)
        _ = orb.update(deltaTime: GameConfig.grownOrbEvolveTime, cameraSystem: cameraSystem)
        let didCompleteAtStart = orb.update(deltaTime: GameConfig.redOrbEvolveTime, cameraSystem: cameraSystem)
        let didCompleteEarly = orb.update(
            deltaTime: EssenceOrbComponent.mutationDuration - 0.01,
            cameraSystem: cameraSystem
        )
        let didCompleteAfterFinalFrame = orb.update(deltaTime: 0.01, cameraSystem: cameraSystem)

        #expect(didCompleteAtStart == false)
        #expect(didCompleteEarly == false)
        #expect(didCompleteAfterFinalFrame == true)
        #expect(orb.essenceTier == .red)
        #expect(orb.visualPhase == .mutating)
    }

    private func makeCameraSystem() -> CameraSystem {
        CameraSystem(cameraNode: SKCameraNode(), viewportSize: GameConfig.cameraViewportSize)
    }

    private func worldZPosition(for sprite: SKSpriteNode) -> CGFloat {
        let footY = sprite.position.y - sprite.size.height / 2
        let sortPriority = (sprite as? WorldLayerSortable)?.worldSortPriority ?? 0
        return Layer.worldZPosition(
            forFootY: footY,
            mapHeight: GameConfig.mapSize.height,
            sortPriority: sortPriority
        )
    }
}
