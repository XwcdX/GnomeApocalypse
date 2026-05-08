import SpriteKit

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
        timeSinceLastShot = 0
        isShooting = true
        shootingTimer = 0

        fire(from: owner)
    }

    private func fire(from owner: PlayerEntity) {
        spawnProjectile(from: owner.position, direction: owner.aimDirection, damage: GameConfig.basePlayerDamage)
    }

    private func spawnProjectile(from position: CGPoint, direction: CGVector, damage: Int) {
        guard let pool, let entityLayer,
              let projectile = pool.dequeue() else { return }
        
        let magnitude = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        guard magnitude > 0 else { return }
        
        let normalisedDirection = CGVector(dx: direction.dx / magnitude, dy: direction.dy / magnitude)
        let spawnPosition = CGPoint(
            x: position.x + normalisedDirection.dx * GameConfig.playerProjectileSpawnOffset,
            y: position.y + normalisedDirection.dy * GameConfig.playerProjectileSpawnOffset
        )
        let velocity = CGVector(
            dx: normalisedDirection.dx * GameConfig.projectileSpeed,
            dy: normalisedDirection.dy * GameConfig.projectileSpeed
        )
        
        projectile.activate(at: spawnPosition, velocity: velocity, damage: damage, lifespan: GameConfig.projectileLifeSpan)
        entityLayer.addChild(projectile)
    }
}
