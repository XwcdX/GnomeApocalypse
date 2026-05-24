import SpriteKit

/// Timer-driven player auto-fire controller.
final class PlayerAttack {
    private weak var owner: PlayerEntity?
    private weak var pool: ProjectilePool?
    private weak var entityLayer: SKNode?

    private var timeSinceLastShot: TimeInterval = 0
    private var shootingTimer: TimeInterval = 0
    private let shootingDisplayDuration: TimeInterval = 0.3
    private(set) var isShooting: Bool = false

    init(owner: PlayerEntity, pool: ProjectilePool, entityLayer: SKNode) {
        self.owner = owner
        self.pool  = pool
        self.entityLayer = entityLayer
    }

    /// Advances cooldown state and fires only when the owner has a non-zero aim direction.
    func update(deltaTime: TimeInterval) {
        guard let owner else { return }
        timeSinceLastShot += deltaTime

        if isShooting {
            shootingTimer += deltaTime
            if shootingTimer >= shootingDisplayDuration {
                isShooting = false
                shootingTimer = 0
            }
        }

        let fireInterval = GameConfig.baseFireRate / Double(owner.attackSpeedMultiplier)
        guard timeSinceLastShot >= fireInterval else { return }

        guard fire(from: owner) else { return }

        timeSinceLastShot = 0
        isShooting = true
        shootingTimer = 0
    }

    private func fire(from owner: PlayerEntity) -> Bool {
        spawnProjectile(from: owner.position, direction: owner.aimDirection, damage: GameConfig.basePlayerDamage, owner: owner)
    }

    private func spawnProjectile(from position: CGPoint, direction: CGVector, damage: Int, owner: PlayerEntity) -> Bool {
        guard let pool, let entityLayer,
              let projectile = pool.dequeue() else { return false }
        
        let magnitude = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        guard magnitude > 0 else { return false }
        
        let normalisedDirection = CGVector(dx: direction.dx / magnitude, dy: direction.dy / magnitude)
        let spawnPosition = CGPoint(
            x: position.x + normalisedDirection.dx * GameConfig.playerProjectileSpawnOffset,
            y: position.y + normalisedDirection.dy * GameConfig.playerProjectileSpawnOffset
        )
        let velocity = CGVector(
            dx: normalisedDirection.dx * GameConfig.projectileSpeed,
            dy: normalisedDirection.dy * GameConfig.projectileSpeed
        )

        if let scene = owner.scene as? GameScene,
           !scene.canPlayerShoot(from: owner.position) {
            return false
        }

        projectile.activate(at: spawnPosition, velocity: velocity, damage: damage, lifespan: GameConfig.projectileLifeSpan)
        entityLayer.addChild(projectile)
        return true
    }
}
