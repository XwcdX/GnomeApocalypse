import SpriteKit

struct ToroidalPositionComponent {
    func update(node: SKNode) {
        node.position = toroidalWrap(node.position, mapSize: GameConfig.mapSize)
    }
}
