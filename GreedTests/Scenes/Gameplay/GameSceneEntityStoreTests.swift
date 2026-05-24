import SpriteKit
import Testing

@testable import Greed

@MainActor
@Suite("GameSceneEntityStore")
struct GameSceneEntityStoreTests {
    @Test("average health fraction aggregates tracked players")
    func averageHealthFractionAggregatesTrackedPlayers() {
        let store = GameSceneEntityStore()
        let fullHealthPlayer = makePlayer(health: 100)
        let damagedPlayer = makePlayer(health: 100)
        damagedPlayer.takeDamage(50)

        store.register(player: fullHealthPlayer)
        store.register(player: damagedPlayer)

        #expect(store.averagePlayerHealthFraction == 0.75)
    }

    @Test("visible enemies ignore detached nodes")
    func visibleEnemiesIgnoreDetachedNodes() {
        let store = GameSceneEntityStore()
        let layer = SKNode()
        let visibleEnemy = makeEnemy(at: CGPoint(x: 20, y: 30))
        let detachedEnemy = makeEnemy(at: CGPoint(x: 10, y: 10))
        layer.addChild(visibleEnemy)

        store.register(enemy: visibleEnemy)
        store.register(enemy: detachedEnemy)

        let visible = store.visibleEnemies(cameraPosition: .zero, viewportSize: CGSize(width: 200, height: 200), margin: 0)

        #expect(visible.count == 1)
        #expect(visible.first === visibleEnemy)
    }

    @Test("magnet target returns nearest attached player inside radius")
    func magnetTargetReturnsNearestAttachedPlayerInsideRadius() {
        let store = GameSceneEntityStore()
        let layer = SKNode()
        let nearPlayer = makePlayer(at: CGPoint(x: 8, y: 0))
        let farPlayer = makePlayer(at: CGPoint(x: 20, y: 0))
        let detachedPlayer = makePlayer(at: CGPoint(x: 2, y: 0))
        layer.addChild(nearPlayer)
        layer.addChild(farPlayer)

        store.register(player: farPlayer)
        store.register(player: detachedPlayer)
        store.register(player: nearPlayer)

        #expect(store.magnetTargetForOrb(at: .zero, radius: 12) == nearPlayer.position)
    }

    @Test("nearest player uses toroidal distance")
    func nearestPlayerUsesToroidalDistance() {
        let store = GameSceneEntityStore()
        let wrappedPlayer = makePlayer(at: CGPoint(x: -GameConfig.mapSize.width / 2 + 5, y: 0))
        let directPlayer = makePlayer(at: CGPoint(x: GameConfig.mapSize.width / 2 - 100, y: 0))
        store.register(player: directPlayer)
        store.register(player: wrappedPlayer)

        let query = CGPoint(x: GameConfig.mapSize.width / 2 - 5, y: 0)

        #expect(store.nearestPlayerPosition(to: query) == wrappedPlayer.position)
    }

    private func makePlayer(at position: CGPoint = .zero, health: Int = 100) -> PlayerEntity {
        let player = PlayerEntity(texture: SKTexture(), health: health)
        player.position = position
        return player
    }

    private func makeEnemy(at position: CGPoint) -> EnemyEntity {
        let enemy = EnemyEntity(texture: SKTexture(), displaySize: CGSize(width: 20, height: 20), health: 10)
        enemy.position = position
        return enemy
    }
}
