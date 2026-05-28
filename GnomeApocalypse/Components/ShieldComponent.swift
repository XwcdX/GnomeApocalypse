import SpriteKit

/// Placeholder level-up shield node retained while active shield physics is disabled.
final class ShieldComponent: SKNode {
    private weak var player: PlayerEntity?

    init(player: PlayerEntity) {
        self.player = player
        super.init()
        name = "levelUpShield"
        zPosition = Layer.world
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Keeps the shield centered on its owner; `affectedNodes` is reserved for future push logic.
    func update(deltaTime: TimeInterval, affectedNodes: [SKNode]) {
        if let player { position = player.position }
    }

    /// Removes the shield from the scene; `affectedNodes` is reserved for future burst logic.
    func burst(affectedNodes: [SKNode]) {
        removeFromParent()
    }

    func dissolve() {
        removeFromParent()
    }
}
