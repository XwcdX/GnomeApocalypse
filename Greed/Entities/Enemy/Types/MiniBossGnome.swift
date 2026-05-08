import SpriteKit

final class MiniBossGnome: EnemyEntity {

    override var budgetWeight: Int { GameConfig.miniBossGnomeBudgetWeight }
    override var moveSpeed: CGFloat { GameConfig.miniBossMoveSpeed }

    private var timeSinceLastShot: TimeInterval = 0

    init() {
        let texture = SKTexture(imageNamed: "gnome_miniboss")
        super.init(texture: texture, health: GameConfig.miniBossHealth)
        self.name = "MiniBossGnome"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func update(deltaTime: TimeInterval) {
        super.update(deltaTime: deltaTime)
        updateRangedAttack(deltaTime: deltaTime)
    }

    private func updateRangedAttack(deltaTime: TimeInterval) {
        timeSinceLastShot += deltaTime
        guard timeSinceLastShot >= GameConfig.miniBossShootInterval else { return }
        timeSinceLastShot = 0
        fireTowardTarget()
    }

    private func fireTowardTarget() {
        guard let gameScene else { return }
        let offset = toroidalOffset(from: position, to: targetPosition, mapSize: GameConfig.mapSize)
        let distance = sqrt(offset.dx * offset.dx + offset.dy * offset.dy)
        guard distance > 0 else { return }
        let direction = CGVector(dx: offset.dx / distance, dy: offset.dy / distance)
        gameScene.spawnEnemyProjectile(at: position, direction: direction, damage: GameConfig.miniBossProjectileDamage)
    }
}
