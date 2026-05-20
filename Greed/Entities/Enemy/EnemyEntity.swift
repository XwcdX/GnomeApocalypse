import SpriteKit

class EnemyEntity: SKSpriteNode {
    var health: HealthComponent
    private var ghostRenderer: ToroidalRenderingComponent?
    private let hitFeedbackActionKey = "enemyHitFeedback"
    private let deathFeedbackActionKey = "enemyDeathFeedback"
    private(set) var isDying = false
    
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
        guard !isDying else { return }
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
        guard !isDying else { return }
        isDying = true
        ghostRenderer?.clear()
        ghostRenderer = nil
        gameScene?.spawnEssenceOrb(at: position)
        gameScene?.directorSystem.recordKill()
        gameScene?.deregister(enemy: self)
        physicsBody = nil
        removeAllActions()
        alpha = 1

        let blinkOut = SKAction.fadeAlpha(to: 0.25, duration: 0.04)
        let blinkIn = SKAction.fadeAlpha(to: 1, duration: 0.04)
        let fadeAway = SKAction.fadeAlpha(to: 0, duration: 0.10)
        run(.sequence([blinkOut, blinkIn, fadeAway, .removeFromParent()]), withKey: deathFeedbackActionKey)
    }

    func takeDamage(_ amount: Int) {
        guard amount > 0, !health.isDead, !isDying else { return }
        let didDie = health.takeDamage(amount)
        if didDie {
            die()
        } else {
            playHitFeedback()
        }
    }

    private func playHitFeedback() {
        removeAction(forKey: hitFeedbackActionKey)
        alpha = 1

        let blinkOut = SKAction.fadeAlpha(to: 0.35, duration: 0.035)
        let blinkIn = SKAction.fadeAlpha(to: 1, duration: 0.055)
        run(.sequence([blinkOut, blinkIn]), withKey: hitFeedbackActionKey)
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
