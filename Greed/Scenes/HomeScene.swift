import SpriteKit

final class HomeScene: SKScene {
    private let onStart: () -> Void

    private let background = SKSpriteNode(texture: SKTexture(imageNamed: "tile_ground"))
    private let dimmer = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.58), size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let startLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")

    init(size: CGSize, onStart: @escaping () -> Void) {
        self.onStart = onStart
        super.init(size: size)
        scaleMode = .resizeFill
        setupNodes()
        layout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func didChangeSize(_ oldSize: CGSize) {
        layout()
    }

    func handleStartInput() {
        onStart()
    }

    private func setupNodes() {
        background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        background.zPosition = 0
        background.color = SKColor(red: 0.10, green: 0.18, blue: 0.24, alpha: 1)
        background.colorBlendFactor = 0.55
        addChild(background)

        dimmer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dimmer.zPosition = 1
        addChild(dimmer)

        titleLabel.text = "Gnome Apocalypse"
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 2
        addChild(titleLabel)

        startLabel.text = "Press Anywhere to Start"
        startLabel.fontColor = .white
        startLabel.horizontalAlignmentMode = .center
        startLabel.verticalAlignmentMode = .center
        startLabel.zPosition = 2
        addChild(startLabel)
    }

    private func layout() {
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.size = size
        dimmer.position = background.position
        dimmer.size = size

        titleLabel.fontSize = max(30, size.width * 0.035)
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.70)

        startLabel.fontSize = max(18, size.width * 0.018)
        startLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.32)
    }
}
