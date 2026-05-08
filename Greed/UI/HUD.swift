import SpriteKit

final class HUD: SKNode {
    private enum Metrics {
        static let sizeMultiplier: CGFloat = 3.0
        static let margin: CGFloat = 0
        static let avatarSize = CGSize(width: 96, height: 84)
        static let essenceBarHeight: CGFloat = 20
        static let healthBarSize = CGSize(width: 420, height: 20)
        static let healthFramePadding: CGFloat = 6
        static let levelRightInset: CGFloat = 0
    }

    private weak var player: PlayerEntity?
    private var screenSize: CGSize
    private var cameraScale: CGFloat

    private let avatarNode = SKShapeNode()
    private let essenceTrack = SKSpriteNode(color: .white, size: .zero)
    private let essenceFill = SKSpriteNode(color: SKColor(red: 0.25, green: 0.72, blue: 1.0, alpha: 1), size: .zero)
    private let healthFrame = SKShapeNode()
    private let healthTrack = SKSpriteNode(color: SKColor(red: 0.08, green: 0.04, blue: 0.06, alpha: 1), size: .zero)
    private let healthFill = SKSpriteNode(color: SKColor(red: 0.94, green: 0.02, blue: 0.10, alpha: 1), size: .zero)
    private let healthIcon = SKShapeNode()
    private let levelLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let stageLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let timerLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")

