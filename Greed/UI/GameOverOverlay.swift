import SpriteKit

/// Snapshot of run stats shown on the game-over overlay.
struct GameOverStats {
    /// One equipped item entry shown in the item summary.
    struct Item {
        let name: String
        let level: Int
        let iconName: String
    }

    let playerLevel: Int
    let maxHealth: Int
    let attackSpeedMultiplier: CGFloat
    let movementSpeed: CGFloat
    let items: [Item]
}

/// Camera-space game-over overlay with survival summary and replay interaction.
final class GameOverOverlay: SKNode {
    private enum Metrics {
        static let baseWidth: CGFloat = GameConfig.uiReferenceSize.width
        static let baseHeight: CGFloat = GameConfig.uiReferenceSize.height
        static let summaryPaddingX: CGFloat = 34
        static let summaryPaddingY: CGFloat = 30
        static let summaryAspectRatio: CGFloat = 930 / 200
    }

    private let survivedTime: TimeInterval
    private let onReplay: () -> Void
    private let usesControllerPrompt: Bool
    private var screenSize: CGSize
    private var replayRect: CGRect = .zero
    private var hasReplayed = false
    private var isReplayHovered = false

    private let dimmer = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.58), size: .zero)
    private let survivedLabel = OutlinedLabel(text: "You survived for")
    private let timeLabel = OutlinedLabel(text: "00:00")
    private let replayButton = SKSpriteNode(imageNamed: "game_over_restart_button")
    private let replayHoverOutline = SKShapeNode()
    private let replayLabel = SKLabelNode(fontNamed: GameConfig.fontName)
    private let summaryPanel = SKSpriteNode(imageNamed: "game_over_score_bg")
    private let summaryDivider = SKShapeNode()
    private let statsTitleLabel = SKLabelNode(fontNamed: GameConfig.fontName)
    private let itemsTitleLabel = SKLabelNode(fontNamed: GameConfig.fontName)
    private var statKeyLabels: [SKLabelNode] = []
    private var statValueLabels: [SKLabelNode] = []
    private var itemSlotRoots: [SKNode] = []
    private var itemIconNodes: [SKSpriteNode] = []
    private var itemInitialLabels: [SKLabelNode] = []
    private var itemLevelLabels: [SKLabelNode] = []
    private let noItemsLabel = SKLabelNode(fontNamed: GameConfig.fontName)
    private let stats: GameOverStats

    init(
        survivedTime: TimeInterval,
        screenSize: CGSize,
        stats: GameOverStats,
        usesControllerPrompt: Bool,
        onReplay: @escaping () -> Void
    ) {
        self.survivedTime = survivedTime
        self.screenSize = screenSize
        self.stats = stats
        self.usesControllerPrompt = usesControllerPrompt
        self.onReplay = onReplay
        super.init()

        name = "gameOverOverlay"
        zPosition = Layer.hud + 30
        setupNodes()
        layout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Relayouts the overlay for a new logical viewport size.
    func updateViewport(_ screenSize: CGSize) {
        guard self.screenSize != screenSize else { return }
        self.screenSize = screenSize
        layout()
    }

    /// Updates replay hover state for a camera-space point.
    @discardableResult
    func handleMouseMoved(at point: CGPoint) -> Bool {
        guard !hasReplayed else { return true }
        updateReplayHoverState(replayRect.contains(point))
        return true
    }

    /// Triggers replay when the camera-space point is inside the replay button.
    @discardableResult
    func handleMouseDown(at point: CGPoint) -> Bool {
        guard !hasReplayed else { return true }
        guard replayRect.contains(point) else { return true }
        replay()
        return true
    }

    /// Invokes the replay callback once.
    func replay() {
        guard !hasReplayed else { return }
        hasReplayed = true
        onReplay()
    }

    private func setupNodes() {
        dimmer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dimmer.zPosition = 0
        addChild(dimmer)

        survivedLabel.root.zPosition = 1
        addChild(survivedLabel.root)

        timeLabel.setText(formatTime(survivedTime))
        timeLabel.root.zPosition = 1
        addChild(timeLabel.root)

        replayButton.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        replayButton.texture?.filteringMode = .nearest
        replayButton.zPosition = 1
        addChild(replayButton)

        replayHoverOutline.fillColor = .clear
        replayHoverOutline.strokeColor = .white
        replayHoverOutline.lineJoin = .miter
        replayHoverOutline.zPosition = 1
        replayHoverOutline.isHidden = true
        replayButton.addChild(replayHoverOutline)

        replayLabel.text = usesControllerPrompt ? "Press Any Button to Start Again" : "Start Again"
        replayLabel.fontColor = .black
        replayLabel.horizontalAlignmentMode = .center
        replayLabel.verticalAlignmentMode = .center
        replayLabel.zPosition = 2
        replayButton.addChild(replayLabel)

        summaryPanel.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        summaryPanel.texture?.filteringMode = .nearest
        summaryPanel.zPosition = 1
        addChild(summaryPanel)

        summaryDivider.strokeColor = SKColor.black.withAlphaComponent(0.72)
        summaryDivider.zPosition = 2
        addChild(summaryDivider)

        statsTitleLabel.text = "Stats"
        statsTitleLabel.fontColor = .black
        statsTitleLabel.horizontalAlignmentMode = .left
        statsTitleLabel.verticalAlignmentMode = .center
        statsTitleLabel.zPosition = 2
        addChild(statsTitleLabel)

        itemsTitleLabel.text = "Items"
        itemsTitleLabel.fontColor = .black
        itemsTitleLabel.horizontalAlignmentMode = .left
        itemsTitleLabel.verticalAlignmentMode = .center
        itemsTitleLabel.zPosition = 2
        addChild(itemsTitleLabel)

        makeStatLabels()
        makeItemSlots()

        noItemsLabel.text = "No items"
        noItemsLabel.fontColor = .black
        noItemsLabel.horizontalAlignmentMode = .left
        noItemsLabel.verticalAlignmentMode = .center
        noItemsLabel.zPosition = 2
        noItemsLabel.isHidden = !stats.items.isEmpty
        addChild(noItemsLabel)
    }

    private func layout() {
        let scale = layoutScale(for: screenSize)
        let halfHeight = screenSize.height / 2

        dimmer.position = .zero
        dimmer.size = screenSize

        survivedLabel.setFontSize(scaled(34, scale) * 1.5)
        survivedLabel.root.position = CGPoint(x: 0, y: halfHeight - scaled(125, scale))

        timeLabel.setFontSize(scaled(74, scale) * 1.5)
        timeLabel.root.position = CGPoint(x: 0, y: halfHeight - scaled(205, scale))

        layoutSummaryColumns(scale: scale, halfHeight: halfHeight)

        let buttonSize = CGSize(width: scaled(470, scale), height: scaled(68, scale))
        let buttonY = -halfHeight + scaled(190, scale)
        replayButton.position = CGPoint(x: 0, y: buttonY)
        replayButton.size = buttonSize
        replayHoverOutline.path = CGPath(
            rect: CGRect(
                x: -buttonSize.width / 2,
                y: -buttonSize.height / 2,
                width: buttonSize.width,
                height: buttonSize.height
            ),
            transform: nil
        )
        replayHoverOutline.lineWidth = max(2, scaled(4, scale))

        replayLabel.fontSize = scaled(23, scale) * 1.5
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

    private func statRows() -> [(String, String)] {
        [
            ("Level reached:", "\(stats.playerLevel)"),
            ("Total health:", "\(stats.maxHealth)"),
            ("Attack speed:", formatMultiplier(stats.attackSpeedMultiplier)),
            ("Move speed:", "\(Int(stats.movementSpeed.rounded()))")
        ]
    }

    private func updateReplayHoverState(_ isHovered: Bool) {
        guard isReplayHovered != isHovered else { return }
        isReplayHovered = isHovered
        replayHoverOutline.isHidden = !isHovered
    }

    private func makeStatLabels() {
        for (key, value) in statRows() {
            let keyLabel = SKLabelNode(fontNamed: GameConfig.fontName)
            keyLabel.text = key
            keyLabel.fontColor = .black
            keyLabel.horizontalAlignmentMode = .left
            keyLabel.verticalAlignmentMode = .center
            keyLabel.zPosition = 2
            addChild(keyLabel)
            statKeyLabels.append(keyLabel)

            let valueLabel = SKLabelNode(fontNamed: GameConfig.fontName)
            valueLabel.text = value
            valueLabel.fontColor = .black
            valueLabel.horizontalAlignmentMode = .right
            valueLabel.verticalAlignmentMode = .center
            valueLabel.zPosition = 2
            addChild(valueLabel)
            statValueLabels.append(valueLabel)
        }
    }

    private func makeItemSlots() {
        for item in stats.items {
            let root = SKNode()
            root.zPosition = 2
            addChild(root)
            itemSlotRoots.append(root)

            let icon = SKSpriteNode(texture: texture(named: item.iconName))
            icon.color = SKColor(red: 0.22, green: 0.34, blue: 0.62, alpha: 1.0)
            icon.colorBlendFactor = icon.texture == nil ? 1 : 0
            icon.zPosition = 1
            root.addChild(icon)
            itemIconNodes.append(icon)

            let initialsLabel = SKLabelNode(fontNamed: GameConfig.fontName)
            initialsLabel.text = initials(for: item.name)
            initialsLabel.fontColor = .black
            initialsLabel.horizontalAlignmentMode = .center
            initialsLabel.verticalAlignmentMode = .center
            initialsLabel.zPosition = 2
            initialsLabel.isHidden = icon.texture != nil
            root.addChild(initialsLabel)
            itemInitialLabels.append(initialsLabel)

            let levelLabel = SKLabelNode(fontNamed: GameConfig.fontName)
            levelLabel.text = "\(item.level)"
            levelLabel.fontColor = .black
            levelLabel.horizontalAlignmentMode = .center
            levelLabel.verticalAlignmentMode = .center
            levelLabel.zPosition = 2
            root.addChild(levelLabel)
            itemLevelLabels.append(levelLabel)
        }
    }

    private func layoutSummaryColumns(scale: CGFloat, halfHeight: CGFloat) {
        let titleFontSize = scaled(24, scale)
        let rowFontSize = scaled(18, scale)
        let lineGap = scaled(screenSize.height < 700 ? 24 : 29, scale)
        let contentInsetX = scaled(Metrics.summaryPaddingX, scale)
        let contentInsetY = scaled(Metrics.summaryPaddingY, scale)
        let panelWidth = min(screenSize.width * 0.76, scaled(930, scale))
        let panelHeight = panelWidth / Metrics.summaryAspectRatio
        let panelCenterY = halfHeight - scaled(390, scale)
        let panelRect = CGRect(
            x: -panelWidth / 2,
            y: panelCenterY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )
        summaryPanel.position = CGPoint(x: panelRect.midX, y: panelRect.midY)
        summaryPanel.size = panelRect.size

        let dividerX = panelRect.midX
        let dividerPath = CGMutablePath()
        dividerPath.move(to: CGPoint(x: dividerX, y: panelRect.minY))
        dividerPath.addLine(to: CGPoint(x: dividerX, y: panelRect.maxY))
        summaryDivider.path = dividerPath
        summaryDivider.lineWidth = scaled(1.5, scale)

        let leftX = panelRect.minX + contentInsetX
        let leftValueX = dividerX - contentInsetX
        let rightX = dividerX + contentInsetX
        let topY = panelRect.maxY - contentInsetY - titleFontSize / 2

        statsTitleLabel.fontSize = titleFontSize
        statsTitleLabel.position = CGPoint(x: leftX, y: topY)
        itemsTitleLabel.fontSize = titleFontSize
        itemsTitleLabel.position = CGPoint(x: rightX, y: topY)

        for index in statKeyLabels.indices {
            statKeyLabels[index].fontSize = rowFontSize
            statKeyLabels[index].position = CGPoint(x: leftX, y: topY - lineGap * CGFloat(index + 1))
            statValueLabels[index].fontSize = rowFontSize
            statValueLabels[index].position = CGPoint(x: leftValueX, y: topY - lineGap * CGFloat(index + 1))
        }

        let iconSize = scaled(screenSize.height < 700 ? 32 : 38, scale)
        let slotGap = scaled(15, scale)
        for index in itemSlotRoots.indices {
            itemSlotRoots[index].position = CGPoint(
                x: rightX + CGFloat(index) * (iconSize + slotGap) + iconSize / 2,
                y: topY - scaled(48, scale)
            )
            itemIconNodes[index].size = CGSize(width: iconSize, height: iconSize)
            itemInitialLabels[index].fontSize = iconSize * 0.36 * 1.5
            itemInitialLabels[index].position = .zero
            itemLevelLabels[index].fontSize = scaled(19, scale) * 1.5
            itemLevelLabels[index].position = CGPoint(x: 0, y: -iconSize * 0.82)
        }

        noItemsLabel.fontSize = scaled(18, scale) * 1.5
        noItemsLabel.position = CGPoint(x: rightX, y: topY - lineGap)
    }

    private func formatMultiplier(_ value: CGFloat) -> String {
        String(format: "%.2fx", Double(value))
    }

    private func texture(named name: String) -> SKTexture? {
        #if os(macOS)
        guard let image = NSImage(named: name) else { return nil }
        let texture = SKTexture(image: image)
        #else
        let texture = SKTexture(imageNamed: name)
        #endif
        texture.filteringMode = .nearest
        return texture
    }

    private func initials(for name: String) -> String {
        name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
    }
}

/// Small label helper that renders shadow copies behind foreground text.
private final class OutlinedLabel {
    let root = SKNode()
    private let shadows: [SKLabelNode]
    private let foreground: SKLabelNode

    init(text: String, fontColor: SKColor = .white, outlineColor: SKColor = .black) {
        let offsets = [
            CGPoint(x: -2, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 0, y: -2),
            CGPoint(x: 0, y: 2)
        ]
        shadows = offsets.map { offset in
            let label = SKLabelNode(fontNamed: GameConfig.fontName)
            label.text = text
            label.fontColor = outlineColor.withAlphaComponent(0.78)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = offset
            label.zPosition = 0
            return label
        }
        foreground = SKLabelNode(fontNamed: GameConfig.fontName)
        foreground.text = text
        foreground.fontColor = fontColor
        foreground.horizontalAlignmentMode = .center
        foreground.verticalAlignmentMode = .center
        foreground.zPosition = 1

        for shadow in shadows {
            root.addChild(shadow)
        }
        root.addChild(foreground)
    }

    func setFontSize(_ fontSize: CGFloat) {
        foreground.fontSize = fontSize
        for shadow in shadows {
            shadow.fontSize = fontSize
        }
    }

    func setText(_ text: String) {
        foreground.text = text
        for shadow in shadows {
            shadow.text = text
        }
    }

    func setZPosition(_ zPosition: CGFloat) {
        root.zPosition = zPosition
    }
}
