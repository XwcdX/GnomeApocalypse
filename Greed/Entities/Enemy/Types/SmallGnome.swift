import SpriteKit

final class SmallGnome: EnemyEntity {
    init(texture: SKTexture) {
        super.init(texture: texture, health: 30)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    
    override var budgetWeight: Int { GameConfig.smallGnomeBudgetWeight }
    override var moveSpeed: CGFloat { 80 }
}
