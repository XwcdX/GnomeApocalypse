import SpriteKit
import MetalKit

final class MetalRenderer: NSObject {
    private(set) var mtkView: MTKView
    private let renderer: SKRenderer
    private let commandQueue: MTLCommandQueue
    private var currentScene: SKScene?

    init?(frame: CGRect) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            Log.error("MetalRenderer: no Metal device available")
            return nil
        }

        commandQueue = queue
        mtkView = MTKView(frame: frame, device: device)
        mtkView.preferredFramesPerSecond = 120
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float_stencil8
        mtkView.colorspace = CGColorSpace(name: CGColorSpace.displayP3)

        renderer = SKRenderer(device: device)
        renderer.showsNodeCount = false
        renderer.showsDrawCount = false

        super.init()

        mtkView.delegate = self
    }

    func present(scene: SKScene) {
        scene.scaleMode = .resizeFill
        let renderSize = mtkView.drawableSize == .zero ? mtkView.bounds.size : mtkView.drawableSize
        scene.size = renderSize
        renderer.scene = scene
        currentScene = scene
        if let gameScene = scene as? GameScene {
            gameScene.updateViewport(renderSize)
        }
    }
}

extension MetalRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        currentScene?.size = size
        if let gameScene = currentScene as? GameScene {
            gameScene.updateViewport(size)
        }
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor
        else { return }

        let now = CACurrentMediaTime()
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
