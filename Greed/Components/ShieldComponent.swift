import SpriteKit

final class ShieldComponent: SKNode {
    private weak var player: PlayerEntity?

    private(set) var radius: CGFloat = 0
    private(set) var isExpanded = true

    init(player: PlayerEntity) {
        self.player = player
        super.init()

        name = "levelUpShield"
        zPosition = Layer.projectile
        position = player.position
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    @discardableResult
    func update(deltaTime: TimeInterval, affectedNodes: [SKNode]) -> Bool {
        if let player {
            position = player.position
        }
        return true
    }

    func burst(affectedNodes: [SKNode]) {
        removeFromParent()
    }

    func dissolve() {
        removeFromParent()
    }
}
