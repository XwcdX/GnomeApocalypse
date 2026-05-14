import SpriteKit

class EnemyEntity: SKSpriteNode {
    var health: HealthComponent
    private var ghostRenderer: ToroidalRenderingComponent?
    
    var targetPosition: CGPoint = .zero
    var isTargetingActive: Bool = true
    var budgetWeight: Int { 1 }
    var moveSpeed: CGFloat { GameConfig.smallGnomeMoveSpeed }
    var preferredTargetRange: CGFloat { 0 }
    
    weak var gameScene: GameScene?

    init(texture: SKTexture, displaySize: CGSize? = nil, health: Int) {
        self.health = HealthComponent(maximum: health)
        super.init(texture: texture, color: .clear, size: displaySize ?? texture.size())
        self.zPosition = Layer.world
        setupPhysics()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    static func scaledSize(for texture: SKTexture, targetHeight: CGFloat) -> CGSize {
        let sourceSize = texture.size()
        guard sourceSize.height > 0 else {
            return CGSize(width: targetHeight, height: targetHeight)
        }

        let scale = targetHeight / sourceSize.height
        return CGSize(width: sourceSize.width * scale, height: targetHeight)
    }

    private var lastPosition: CGPoint = .zero
    var movementDelta: CGPoint { CGPoint(x: position.x - lastPosition.x, y: position.y - lastPosition.y) }

    func update(deltaTime: TimeInterval) {
        if ghostRenderer == nil {
            ghostRenderer = ToroidalRenderingComponent(owner: self, mapSize: GameConfig.mapSize)
        }
        lastPosition = position
        moveTowardTarget(deltaTime: deltaTime)
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        guard let cam = gameScene?.cameraSystem else { return }
        cam.clampToroidal(&position)
        ghostRenderer?.update(cameraPosition: cam.cameraNode.position, viewportSize: GameConfig.cameraViewportSize)
    }

    func die() {
        ghostRenderer?.clear()
        ghostRenderer = nil
        gameScene?.spawnEssenceOrb(at: position)
        gameScene?.directorSystem.recordKill()
        gameScene?.deregister(enemy: self)
        removeFromParent()
    }

    private func moveTowardTarget(deltaTime: TimeInterval) {
        let offset = toroidalOffset(from: position, to: targetPosition, mapSize: GameConfig.mapSize)
        let distance = sqrt(offset.dx * offset.dx + offset.dy * offset.dy)
        let remainingDistance = max(0, distance - preferredTargetRange)
        guard remainingDistance > 1 else { return }
        let step = min(moveSpeed * CGFloat(deltaTime), remainingDistance)
        position.x += (offset.dx / distance) * step
        position.y += (offset.dy / distance) * step
    }

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: size.width * 0.35)
        body.categoryBitMask = PhysicsCategory.enemy
        body.contactTestBitMask = PhysicsCategory.playerProjectile | PhysicsCategory.shield
        body.collisionBitMask = PhysicsCategory.enemy | PhysicsCategory.decoration
        body.affectedByGravity = false
        body.allowsRotation = false
        body.restitution = 0
        body.linearDamping = 8
        body.angularDamping = 0
        body.friction = 0
        physicsBody = body
    }
}
