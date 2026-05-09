import MetalKit
import SpriteKit
import Testing
@testable import Greed

@MainActor
struct EnemyProjectilePoolTests {

    @Test func spawnEnemyProjectileCreatesActiveEnemyProjectile() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())

        let view = MTKView(frame: CGRect(origin: .zero, size: CGSize(width: 640, height: 360)), device: device)
        let scene = GameScene(size: view.bounds.size)
        scene.setup(view: view)

        scene.spawnEnemyProjectile(
            at: .zero,
            direction: CGVector(dx: 1, dy: 0),
            damage: GameConfig.miniBossProjectileDamage
        )

        let projectile = try #require(firstEnemyProjectile(in: scene))
        #expect(projectile.isActive)
        #expect(projectile.damage == GameConfig.miniBossProjectileDamage)
        #expect(projectile.physicsBody?.categoryBitMask == PhysicsCategory.enemyProjectile)
        #expect(projectile.physicsBody?.contactTestBitMask == PhysicsCategory.player)

        projectile.update(deltaTime: 0.1)
        #expect(projectile.position.x > 0)
    }

    private func firstEnemyProjectile(in node: SKNode) -> Projectile? {
        for child in node.children {
            if let projectile = child as? Projectile,
               projectile.physicsBody?.categoryBitMask == PhysicsCategory.enemyProjectile {
                return projectile
            }

            if let projectile = firstEnemyProjectile(in: child) {
                return projectile
            }
        }

        return nil
    }
}
