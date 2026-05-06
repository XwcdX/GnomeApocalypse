import SpriteKit

final class CameraSystem {
    let cameraNode: SKCameraNode
    private(set) var players: [PlayerEntity] = []

    private let viewportSize: CGSize

    init(cameraNode: SKCameraNode, viewportSize: CGSize) {
        self.cameraNode = cameraNode
        self.viewportSize = viewportSize
    }

    func addPlayer(_ player: PlayerEntity) {
        guard !players.contains(where: { $0 === player }) else { return }
        players.append(player)
    }

    func removePlayer(_ player: PlayerEntity) {
        players.removeAll { $0 === player }
    }

    func update(deltaTime: TimeInterval) {
        guard !players.isEmpty else { return }
        
        let target = midpoint(of: players.map { $0.position })
        let current = cameraNode.position
        
        let offset = toroidalOffset(from: current, to: target, mapSize: GameConfig.mapSize)
        
        cameraNode.position = CGPoint(
            x: current.x + offset.dx * GameConfig.cameraFollowSpeed,
            y: current.y + offset.dy * GameConfig.cameraFollowSpeed
        )
        
        cameraNode.position = toroidalWrap(cameraNode.position, mapSize: GameConfig.mapSize)
    }

    var visibleRect: CGRect {
        let origin = CGPoint(
            x: cameraNode.position.x - viewportSize.width  / 2,
            y: cameraNode.position.y - viewportSize.height / 2
        )
        return CGRect(origin: origin, size: viewportSize)
    }

    var isLocked: Bool = false

    func isWithinLeash(_ position: CGPoint) -> Bool {
        let halfW = (viewportSize.width  / 2) * GameConfig.cameraLeashFactor
        let halfH = (viewportSize.height / 2) * GameConfig.cameraLeashFactor
        let centre = cameraNode.position
        return abs(position.x - centre.x) <= halfW
            && abs(position.y - centre.y) <= halfH
    }

    private func midpoint(of positions: [CGPoint]) -> CGPoint {
        guard !positions.isEmpty else { return cameraNode.position }
        let sum = positions.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(positions.count), y: sum.y / CGFloat(positions.count))
    }
}
