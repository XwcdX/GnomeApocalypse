import SpriteKit

final class BossGnome: EnemyEntity {
    override var budgetWeight: Int { 0 }
    override var moveSpeed: CGFloat { 40 }
    
    private var timeSinceLastAbility: TimeInterval = 0
    private let abilityInterval: TimeInterval = 8.0
    private var phase: Phase = .one
    private enum Phase { case one, two }
    
    init() {
        let texture = SKTexture(imageNamed: "gnome_boss")
        super.init(texture: texture, health: 2000)
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
        let interval = phase == .two ? abilityInterval / 2 : abilityInterval
        guard timeSinceLastAbility >= interval else { return }
        timeSinceLastAbility = 0
        
        switch phase {
        case .one: spawnMiniGnomes(count: 3)
        case .two: spawnMiniGnomes(count: 6)
        }
    }
    
    private func spawnMiniGnomes(count: Int) {
        gameScene?.spawnBossMinions(count: count, around: position)
    }
}
