import Cocoa
import Metal
import MetalKit
import SpriteKit

final class ViewController: NSViewController {
    private var metalView: MTKView!
    private var renderer: SKRenderer!
    private var commandQueue: MTLCommandQueue!
    private var scene: GameScene!
    private var lastTime: CFTimeInterval = 0

    override var acceptsFirstResponder: Bool { true }

    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.makeFirstResponder(self)
        
        guard scene == nil else { return }
        setupMetal()
        setupScene()
        setupInput()
    }

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("Metal not supported")
        }
        commandQueue = queue
        renderer = SKRenderer(device: device)

        metalView = MTKView(frame: view.bounds, device: device)
        metalView.autoresizingMask = [.width, .height]
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        metalView.preferredFramesPerSecond = 120
        metalView.framebufferOnly = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.colorspace = CGColorSpace(name: CGColorSpace.displayP3)
        metalView.delegate = self
        view.addSubview(metalView)
    }

    private func setupScene() {
        scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        scene.setup(view: metalView)
        renderer.scene = scene
    }
    
    private func setupInput() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            InputSystem.shared.keyDown(with: event)
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            InputSystem.shared.keyUp(with: event)
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            guard let self, event.window === self.view.window else { return event }
            
            let viewPosition = self.metalView.convert(event.locationInWindow, from: nil)
            let worldPosition = self.scene.convertPoint(fromView: viewPosition)
            InputSystem.shared.mouseMoved(to: worldPosition)
            return event
        }
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        scene.size = size
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable
        else { return }

        let now = CACurrentMediaTime()
        if lastTime == 0 { lastTime = now }
        lastTime = now

        renderer.update(atTime: now)
        renderer.render(
            withViewport: CGRect(origin: .zero, size: view.drawableSize),
            commandBuffer: commandBuffer,
            renderPassDescriptor: descriptor
        )
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
