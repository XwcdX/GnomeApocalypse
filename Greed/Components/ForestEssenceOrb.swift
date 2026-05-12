import SpriteKit

final class ForestEssenceOrb: SKSpriteNode {
    enum OrbState {
        case small
        case grown
        case red
        case mistExplosion
    }

    private var ghostRenderer: ToroidalRenderingComponent?
    private let orbAtlas = SKTextureAtlas(named: "EssenceOrb")
    private let mistAtlas = SKTextureAtlas(named: "MistEffect")
    private(set) var state: OrbState = .small
    private(set) var essenceValue: Int
    private var stateElapsedTime: TimeInterval = 0
    
    init(essenceValue: Int = GameConfig.smallOrbEssenceValue) {
        self.essenceValue = essenceValue
        let texture = SKTextureAtlas(named: "EssenceOrb").textureNamed("orb_000")
        texture.filteringMode = .nearest
        super.init(texture: texture, color: .clear, size: Self.scaledSize(for: texture, targetHeight: GameConfig.smallOrbTargetHeight))
        self.zPosition = Layer.orb
        setupPhysics()
        startIdleBob()
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
        removeAction(forKey: "idleBob")
        removeFromParent()
    }
    
    private func becomeGrown() {
        state = .grown
        stateElapsedTime = 0
        essenceValue = GameConfig.grownOrbEssenceValue
        let nextTexture = orbTexture("orb_001")
        texture = nextTexture
        size = Self.scaledSize(for: nextTexture, targetHeight: GameConfig.grownOrbTargetHeight)
        setupPhysics(radius: 12)
    }

    private func becomeRed() {
        state = .red
        stateElapsedTime = 0
        essenceValue = GameConfig.redOrbEssenceValue
        let nextTexture = orbTexture("orb_002")
        texture = nextTexture
        size = Self.scaledSize(for: nextTexture, targetHeight: GameConfig.redOrbTargetHeight)
        setupPhysics(radius: 16)
    }

    private func explodeIntoMist() {
        state = .mistExplosion
        stateElapsedTime = 0
        physicsBody = nil
        isHidden = true
        removeAction(forKey: "idleBob")
        ghostRenderer?.clear()
        playMistExplosionPlaceholder()
    }

    private func playMistExplosionPlaceholder() {
        guard let parent else { return }

        let mistBurst = SKSpriteNode(texture: mistTexture("mist_000"))
        mistBurst.position = position
        mistBurst.size = CGSize(width: GameConfig.playerReferenceSpriteSize.width * 2.2, height: GameConfig.playerReferenceSpriteSize.width * 2.2)
        mistBurst.zPosition = zPosition + 1
        parent.addChild(mistBurst)

        let frames = (0..<3).map { mistTexture("mist_\(String(format: "%03d", $0))") }
        let animate = SKAction.animate(with: frames, timePerFrame: 0.08)
        let expand = SKAction.scale(to: 1.5, duration: 0.24)
        let fade = SKAction.fadeOut(withDuration: 0.24)
        mistBurst.run(.sequence([.group([animate, expand, fade]), .removeFromParent()]))
    }

    private func orbTexture(_ name: String) -> SKTexture {
        let texture = orbAtlas.textureNamed(name)
        texture.filteringMode = .nearest
        return texture
    }

    private func mistTexture(_ name: String) -> SKTexture {
        let texture = mistAtlas.textureNamed(name)
        texture.filteringMode = .nearest
        return texture
    }

    private static func scaledSize(for texture: SKTexture, targetHeight: CGFloat) -> CGSize {
        let sourceSize = texture.size()
        guard sourceSize.height > 0 else {
            return CGSize(width: targetHeight, height: targetHeight)
        }

        let scale = targetHeight / sourceSize.height
        return CGSize(width: sourceSize.width * scale, height: targetHeight)
    }

    private func startIdleBob() {
        let amplitude = max(2, size.height * 0.08)
        let duration = TimeInterval.random(in: 0.6...0.9)
        let driftUp = SKAction.moveBy(x: 0, y: amplitude, duration: duration)
        let driftDown = SKAction.moveBy(x: 0, y: -amplitude, duration: duration)
        driftUp.timingMode = .easeInEaseOut
        driftDown.timingMode = .easeInEaseOut

        let initialDelay = SKAction.wait(forDuration: TimeInterval.random(in: 0...0.35))
        let bob = SKAction.repeatForever(.sequence([driftUp, driftDown]))
        run(.sequence([initialDelay, bob]), withKey: "idleBob")
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
