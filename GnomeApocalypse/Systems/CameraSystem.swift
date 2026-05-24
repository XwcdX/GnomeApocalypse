import SpriteKit

/// Owns camera following, toroidal wrapping relative to the camera, and boss-stage locks.
final class CameraSystem {
    let cameraNode: SKCameraNode
    private(set) var players: [PlayerEntity] = []

    private(set) var viewportSize: CGSize

    init(cameraNode: SKCameraNode, viewportSize: CGSize) {
        self.cameraNode = cameraNode
        self.viewportSize = viewportSize
        cameraNode.setScale(1.0 / GameConfig.cameraZoom)
    }

    /// Stores the current view size in points for camera-space constraints.
    func updateViewport(_ size: CGSize) {
        viewportSize = size
    }

    var worldViewportSize: CGSize { GameConfig.cameraViewportSize }

    /// Starts including a player in camera follow calculations.
    func addPlayer(_ player: PlayerEntity) {
        guard !players.contains(where: { $0 === player }) else { return }
        players.append(player)
    }

    /// Stops including a player in camera follow calculations.
    func removePlayer(_ player: PlayerEntity) {
        players.removeAll { $0 === player }
    }

    /// Repositions a world point to the nearest wrapped sector around the camera.
    func clampToroidal(_ position: inout CGPoint) {
        let camPos = cameraNode.position
        let hw = GameConfig.mapSize.width / 2
        let hh = GameConfig.mapSize.height / 2
        if position.x - camPos.x >  hw { position.x -= GameConfig.mapSize.width }
        if position.x - camPos.x < -hw { position.x += GameConfig.mapSize.width }
        if position.y - camPos.y >  hh { position.y -= GameConfig.mapSize.height }
        if position.y - camPos.y < -hh { position.y += GameConfig.mapSize.height }
    }

    /// Moves the camera toward the midpoint of tracked players unless locked.
    func update(deltaTime: TimeInterval) {
        guard !isLocked else { return }
        guard !players.isEmpty else { return }

        let target = midpoint(of: players.map { $0.position })
        let current = cameraNode.position
        let offset = toroidalOffset(from: current, to: target, mapSize: GameConfig.mapSize)
        cameraNode.position = CGPoint(
            x: current.x + offset.dx * GameConfig.cameraFollowSpeed,
            y: current.y + offset.dy * GameConfig.cameraFollowSpeed
        )
    }

    /// Current world-space rectangle visible through the camera.
    var visibleRect: CGRect {
        let origin = CGPoint(
            x: cameraNode.position.x - worldViewportSize.width  / 2,
            y: cameraNode.position.y - worldViewportSize.height / 2
        )
        return CGRect(origin: origin, size: worldViewportSize)
    }

    var isLocked: Bool = false
    var bossArenaCenter: CGPoint = .zero

    /// Freezes camera follow at a boss arena center until explicitly unlocked.
    func lockCamera(at position: CGPoint) {
        isLocked = true
        bossArenaCenter = position
    }

    /// Restores normal player-follow behavior.
    func unlockCamera() {
        isLocked = false
    }

    /// Keeps a player inside the visible boss arena while the camera is locked.
    func enforceLeash(for player: PlayerEntity) {
        guard isLocked else { return }
        
        let halfW = viewportSize.width  / (GameConfig.cameraZoom * 2)
        let halfH = viewportSize.height / (GameConfig.cameraZoom * 2)
        
        player.position.x = min(max(player.position.x, bossArenaCenter.x - halfW), bossArenaCenter.x + halfW)
        player.position.y = min(max(player.position.y, bossArenaCenter.y - halfH), bossArenaCenter.y + halfH)
    }

    /// Applies a temporary shake around the current camera anchor.
    func shakeCamera(duration: TimeInterval, amplitude: CGFloat) {
        let originalPos = cameraNode.position
        
        let shakeAction = SKAction.customAction(withDuration: duration) { _, elapsedTime in
            let percent = elapsedTime / CGFloat(duration)
            let currentAmplitude = amplitude * (1.0 - percent)
            let randomX = CGFloat.random(in: -currentAmplitude...currentAmplitude)
            let randomY = CGFloat.random(in: -currentAmplitude...currentAmplitude)
            self.cameraNode.position = CGPoint(x: originalPos.x + randomX, y: originalPos.y + randomY)
        }
        
        let resetAction = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.cameraNode.position = self.isLocked ? self.bossArenaCenter : originalPos
        }
        
        cameraNode.run(SKAction.sequence([shakeAction, resetAction]), withKey: "camera_shake")
    }

    private func midpoint(of positions: [CGPoint]) -> CGPoint {
        guard !positions.isEmpty else { return cameraNode.position }
        let sum = positions.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(positions.count), y: sum.y / CGFloat(positions.count))
    }
}
