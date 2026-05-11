import SpriteKit

final class ForestEssenceOrb: SKSpriteNode {
    enum OrbState {
        case small
        case grown
        case red
        case mistExplosion
    }

    private var ghostRenderer: ToroidalRenderingComponent?
    private(set) var state: OrbState = .small
    private(set) var essenceValue: Int
    private var stateElapsedTime: TimeInterval = 0
    
    init(essenceValue: Int = GameConfig.smallOrbEssenceValue) {
        self.essenceValue = essenceValue
        super.init(texture: nil, color: .green, size: CGSize(width: 16, height: 16))
        self.zPosition = Layer.orb
        setupPhysics()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    
    func update(deltaTime: TimeInterval, cameraSystem: CameraSystem) -> Bool {
        if ghostRenderer == nil {
            ghostRenderer = ToroidalRenderingComponent(owner: self, mapSize: GameConfig.mapSize)
        }
        cameraSystem.clampToroidal(&position)
        ghostRenderer?.update(cameraPosition: cameraSystem.cameraNode.position, viewportSize: GameConfig.cameraViewportSize)

        stateElapsedTime += deltaTime
        switch state {
        case .small where stateElapsedTime >= GameConfig.smallOrbEvolveTime:
            becomeGrown()
        case .grown where stateElapsedTime >= GameConfig.grownOrbEvolveTime:
            becomeRed()
        case .red where stateElapsedTime >= GameConfig.redOrbEvolveTime:
            explodeIntoMist()
            return true
        default:
            break
        }

        return state == .mistExplosion
    }
    
    func cleanup() {
        ghostRenderer?.clear()
        removeFromParent()
    }
    
    private func becomeGrown() {
        state = .grown
        stateElapsedTime = 0
        essenceValue = GameConfig.grownOrbEssenceValue
        color = .yellow
        size = CGSize(width: 24, height: 24)
        setupPhysics(radius: 12)
    }

    private func becomeRed() {
        state = .red
        stateElapsedTime = 0
        essenceValue = GameConfig.redOrbEssenceValue
        color = .red
        size = CGSize(width: 32, height: 32)
        setupPhysics(radius: 16)
    }

    private func explodeIntoMist() {
        state = .mistExplosion
        stateElapsedTime = 0
        physicsBody = nil
        isHidden = true
        ghostRenderer?.clear()
        playMistExplosionPlaceholder()
    }

    private func playMistExplosionPlaceholder() {
        guard let parent else { return }

        let mistBurst = SKShapeNode(circleOfRadius: 24)
        mistBurst.position = position
        mistBurst.strokeColor = .purple
        mistBurst.fillColor = .clear
        mistBurst.lineWidth = 3
        mistBurst.zPosition = zPosition + 1
        parent.addChild(mistBurst)

        let expand = SKAction.scale(to: 3, duration: 0.35)
        let fade = SKAction.fadeOut(withDuration: 0.35)
        mistBurst.run(.sequence([.group([expand, fade]), .removeFromParent()]))
    }

    private func setupPhysics(radius: CGFloat = 8) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.categoryBitMask = PhysicsCategory.forestEssenceOrb
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = false
        physicsBody = body
    }
}
