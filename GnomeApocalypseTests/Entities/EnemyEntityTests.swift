import SpriteKit
import Testing

@testable import GnomeApocalypse

@MainActor
@Suite("EnemyEntity")
struct EnemyEntityTests {
    @Test("enemy physics bodies collide with other enemies")
    func enemyPhysicsBodiesCollideWithOtherEnemies() throws {
        let enemy = Grove()
        let body = try #require(enemy.physicsBody)

        #expect(body.categoryBitMask == PhysicsCategory.enemy)
        #expect(body.collisionBitMask & PhysicsCategory.enemy != 0)
        #expect(body.restitution == 0)
    }
}
