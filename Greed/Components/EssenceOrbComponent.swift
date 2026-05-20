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
private let mutationFrameCount: Int = 5
private let mutationFrameTime: TimeInterval = 0.08

final class EssenceOrbComponent: SKSpriteNode {
    enum EssenceTier {
        case green
        case blue
        case red

        var essenceValue: Int {
            switch self {
            case .green: return GameConfig.smallOrbEssenceValue
            case .blue: return GameConfig.grownOrbEssenceValue
            case .red: return GameConfig.redOrbEssenceValue
            }
        }

        var textureName: String {
            switch self {
            case .green: return "forest_essence_green"
            case .blue: return "forest_essence_blue"
            case .red: return "forest_essence_red"
            }
        }

        var targetHeight: CGFloat {
            switch self {
            case .green: return smallOrbTargetHeight
            case .blue: return grownOrbTargetHeight
            case .red: return redOrbTargetHeight
            }
        }

        var physicsRadius: CGFloat {
            switch self {
            case .green: return smallOrbPhysicsRadius
            case .blue: return grownOrbPhysicsRadius
            case .red: return redOrbPhysicsRadius
            }
        }
    }

    enum VisualPhase {
        case collectible
        case mutating
    }

    static let mutationDuration: TimeInterval = TimeInterval(mutationFrameCount) * mutationFrameTime

    private var ghostRenderer: ToroidalRenderingComponent?
    private let mutationAtlas = SKTextureAtlas(named: "forest_essence_mutation")
    private(set) var essenceTier: EssenceTier = .green
    private(set) var visualPhase: VisualPhase = .collectible
    private(set) var essenceValue: Int = GameConfig.smallOrbEssenceValue
    private(set) var currentTextureName: String = EssenceTier.green.textureName
    private var stateElapsedTime: TimeInterval = 0
    private var mutationElapsedTime: TimeInterval = 0
    
    init() {
        let texture = Self.pickupTexture(named: EssenceTier.green.textureName)
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

        if visualPhase == .mutating {
            ghostRenderer?.clear()
            return advanceMutation(deltaTime: deltaTime)
        }

        ghostRenderer?.update(cameraPosition: cameraSystem.cameraNode.position, viewportSize: GameConfig.cameraViewportSize)

        stateElapsedTime += deltaTime
        switch essenceTier {
        case .green where stateElapsedTime >= GameConfig.smallOrbEvolveTime:
            become(.blue)
        case .blue where stateElapsedTime >= GameConfig.grownOrbEvolveTime:
            become(.red)
        case .red where stateElapsedTime >= GameConfig.redOrbEvolveTime:
            startMutation()
        default:
            break
        }

        return false
    }
    
    func cleanup() {
        ghostRenderer?.clear()
        removeAction(forKey: "idleBob")
        removeFromParent()
    }
    
    private func become(_ nextTier: EssenceTier) {
        essenceTier = nextTier
        stateElapsedTime = 0
        essenceValue = nextTier.essenceValue
        currentTextureName = nextTier.textureName
        let nextTexture = Self.pickupTexture(named: nextTier.textureName)
        texture = nextTexture
        size = Self.scaledSize(for: nextTexture, targetHeight: nextTier.targetHeight)
        setupPhysics(radius: nextTier.physicsRadius)
    }

    private func startMutation() {
        visualPhase = .mutating
        stateElapsedTime = 0
        mutationElapsedTime = 0
        physicsBody = nil
        isHidden = false
        removeAction(forKey: "idleBob")
        ghostRenderer?.clear()
        applyMutationFrame(index: 0)
    }

    private func advanceMutation(deltaTime: TimeInterval) -> Bool {
        mutationElapsedTime += deltaTime
        let frameIndex = min(mutationFrameCount - 1, Int(mutationElapsedTime / mutationFrameTime))
        applyMutationFrame(index: frameIndex)
        return mutationElapsedTime >= Self.mutationDuration
    }

    private func applyMutationFrame(index: Int) {
        let frameName = Self.mutationFrameName(index: index)
        currentTextureName = frameName
        let frameTexture = mutationTexture(named: frameName)
        texture = frameTexture
        size = Self.scaledSize(for: frameTexture, targetHeight: redOrbTargetHeight)
    }

    private func mutationTexture(named name: String) -> SKTexture {
        let texture = mutationAtlas.textureNamed(name)
        texture.filteringMode = .nearest
        return texture
    }

    private static func pickupTexture(named name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        return texture
    }

    private static func mutationFrameName(index: Int) -> String {
        "vfx_forest_essence_mutation_\(String(format: "%03d", index))"
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
