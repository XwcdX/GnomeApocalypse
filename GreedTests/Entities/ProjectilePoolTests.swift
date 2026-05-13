import SpriteKit
import Testing
@testable import Greed

@MainActor
@Suite("ProjectilePool")
struct ProjectilePoolTests {

    // MARK: - Dequeue

    @Test("dequeue returns an inactive projectile")
    func dequeueReturnsInactiveProjectile() {
        let pool = makePool(size: 4)
        let projectile = pool.dequeue()
        #expect(projectile != nil)
        #expect(projectile?.isActive == false)
    }

    @Test("dequeue returns nil when all projectiles are active")
    func dequeueReturnsNilWhenExhausted() {
        let pool = makePool(size: 2)
        let parent = SKNode()
        pool.attachAll(to: parent)

        let p1 = pool.dequeue()
        p1?.activate(at: .zero, velocity: CGVector(dx: 1, dy: 0), damage: 1, lifespan: 10)
        let p2 = pool.dequeue()
        p2?.activate(at: .zero, velocity: CGVector(dx: 1, dy: 0), damage: 1, lifespan: 10)

        #expect(pool.dequeue() == nil)
    }

    // MARK: - Enqueue

    @Test("enqueue deactivates the projectile")
    func enqueueDeactivatesProjectile() {
        let pool = makePool(size: 2)
        let parent = SKNode()
        pool.attachAll(to: parent)

        guard let projectile = pool.dequeue() else { return }
        projectile.activate(at: .zero, velocity: CGVector(dx: 1, dy: 0), damage: 1, lifespan: 10)
        #expect(projectile.isActive == true)

        pool.enqueue(projectile)
        #expect(projectile.isActive == false)
    }

    @Test("dequeue after enqueue returns the recycled projectile")
    func dequeueAfterEnqueueReturnsRecycled() {
        let pool = makePool(size: 1)
        let parent = SKNode()
        pool.attachAll(to: parent)

        guard let p1 = pool.dequeue() else { return }
        p1.activate(at: .zero, velocity: CGVector(dx: 1, dy: 0), damage: 5, lifespan: 10)
        pool.enqueue(p1)

        let p2 = pool.dequeue()
        #expect(p2 != nil)
        #expect(p2?.isActive == false)
    }

    // MARK: - Physics bitmasks

    @Test("pool projectiles have correct category bitmask")
    func poolProjectilesHaveCorrectCategory() {
        let pool = makePool(size: 4)
        let parent = SKNode()
        pool.attachAll(to: parent)
        guard let projectile = pool.dequeue() else { return }
        #expect(projectile.physicsBody?.categoryBitMask == PhysicsCategory.playerProjectile)
        #expect(projectile.physicsBody?.contactTestBitMask == PhysicsCategory.enemy)
    }

    // MARK: - updateAll

    @Test("updateAll only updates active projectiles")
    func updateAllOnlyUpdatesActive() {
        let pool = makePool(size: 3)
        let parent = SKNode()
        pool.attachAll(to: parent)

        guard let p = pool.dequeue() else { return }
        p.activate(at: .zero, velocity: CGVector(dx: 100, dy: 0), damage: 1, lifespan: 10)

        pool.updateAll(deltaTime: 0.1)
        #expect(p.position.x > 0)
    }

    @Test("updateAll deactivates projectile past lifespan")
    func updateAllDeactivatesPastLifespan() {
        let pool = makePool(size: 2)
        let parent = SKNode()
        pool.attachAll(to: parent)

        guard let p = pool.dequeue() else { return }
        p.activate(at: .zero, velocity: CGVector(dx: 1, dy: 0), damage: 1, lifespan: 0.1)

        pool.updateAll(deltaTime: 0.2)
        #expect(p.isActive == false)
    }

    // MARK: - Helper

    private func makePool(size: Int) -> ProjectilePool {
        ProjectilePool(
            size: size,
            atlasName: "LuminousWisp",
            frameNames: ["right_walk_000"],
            projectileSize: GameConfig.playerProjectileSize,
            category: PhysicsCategory.playerProjectile,
            contactTestBitMask: PhysicsCategory.enemy,
            frameTime: GameConfig.playerProjectileFrameTime
        )
    }
}
