import SpriteKit
import Testing
@testable import GnomeApocalypse

@MainActor
@Suite("CameraSystem")
struct CameraSystemTests {
    @Test("camera moves toward player position each update")
    func cameraMoveTowardPlayer() {
        let cam = SKCameraNode()
        let system = CameraSystem(cameraNode: cam, viewportSize: GameConfig.cameraViewportSize)
        let player = PlayerEntity(texture: SKTexture())
        player.position = CGPoint(x: 200, y: 100)
        system.addPlayer(player)

        system.update(deltaTime: 1)

        #expect(cam.position.x > 0)
        #expect(cam.position.y > 0)
    }

    @Test("camera does not move with no players")
    func cameraDoesNotMoveWithNoPlayers() {
        let cam = SKCameraNode()
        let system = CameraSystem(cameraNode: cam, viewportSize: GameConfig.cameraViewportSize)
        system.update(deltaTime: 1)
        #expect(cam.position == .zero)
    }

    @Test("locked camera does not follow players")
    func lockedCameraDoesNotFollowPlayers() {
        let cam = SKCameraNode()
        let system = CameraSystem(cameraNode: cam, viewportSize: GameConfig.cameraViewportSize)
        let player = PlayerEntity(texture: SKTexture())
        player.position = CGPoint(x: 200, y: 100)
        system.addPlayer(player)

        system.isLocked = true
        system.update(deltaTime: 1)

        #expect(cam.position == .zero)
    }

    @Test("addPlayer does not add the same player twice")
    func addPlayerNoDuplicates() {
        let system = CameraSystem(cameraNode: SKCameraNode(), viewportSize: GameConfig.cameraViewportSize)
        let player = PlayerEntity(texture: SKTexture())
        system.addPlayer(player)
        system.addPlayer(player)
        #expect(system.players.count == 1)
    }

    @Test("removePlayer removes the player")
    func removePlayerRemovesPlayer() {
        let system = CameraSystem(cameraNode: SKCameraNode(), viewportSize: GameConfig.cameraViewportSize)
        let player = PlayerEntity(texture: SKTexture())
        system.addPlayer(player)
        system.removePlayer(player)
        #expect(system.players.isEmpty)
    }

    @Test("visibleRect is centered on camera position")
    func visibleRectCenteredOnCamera() {
        let cam = SKCameraNode()
        cam.position = CGPoint(x: 100, y: 50)
        let vp = GameConfig.cameraViewportSize
        let system = CameraSystem(cameraNode: cam, viewportSize: vp)

        let rect = system.visibleRect
        #expect(abs(rect.midX - 100) < 0.001)
        #expect(abs(rect.midY - 50) < 0.001)
        #expect(abs(rect.width - vp.width) < 0.001)
        #expect(abs(rect.height - vp.height) < 0.001)
    }

    @Test("clampToroidal does not move position within one map-width of camera")
    func clampToroidalDoesNotMoveNearbyPosition() {
        let cam = SKCameraNode()
        cam.position = .zero
        let system = CameraSystem(cameraNode: cam, viewportSize: GameConfig.cameraViewportSize)

        var pos = CGPoint(x: 100, y: 50)
        system.clampToroidal(&pos)
        #expect(pos.x == 100)
        #expect(pos.y == 50)
    }

    @Test("clampToroidal wraps position more than half map-width east of camera")
    func clampToroidalWrapsEast() {
        let cam = SKCameraNode()
        cam.position = .zero
        let system = CameraSystem(cameraNode: cam, viewportSize: GameConfig.cameraViewportSize)

        var pos = CGPoint(x: GameConfig.mapSize.width * 0.6, y: 0)
        system.clampToroidal(&pos)
        #expect(pos.x < 0)
    }

    @Test("clampToroidal wraps position more than half map-width west of camera")
    func clampToroidalWrapsWest() {
        let cam = SKCameraNode()
        cam.position = .zero
        let system = CameraSystem(cameraNode: cam, viewportSize: GameConfig.cameraViewportSize)

        var pos = CGPoint(x: -GameConfig.mapSize.width * 0.6, y: 0)
        system.clampToroidal(&pos)
        #expect(pos.x > 0)
    }

    @Test("updateViewport changes viewportSize")
    func updateViewportChangesSize() {
        let system = CameraSystem(cameraNode: SKCameraNode(), viewportSize: GameConfig.cameraViewportSize)
        let newSize = CGSize(width: 800, height: 600)
        system.updateViewport(newSize)
        #expect(system.viewportSize == newSize)
    }

    @Test("lockCamera locks and sets center, enforceLeash clamps player within boundary")
    func lockAndEnforceLeash() {
        let cam = SKCameraNode()
        let system = CameraSystem(cameraNode: cam, viewportSize: CGSize(width: 1000, height: 600))
        let player = PlayerEntity(texture: SKTexture())
        
        // Locked position at (500, 500)
        system.lockCamera(at: CGPoint(x: 500, y: 500))
        
        #expect(system.isLocked == true)
        #expect(system.bossArenaCenter == CGPoint(x: 500, y: 500))
        
        // Try to place player far away (e.g. 1000, 1000)
        player.position = CGPoint(x: 1000, y: 1000)
        system.enforceLeash(for: player)
        
        // cameraZoom is 2.5 (from GameConfig)
        // halfW = 1000 / (2.5 * 2) = 200
        // halfH = 600 / (2.5 * 2) = 120
        // x bound: [300, 700]
        // y bound: [380, 620]
        #expect(player.position.x == 700)
        #expect(player.position.y == 620)
        
        // Unlock camera
        system.unlockCamera()
        #expect(system.isLocked == false)
        
        // Under unlocked state, enforceLeash should not modify position
        player.position = CGPoint(x: 1000, y: 1000)
        system.enforceLeash(for: player)
        #expect(player.position.x == 1000)
        #expect(player.position.y == 1000)
    }
}
