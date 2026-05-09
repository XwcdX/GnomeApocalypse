import SpriteKit
import Testing

@testable import Greed

@MainActor
@Suite("CameraSystem")
struct CameraSystemTests {
    @Test("locked camera does not follow players")
    func lockedCameraDoesNotFollowPlayers() {
        let cameraNode = SKCameraNode()
        let cameraSystem = CameraSystem(cameraNode: cameraNode, viewportSize: GameConfig.cameraViewportSize)
        let player = PlayerEntity(texture: SKTexture(imageNamed: "tile_ground"))
        player.position = CGPoint(x: 200, y: 100)
        cameraSystem.addPlayer(player)

        cameraSystem.isLocked = true
        cameraSystem.update(deltaTime: 1)

        #expect(cameraNode.position == .zero)
    }
}
