import SpriteKit

struct GameOverStats {
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

final class GameOverOverlay: SKNode {
    private enum Metrics {
        static let baseWidth: CGFloat = GameConfig.uiReferenceSize.width
        static let baseHeight: CGFloat = GameConfig.uiReferenceSize.height
        static let summaryPaddingX: CGFloat = 34
        static let summaryPaddingY: CGFloat = 30
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
    private let summaryPanel = SKShapeNode()
    private let summaryDivider = SKShapeNode()
    private let statsTitleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let itemsTitleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private var statKeyLabels: [SKLabelNode] = []
    private var statValueLabels: [SKLabelNode] = []
    private var itemSlotRoots: [SKNode] = []
    private var itemIconNodes: [SKSpriteNode] = []
    private var itemInitialLabels: [SKLabelNode] = []
    private var itemLevelLabels: [SKLabelNode] = []
    private let noItemsLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let stats: GameOverStats

    init(
        survivedTime: TimeInterval,
        screenSize: CGSize,
        stats: GameOverStats,
        onReplay: @escaping () -> Void
    ) {
        self.survivedTime = survivedTime
        self.screenSize = screenSize
        self.stats = stats
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

        replayButton.fillColor = .white
        replayButton.strokeColor = .black
        replayButton.lineJoin = .miter
        replayButton.zPosition = 1
        addChild(replayButton)

        replayLabel.text = "Press Any Button to Start Again"
        replayLabel.fontColor = .black
        replayLabel.horizontalAlignmentMode = .center
        replayLabel.verticalAlignmentMode = .center
        replayLabel.zPosition = 2
        replayButton.addChild(replayLabel)

        summaryPanel.fillColor = .white
        summaryPanel.strokeColor = .black
        summaryPanel.lineJoin = .miter
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

        survivedLabel.fontSize = scaled(34, scale)
        survivedLabel.position = CGPoint(x: 0, y: halfHeight - scaled(125, scale))

        timeLabel.fontSize = scaled(74, scale)
        timeLabel.position = CGPoint(x: 0, y: halfHeight - scaled(205, scale))

        layoutSummaryColumns(scale: scale, halfHeight: halfHeight)

        let buttonSize = CGSize(width: scaled(470, scale), height: scaled(68, scale))
        let buttonY = -halfHeight + scaled(190, scale)
        replayButton.position = CGPoint(x: 0, y: buttonY)
        replayButton.path = CGPath(
            rect: CGRect(
                x: -buttonSize.width / 2,
                y: -buttonSize.height / 2,
                width: buttonSize.width,
                height: buttonSize.height
            ),
            transform: nil
        )
        replayButton.lineWidth = scaled(2, scale)

        replayLabel.fontSize = scaled(23, scale)
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

    private func makeStatLabels() {
        for (key, value) in statRows() {
            let keyLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            keyLabel.text = key
            keyLabel.fontColor = .black
            keyLabel.horizontalAlignmentMode = .left
            keyLabel.verticalAlignmentMode = .center
            keyLabel.zPosition = 2
            addChild(keyLabel)
            statKeyLabels.append(keyLabel)

            let valueLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
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

            let initialsLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            initialsLabel.text = initials(for: item.name)
            initialsLabel.fontColor = .black
            initialsLabel.horizontalAlignmentMode = .center
            initialsLabel.verticalAlignmentMode = .center
            initialsLabel.zPosition = 2
            initialsLabel.isHidden = icon.texture != nil
            root.addChild(initialsLabel)
            itemInitialLabels.append(initialsLabel)

            let levelLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
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
        let rowCount = CGFloat(statKeyLabels.count)
        let panelWidth = min(screenSize.width * 0.76, scaled(930, scale))
        let panelHeight = max(
            scaled(screenSize.height < 700 ? 150 : 170, scale),
            contentInsetY * 2
                + titleFontSize / 2
                + lineGap * rowCount
                + rowFontSize / 2
        )
        let panelCenterY = halfHeight - scaled(390, scale)
        let panelRect = CGRect(
            x: -panelWidth / 2,
            y: panelCenterY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )
        summaryPanel.path = CGPath(
            rect: panelRect,
            transform: nil
        )
        summaryPanel.lineWidth = scaled(2, scale)

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
            itemInitialLabels[index].fontSize = iconSize * 0.36
            itemInitialLabels[index].position = .zero
            itemLevelLabels[index].fontSize = scaled(19, scale)
            itemLevelLabels[index].position = CGPoint(x: 0, y: -iconSize * 0.82)
        }

        noItemsLabel.fontSize = scaled(18, scale)
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
