import SpriteKit

final class SkillCardOverlay: SKNode {
    private enum Metrics {
        static let baseWidth: CGFloat = 1440
        static let baseHeight: CGFloat = 810
    }

    private let skills: [Skill]
    private let onSelect: (Skill) -> Void
    private var screenSize: CGSize
    private var cardRects: [CGRect] = []
    private var cardNodes: [SKShapeNode] = []
    private var selectedIndex = 0
    private var hasSelected = false

    private let dimmer = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.62), size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")

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
        select(index: index)
        return true
    }

    func selectHighlightedCard() {
        select(index: selectedIndex)
    }

    private func setupNodes() {
        dimmer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dimmer.zPosition = 0
        addChild(dimmer)

        titleLabel.text = "Choose 1 of these Ancient Cards"
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 1
        addChild(titleLabel)

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

        let icon = SKShapeNode(rectOf: .zero)
        icon.name = "skillCardIcon"
        icon.fillColor = SKColor(red: 0.50, green: 0.60, blue: 0.98, alpha: 1.0)
        icon.strokeColor = .clear
        icon.zPosition = 1
        card.addChild(icon)

        let nameLabel = SKLabelNode(fontNamed: "HelveticaNeue")
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
        let scale = layoutScale(for: screenSize)
        let halfHeight = screenSize.height / 2

        dimmer.position = .zero
        dimmer.size = screenSize

        titleLabel.fontSize = scaled(34, scale)
        titleLabel.position = CGPoint(x: 0, y: halfHeight - scaled(120, scale))

        let cardSize = CGSize(width: scaled(250, scale), height: scaled(395, scale))
        let gap = scaled(64, scale)
        let totalWidth = CGFloat(cardNodes.count) * cardSize.width + CGFloat(max(cardNodes.count - 1, 0)) * gap
        let startX = -totalWidth / 2 + cardSize.width / 2
        let cardY = -scaled(45, scale)

        cardRects.removeAll(keepingCapacity: true)

        for (index, card) in cardNodes.enumerated() {
            let x = startX + CGFloat(index) * (cardSize.width + gap)
            card.position = CGPoint(x: x, y: cardY)
            card.path = CGPath(
                rect: CGRect(x: -cardSize.width / 2, y: -cardSize.height / 2, width: cardSize.width, height: cardSize.height),
                transform: nil
            )
            card.strokeColor = index == selectedIndex ? SKColor.white : .clear
            card.lineWidth = scaled(4, scale)

            if let icon = card.childNode(withName: "skillCardIcon") as? SKShapeNode {
                let iconSize = CGSize(width: scaled(170, scale), height: scaled(170, scale))
                icon.path = CGPath(
                    rect: CGRect(x: -iconSize.width / 2, y: -iconSize.height / 2, width: iconSize.width, height: iconSize.height),
                    transform: nil
                )
                icon.position = CGPoint(x: 0, y: scaled(70, scale))
            }

            if let nameLabel = card.childNode(withName: "skillCardName") as? SKLabelNode {
                nameLabel.fontSize = scaled(20, scale)
                nameLabel.position = CGPoint(x: 0, y: -scaled(90, scale))
            }

            cardRects.append(
                CGRect(
                    x: x - cardSize.width / 2,
                    y: cardY - cardSize.height / 2,
                    width: cardSize.width,
                    height: cardSize.height
                )
            )
        }

        position = .zero
    }

    private func select(index: Int) {
        guard !hasSelected, skills.indices.contains(index) else { return }
        hasSelected = true
        onSelect(skills[index])
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
