import Cocoa
import MetalKit
import SpriteKit

final class ViewController: NSViewController {
    private var metalRenderer: MetalRenderer!
    private var homeScene: HomeScene!
    private var gameScene: GameScene?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(self)
        guard homeScene == nil, gameScene == nil else { return }
        setupRenderer()
        setupScene()
        setupInput()
    }

    private func setupRenderer() {
        guard let renderer = MetalRenderer(frame: view.bounds) else {
            fatalError("MetalRenderer init failed")
        }
        metalRenderer = renderer
        metalRenderer.mtkView.autoresizingMask = [.width, .height]
        view.addSubview(metalRenderer.mtkView)
    }

    private func setupScene() {
        homeScene = HomeScene(size: view.bounds.size) { [weak self] in
            self?.startGame()
        }
        metalRenderer.present(scene: homeScene)
    }

    private func startGame() {
        let scene = GameScene(size: metalRenderer.mtkView.bounds.size)
        scene.setup(view: metalRenderer.mtkView)
        gameScene = scene
        metalRenderer.present(scene: scene)
        view.window?.makeFirstResponder(self)
    }

    private func setupInput() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard gameScene != nil else {
                homeScene.handleStartInput()
                return nil
            }
            InputSystem.shared.keyDown(with: event)
            return event
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard self?.gameScene != nil else { return event }
            InputSystem.shared.keyUp(with: event)
            return event
        }
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, event.window === view.window else { return event }
            if gameScene == nil {
                homeScene.handleStartInput()
            }
            return event
        }
        NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            guard let self, let gameScene, event.window === view.window else { return event }
            let viewPos = metalRenderer.mtkView.convert(event.locationInWindow, from: nil)
            let viewSize = metalRenderer.mtkView.bounds.size
            let nx = (viewPos.x / viewSize.width) - 0.5
            let ny = (viewPos.y / viewSize.height) - 0.5
            let cam = gameScene.camera?.position ?? .zero
            let vp = GameConfig.cameraViewportSize
            InputSystem.shared.mouseMoved(to: CGPoint(x: cam.x + nx * vp.width, y: cam.y + ny * vp.height))
            return event
        }
    }
}
