import SpriteKit

class EnemyEntity: SKSpriteNode {
    var health: HealthComponent
    private var ghostRenderer: ToroidalRenderingComponent?
    
    var targetPosition: CGPoint = .zero
    var isTargetingActive: Bool = true
    var budgetWeight: Int { 1 }
    var moveSpeed: CGFloat { GameConfig.smallGnomeMoveSpeed }
    
    weak var gameScene: GameScene?

    init(texture: SKTexture, health: Int) {
        self.health = HealthComponent(maximum: health)
        super.init(texture: texture, color: .clear, size: texture.size())
        self.zPosition = Layer.enemy
        setupPhysics()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(deltaTime: TimeInterval) {
        if ghostRenderer == nil {
            ghostRenderer = ToroidalRenderingComponent(owner: self, mapSize: GameConfig.mapSize)
        }
        moveTowardTarget(deltaTime: deltaTime)
        guard let cam = gameScene?.cameraSystem else { return }
        cam.clampToroidal(&position)
        ghostRenderer?.update(cameraPosition: cam.cameraNode.position, viewportSize: GameConfig.cameraViewportSize)
    }

    func die() {
        ghostRenderer?.clear()
        ghostRenderer = nil
        gameScene?.spawnForestEssenceOrb(at: position)
        gameScene?.directorSystem.recordKill()
        gameScene?.deregister(enemy: self)
        removeFromParent()
    }

    private func moveTowardTarget(deltaTime: TimeInterval) {
        let offset = toroidalOffset(from: position, to: targetPosition, mapSize: GameConfig.mapSize)
        let distance = sqrt(offset.dx * offset.dx + offset.dy * offset.dy)
        guard distance > 1 else { return }
        
        let speed = moveSpeed * CGFloat(deltaTime)
        let ratio = min(speed / distance, 1.0)
        position.x += offset.dx * ratio
        position.y += offset.dy * ratio
    }

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: size.width / 2)
        body.categoryBitMask = PhysicsCategory.enemy
        body.contactTestBitMask = PhysicsCategory.playerProjectile | PhysicsCategory.shield
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = false
        body.allowsRotation = false
        physicsBody = body
    }
}
