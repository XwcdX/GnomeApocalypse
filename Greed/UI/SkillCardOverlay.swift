import SpriteKit
#if os(macOS)
import AppKit
#endif

final class SkillCardOverlay: SKNode {
    private enum Metrics {
        static let cardSize = CGSize(width: 250, height: 395)
        static let maxCardHeight: CGFloat = 520
        static let minCardHeight: CGFloat = 150
        static let horizontalSafeAreaFactor: CGFloat = 0.84
        static let verticalSafeAreaFactor: CGFloat = 0.58
    }

    private let skills: [Skill]
    private let onSelect: (Skill) -> Void
    private var screenSize: CGSize
    private var cardRects: [CGRect] = []
    private var cardNodes: [SKShapeNode] = []
    private var selectedIndex = 0
    private var hasSelected = false

    private let dimmer = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.44), size: .zero)
    private let titleLabel = OutlinedLabel(text: "Choose 1 of these Ancient Cards")
    private let confirmPromptRoot = SKNode()
    private let confirmButtonCircle = SKShapeNode()
    private let confirmButtonLabel = SKLabelNode(fontNamed: GameConfig.fontName)
    private let confirmTextLabel = SKLabelNode(fontNamed: GameConfig.fontName)

    private final class OutlinedLabel {
        let root = SKNode()
        private let shadows: [SKLabelNode]
        private let foreground: SKLabelNode

        init(text: String) {
            let offsets = [
                CGPoint(x: -2, y: 0),
                CGPoint(x: 2, y: 0),
                CGPoint(x: 0, y: -2),
                CGPoint(x: 0, y: 2)
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

            for shadow in shadows {
                root.addChild(shadow)
            }
            root.addChild(foreground)
        }

        func setFontSize(_ fontSize: CGFloat) {
            foreground.fontSize = fontSize * 1.5
            for shadow in shadows {
                shadow.fontSize = fontSize * 1.5
            }
        }
    }

    init(skills: [Skill], screenSize: CGSize, onSelect: @escaping (Skill) -> Void) {
        self.skills = skills
        self.screenSize = screenSize
        self.onSelect = onSelect
        super.init()

        name = "skillCardOverlay"
        zPosition = Layer.hud + 20
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
        guard !hasSelected else { return true }
        guard let index = cardRects.firstIndex(where: { $0.contains(point) }) else { return true }
        setSelectedIndex(index)
        select(index: index)
        return true
    }

    @discardableResult
    func handleMouseMoved(at point: CGPoint) -> Bool {
        guard !hasSelected,
              let index = cardRects.firstIndex(where: { $0.contains(point) })
        else { return true }

        setSelectedIndex(index)
        return true
    }

    func selectHighlightedCard() {
        select(index: selectedIndex)
    }

    func moveSelection(_ direction: InputSystem.MenuDirection) {
        guard !hasSelected, !skills.isEmpty else { return }
        switch direction {
        case .left, .up:
            setSelectedIndex((selectedIndex - 1 + skills.count) % skills.count)
        case .right, .down:
            setSelectedIndex((selectedIndex + 1) % skills.count)
        }
    }

    private func setupNodes() {
        dimmer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dimmer.zPosition = 0
        addChild(dimmer)

        titleLabel.root.zPosition = 1
        addChild(titleLabel.root)

        confirmPromptRoot.zPosition = 1
        addChild(confirmPromptRoot)

        confirmButtonCircle.fillColor = .black
        confirmButtonCircle.strokeColor = .white
        confirmButtonCircle.zPosition = 0
        confirmPromptRoot.addChild(confirmButtonCircle)

        confirmButtonLabel.text = "A"
        confirmButtonLabel.fontColor = .white
        confirmButtonLabel.horizontalAlignmentMode = .center
        confirmButtonLabel.verticalAlignmentMode = .center
        confirmButtonLabel.zPosition = 1
        confirmPromptRoot.addChild(confirmButtonLabel)

        confirmTextLabel.text = "to confirm"
        confirmTextLabel.fontColor = SKColor.white.withAlphaComponent(0.92)
        confirmTextLabel.horizontalAlignmentMode = .left
        confirmTextLabel.verticalAlignmentMode = .center
        confirmTextLabel.zPosition = 1
        confirmPromptRoot.addChild(confirmTextLabel)

        for (index, skill) in skills.enumerated() {
            let card = makeCard(for: skill, index: index)
            cardNodes.append(card)
            addChild(card)
        }
    }

    private func makeCard(for skill: Skill, index: Int) -> SKShapeNode {
        let card = SKShapeNode()
        card.name = "skillCard_\(index)"
        card.fillColor = SKColor(red: 0.82, green: 0.86, blue: 1.0, alpha: 1.0)
        card.strokeColor = .clear
        card.zPosition = 1

        if let frameTexture = texture(named: cardFrameTextureName(for: skill.type)) {
            let frame = SKSpriteNode(texture: frameTexture)
            frame.name = "skillCardFrame"
            frame.zPosition = 0
            card.fillColor = .clear
            card.addChild(frame)
        }

        if let texture = iconTexture(named: skill.iconName) {
            let art = SKSpriteNode(texture: texture)
            art.name = "skillCardArt"
            art.zPosition = 1
            card.addChild(art)
        }

        let icon = SKShapeNode(rectOf: .zero)
        icon.name = "skillCardIcon"
        icon.fillColor = SKColor(red: 0.50, green: 0.60, blue: 0.98, alpha: 1.0)
        icon.strokeColor = .clear
        icon.zPosition = 1
        icon.isHidden = card.childNode(withName: "skillCardArt") != nil
        card.addChild(icon)

        let nameLabel = SKLabelNode(fontNamed: GameConfig.fontName)
        nameLabel.text = skill.name
        nameLabel.fontColor = .black
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.verticalAlignmentMode = .center
        nameLabel.name = "skillCardName"
        nameLabel.zPosition = 1
        card.addChild(nameLabel)

        return card
    }

    private func layout() {
        let layout = modalLayout(for: screenSize)
        let scale = layout.scale
        let halfHeight = screenSize.height / 2

        dimmer.position = .zero
        dimmer.size = screenSize

        titleLabel.root.isHidden = screenSize.height < 540
        titleLabel.setFontSize(min(34, max(20, screenSize.height * 0.032)))
        titleLabel.root.position = CGPoint(x: 0, y: halfHeight - max(48, screenSize.height * 0.10))

        layoutConfirmPrompt()

        cardRects.removeAll(keepingCapacity: true)

        for (index, card) in cardNodes.enumerated() {
            let x = layout.startX + CGFloat(index) * (layout.cardSize.width + layout.gap)
            card.position = CGPoint(x: x, y: layout.cardY)
            card.path = CGPath(
                rect: CGRect(
                    x: -layout.cardSize.width / 2,
                    y: -layout.cardSize.height / 2,
                    width: layout.cardSize.width,
                    height: layout.cardSize.height
                ),
                transform: nil
            )
            card.lineWidth = max(2, scaled(4, scale))

            if let frame = card.childNode(withName: "skillCardFrame") as? SKSpriteNode {
                frame.size = layout.cardSize
                frame.position = .zero
            }

            if let art = card.childNode(withName: "skillCardArt") as? SKSpriteNode {
                art.size = fittedArtSize(
                    for: art.texture,
                    maxSize: CGSize(
                        width: layout.cardSize.width * 0.68,
                        height: layout.cardSize.height * 0.38
                    )
                )
                art.position = CGPoint(x: 0, y: layout.cardSize.height * 0.20)
            }

            if let icon = card.childNode(withName: "skillCardIcon") as? SKShapeNode {
                let iconSize = CGSize(
                    width: layout.cardSize.width * 0.64,
                    height: layout.cardSize.height * 0.34
                )
                icon.path = CGPath(
                    rect: CGRect(x: -iconSize.width / 2, y: -iconSize.height / 2, width: iconSize.width, height: iconSize.height),
                    transform: nil
                )
                icon.position = CGPoint(x: 0, y: layout.cardSize.height * 0.20)
            }

            if let nameLabel = card.childNode(withName: "skillCardName") as? SKLabelNode {
                nameLabel.fontSize = min(layout.cardSize.height * 0.052, layout.cardSize.width * 0.105) * 1.5
                nameLabel.position = CGPoint(x: 0, y: -layout.cardSize.height * 0.27)
            }

            cardRects.append(
                CGRect(
                    x: x - layout.cardSize.width / 2,
                    y: layout.cardY - layout.cardSize.height / 2,
                    width: layout.cardSize.width,
                    height: layout.cardSize.height
                )
            )
        }

        position = .zero
        updateCardSelection()
    }

    private func layoutConfirmPrompt() {
        let hasController = InputSystem.shared.hasConnectedController
        confirmPromptRoot.isHidden = !hasController || screenSize.height < 390
        guard !confirmPromptRoot.isHidden else { return }

        let buttonDiameter = min(34, max(24, screenSize.height * 0.033))
        let fontSize = min(24, max(16, screenSize.height * 0.022))
        let gap = buttonDiameter * 0.38

        confirmPromptRoot.position = CGPoint(
            x: -buttonDiameter * 1.8,
            y: -screenSize.height / 2 + max(34, screenSize.height * 0.065)
        )

        confirmButtonCircle.path = CGPath(
            ellipseIn: CGRect(
                x: -buttonDiameter / 2,
                y: -buttonDiameter / 2,
                width: buttonDiameter,
                height: buttonDiameter
            ),
            transform: nil
        )
        confirmButtonCircle.lineWidth = max(1.5, buttonDiameter * 0.07)

        confirmButtonLabel.fontSize = buttonDiameter * 0.58 * 1.5
        confirmButtonLabel.position = .zero

        confirmTextLabel.fontSize = fontSize * 1.5
        confirmTextLabel.position = CGPoint(x: buttonDiameter / 2 + gap, y: 0)
    }

    private func select(index: Int) {
        guard !hasSelected, skills.indices.contains(index) else { return }
        hasSelected = true
        onSelect(skills[index])
    }

    private func setSelectedIndex(_ index: Int) {
        guard skills.indices.contains(index), selectedIndex != index else { return }
        selectedIndex = index
        updateCardSelection()
    }

    private func updateCardSelection() {
        for (index, card) in cardNodes.enumerated() {
            card.strokeColor = index == selectedIndex ? SKColor.white : .clear
        }
    }

    private struct ModalLayout {
        let scale: CGFloat
        let cardSize: CGSize
        let gap: CGFloat
        let startX: CGFloat
        let cardY: CGFloat
    }

    private func modalLayout(for size: CGSize) -> ModalLayout {
        let count = max(cardNodes.count, 1)
        let aspect = Metrics.cardSize.width / Metrics.cardSize.height
        let horizontalSpace = max(0, size.width * Metrics.horizontalSafeAreaFactor)
        let baseGap = min(max(size.width * 0.035, 18), 64)
        let widthPerCard = max(1, (horizontalSpace - CGFloat(count - 1) * baseGap) / CGFloat(count))
        let heightFromWidth = widthPerCard / aspect
        let heightFromViewport = max(1, size.height * Metrics.verticalSafeAreaFactor)
        let cardHeight = min(max(Metrics.minCardHeight, min(heightFromWidth, heightFromViewport)), Metrics.maxCardHeight)
        let cardSize = CGSize(width: cardHeight * aspect, height: cardHeight)
        let totalWidth = CGFloat(count) * cardSize.width + CGFloat(count - 1) * baseGap
        let startX = -totalWidth / 2 + cardSize.width / 2
        let topLimit = size.height / 2 - max(90, size.height * 0.13)
        let bottomLimit = -size.height / 2 + max(44, size.height * 0.06)
        let cardY = (topLimit + bottomLimit) / 2

        return ModalLayout(
            scale: cardHeight / Metrics.cardSize.height,
            cardSize: cardSize,
            gap: baseGap,
            startX: startX,
            cardY: cardY
        )
    }

    private func scaled(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
        value * scale
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

    private func iconTexture(named name: String) -> SKTexture? {
        guard let baseTexture = texture(named: name) else { return nil }

        guard !name.hasPrefix("icon_") else {
            return baseTexture
        }

        let rect = CGRect(x: 0.14, y: 0.34, width: 0.72, height: 0.50)
        let texture = SKTexture(rect: rect, in: baseTexture)
        texture.filteringMode = .nearest
        return texture
    }

    private func cardFrameTextureName(for type: SkillType) -> String {
        switch type {
        case .weapon:
            return "card_frame_weapon"
        case .powerUp:
            return "card_frame_power_up"
        }
    }

    private func fittedArtSize(for texture: SKTexture?, maxSize: CGSize) -> CGSize {
        guard let texture else { return maxSize }
        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return maxSize }
        let scale = min(maxSize.width / textureSize.width, maxSize.height / textureSize.height)
        return CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
    }
}
