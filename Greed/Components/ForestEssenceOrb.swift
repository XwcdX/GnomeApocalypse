import SpriteKit

final class ForestEssenceOrb: SKSpriteNode {
    private var ghostRenderer: ToroidalRenderingComponent?
    let essenceValue: Int
    
    init(essenceValue: Int) {
        self.essenceValue = essenceValue
        super.init(texture: nil, color: .green, size: CGSize(width: 16, height: 16))
        self.zPosition = Layer.orb
        setupPhysics()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    
    func update(cameraSystem: CameraSystem) {
        if ghostRenderer == nil {
            ghostRenderer = ToroidalRenderingComponent(owner: self, mapSize: GameConfig.mapSize)
        }
        cameraSystem.clampToroidal(&position)
        ghostRenderer?.update(cameraPosition: cameraSystem.cameraNode.position, viewportSize: GameConfig.cameraViewportSize)
    }
    
    func cleanup() {
        ghostRenderer?.clear()
        removeFromParent()
    }
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 8)
        body.categoryBitMask = PhysicsCategory.forestEssenceOrb
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = false
        physicsBody = body
    }
}
