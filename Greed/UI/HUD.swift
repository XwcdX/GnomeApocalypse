import SpriteKit
#if os(macOS)
import AppKit
#endif

final class HUD: SKNode {
    private enum Metrics {
        static let baseWidth: CGFloat = GameConfig.mapSize.width
        static let baseHeight: CGFloat = GameConfig.mapSize.height
        static let avatarSize = CGSize(width: 104, height: 82)
        static let essenceBarHeight: CGFloat = 26
        static let healthBarHeight: CGFloat = 22
        static let healthBarMaxWidth: CGFloat = 470
        static let healthFramePadding: CGFloat = 6
        static let levelRightInset: CGFloat = 0
        static let itemSlotSize = CGSize(width: 52, height: 52)
        static let itemSlotGapX: CGFloat = 50
        static let itemSlotGapY: CGFloat = 40
    }

    private weak var player: PlayerEntity?
    private var screenSize: CGSize
    private var weaponSlots: [ItemSlotVisual] = []
    private var powerUpSlots: [ItemSlotVisual] = []

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

    private final class ItemSlotVisual {
        let root = SKNode()
        let background = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.34), size: .zero)
        let frame = SKShapeNode()
        let icon = SKSpriteNode(color: .clear, size: .zero)
        let initials = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        let levelLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        var representedSkillID: String?
    }

    init(player: PlayerEntity, screenSize: CGSize) {
        self.player = player
        self.screenSize = screenSize
        super.init()

        name = "hud"
        zPosition = Layer.hud
        isUserInteractionEnabled = false

        setupNodes()
        layout()
        update(elapsedTime: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func updateViewport(_ screenSize: CGSize) {
        guard self.screenSize != screenSize else { return }
        self.screenSize = screenSize
        layout()
    }

    func update(elapsedTime: TimeInterval) {
        guard let player else { return }
        setHealthFraction(player.health.fraction)
        setEssenceFraction(player.level.xpFraction)
        levelLabel.text = "LV \(player.level.currentLevel)"
        timerLabel.text = formatElapsedTime(elapsedTime)
        updateItemSlots(for: player)
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

        weaponSlots = makeItemSlots(count: GameConfig.maxWeaponSlots)
        powerUpSlots = makeItemSlots(count: GameConfig.maxPowerUpSlots)
        for slot in weaponSlots + powerUpSlots {
            addChild(slot.root)
        }
    }

    private func layout() {
        let visibleSize = screenSize
        let scale = layoutScale(for: visibleSize)
        let left = -visibleSize.width / 2
        let right = visibleSize.width / 2
        let top = visibleSize.height / 2
        let avatarSize = scaled(Metrics.avatarSize)
        let essenceBarHeight = scaled(Metrics.essenceBarHeight, scale)

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

        levelLabel.fontSize = scaled(30, scale)
        levelLabel.position = CGPoint(
            x: right - scaled(Metrics.levelRightInset, scale),
            y: essenceTrack.position.y
        )

        let healthLeft = essenceLeft
        let healthY = top - scaled(60, scale)
        let healthIconSize = scaled(CGSize(width: 30, height: 30), scale)
        let healthBarWidth = min(
            scaled(Metrics.healthBarMaxWidth, scale),
            max(0, right - healthLeft - healthIconSize.width - scaled(28, scale))
        )
        let healthBarSize = CGSize(width: healthBarWidth, height: scaled(Metrics.healthBarHeight, scale))
        healthTrack.position = CGPoint(x: healthLeft + healthIconSize.width + scaled(18, scale), y: healthY)
        healthTrack.size = healthBarSize
        healthFill.position = healthTrack.position
        healthIcon.path = diamondPath(size: healthIconSize)
        healthIcon.lineWidth = scaled(2, scale)
        healthIcon.position = CGPoint(x: healthLeft + healthIconSize.width / 2 + scaled(4, scale), y: healthY)

        let frameSize = CGSize(
            width: healthBarSize.width + healthIconSize.width + scaled(30, scale),
            height: healthBarSize.height + scaled(Metrics.healthFramePadding * 2, scale)
        )
        healthFrame.lineWidth = scaled(2, scale)
        healthFrame.path = CGPath(
            rect: CGRect(
                x: healthLeft,
                y: healthY - frameSize.height / 2,
                width: frameSize.width,
                height: frameSize.height
            ),
            transform: nil
        )

        stageLabel.fontSize = scaled(18, scale)
        timerLabel.fontSize = scaled(32, scale)
        stageLabel.position = CGPoint(x: 0, y: top - scaled(128, scale))
        timerLabel.position = CGPoint(x: 0, y: top - scaled(156, scale))

        layoutItemSlots(
            slotSize: scaled(Metrics.itemSlotSize, scale),
            origin: CGPoint(
                x: healthLeft + scaled(8, scale),
                y: healthY - scaled(82, scale)
            ),
            scale: scale
        )

        setEssenceFraction(player?.level.xpFraction ?? 0)
        setHealthFraction(player?.health.fraction ?? 0)
        if let player {
            updateItemSlots(for: player)
        }
    }

    private func setHealthFraction(_ fraction: CGFloat) {
        healthFill.size = CGSize(
            width: healthTrack.size.width * clampedFraction(fraction),
            height: healthTrack.size.height
        )
    }

    private func setEssenceFraction(_ fraction: CGFloat) {
        essenceFill.size = CGSize(
            width: essenceTrack.size.width * clampedFraction(fraction),
            height: essenceTrack.size.height
        )
    }

    private func makeItemSlots(count: Int) -> [ItemSlotVisual] {
        (0..<count).map { index in
            let slot = ItemSlotVisual()
            slot.root.name = "itemSlot_\(index)"
            slot.root.zPosition = 5

            slot.background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            slot.background.name = "itemSlotBackground"
            slot.background.zPosition = 0
            slot.root.addChild(slot.background)

            slot.frame.fillColor = .clear
            slot.frame.strokeColor = SKColor.white.withAlphaComponent(0.88)
            slot.frame.lineWidth = 2
            slot.frame.name = "itemSlotFrame"
            slot.frame.zPosition = 2
            slot.root.addChild(slot.frame)

            slot.icon.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            slot.icon.name = "itemSlotIcon"
            slot.icon.zPosition = 1
            slot.root.addChild(slot.icon)

            slot.initials.fontColor = .white
            slot.initials.horizontalAlignmentMode = .center
            slot.initials.verticalAlignmentMode = .center
            slot.initials.name = "itemSlotInitials"
            slot.initials.zPosition = 3
            slot.root.addChild(slot.initials)

            slot.levelLabel.fontColor = .white
            slot.levelLabel.horizontalAlignmentMode = .right
            slot.levelLabel.verticalAlignmentMode = .bottom
            slot.levelLabel.name = "itemSlotLevel"
            slot.levelLabel.zPosition = 4
            slot.root.addChild(slot.levelLabel)

            return slot
        }
    }

    private func layoutItemSlots(slotSize: CGSize, origin: CGPoint, scale: CGFloat) {
        let stepX = slotSize.width + scaled(Metrics.itemSlotGapX, scale)
        let stepY = slotSize.height + scaled(Metrics.itemSlotGapY, scale)
        layoutItemSlotRow(weaponSlots, slotSize: slotSize, start: origin, stepX: stepX)
        layoutItemSlotRow(
            powerUpSlots,
            slotSize: slotSize,
            start: CGPoint(x: origin.x, y: origin.y - stepY),
            stepX: stepX
        )
    }

    private func layoutItemSlotRow(_ slots: [ItemSlotVisual], slotSize: CGSize, start: CGPoint, stepX: CGFloat) {
        for (index, slot) in slots.enumerated() {
            slot.root.position = CGPoint(x: start.x + CGFloat(index) * stepX, y: start.y)
            slot.background.size = slotSize
            slot.frame.path = CGPath(
                rect: CGRect(
                    x: -slotSize.width / 2,
                    y: -slotSize.height / 2,
                    width: slotSize.width,
                    height: slotSize.height
                ),
                transform: nil
            )
            slot.icon.size = CGSize(width: slotSize.width * 0.72, height: slotSize.height * 0.72)
            slot.initials.fontSize = slotSize.height * 0.30
            slot.levelLabel.fontSize = slotSize.height * 0.26
            slot.levelLabel.position = CGPoint(x: slotSize.width / 2 - 4, y: -slotSize.height / 2 + 3)
        }
    }

    private func updateItemSlots(for player: PlayerEntity) {
        updateSlotRow(slots: weaponSlots, skills: player.equippedWeapons, player: player)
        updateSlotRow(slots: powerUpSlots, skills: player.equippedPowerUps, player: player)
    }

    private func updateSlotRow(slots: [ItemSlotVisual], skills: [Skill], player: PlayerEntity) {
        for (index, slot) in slots.enumerated() {
            guard index < skills.count else {
                clear(slot)
                continue
            }

            let skill = skills[index]
            let level = player.skillState.level(of: skill.id, type: skill.type)
            fill(slot, with: skill, level: level)
        }
    }

    private func fill(_ slot: ItemSlotVisual, with skill: Skill, level: Int) {
        if slot.representedSkillID != skill.id {
            slot.representedSkillID = skill.id
            slot.icon.texture = texture(named: skill.iconName)
            slot.icon.color = placeholderColor(for: skill)
            slot.icon.colorBlendFactor = slot.icon.texture == nil ? 1 : 0
            slot.initials.text = initials(for: skill.name)
            slot.initials.isHidden = slot.icon.texture != nil
        }

        slot.root.alpha = 1
        slot.levelLabel.text = level > 1 ? "\(level)" : ""
    }

    private func clear(_ slot: ItemSlotVisual) {
        slot.representedSkillID = nil
        slot.icon.texture = nil
        slot.icon.color = .clear
        slot.icon.colorBlendFactor = 1
        slot.initials.text = ""
        slot.levelLabel.text = ""
        slot.root.alpha = 0.65
    }

    private func texture(named name: String) -> SKTexture? {
        #if os(macOS)
        guard let image = NSImage(named: name) else { return nil }
        return SKTexture(image: image)
        #else
        return SKTexture(imageNamed: name)
        #endif
    }

    private func placeholderColor(for skill: Skill) -> SKColor {
        switch skill.type {
        case .weapon:
            return SKColor(red: 0.18, green: 0.35, blue: 0.72, alpha: 0.92)
        case .powerUp:
            return SKColor(red: 0.52, green: 0.36, blue: 0.72, alpha: 0.92)
        }
    }

    private func initials(for name: String) -> String {
        name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
            .uppercased()
    }

    private func clampedFraction(_ fraction: CGFloat) -> CGFloat {
        min(max(fraction, 0), 1)
    }

    private func formatElapsedTime(_ elapsedTime: TimeInterval) -> String {
        let totalSeconds = max(0, Int(elapsedTime))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func layoutScale(for visibleSize: CGSize) -> CGFloat {
        let widthScale = visibleSize.width / Metrics.baseWidth
        let heightScale = visibleSize.height / Metrics.baseHeight
        return min(max(min(widthScale, heightScale), 0.55), 1.45)
    }

    private func scaled(_ size: CGSize) -> CGSize {
        let scale = layoutScale(for: screenSize)
        return scaled(size, scale)
    }

    private func scaled(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
        value * scale
    }

    private func scaled(_ size: CGSize, _ scale: CGFloat) -> CGSize {
        CGSize(width: scaled(size.width, scale), height: scaled(size.height, scale))
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
