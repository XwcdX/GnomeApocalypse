import SpriteKit

final class CameraSystem {
    let cameraNode: SKCameraNode
    private(set) var players: [PlayerEntity] = []

    private(set) var viewportSize: CGSize

    init(cameraNode: SKCameraNode, viewportSize: CGSize) {
        self.cameraNode = cameraNode
        self.viewportSize = viewportSize
        cameraNode.setScale(1.0 / GameConfig.cameraZoom)
    }

    func updateViewport(_ size: CGSize) {
        viewportSize = size
    }

    var worldViewportSize: CGSize { GameConfig.cameraViewportSize }

    func addPlayer(_ player: PlayerEntity) {
        guard !players.contains(where: { $0 === player }) else { return }
        players.append(player)
    }

    func removePlayer(_ player: PlayerEntity) {
        players.removeAll { $0 === player }
    }

    func clampToroidal(_ position: inout CGPoint) {
        let camPos = cameraNode.position
        let hw = GameConfig.mapSize.width / 2
        let hh = GameConfig.mapSize.height / 2
        if position.x - camPos.x >  hw { position.x -= GameConfig.mapSize.width }
        if position.x - camPos.x < -hw { position.x += GameConfig.mapSize.width }
        if position.y - camPos.y >  hh { position.y -= GameConfig.mapSize.height }
        if position.y - camPos.y < -hh { position.y += GameConfig.mapSize.height }
    }

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

    var visibleRect: CGRect {
        let origin = CGPoint(
            x: cameraNode.position.x - worldViewportSize.width  / 2,
            y: cameraNode.position.y - worldViewportSize.height / 2
        )
        return CGRect(origin: origin, size: worldViewportSize)
    }

    var isLocked: Bool = false
    var bossArenaCenter: CGPoint = .zero

    func lockCamera(at position: CGPoint) {
        isLocked = true
        bossArenaCenter = position
    }

    func unlockCamera() {
        isLocked = false
    }

    /// Membatasi posisi pemain agar tidak keluar dari layar/viewport yang terlihat saat kamera terkunci (Boss Stage).
    func enforceLeash(for player: PlayerEntity) {
        guard isLocked else { return }
        
        // Ukuran dunia yang terlihat di layar = viewportSize / cameraZoom
        let halfW = viewportSize.width  / (GameConfig.cameraZoom * 2)
        let halfH = viewportSize.height / (GameConfig.cameraZoom * 2)
        
        player.position.x = min(max(player.position.x, bossArenaCenter.x - halfW), bossArenaCenter.x + halfW)
        player.position.y = min(max(player.position.y, bossArenaCenter.y - halfH), bossArenaCenter.y + halfH)
    }

    /// Efek kamera bergetar (screen shake) dengan durasi dan amplitudo tertentu.
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
