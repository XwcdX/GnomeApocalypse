import SpriteKit

private let grumbleTargetHeight: CGFloat = 48 * 1.35

final class Grumble: EnemyEntity {

    override var budgetWeight: Int { GameConfig.grumbleBudgetWeight }
    override var moveSpeed: CGFloat {
        if attackWindupRemaining > 0 {
            return 0
        }
        return GameConfig.miniBossMoveSpeed
    }
    override var preferredTargetRange: CGFloat { GameConfig.miniBossPreferredRange }

    private var timeSinceLastShot: TimeInterval = 0
    private var animator: AnimationComponent!
    private var lastDirection: String = "right"
    private var attackWindupRemaining: TimeInterval = 0
    private var queuedAttackDirection: CGVector = .zero

    init() {
        let atlas = SKTextureAtlas(named: "grumble")
        let firstFrame = atlas.textureNamed("grumble_walk_000")
        super.init(
            texture: firstFrame,
            displaySize: EnemyEntity.scaledSize(for: firstFrame, targetHeight: grumbleTargetHeight),
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
        animator = AnimationComponent(atlasName: "grumble", owner: self, canMirror: true)
        animator.loadAnimation(name: "grumble_walk", frameCount: 4)
        animator.loadAnimation(name: "grumble_attack", frameCount: 3)
    }

    private func updateAnimation() {
        if attackWindupRemaining > 0 {
            animator.play(animation: "grumble_attack", timePerFrame: 0.12, repeat: false)
            return
        }

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
        if attackWindupRemaining > 0 {
            attackWindupRemaining = max(0, attackWindupRemaining - deltaTime)
            if attackWindupRemaining == 0 {
                launchQueuedAttack()
            }
            return
        }

        // Always update cooldown so the mini-boss can attack immediately when reaching the target
        timeSinceLastShot += deltaTime

        let offset = toroidalOffset(from: position, to: targetPosition, mapSize: GameConfig.mapSize)
        let distance = sqrt(offset.dx * offset.dx + offset.dy * offset.dy)
        let shootRadius = preferredTargetRange + 1.0
        
        guard distance <= shootRadius else { return }
        guard timeSinceLastShot >= GameConfig.miniBossShootInterval else { return }
        timeSinceLastShot = 0
        
        if distance > 0 {
            queuedAttackDirection = CGVector(dx: offset.dx / distance, dy: offset.dy / distance)
        } else {
            queuedAttackDirection = .zero
        }
        
        if offset.dx != 0 {
            lastDirection = offset.dx < 0 ? "left" : "right"
            xScale = lastDirection == "left" ? 1 : -1
        }
        
        attackWindupRemaining = GameConfig.miniBossAttackWindup
        animator.stop()
        animator.play(animation: "grumble_attack", timePerFrame: 0.12, repeat: false)
    }

    private func launchQueuedAttack() {
        guard let gameScene, queuedAttackDirection != .zero else { return }
        let projectileRange: CGFloat = 200.0
        let lifespan = TimeInterval(projectileRange / GameConfig.projectileSpeed)
        
        gameScene.spawnEnemyProjectile(
            at: position,
            direction: queuedAttackDirection,
            damage: GameConfig.miniBossProjectileDamage,
            textureName: "projectile_enemy_grumble",
            lifespan: lifespan
        )
        queuedAttackDirection = .zero
    }
}
