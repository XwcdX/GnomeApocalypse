import SpriteKit

final class GameScene: SKScene {
    private let spriteCount = 10000
    private var sprites: [SKSpriteNode] = []
    private var velocities: [CGVector] = []
    private var metricsLabel: SKLabelNode!

    private var currentBackend = "Metal + SKRenderer"

    private var lastTime: TimeInterval = 0
    private var frameCount: Int = 0
    private var fpsAccum: TimeInterval = 0
    private var displayFPS: Double = 0

    func setup(backend: String) {
        anchorPoint = CGPoint(x: 0, y: 0)
        backgroundColor = .black
        setupSprites()
        setupMetricsLabel(backend: backend)
    }

    func updateBackendLabel(_ backend: String) {
        guard metricsLabel != nil else { return }
        currentBackend = backend
    }

    private func setupSprites() {
        let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemCyan, .systemPurple]
        sprites.reserveCapacity(spriteCount)
        velocities.reserveCapacity(spriteCount)

        for i in 0..<spriteCount {
            let node = SKSpriteNode(color: colors[i % colors.count], size: CGSize(width: 8, height: 8))
            node.position = CGPoint(
                x: CGFloat.random(in: 0..<size.width),
                y: CGFloat.random(in: 0..<size.height)
            )
            let speed = CGFloat.random(in: 60...180)
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            velocities.append(CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed))
            addChild(node)
            sprites.append(node)
        }
    }

    private func setupMetricsLabel(backend: String) {
        currentBackend = backend
        metricsLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        metricsLabel.fontSize = 14
        metricsLabel.fontColor = .white
        metricsLabel.horizontalAlignmentMode = .left
        metricsLabel.verticalAlignmentMode = .top
        metricsLabel.zPosition = 100
        metricsLabel.position = CGPoint(x: 12, y: size.height - 12)
        addChild(metricsLabel)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : currentTime - lastTime
        lastTime = currentTime

        guard sprites.count == spriteCount else { return }

        fpsAccum += dt
        frameCount += 1
        if fpsAccum >= 0.5 {
            displayFPS = Double(frameCount) / fpsAccum
            frameCount = 0
            fpsAccum = 0
        }

        let w = size.width
        let h = size.height

        for i in 0..<spriteCount {
            var pos = sprites[i].position
            let vel = velocities[i]
            pos.x += vel.dx * dt
            pos.y += vel.dy * dt

            if pos.x < 0 { pos.x += w } else if pos.x >= w { pos.x -= w }
            if pos.y < 0 { pos.y += h } else if pos.y >= h { pos.y -= h }

            sprites[i].position = pos
        }

        metricsLabel.text = String(format: "FPS: %.0f  Nodes: %d  %@",
                                   displayFPS, children.count, currentBackend)
    }
}
