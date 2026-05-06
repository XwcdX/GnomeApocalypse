import SpriteKit
import MetalKit

final class MetalRenderer: NSObject {
    private(set) var mtkView: MTKView
    private let renderer: SKRenderer
    private var currentScene: SKScene?
    private var lastRenderTime: CFTimeInterval = 0

    init?(frame: CGRect) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            Log.error("MetalRenderer: no Metal device available")
            return nil
        }

        mtkView = MTKView(frame: frame, device: device)
        mtkView.preferredFramesPerSecond = 120
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false

        renderer = SKRenderer(device: device)
        renderer.showsNodeCount = false
        renderer.showsDrawCount = false

        super.init()

        mtkView.delegate = self
    }

    func present(scene: SKScene) {
        scene.scaleMode = .resizeFill
        renderer.scene = scene
        currentScene = scene
        lastRenderTime = 0
    }
}

extension MetalRenderer: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        currentScene?.size = size
    }

    func draw(in view: MTKView) {
        guard
            let commandQueue = view.device?.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor
        else { return }

        let now = CACurrentMediaTime()
        let deltaTime = lastRenderTime == 0 ? 0 : now - lastRenderTime
        lastRenderTime = now

        renderer.update(atTime: now)
        renderer.render(
            withViewport: CGRect(origin: .zero, size: view.drawableSize),
            commandBuffer: commandBuffer,
            renderPassDescriptor: descriptor
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()

        _ = deltaTime
    }
}
