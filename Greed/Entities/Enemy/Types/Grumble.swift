import SpriteKit

final class Grumble: EnemyEntity {

    override var budgetWeight: Int { GameConfig.grumbleBudgetWeight }
    override var moveSpeed: CGFloat { GameConfig.miniBossMoveSpeed }
    override var preferredTargetRange: CGFloat { GameConfig.miniBossPreferredRange }

    private var timeSinceLastShot: TimeInterval = 0
    private var animator: AnimationComponent!
    private var lastDirection: String = "right"

    init() {
        let atlas = SKTextureAtlas(named: "Grumble")
        let firstFrame = atlas.textureNamed("grumble_walk_000")
        super.init(
            texture: firstFrame,
            displaySize: EnemyEntity.scaledSize(for: firstFrame, targetHeight: GameConfig.miniBossTargetHeight),
            health: GameConfig.miniBossHealth
        )
        self.name = "Grumble"
        setupAnimations()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func update(deltaTime: TimeInterval) {
        super.update(deltaTime: deltaTime)
        updateAnimation()
        updateRangedAttack(deltaTime: deltaTime)
    }

    private func setupAnimations() {
        animator = AnimationComponent(atlasName: "Grumble", owner: self, canMirror: true)
        animator.loadAnimation(name: "grumble_walk", frameCount: 4)
        animator.loadAnimation(name: "grumble_attack", frameCount: 3)
    }

    private func updateAnimation() {
        let delta = movementDelta
        let isMoving = abs(delta.x) > 0.01 || abs(delta.y) > 0.01

        if isMoving {
            lastDirection = delta.x < 0 ? "left" : "right"
            xScale = lastDirection == "left" ? 1 : -1
        }

        let animationName = isMoving ? "grumble_walk" : "grumble_attack"
        animator.play(animation: animationName, timePerFrame: 0.12, repeat: true)
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
        gameScene.spawnEnemyProjectile(
            at: position,
            direction: direction,
            damage: GameConfig.miniBossProjectileDamage,
            textureName: "GrumbleBullet"
        )
    }
}
