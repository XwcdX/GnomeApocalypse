import SpriteKit

private let orbSpriteHeight: CGFloat = 48
private let smallOrbTargetHeight: CGFloat = orbSpriteHeight * 0.82
private let grownOrbTargetHeight: CGFloat = orbSpriteHeight * 0.98
private let redOrbTargetHeight: CGFloat = orbSpriteHeight * 1.12
private let smallOrbPhysicsRadius: CGFloat = 8
private let grownOrbPhysicsRadius: CGFloat = 12
private let redOrbPhysicsRadius: CGFloat = 16
private let orbBobAmplitudeFactor: CGFloat = 0.08
private let orbBobMinAmplitude: CGFloat = 2
private let orbBobDurationMin: TimeInterval = 0.6
private let orbBobDurationMax: TimeInterval = 0.9
private let orbBobInitialDelayMax: TimeInterval = 0.35
private let orbMistBurstSize: CGFloat = orbSpriteHeight * 2.2
private let orbMistBurstAnimFrameTime: TimeInterval = 0.08
private let orbMistBurstScale: CGFloat = 1.5
private let orbMistBurstDuration: TimeInterval = 0.24

final class EssenceOrbComponent: SKSpriteNode {
    enum OrbState {
        case small
        case grown
        case red
        case mistExplosion
    }

    private var ghostRenderer: ToroidalRenderingComponent?
    private let orbAtlas = SKTextureAtlas(named: "forest_essence")
    private let mistAtlas = SKTextureAtlas(named: "poisonous_mist")
    private(set) var state: OrbState = .small
    private(set) var essenceValue: Int
    private var stateElapsedTime: TimeInterval = 0
    
    init(essenceValue: Int = GameConfig.smallOrbEssenceValue) {
        self.essenceValue = essenceValue
        let texture = SKTextureAtlas(named: "forest_essence").textureNamed("pickup_forest_essence_000")
        texture.filteringMode = .nearest
        super.init(texture: texture, color: .clear, size: Self.scaledSize(for: texture, targetHeight: smallOrbTargetHeight))
        self.zPosition = Layer.world
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
        let nextTexture = orbTexture("pickup_forest_essence_001")
        texture = nextTexture
        size = Self.scaledSize(for: nextTexture, targetHeight: grownOrbTargetHeight)
        setupPhysics(radius: grownOrbPhysicsRadius)
    }

    private func becomeRed() {
        state = .red
        stateElapsedTime = 0
        essenceValue = GameConfig.redOrbEssenceValue
        let nextTexture = orbTexture("pickup_forest_essence_002")
        texture = nextTexture
        size = Self.scaledSize(for: nextTexture, targetHeight: redOrbTargetHeight)
        setupPhysics(radius: redOrbPhysicsRadius)
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

        let mistBurst = SKSpriteNode(texture: mistTexture("vfx_poisonous_mist_000"))
        mistBurst.position = position
        mistBurst.size = CGSize(width: orbMistBurstSize, height: orbMistBurstSize)
        mistBurst.zPosition = zPosition + 1
        parent.addChild(mistBurst)

        let frames = (0..<3).map { mistTexture("vfx_poisonous_mist_\(String(format: "%03d", $0))") }
        let animate = SKAction.animate(with: frames, timePerFrame: orbMistBurstAnimFrameTime)
        let expand = SKAction.scale(to: orbMistBurstScale, duration: orbMistBurstDuration)
        let fade = SKAction.fadeOut(withDuration: orbMistBurstDuration)
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
        let amplitude = max(orbBobMinAmplitude, size.height * orbBobAmplitudeFactor)
        let duration = TimeInterval.random(in: orbBobDurationMin...orbBobDurationMax)
        let driftUp = SKAction.moveBy(x: 0, y: amplitude, duration: duration)
        let driftDown = SKAction.moveBy(x: 0, y: -amplitude, duration: duration)
        driftUp.timingMode = .easeInEaseOut
        driftDown.timingMode = .easeInEaseOut

        let initialDelay = SKAction.wait(forDuration: TimeInterval.random(in: 0...orbBobInitialDelayMax))
        let bob = SKAction.repeatForever(.sequence([driftUp, driftDown]))
        run(.sequence([initialDelay, bob]), withKey: "idleBob")
    }

    private func setupPhysics(radius: CGFloat = smallOrbPhysicsRadius) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.categoryBitMask = PhysicsCategory.forestEssenceOrb
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = false
        physicsBody = body
    }
}
