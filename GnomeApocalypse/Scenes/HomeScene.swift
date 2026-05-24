import SpriteKit

/// Title scene that preloads gameplay assets and starts the run after user input.
final class HomeScene: SKScene {
    private let onStart: () -> Void
    private var hasStarted = false

    private let background = SKSpriteNode(texture: SKTexture(imageNamed: "tile_ground"))
    private let dimmer = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.58), size: .zero)
    private let titleLabel = OutlinedLabel(text: "Gnome Apocalypse")
    private let startLabel = OutlinedLabel(text: "Press Any Button to Start")

    private final class OutlinedLabel {
        let root = SKNode()
        private let foreground: SKLabelNode
        private let shadows: [SKLabelNode]

        init(text: String) {
            let offsets = [
                CGPoint(x: -2, y: -2),
                CGPoint(x: 2, y: -2),
                CGPoint(x: -2, y: 2),
                CGPoint(x: 2, y: 2)
            ]

            shadows = offsets.map { offset in
                let label = SKLabelNode(fontNamed: GameConfig.fontName)
                label.text = text
                label.fontColor = .black
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.position = offset
                return label
            }

            foreground = SKLabelNode(fontNamed: GameConfig.fontName)
            foreground.text = text
            foreground.fontColor = .white
            foreground.horizontalAlignmentMode = .center
            foreground.verticalAlignmentMode = .center

            shadows.forEach { root.addChild($0) }
            root.addChild(foreground)
        }

        func setFontSize(_ fontSize: CGFloat) {
            foreground.fontSize = fontSize * 1.5
            shadows.forEach { $0.fontSize = fontSize * 1.5 }
        }

        func setText(_ text: String) {
            foreground.text = text
            shadows.forEach { $0.text = text }
        }
    }

    init(size: CGSize, onStart: @escaping () -> Void) {
        self.onStart = onStart
        super.init(size: size)
        scaleMode = .resizeFill
        setupNodes()
        layout()
        preloadGameplayAssets()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func didChangeSize(_ oldSize: CGSize) {
        layout()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !hasStarted else { return }
        if InputSystem.shared.consumeAnyMenuButton(for: 0) {
            handleStartInput()
        }
    }

    /// Starts gameplay once preloading has completed.
    func handleStartInput() {
        guard !hasStarted else { return }
        guard GameAssetPreloader.shared.isReady else { return }
        hasStarted = true
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

        titleLabel.root.zPosition = 2
        addChild(titleLabel.root)

        startLabel.setText(GameAssetPreloader.shared.isReady ? "Press Any Button to Start" : "Loading...")
        startLabel.root.zPosition = 2
        addChild(startLabel.root)
    }

    private func preloadGameplayAssets() {
        GameAssetPreloader.shared.preloadGameplayAssets { [weak self] in
            self?.startLabel.setText("Press Any Button to Start")
        }
    }

    private func layout() {
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.size = size
        dimmer.position = background.position
        dimmer.size = size

        titleLabel.setFontSize(max(30, size.width * 0.035))
        titleLabel.root.position = CGPoint(x: size.width / 2, y: size.height * 0.70)

        startLabel.setFontSize(max(18, size.width * 0.018))
        startLabel.root.position = CGPoint(x: size.width / 2, y: size.height * 0.32)
    }
}
