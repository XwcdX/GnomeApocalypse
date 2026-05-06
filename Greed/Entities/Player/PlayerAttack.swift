import SpriteKit

final class PlayerAttack {
    private weak var owner: PlayerEntity?
    private weak var pool: ProjectilePool?
    private weak var entityLayer: SKNode?

    private var timeSinceLastShot: TimeInterval = 0

    init(owner: PlayerEntity, pool: ProjectilePool, entityLayer: SKNode) {
        self.owner = owner
        self.pool  = pool
        self.entityLayer = entityLayer
    }

    func update(deltaTime: TimeInterval) {
        guard let owner else { return }
        timeSinceLastShot += deltaTime

        let fireInterval = GameConfig.baseFireRate / Double(owner.attackSpeedMultiplier)
        guard timeSinceLastShot >= fireInterval else { return }
        timeSinceLastShot = 0

        fire(from: owner)
    }

    private func fire(from owner: PlayerEntity) {
        guard owner.aimDirection != .zero else { return }
        spawnProjectile(from: owner.position, direction: owner.aimDirection, damage: GameConfig.basePlayerDamage)
    }

    private func spawnProjectile(from position: CGPoint, direction: CGVector, damage: Int) {
        guard let pool, let entityLayer,
              let projectile = pool.dequeue() else { return }
        
        let velocity = CGVector(dx: direction.dx * GameConfig.projectileSpeed, dy: direction.dy * GameConfig.projectileSpeed)
        projectile.activate(at: position, velocity: velocity, damage: damage, lifespan: GameConfig.projectileLifeSpan)
        entityLayer.addChild(projectile)
    }
}
