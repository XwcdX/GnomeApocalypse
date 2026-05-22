import SpriteKit

private let countdownStepDuration: TimeInterval = 1.0
private let countdownFadeInPortion: CGFloat = 0.24
private let countdownFadeOutPortion: CGFloat = 0.34

final class StartCountdownOverlay: SKNode {
    private let values = ["3", "2", "1"]
    private let label = OutlinedLabel(text: "3")
    private var screenSize: CGSize
    private var elapsedTime: TimeInterval = 0
    private var currentIndex = 0

    init(screenSize: CGSize) {
        self.screenSize = screenSize
        super.init()

        name = "startCountdownOverlay"
        zPosition = Layer.hud + 25
        isUserInteractionEnabled = false
        addChild(label.root)
        layout()
        applyStep(index: 0, progress: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func updateViewport(_ screenSize: CGSize) {
        guard self.screenSize != screenSize else { return }
        self.screenSize = screenSize
        layout()
    }

    @discardableResult
    func update(deltaTime: TimeInterval) -> Bool {
        elapsedTime += deltaTime

        let totalDuration = countdownStepDuration * TimeInterval(values.count)
        if elapsedTime >= totalDuration {
            removeFromParent()
            return true
        }

        let stepIndex = min(Int(elapsedTime / countdownStepDuration), values.count - 1)
        let stepElapsed = elapsedTime - TimeInterval(stepIndex) * countdownStepDuration
        let progress = CGFloat(stepElapsed / countdownStepDuration)
        applyStep(index: stepIndex, progress: progress)
        return false
    }

    private func applyStep(index: Int, progress: CGFloat) {
        if index != currentIndex {
            currentIndex = index
            label.setText(values[index])
        }

        let fadeIn = min(max(progress / countdownFadeInPortion, 0), 1)
        let fadeOut = min(max((1 - progress) / countdownFadeOutPortion, 0), 1)
        let visibility = min(fadeIn, fadeOut)

        label.root.alpha = visibility
        label.root.setScale(0.78 + easeOut(progress) * 0.28)
    }

    private func layout() {
        let scale = layoutScale(for: screenSize)
        let fontSize = min(220, max(120, min(screenSize.width * 0.18, screenSize.height * 0.32)))
        label.setFontSize(fontSize)
        label.root.position = CGPoint(x: 0, y: 24 * scale)
    }

    private func layoutScale(for visibleSize: CGSize) -> CGFloat {
        let widthScale = visibleSize.width / GameConfig.uiReferenceSize.width
        let heightScale = visibleSize.height / GameConfig.uiReferenceSize.height
        return min(max(min(widthScale, heightScale), 0.55), 1.45)
    }

    private func easeOut(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }
}

private final class OutlinedLabel {
    let root = SKNode()
    private let shadows: [SKLabelNode]
    private let foreground: SKLabelNode

    init(text: String) {
        let offsets = [
            CGPoint(x: -4, y: 0),
            CGPoint(x: 4, y: 0),
            CGPoint(x: 0, y: -4),
            CGPoint(x: 0, y: 4)
        ]

        shadows = offsets.map { offset in
            let label = SKLabelNode(fontNamed: GameConfig.fontName)
            label.text = text
            label.fontColor = SKColor.black.withAlphaComponent(0.78)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = offset
            label.zPosition = 0
            return label
        }

        foreground = SKLabelNode(fontNamed: GameConfig.fontName)
        foreground.text = text
        foreground.fontColor = .white
        foreground.horizontalAlignmentMode = .center
        foreground.verticalAlignmentMode = .center
        foreground.zPosition = 1

        shadows.forEach { root.addChild($0) }
        root.addChild(foreground)
    }

    func setFontSize(_ fontSize: CGFloat) {
        foreground.fontSize = fontSize
        shadows.forEach { $0.fontSize = fontSize }
    }

    func setText(_ text: String) {
        foreground.text = text
        shadows.forEach { $0.text = text }
    }
}
