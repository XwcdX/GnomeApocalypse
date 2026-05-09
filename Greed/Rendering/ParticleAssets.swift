import SpriteKit

final class ParticleAssets {
    static let shared = ParticleAssets()

    enum Effect: String, CaseIterable {
        case orbCollect = "OrbCollect"
        case gnomeDeath = "GnomeDeath"
        case shieldExpand = "ShieldExpand"
        case shieldBurst = "ShieldBurst"
        case mistExplosion = "MistExplosion"
    }

    private var emitters: [Effect: SKEmitterNode] = [:]

    private init() {}

    func preloadAll() {
        Effect.allCases.forEach { preload($0) }
    }

    func makeEmitter(for effect: Effect) -> SKEmitterNode? {
        emitters[effect]?.copy() as? SKEmitterNode
    }

    func emit(_ effect: Effect, at position: CGPoint, in parent: SKNode) {
        guard let emitter = makeEmitter(for: effect) else { return }
        emitter.position = position
        parent.addChild(emitter)

        let lifetime = TimeInterval(emitter.particleLifetime + emitter.particleLifetimeRange)
        emitter.run(.sequence([.wait(forDuration: lifetime), .removeFromParent()]))
    }

    private func preload(_ effect: Effect) {
        guard emitters[effect] == nil,
              let emitter = SKEmitterNode(fileNamed: effect.rawValue)
        else { return }

        emitter.targetNode = nil
        emitters[effect] = emitter
    }
}
