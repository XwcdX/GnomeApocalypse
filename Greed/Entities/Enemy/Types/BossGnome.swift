import SpriteKit

final class BossGnome: EnemyEntity {
    override var budgetWeight: Int { 0 }
    override var moveSpeed: CGFloat { GameConfig.bossMoveSpeed }

    private var timeSinceLastAbility: TimeInterval = 0
    private var phase: Phase = .one
    private enum Phase { case one, two }

    init() {
        let texture = SKTexture(imageNamed: "gnome_boss")
        super.init(texture: texture, health: GameConfig.bossHealth)
        self.name = "BossGnome"
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    
    override func update(deltaTime: TimeInterval) {
        super.update(deltaTime: deltaTime)
        updatePhase()
        updateAbility(deltaTime: deltaTime)
    }
    
    override func die() {
        gameScene?.handleBossDeath()
        super.die()
    }
    
    private func updatePhase() {
        if phase == .one, health.fraction <= 0.5 {
            phase = .two
            Log.debug("BossGnome: entering phase two")
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
