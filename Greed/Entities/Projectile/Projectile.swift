import SpriteKit

final class Projectile: SKSpriteNode {
    let toroidal = ToroidalPositionComponent()
    private var ghostRenderer: ToroidalRenderingComponent?
    
    var damage: Int = 0
    var velocity: CGVector = .zero
    var lifespan: TimeInterval = 0
    private var age: TimeInterval = 0
    private var animationFrames: [SKTexture] = []
    private var frameTime: TimeInterval = 0
    
    var isActive: Bool = false
    
    func configurePhysics(category: UInt32, contactTestBitMask: UInt32) {
        let body = SKPhysicsBody(circleOfRadius: max(size.width, size.height) / 2)
        body.categoryBitMask = category
        body.contactTestBitMask = contactTestBitMask
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = false
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = true
        physicsBody = body
    }
    
    func configureAnimation(frames: [SKTexture], frameTime: TimeInterval) {
        animationFrames = frames
        self.frameTime = frameTime
    }
    
    func activate(at position: CGPoint, velocity: CGVector, damage: Int, lifespan: TimeInterval) {
        self.position = position
        self.velocity = velocity
        self.damage = damage
        self.lifespan = lifespan
        self.age = 0
        self.isActive = true
        self.isHidden = false
        
        if velocity.dx != 0 || velocity.dy != 0 {
            zRotation = atan2(velocity.dy, velocity.dx)
        }
        
        playAnimation()
    }
    
    func deactivate() {
        isActive = false
        isHidden = true
        removeAction(forKey: "projectileAnimation")
        ghostRenderer?.clear()
        removeFromParent()
    }
    
    func update(deltaTime: TimeInterval) {
        guard isActive else { return }
        
        age += deltaTime
        if age >= lifespan {
            deactivate()
            return
        }
        
        position.x += velocity.dx * deltaTime
        position.y += velocity.dy * deltaTime
        toroidal.update(node: self)
        updateToroidalGhosts()
    }
    
    private func playAnimation() {
        guard animationFrames.count > 1, frameTime > 0 else { return }
        removeAction(forKey: "projectileAnimation")
        
        let animate = SKAction.animate(with: animationFrames, timePerFrame: frameTime)
        run(SKAction.repeatForever(animate), withKey: "projectileAnimation")
    }
    
    private func updateToroidalGhosts() {
        if ghostRenderer == nil {
            ghostRenderer = ToroidalRenderingComponent(owner: self, mapSize: GameConfig.mapSize)
        }
        
        guard let scene = scene as? GameScene, let camera = scene.camera else { return }
        ghostRenderer?.update(cameraPosition: camera.position, viewportSize: scene.size)
    }
}