    init(player: PlayerEntity, screenSize: CGSize, cameraScale: CGFloat) {
        self.player = player
        self.screenSize = screenSize
        self.cameraScale = cameraScale
        super.init()

        name = "hud"
        zPosition = Layer.hud
        isUserInteractionEnabled = false

        setupNodes()
        layout()
        update(elapsedTime: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func updateViewport(_ screenSize: CGSize, cameraScale: CGFloat) {
        self.screenSize = screenSize
        self.cameraScale = cameraScale
        layout()
    }

    func update(elapsedTime: TimeInterval) {
        guard let player else { return }
        setHealthFraction(player.health.fraction)
        setEssenceFraction(player.level.xpFraction)
        levelLabel.text = "LV \(player.level.currentLevel)"
        timerLabel.text = formatElapsedTime(elapsedTime)
    }

    private func setupNodes() {
        avatarNode.fillColor = SKColor(red: 0.28, green: 0.37, blue: 0.72, alpha: 1)
        avatarNode.strokeColor = .clear
        avatarNode.name = "hudAvatar"
        addChild(avatarNode)

        essenceTrack.anchorPoint = CGPoint(x: 0, y: 0.5)
        essenceTrack.name = "essenceBarTrack"
        essenceTrack.zPosition = 0
        addChild(essenceTrack)

        essenceFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        essenceFill.name = "essenceBarFill"
        essenceFill.zPosition = 1
        addChild(essenceFill)

        healthFrame.strokeColor = SKColor(red: 0.38, green: 0.38, blue: 1.0, alpha: 1)
        healthFrame.lineWidth = 2
        healthFrame.fillColor = .clear
        healthFrame.name = "healthBarFrame"
        healthFrame.zPosition = 3
        addChild(healthFrame)

        healthTrack.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthTrack.name = "healthBarTrack"
        healthTrack.zPosition = 1
        addChild(healthTrack)

        healthFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthFill.name = "healthBarFill"
        healthFill.zPosition = 2
        addChild(healthFill)

        healthIcon.fillColor = SKColor(red: 1.0, green: 0.04, blue: 0.10, alpha: 1)
        healthIcon.strokeColor = SKColor(red: 0.32, green: 0.0, blue: 0.02, alpha: 1)
        healthIcon.name = "healthIcon"
        healthIcon.zPosition = 4
        addChild(healthIcon)

        levelLabel.fontColor = .black
        levelLabel.horizontalAlignmentMode = .right
        levelLabel.verticalAlignmentMode = .center
        levelLabel.name = "levelLabel"
        levelLabel.zPosition = 2
        addChild(levelLabel)

        stageLabel.text = "Stage"
        stageLabel.fontColor = .white
        stageLabel.horizontalAlignmentMode = .center
        stageLabel.verticalAlignmentMode = .center
        stageLabel.name = "stageLabel"
        addChild(stageLabel)

        timerLabel.text = "00:00"
        timerLabel.fontColor = .white
        timerLabel.horizontalAlignmentMode = .center
        timerLabel.verticalAlignmentMode = .center
        timerLabel.name = "timerLabel"
        addChild(timerLabel)
    }

    private func layout() {
        let visibleSize = CGSize(width: screenSize.width * cameraScale, height: screenSize.height * cameraScale)
        let left = -visibleSize.width / 2 + scaled(Metrics.margin)
        let right = visibleSize.width / 2 - scaled(Metrics.margin)
        let top = visibleSize.height / 2 - scaled(Metrics.margin)
        let avatarSize = scaled(Metrics.avatarSize)
        let healthBarSize = scaled(Metrics.healthBarSize)
        let essenceBarHeight = scaled(Metrics.essenceBarHeight)

        avatarNode.path = rectPath(size: avatarSize)
        avatarNode.position = CGPoint(
            x: left + avatarSize.width / 2,
            y: top - avatarSize.height / 2
        )

        let essenceLeft = left + avatarSize.width
        let essenceWidth = max(0, right - essenceLeft)
        essenceTrack.position = CGPoint(x: essenceLeft, y: top - essenceBarHeight / 2)
        essenceTrack.size = CGSize(width: essenceWidth, height: essenceBarHeight)
        essenceFill.position = essenceTrack.position

        levelLabel.fontSize = scaled(28)
        levelLabel.position = CGPoint(
            x: right - scaled(Metrics.levelRightInset),
            y: essenceTrack.position.y
        )

        let healthLeft = essenceLeft
        let healthY = top - scaled(52)
        healthTrack.position = CGPoint(x: healthLeft + scaled(34), y: healthY)
        healthTrack.size = healthBarSize
        healthFill.position = healthTrack.position
        healthIcon.path = diamondPath(size: scaled(CGSize(width: 28, height: 28)))
        healthIcon.lineWidth = scaled(2)
        healthIcon.position = CGPoint(x: healthLeft + scaled(16), y: healthY)

        let frameSize = CGSize(
            width: healthBarSize.width + scaled(28),
            height: healthBarSize.height + scaled(Metrics.healthFramePadding * 2)
        )
        healthFrame.lineWidth = scaled(2)
        healthFrame.path = CGPath(
            rect: CGRect(
                x: healthLeft - scaled(Metrics.healthFramePadding),
                y: healthY - frameSize.height / 2,
                width: frameSize.width,
                height: frameSize.height
            ),
            transform: nil
        )

        stageLabel.fontSize = scaled(22)
        timerLabel.fontSize = scaled(38)
        stageLabel.position = CGPoint(x: 0, y: top - scaled(120))
        timerLabel.position = CGPoint(x: 0, y: top - scaled(152))

        setEssenceFraction(player?.level.xpFraction ?? 0)
        setHealthFraction(player?.health.fraction ?? 0)
    }

    private func setHealthFraction(_ fraction: CGFloat) {
        healthFill.size = CGSize(
            width: scaled(Metrics.healthBarSize.width) * clampedFraction(fraction),
            height: scaled(Metrics.healthBarSize.height)
        )
    }

    private func setEssenceFraction(_ fraction: CGFloat) {
        essenceFill.size = CGSize(
            width: essenceTrack.size.width * clampedFraction(fraction),
            height: scaled(Metrics.essenceBarHeight)
        )
    }

    private func clampedFraction(_ fraction: CGFloat) -> CGFloat {
        min(max(fraction, 0), 1)
    }

    private func formatElapsedTime(_ elapsedTime: TimeInterval) -> String {
        let totalSeconds = max(0, Int(elapsedTime))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        value * cameraScale * Metrics.sizeMultiplier
    }

    private func scaled(_ size: CGSize) -> CGSize {
        CGSize(width: scaled(size.width), height: scaled(size.height))
    }

    private func rectPath(size: CGSize) -> CGPath {
        CGPath(
            rect: CGRect(
                x: -size.width / 2,
                y: -size.height / 2,
                width: size.width,
                height: size.height
            ),
            transform: nil
        )
    }

    private func diamondPath(size: CGSize) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -size.height / 2))
        path.addLine(to: CGPoint(x: -size.width / 2, y: 0))
        path.closeSubpath()
        return path
    }
}
