import SpriteKit

private let grandTargetHeight: CGFloat = 48 * 1.8

/// Budget-exempt boss enemy with locked-arena melee attacks and phase-based minion spawns.
final class Grand: EnemyEntity {
    override var budgetWeight: Int { 0 }
    private var isAnimatingSmash: Bool = false

    override var moveSpeed: CGFloat {
        return isAnimatingSmash ? 0 : GameConfig.bossMoveSpeed
    }

    private var timeSinceLastAbility: TimeInterval = 0
    private var phase: Phase = .one
    private var animator: AnimationComponent!
    private var lastDirection: String = "right"

    private var timeSinceLastMelee: TimeInterval = 0
    private var meleeWindupRemaining: TimeInterval = 0
    private var isInMeleeWindup: Bool = false

    private enum Phase { case one, two }

    init() {
        let atlas = SKTextureAtlas(named: "grand")
        let firstFrame = atlas.textureNamed("grand_walk_000")
        super.init(
            texture: firstFrame,
            displaySize: EnemyEntity.scaledSize(for: firstFrame, targetHeight: grandTargetHeight),
            health: GameConfig.bossHealth
        )
        self.name = "Grand"
        setupAnimations()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    
    override func update(deltaTime: TimeInterval) {
        super.update(deltaTime: deltaTime)
        updateMeleeAttack(deltaTime: deltaTime)
        updateAnimation()
        updatePhase()
        updateAbility(deltaTime: deltaTime)
    }

    private func setupAnimations() {
        animator = AnimationComponent(atlasName: "grand", owner: self, canMirror: true)
        animator.loadAnimation(name: "grand_walk", frameCount: 7)
        animator.loadAnimation(name: "grand_attack", frameCount: 5)
    }

    private func updateMeleeAttack(deltaTime: TimeInterval) {
        if isInMeleeWindup {
            meleeWindupRemaining = max(0, meleeWindupRemaining - deltaTime)
            if meleeWindupRemaining == 0 {
                isInMeleeWindup = false
                deliverMeleeDamage()
            }
            return
        }

        timeSinceLastMelee += deltaTime
        guard timeSinceLastMelee >= GameConfig.bossMeleeAttackInterval else { return }

        let offset = toroidalOffset(from: position, to: targetPosition, mapSize: GameConfig.mapSize)
        let distance = sqrt(offset.dx * offset.dx + offset.dy * offset.dy)
        guard distance <= GameConfig.bossMeleeRange else { return }

        timeSinceLastMelee = 0
        isInMeleeWindup = true
        isAnimatingSmash = true
        meleeWindupRemaining = GameConfig.bossMeleeWindup
        animator.stop()
        animator.play(animation: "grand_attack", timePerFrame: GameConfig.bossMeleeWindup / 5, repeat: false)
        playProgrammaticSmashAnimation()
    }

    private func playProgrammaticSmashAnimation() {
        let baseDir: CGFloat = lastDirection == "left" ? 1.0 : -1.0
        
        // Windup, impact, and recovery intentionally mirror the melee timing constants.
        let stretchX = SKAction.scaleX(to: baseDir * 0.85, duration: GameConfig.bossMeleeWindup)
        let stretchY = SKAction.scaleY(to: 1.25, duration: GameConfig.bossMeleeWindup)
        let lift = SKAction.moveBy(x: 0, y: 15, duration: GameConfig.bossMeleeWindup)
        let windupGroup = SKAction.group([stretchX, stretchY, lift])
        
        let squashX = SKAction.scaleX(to: baseDir * 1.3, duration: 0.08)
        let squashY = SKAction.scaleY(to: 0.7, duration: 0.08)
        let slam = SKAction.moveBy(x: 0, y: -20, duration: 0.08)
        let smashGroup = SKAction.group([squashX, squashY, slam])
        
        let recoverX = SKAction.scaleX(to: baseDir * 1.0, duration: 0.15)
        let recoverY = SKAction.scaleY(to: 1.0, duration: 0.15)
        let rise = SKAction.moveBy(x: 0, y: 5, duration: 0.15)
        let recoverGroup = SKAction.group([recoverX, recoverY, rise])
        
        let resetState = SKAction.run { [weak self] in
            self?.isAnimatingSmash = false
        }
        
        self.run(SKAction.sequence([windupGroup, smashGroup, recoverGroup, resetState]), withKey: "smash_animation")
    }

    private func deliverMeleeDamage() {
        gameScene?.dealMeleeDamageToNearestPlayer(
            from: position,
            damage: GameConfig.bossMeleeDamage,
            range: GameConfig.bossMeleeRange
        )
    }

    private func updateAnimation() {
        if isAnimatingSmash { return }

        let delta = movementDelta
        let isMoving = abs(delta.x) > 0.01 || abs(delta.y) > 0.01

        if isMoving {
            lastDirection = delta.x < 0 ? "left" : "right"
            xScale = lastDirection == "left" ? 1 : -1
        }

        let animationName = isMoving ? "grand_walk" : "grand_attack"
        animator.play(animation: animationName, timePerFrame: 0.12, repeat: true)
    }
    
    override func die() {
        gameScene?.handleBossDeath()
        super.die()
    }
    
    private func updatePhase() {
        if phase == .one, health.fraction <= 0.5 {
            phase = .two
            Log.debug("Grand: entering phase two")
        }
    }
    
    private func updateAbility(deltaTime: TimeInterval) {
        timeSinceLastAbility += deltaTime
        let interval = phase == .two ? GameConfig.bossAbilityInterval / 2 : GameConfig.bossAbilityInterval
        guard timeSinceLastAbility >= interval else { return }
        timeSinceLastAbility = 0
        switch phase {
        case .one: spawnMiniGnomes(count: GameConfig.bossPhase1MinionCount)
        case .two: spawnMiniGnomes(count: GameConfig.bossPhase2MinionCount)
        }
    }
    
    private func spawnMiniGnomes(count: Int) {
        gameScene?.spawnBossMinions(count: count, around: position)
    }
}
