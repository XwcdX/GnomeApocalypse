import SpriteKit

final class SmallGnome: EnemyEntity {
    private var animator: AnimationComponent!
    private var lastDirection: String = "right"
    
    init() {
        let atlas = SKTextureAtlas(named: "LuminousWisp")
        let firstFrame = atlas.textureNamed("right_walk_000")
        super.init(texture: firstFrame, health: GameConfig.smallGnomeHealth)
        self.name = "SmallGnome"
        setupAnimations()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    
    override var budgetWeight: Int { GameConfig.smallGnomeBudgetWeight }
    override var moveSpeed: CGFloat { GameConfig.smallGnomeMoveSpeed }
    
    private func setupAnimations() {
        animator = AnimationComponent(atlasName: "LuminousWisp", owner: self, canMirror: true)
        animator.loadAnimation(name: "right_walk", frameCount: 6)
        animator.loadAnimation(name: "right_shoot", frameCount: 6)
    }
    
    override func update(deltaTime: TimeInterval) {
        super.update(deltaTime: deltaTime)
        updateAnimation()
    }
    
    private func updateAnimation() {
        let offset = toroidalOffset(from: position, to: targetPosition, mapSize: GameConfig.mapSize)
        let isMoving = sqrt(offset.dx * offset.dx + offset.dy * offset.dy) > 1
        
        if isMoving {
            lastDirection = animator.setDirection(dx: offset.dx, dy: offset.dy)
        }
        
        let animationName = isMoving ? "right_walk" : "right_shoot"
        animator.play(animation: animationName, timePerFrame: 0.1, repeat: true)
    }
}
