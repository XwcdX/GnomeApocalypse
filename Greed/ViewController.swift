import Cocoa
import MetalKit
import SpriteKit

final class ViewController: NSViewController {
    private var metalRenderer: MetalRenderer!
    private var homeScene: HomeScene!
    private var gameScene: GameScene?
    private lazy var manualAimCursor = makeManualAimCursor()
    private lazy var hiddenAimCursor = makeHiddenAimCursor()
    private var currentAimCursor: NSCursor?

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
        scene.onReplayRequested = { [weak self] in
            self?.startGame()
        }
        scene.onAimModeChanged = { [weak self] mode in
            self?.applyAimCursorMode(mode)
        }
        scene.onGameOverPresented = { [weak self] in
            self?.restoreSystemCursor()
        }
        scene.setup(view: metalRenderer.mtkView)
        gameScene = scene
        metalRenderer.present(scene: scene)
        view.window?.makeFirstResponder(self)
        applyAimCursorMode(InputSystem.shared.aimMode(for: 0))
    }

    private func applyAimCursorMode(_ mode: InputSystem.AimMode) {
        let cursor: NSCursor = mode == .manual ? manualAimCursor : hiddenAimCursor
        guard currentAimCursor !== cursor else { return }
        currentAimCursor = cursor
        metalRenderer.mtkView.discardCursorRects()
        metalRenderer.mtkView.addCursorRect(metalRenderer.mtkView.bounds, cursor: cursor)
        cursor.set()
    }

    private func restoreSystemCursor() {
        currentAimCursor = nil
        metalRenderer.mtkView.discardCursorRects()
        NSCursor.arrow.set()
    }

    private func makeHiddenAimCursor() -> NSCursor {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        return NSCursor(image: image, hotSpot: .zero)
    }

    private func makeManualAimCursor() -> NSCursor {
        let size = NSSize(width: 28, height: 28)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.withAlphaComponent(0.82).setStroke()
            let outerShadow = NSBezierPath(ovalIn: rect.insetBy(dx: 5, dy: 5))
            outerShadow.lineWidth = 4
            outerShadow.stroke()

            NSColor(calibratedRed: 0.35, green: 0.9, blue: 1.0, alpha: 1).setStroke()
            let outer = NSBezierPath(ovalIn: rect.insetBy(dx: 5, dy: 5))
            outer.lineWidth = 2
            outer.stroke()

            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 12, dy: 12)).fill()

            NSColor(calibratedRed: 0.35, green: 0.9, blue: 1.0, alpha: 1).setStroke()
            let horizontal = NSBezierPath()
            horizontal.move(to: NSPoint(x: 2, y: rect.midY))
            horizontal.line(to: NSPoint(x: 9, y: rect.midY))
            horizontal.move(to: NSPoint(x: 19, y: rect.midY))
            horizontal.line(to: NSPoint(x: 26, y: rect.midY))
            horizontal.lineWidth = 2
            horizontal.stroke()

            let vertical = NSBezierPath()
            vertical.move(to: NSPoint(x: rect.midX, y: 2))
            vertical.line(to: NSPoint(x: rect.midX, y: 9))
            vertical.move(to: NSPoint(x: rect.midX, y: 19))
            vertical.line(to: NSPoint(x: rect.midX, y: 26))
            vertical.lineWidth = 2
            vertical.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
    }

    private func setupInput() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard gameScene != nil else {
                homeScene.handleStartInput()
                return nil
            }
            if gameScene?.handleKeyDown(event) == true {
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
                return event
            }
            let viewPosition = metalRenderer.mtkView.convert(event.locationInWindow, from: nil)
            if gameScene?.handleMouseDown(atViewPosition: viewPosition, viewSize: metalRenderer.mtkView.bounds.size) == true {
                return nil
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
