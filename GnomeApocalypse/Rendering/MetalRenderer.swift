import SpriteKit
import MetalKit

/// Bridges SpriteKit scenes into an `MTKView` through `SKRenderer`.
final class MetalRenderer: NSObject {
    private(set) var mtkView: MTKView
    private let renderer: SKRenderer
    private let commandQueue: MTLCommandQueue
    private var currentScene: SKScene?
    private var currentLogicalSize: CGSize = .zero

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
        mtkView.layerContentsRedrawPolicy = .duringViewResize
        mtkView.layer?.needsDisplayOnBoundsChange = true
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float_stencil8
        mtkView.colorspace = CGColorSpace(name: CGColorSpace.displayP3)

        renderer = SKRenderer(device: device)
        renderer.showsNodeCount = false
        renderer.showsDrawCount = false

        super.init()

        mtkView.delegate = self
    }

    /// Presents a scene and synchronizes its logical viewport with the Metal view bounds.
    func present(scene: SKScene) {
        scene.scaleMode = .resizeFill
        let logicalSize = mtkView.bounds.size
        currentLogicalSize = logicalSize
        scene.size = logicalSize
        renderer.scene = scene
        currentScene = scene
        if let gameScene = scene as? GameScene {
            gameScene.updateViewport(logicalSize)
        }
    }

    /// Forces viewport synchronization after AppKit layout changes.
    func updateLogicalViewport() {
        updateLogicalViewportIfNeeded(for: mtkView)
    }

    /// Marks the Metal view and backing layer as needing display.
    func requestRedraw() {
        mtkView.needsDisplay = true
        mtkView.layer?.setNeedsDisplay()
    }
}

extension MetalRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateLogicalViewportIfNeeded(for: view)
    }

    func draw(in view: MTKView) {
        updateLogicalViewportIfNeeded(for: view)

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

    private func updateLogicalViewportIfNeeded(for view: MTKView) {
        let logicalSize = view.bounds.size
        guard logicalSize.width > 0, logicalSize.height > 0 else { return }
        guard logicalSize != currentLogicalSize else { return }
        currentLogicalSize = logicalSize
        currentScene?.size = logicalSize
        if let gameScene = currentScene as? GameScene {
            gameScene.updateViewport(logicalSize)
        }
    }
}
