import Cocoa
import Metal
import MetalKit
import SpriteKit

final class ViewController: NSViewController {

    // Metal path
    private var metalView: MTKView!
    private var renderer: SKRenderer!
    private var commandQueue: MTLCommandQueue!

    // CPU path
    private var skView: SKView!

    private var scene: GameScene!
    private var lastTime: CFTimeInterval = 0
    private var usingMetal = true

    override var acceptsFirstResponder: Bool { true }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard scene == nil else { return }
        setupMetal()
        setupSKView()
        setupScene()
        activateMetal()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.charactersIgnoringModifiers?.lowercased() == "m" {
                self?.usingMetal == true ? self?.activateSKView() : self?.activateMetal()
                return nil
            }
            return event
        }
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
        metalView.preferredFramesPerSecond = 60
        metalView.framebufferOnly = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.colorspace = CGColorSpace(name: CGColorSpace.displayP3)
        metalView.delegate = self
        metalView.isHidden = true
        view.addSubview(metalView)

        print("[Metal] Device: \(device.name)")
    }

    private func setupSKView() {
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.width, .height]
        skView.isHidden = true
        view.addSubview(skView)
    }

    private func setupScene() {
        scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        scene.setup(backend: "Metal + SKRenderer")
    }

    private func activateMetal() {
        usingMetal = true
        skView.isHidden = true
        skView.presentScene(nil)
        metalView.isHidden = false
        renderer.scene = scene
        scene.updateBackendLabel("Metal + SKRenderer  [press M to switch]")
    }

    private func activateSKView() {
        usingMetal = false
        metalView.isHidden = true
        renderer.scene = nil
        skView.isHidden = false
        skView.presentScene(scene)
        scene.updateBackendLabel("SKView CPU  [press M to switch]")
    }

}

extension ViewController: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        scene.size = size
    }

    func draw(in view: MTKView) {
        guard usingMetal,
              let commandBuffer = commandQueue.makeCommandBuffer(),
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
