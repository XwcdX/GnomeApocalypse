import SpriteKit

final class GameOverOverlay: SKNode {
    private enum Metrics {
        static let baseWidth: CGFloat = GameConfig.mapSize.width
        static let baseHeight: CGFloat = GameConfig.mapSize.height
    }

    private let survivedTime: TimeInterval
    private let onReplay: () -> Void
    private var screenSize: CGSize
    private var replayRect: CGRect = .zero
    private var hasReplayed = false

    private let dimmer = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.58), size: .zero)
    private let survivedLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let timeLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let replayButton = SKShapeNode()
    private let replayLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")

    init(survivedTime: TimeInterval, screenSize: CGSize, onReplay: @escaping () -> Void) {
        self.survivedTime = survivedTime
        self.screenSize = screenSize
        self.onReplay = onReplay
        super.init()

        name = "gameOverOverlay"
        zPosition = Layer.hud + 30
        setupNodes()
        layout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func updateViewport(_ screenSize: CGSize) {
        guard self.screenSize != screenSize else { return }
        self.screenSize = screenSize
        layout()
    }

    @discardableResult
    func handleMouseDown(at point: CGPoint) -> Bool {
        guard !hasReplayed else { return true }
        guard replayRect.contains(point) else { return true }
        replay()
        return true
    }

    func replay() {
        guard !hasReplayed else { return }
        hasReplayed = true
        onReplay()
    }

    private func setupNodes() {
        dimmer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dimmer.zPosition = 0
        addChild(dimmer)

        survivedLabel.text = "You survived for"
        survivedLabel.fontColor = .white
        survivedLabel.horizontalAlignmentMode = .center
        survivedLabel.verticalAlignmentMode = .center
        survivedLabel.zPosition = 1
        addChild(survivedLabel)

        timeLabel.text = formatTime(survivedTime)
        timeLabel.fontColor = .white
        timeLabel.horizontalAlignmentMode = .center
        timeLabel.verticalAlignmentMode = .center
        timeLabel.zPosition = 1
        addChild(timeLabel)

        replayButton.fillColor = .black
        replayButton.strokeColor = .white
        replayButton.lineJoin = .round
        replayButton.zPosition = 1
        addChild(replayButton)

        replayLabel.text = "Start Again"
        replayLabel.fontColor = .white
        replayLabel.horizontalAlignmentMode = .center
        replayLabel.verticalAlignmentMode = .center
        replayLabel.zPosition = 2
        replayButton.addChild(replayLabel)
    }

    private func layout() {
        let scale = layoutScale(for: screenSize)
        let halfHeight = screenSize.height / 2

        dimmer.position = .zero
        dimmer.size = screenSize

        survivedLabel.fontSize = scaled(34, scale)
        survivedLabel.position = CGPoint(x: 0, y: halfHeight - scaled(150, scale))

        timeLabel.fontSize = scaled(74, scale)
        timeLabel.position = CGPoint(x: 0, y: halfHeight - scaled(230, scale))

        let buttonSize = CGSize(width: scaled(320, scale), height: scaled(90, scale))
        let buttonY = halfHeight - scaled(360, scale)
        replayButton.position = CGPoint(x: 0, y: buttonY)
        replayButton.path = CGPath(
            roundedRect: CGRect(
                x: -buttonSize.width / 2,
                y: -buttonSize.height / 2,
                width: buttonSize.width,
                height: buttonSize.height
            ),
            cornerWidth: scaled(12, scale),
            cornerHeight: scaled(12, scale),
            transform: nil
        )
        replayButton.lineWidth = scaled(2, scale)

        replayLabel.fontSize = scaled(34, scale)
        replayLabel.position = .zero

        replayRect = CGRect(
            x: -buttonSize.width / 2,
            y: buttonY - buttonSize.height / 2,
            width: buttonSize.width,
            height: buttonSize.height
        )

        position = .zero
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = max(0, Int(time))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func layoutScale(for size: CGSize) -> CGFloat {
        let widthScale = size.width / Metrics.baseWidth
        let heightScale = size.height / Metrics.baseHeight
        return min(max(min(widthScale, heightScale), 0.65), 1.25)
    }

    private func scaled(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
        value * scale
    }
}
