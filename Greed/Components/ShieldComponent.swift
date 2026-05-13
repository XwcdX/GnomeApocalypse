import SpriteKit

// TODO: V1 — implement full shield expansion, physics impulse, isTargetingActive toggle
final class ShieldComponent: SKNode {
    private weak var player: PlayerEntity?

    init(player: PlayerEntity) {
        self.player = player
        super.init()
        name = "levelUpShield"
        zPosition = Layer.projectile
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(deltaTime: TimeInterval, affectedNodes: [SKNode]) {
        if let player { position = player.position }
    }

    func burst(affectedNodes: [SKNode]) {
        removeFromParent()
    }

    func dissolve() {
        removeFromParent()
    }
}
