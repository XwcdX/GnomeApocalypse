import SpriteKit
import Testing

@testable import Greed

@MainActor
@Suite("SpawnSystem")
struct SpawnSystemTests {
    @Test("orb mist explosion spawns budgeted MiniBoss outside camera")
    func orbMistExplosionSpawnsBudgetedMiniBossOutsideCamera() throws {
        let harness = makeHarness()

        harness.spawnSystem.spawnEssenceOrb(at: .zero)
        harness.spawnSystem.update(
            deltaTime: GameConfig.smallOrbEvolveTime,
            activeBudgetUsed: harness.director.currentBudget
        )
        harness.spawnSystem.update(
            deltaTime: GameConfig.grownOrbEvolveTime,
            activeBudgetUsed: 0
        )
        #expect(children(of: Grumble.self, in: harness.layer).isEmpty)
        harness.spawnSystem.update(
            deltaTime: GameConfig.redOrbEvolveTime,
            activeBudgetUsed: 0
        )

        let miniBoss = try #require(children(of: Grumble.self, in: harness.layer).first)
        #expect(!harness.camera.visibleRect.contains(miniBoss.position))
        #expect(children(of: EssenceOrbComponent.self, in: harness.layer).isEmpty)
    }

    @Test("orb mist explosion consumes orb without MiniBoss when budget is full")
    func orbMistExplosionDoesNotSpawnMiniBossWhenBudgetIsFull() {
        let harness = makeHarness()

        harness.spawnSystem.spawnEssenceOrb(at: .zero)
        harness.spawnSystem.update(
            deltaTime: GameConfig.smallOrbEvolveTime,
            activeBudgetUsed: harness.director.currentBudget
        )
        harness.spawnSystem.update(
            deltaTime: GameConfig.grownOrbEvolveTime,
            activeBudgetUsed: harness.director.currentBudget
        )
        harness.spawnSystem.update(
            deltaTime: GameConfig.redOrbEvolveTime,
            activeBudgetUsed: harness.director.currentBudget
        )

        #expect(children(of: Grumble.self, in: harness.layer).isEmpty)
        #expect(children(of: EssenceOrbComponent.self, in: harness.layer).isEmpty)
    }

    @Test("boss stage pauses regular spawning and spawns one Grand outside camera")
    func bossStageSpawnsSingleBossAndPausesRegularSpawning() throws {
        let harness = makeHarness()
        harness.director.update(deltaTime: GameConfig.bossSpawnInterval, activeBudgetUsed: 0)

        harness.spawnSystem.update(deltaTime: 0.1, activeBudgetUsed: 0)
        harness.spawnSystem.update(deltaTime: 2.1, activeBudgetUsed: 0)

        let boss = try #require(children(of: Grand.self, in: harness.layer).first)
        #expect(children(of: Grand.self, in: harness.layer).count == 1)
        #expect(children(of: Grove.self, in: harness.layer).isEmpty)
        #expect(!harness.camera.visibleRect.contains(boss.position))
    }

    @Test("boss minions spawn around boss outside Director budget")
    func bossMinionsSpawnAroundBossOutsideDirectorBudget() {
        let harness = makeHarness()
        let bossPosition = CGPoint(x: 120, y: -40)

        harness.spawnSystem.spawnBossMinions(count: 3, around: bossPosition)

        let minions = children(of: Grove.self, in: harness.layer)
        #expect(minions.count == 3)
        #expect(minions.allSatisfy { $0.gameScene === harness.scene })
    }

    @Test("regular spawn respects active budget usage")
    func regularSpawnRespectsActiveBudgetUsage() {
        let harness = makeHarness()

        harness.spawnSystem.update(
            deltaTime: GameConfig.baseSpawnInterval + 0.1,
            activeBudgetUsed: harness.director.currentBudget
        )

        #expect(children(of: Grove.self, in: harness.layer).isEmpty)
    }

    @Test("wave escalation shortens interval and increases gnome count")
    func waveEscalationShortensIntervalAndIncreasesGnomeCount() {
        let harness = makeHarness()

        #expect(harness.spawnSystem.currentWaveIndex == 0)
        #expect(harness.spawnSystem.currentSpawnInterval == GameConfig.baseSpawnInterval)
        #expect(harness.spawnSystem.currentGnomesPerSpawn == GameConfig.baseGnomesPerSpawn)

        harness.spawnSystem.update(
            deltaTime: GameConfig.spawnWaveEscalationInterval * 2,
            activeBudgetUsed: 0
        )

        #expect(harness.spawnSystem.currentWaveIndex == 2)
        #expect(harness.spawnSystem.currentSpawnInterval < GameConfig.baseSpawnInterval)
        #expect(harness.spawnSystem.currentGnomesPerSpawn == GameConfig.baseGnomesPerSpawn + 2)
        #expect(children(of: Grove.self, in: harness.layer).count == GameConfig.baseGnomesPerSpawn + 2)
    }

    @Test("wave batch respects remaining Director budget")
    func waveBatchRespectsRemainingDirectorBudget() {
        let harness = makeHarness()
        let remainingBudget = 2

        harness.spawnSystem.update(
            deltaTime: GameConfig.spawnWaveEscalationInterval * 10,
            activeBudgetUsed: harness.director.currentBudget - remainingBudget
        )

        #expect(harness.spawnSystem.currentGnomesPerSpawn == GameConfig.maximumGnomesPerSpawn)
        #expect(children(of: Grove.self, in: harness.layer).count == remainingBudget)
    }

    private func makeHarness() -> Harness {
        let scene = GameScene(size: GameConfig.cameraViewportSize)
        let layer = SKNode()
        let cameraNode = SKCameraNode()
        cameraNode.position = .zero
        scene.addChild(cameraNode)
        scene.addChild(layer)

        let camera = CameraSystem(cameraNode: cameraNode, viewportSize: GameConfig.cameraViewportSize)
        let director = DirectorSystem()
        let spawnSystem = SpawnSystem(entityLayer: layer, cameraSystem: camera, directorSystem: director)
        return Harness(scene: scene, layer: layer, camera: camera, director: director, spawnSystem: spawnSystem)
    }

    private func children<T>(of type: T.Type, in node: SKNode) -> [T] {
        node.children.compactMap { $0 as? T }
    }

    private struct Harness {
        let scene: GameScene
        let layer: SKNode
        let camera: CameraSystem
        let director: DirectorSystem
        let spawnSystem: SpawnSystem
    }
}
