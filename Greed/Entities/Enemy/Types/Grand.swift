import SpriteKit

private let grandTargetHeight: CGFloat = 48 * 1.8

final class Grand: EnemyEntity {
    override var budgetWeight: Int { 0 }
    override var moveSpeed: CGFloat { GameConfig.bossMoveSpeed }

    private var timeSinceLastAbility: TimeInterval = 0
    private var phase: Phase = .one
    private var animator: AnimationComponent!
    private var lastDirection: String = "right"
    private enum Phase { case one, two }

    init() {
        let atlas = SKTextureAtlas(named: "Grand")
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
        updateAnimation()
        updatePhase()
        updateAbility(deltaTime: deltaTime)
    }

    private func setupAnimations() {
        animator = AnimationComponent(atlasName: "Grand", owner: self, canMirror: true)
        animator.loadAnimation(name: "grand_walk", frameCount: 7)
        animator.loadAnimation(name: "grand_attack", frameCount: 5)
    }

    private func updateAnimation() {
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
