import SpriteKit

/// Preloads particle emitters and provides programmatic fallbacks when `.sks` files are missing.
final class ParticleAssets {
    /// Shared effect cache for gameplay scenes.
    static let shared = ParticleAssets()

    /// Particle effect names shared by gameplay call sites and emitter files.
    enum Effect: String, CaseIterable {
        case orbCollect = "OrbCollect"
        case gnomeDeath = "GnomeDeath"
        case shieldExpand = "ShieldExpand"
        case shieldBurst = "ShieldBurst"
        case mistExplosion = "MistExplosion"
        case wardenThornsHit = "WardenThornsHit"
        case lightningImpact = "LightningImpact"
    }

    private var emitters: [Effect: SKEmitterNode] = [:]

    private init() {}

    /// Builds or loads every effect so gameplay emission can copy cached emitters.
    func preloadAll() {
        Effect.allCases.forEach { preload($0) }
    }

    /// Returns a copy of a cached emitter so callers can place and remove it independently.
    func makeEmitter(for effect: Effect) -> SKEmitterNode? {
        emitters[effect]?.copy() as? SKEmitterNode
    }

    /// Emits an effect at a world-space position and removes it after particle lifetime expires.
    func emit(_ effect: Effect, at position: CGPoint, in parent: SKNode) {
        guard let emitter = makeEmitter(for: effect) else { return }
        emitter.position = position
        parent.addChild(emitter)

        let lifetime = TimeInterval(emitter.particleLifetime + emitter.particleLifetimeRange)
        emitter.run(.sequence([.wait(forDuration: lifetime), .removeFromParent()]))
    }

    private func preload(_ effect: Effect) {
        guard emitters[effect] == nil else { return }
        let emitter = SKEmitterNode(fileNamed: effect.rawValue) ?? makeProgrammaticEmitter(for: effect)
        emitter.targetNode = nil
        emitters[effect] = emitter
    }

    private func makeProgrammaticEmitter(for effect: Effect) -> SKEmitterNode {
        switch effect {
        case .orbCollect:        return makeOrbCollectEmitter()
        case .gnomeDeath:        return makeGnomeDeathEmitter()
        case .shieldExpand:      return makeShieldExpandEmitter()
        case .shieldBurst:       return makeShieldBurstEmitter()
        case .mistExplosion:     return makeMistExplosionEmitter()
        case .wardenThornsHit:   return makeWardenThornsHitEmitter()
        case .lightningImpact:   return makeLightningImpactEmitter()
        }
    }

    private func makeBurstEmitter(
        color: SKColor,
        count: Int,
        lifetime: CGFloat,
        speed: CGFloat,
        speedRange: CGFloat,
        scale: CGFloat,
        scaleSpeed: CGFloat = -1.5
    ) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = nil
        emitter.particleBirthRate = CGFloat(count) / 0.05
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = lifetime
        emitter.particleLifetimeRange = lifetime * 0.4
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speedRange
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.0 / lifetime
        emitter.particleScale = scale
        emitter.particleScaleRange = scale * 0.5
        emitter.particleScaleSpeed = scaleSpeed
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        return emitter
    }

    private func makeOrbCollectEmitter() -> SKEmitterNode {
        makeBurstEmitter(
            color: SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0),
            count: 14, lifetime: 0.4, speed: 90, speedRange: 40, scale: 0.35
        )
    }

    private func makeGnomeDeathEmitter() -> SKEmitterNode {
        makeBurstEmitter(
            color: SKColor(red: 0.45, green: 0.3, blue: 0.15, alpha: 1.0),
            count: 12, lifetime: 0.45, speed: 70, speedRange: 30, scale: 0.4
        )
    }

    private func makeShieldExpandEmitter() -> SKEmitterNode {
        let emitter = makeBurstEmitter(
            color: SKColor(red: 0.4, green: 0.85, blue: 1.0, alpha: 1.0),
            count: 18, lifetime: 0.5, speed: 60, speedRange: 20, scale: 0.5,
            scaleSpeed: 1.0
        )
        emitter.particleAlphaSpeed = -2.0
        return emitter
    }

    private func makeShieldBurstEmitter() -> SKEmitterNode {
        makeBurstEmitter(
            color: SKColor(red: 0.5, green: 0.95, blue: 1.0, alpha: 1.0),
            count: 20, lifetime: 0.35, speed: 150, speedRange: 50, scale: 0.3
        )
    }

    private func makeMistExplosionEmitter() -> SKEmitterNode {
        makeBurstEmitter(
            color: SKColor(red: 0.4, green: 0.85, blue: 0.3, alpha: 1.0),
            count: 16, lifetime: 0.55, speed: 50, speedRange: 30, scale: 0.6,
            scaleSpeed: 0.4
        )
    }

    private func makeWardenThornsHitEmitter() -> SKEmitterNode {
        makeBurstEmitter(
            color: SKColor(red: 0.65, green: 0.3, blue: 0.85, alpha: 1.0),
            count: 12, lifetime: 0.35, speed: 110, speedRange: 50, scale: 0.3
        )
    }

    private func makeLightningImpactEmitter() -> SKEmitterNode {
        makeBurstEmitter(
            color: SKColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 1.0),
            count: 14, lifetime: 0.3, speed: 140, speedRange: 60, scale: 0.3
        )
    }
}
