import SpriteKit

private let groveTargetHeight: CGFloat = 48 * 0.62

final class Grove: EnemyEntity {
    private var animator: AnimationComponent!
    private var lastDirection: String = "right"
    private var timeSinceLastAttack: TimeInterval = 0
    private var attackWindupRemaining: TimeInterval = 0
    private var queuedAttackDirection: CGVector = .zero
    private var queuedAttackLifespan: TimeInterval = 0
    
    init() {
        let atlas = SKTextureAtlas(named: "grove")
        let firstFrame = atlas.textureNamed("grove_walk_000")
        super.init(
            texture: firstFrame,
            displaySize: EnemyEntity.scaledSize(for: firstFrame, targetHeight: groveTargetHeight),
            health: GameConfig.smallGnomeHealth
        )
        self.name = "Grove"
        setupAnimations()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    
    override var budgetWeight: Int { GameConfig.smallGnomeBudgetWeight }
    override var moveSpeed: CGFloat { GameConfig.smallGnomeMoveSpeed }
    
    private func setupAnimations() {
        animator = AnimationComponent(atlasName: "grove", owner: self, canMirror: true)
        animator.loadAnimation(name: "grove_walk", frameCount: 4)
        animator.loadAnimation(name: "grove_attack", frameCount: 4)
    }
    
    override func update(deltaTime: TimeInterval) {
        super.update(deltaTime: deltaTime)
        updateAnimation()
        updateShortRangeAttack(deltaTime: deltaTime)
    }
    
    private func updateAnimation() {
        if attackWindupRemaining > 0 {
            animator.play(animation: "grove_attack", timePerFrame: 0.1, repeat: false)
            return
        }

        let delta = movementDelta
        let isMoving = abs(delta.x) > 0.01 || abs(delta.y) > 0.01

        if isMoving {
            lastDirection = delta.x < 0 ? "left" : "right"
            xScale = lastDirection == "left" ? 1 : -1
        }

        let animationName = isMoving ? "grove_walk" : "grove_attack"
        animator.play(animation: animationName, timePerFrame: 0.1, repeat: true)
    }

    private func updateShortRangeAttack(deltaTime: TimeInterval) {
        if attackWindupRemaining > 0 {
            attackWindupRemaining = max(0, attackWindupRemaining - deltaTime)
            if attackWindupRemaining == 0 {
                launchQueuedAttack()
            }
            return
        }

        timeSinceLastAttack += deltaTime
        guard timeSinceLastAttack >= GameConfig.smallGnomeAttackInterval else { return }

        let offset = toroidalOffset(from: position, to: targetPosition, mapSize: GameConfig.mapSize)
        let distance = sqrt(offset.dx * offset.dx + offset.dy * offset.dy)
        guard distance <= GameConfig.smallGnomeAttackRange, distance > 0 else { return }

        timeSinceLastAttack = 0
        queuedAttackDirection = CGVector(dx: offset.dx / distance, dy: offset.dy / distance)
        queuedAttackLifespan = TimeInterval(GameConfig.smallGnomeAttackRange / GameConfig.projectileSpeed) + 0.05
        attackWindupRemaining = GameConfig.smallGnomeAttackWindup
        animator.stop()
        animator.play(animation: "grove_attack", timePerFrame: 0.1, repeat: false)
    }

    private func launchQueuedAttack() {
        gameScene?.spawnEnemyProjectile(
            at: position,
            direction: queuedAttackDirection,
            damage: GameConfig.smallGnomeAttackDamage,
            textureName: "projectile_enemy_grove",
            lifespan: queuedAttackLifespan
        )
    }
}
