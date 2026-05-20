import SpriteKit
#if os(macOS)
import AppKit
#endif

// MARK: - Visual constants (set-and-forget, never balance-tuned)
private let guideVerticalOffsetFactor: CGFloat = -0.02
private let guideHorizontalInsetFactor: CGFloat = 0.22
private let guideMaxScale: CGFloat = 0.58
private let guideIconOffsetY: CGFloat = 112
private let guideTitleOffsetY: CGFloat = -10
private let guideSubtitleOffsetY: CGFloat = -70
private let guideTitleFontSize: CGFloat = 64
private let guideSubtitleFontSize: CGFloat = 45
private let guideKeyboardMoveIconSize = CGSize(width: 330, height: 176)
private let guideKeyboardAimIconSize = CGSize(width: 342, height: 269)
private let guideControllerMoveIconSize = CGSize(width: 224, height: 224)
private let guideControllerAimIconSize = CGSize(width: 292, height: 292)
private let healthValueFontSize: CGFloat = 16

final class HUD: SKNode {
    private enum ControlGuideInputMode {
        case keyboardMouse
        case controller
    }

    private enum Metrics {
        static let baseWidth: CGFloat = GameConfig.uiReferenceSize.width
        static let baseHeight: CGFloat = GameConfig.uiReferenceSize.height
        static let hudEdgePadding: CGFloat = 16
        static let avatarSize = CGSize(width: 102.4, height: 102.4)
        static let essenceBarHeight: CGFloat = 52
        static let healthBarHeight: CGFloat = 48
        static let healthBarMaxWidth: CGFloat = 620
        static let healthFramePadding: CGFloat = 6
        static let barLeftGap: CGFloat = 12
        static let barRowGap: CGFloat = 4
        static let levelRightInset: CGFloat = 34
        static let xpFillInsetLeft: CGFloat = 44
        static let xpFillInsetRight: CGFloat = 17
        static let xpFillInsetY: CGFloat = 18.5
        static let healthFillInsetLeft: CGFloat = 0
        static let healthFillInsetRight: CGFloat = 0
        static let healthFillInsetY: CGFloat = 0
        static let healthValueRightInset: CGFloat = 34
        static let itemSlotSize = CGSize(width: 52, height: 52)
        static let itemSlotGapX: CGFloat = 18
        static let itemSlotGapY: CGFloat = 18
    }

    private weak var player: PlayerEntity?
    private var screenSize: CGSize
    private var currentLayoutScale: CGFloat = 1
    private var essenceTextureScale: CGFloat = 1
    private var healthTextureScale: CGFloat = 1
    private var weaponSlots: [ItemSlotVisual] = []
    private var powerUpSlots: [ItemSlotVisual] = []
    private var isControlGuideDismissed = false
    private var controlGuideInputMode: ControlGuideInputMode = InputSystem.shared.hasConnectedController ? .controller : .keyboardMouse
    private var forcedEssenceFraction: CGFloat?
    private var forcedEssenceFractionUntil: TimeInterval = 0

    private let avatarNode = SKSpriteNode(texture: nil)
    private let essenceTrack = SKSpriteNode(color: .white, size: .zero)
    private let essenceFillCrop = SKCropNode()
    private let essenceFillMask = SKSpriteNode(color: .white, size: .zero)
    private let essenceFill = SKSpriteNode(color: SKColor(red: 0.25, green: 0.72, blue: 1.0, alpha: 1), size: .zero)
    private let healthFrame = SKShapeNode()
    private let healthTrack = SKSpriteNode(color: SKColor(red: 0.08, green: 0.04, blue: 0.06, alpha: 1), size: .zero)
    private let healthFillCrop = SKCropNode()
    private let healthFillMask = SKSpriteNode(color: .white, size: .zero)
    private let healthFill = SKSpriteNode(color: SKColor(red: 0.94, green: 0.02, blue: 0.10, alpha: 1), size: .zero)
    private let healthIcon = SKShapeNode()
    private let healthValueLabel = OutlinedLabel(text: "100/100")
    private let levelLabel = OutlinedLabel(text: "LV 1")
    private let stageLabel = OutlinedLabel(text: "Stage")
    private let timerLabel = OutlinedLabel(text: "00:00")
    private let guideRoot = SKNode()
    private let moveGuide = GuidePromptVisual(title: "W, A, S, D", subtitle: "to move")
    private let aimGuide = GuidePromptVisual(title: "Move Mouse", subtitle: "to aim")

    private final class ItemSlotVisual {
        let root = SKNode()
        let background = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.34), size: .zero)
        let frame = SKShapeNode()
        let icon = SKSpriteNode(color: .clear, size: .zero)
        let initials = SKLabelNode(fontNamed: GameConfig.fontName)
        let levelLabel = SKLabelNode(fontNamed: GameConfig.fontName)
        var representedSkillID: String?
    }

    private final class GuidePromptVisual {
        let root = SKNode()
        let iconRoot = SKNode()
        let title: OutlinedLabel
        let subtitle: OutlinedLabel

        init(title: String, subtitle: String) {
            self.title = OutlinedLabel(text: title)
            self.subtitle = OutlinedLabel(text: subtitle)
            root.addChild(iconRoot)
            root.addChild(self.title.root)
            root.addChild(self.subtitle.root)
        }
    }

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

        func setText(_ text: String) {
            foreground.text = text
            for shadow in shadows {
                shadow.text = text
            }
        }

        func setHorizontalAlignment(_ alignment: SKLabelHorizontalAlignmentMode) {
            foreground.horizontalAlignmentMode = alignment
            for shadow in shadows {
                shadow.horizontalAlignmentMode = alignment
            }
        }
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
        setControlGuideUsesController(InputSystem.shared.hasConnectedController)
        setHealthFraction(player.health.fraction)
        if let forcedEssenceFraction, CACurrentMediaTime() < forcedEssenceFractionUntil {
            setEssenceFraction(forcedEssenceFraction)
        } else {
            forcedEssenceFraction = nil
            setEssenceFraction(player.level.xpFraction)
        }
        healthValueLabel.setText("\(player.health.current)/\(player.health.maximum)")
        levelLabel.setText("LV \(player.level.currentLevel)")
        timerLabel.setText(formatElapsedTime(elapsedTime))
        updateItemSlots(for: player)
        updateGuideVisibility()
    }

    func showFullEssenceBriefly(duration: TimeInterval) {
        forcedEssenceFraction = 1
        forcedEssenceFractionUntil = CACurrentMediaTime() + duration
        setEssenceFraction(1)
    }

    func dismissControlGuide() {
        guard !isControlGuideDismissed else { return }
        isControlGuideDismissed = true
        updateGuideVisibility()
    }

    func setControlGuideUsesController(_ usesController: Bool) {
        let mode: ControlGuideInputMode = usesController ? .controller : .keyboardMouse
        guard mode != controlGuideInputMode else { return }
        controlGuideInputMode = mode
        configureGuideForCurrentInputMode()
        layoutGuide()
    }

    private func setupNodes() {
        avatarNode.texture = hudTexture("Icon_luminous_wisp")
        avatarNode.colorBlendFactor = 0
        avatarNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        avatarNode.name = "hudAvatar"
        addChild(avatarNode)

        essenceTrack.anchorPoint = CGPoint(x: 0, y: 0.5)
        essenceTrack.texture = hudTexture("xp_bar_frame")
        essenceTrack.colorBlendFactor = 0
        essenceTrack.name = "essenceBarTrack"
        essenceTrack.zPosition = 0
        addChild(essenceTrack)

        essenceFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        essenceFill.texture = hudTexture("xp_bar_fill")
        essenceFill.colorBlendFactor = 0
        essenceFill.name = "essenceBarFill"
        essenceFill.zPosition = 0
        essenceFillCrop.name = "essenceBarFillCrop"
        essenceFillCrop.zPosition = 1
        essenceFillMask.anchorPoint = CGPoint(x: 0, y: 0.5)
        essenceFillMask.position = .zero
        essenceFillCrop.maskNode = essenceFillMask
        essenceFillCrop.addChild(essenceFill)
        addChild(essenceFillCrop)

        healthFrame.strokeColor = SKColor(red: 0.38, green: 0.38, blue: 1.0, alpha: 1)
        healthFrame.lineWidth = 2
        healthFrame.fillColor = .clear
        healthFrame.name = "healthBarFrame"
        healthFrame.zPosition = 3
        healthFrame.isHidden = true
        addChild(healthFrame)

        healthTrack.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthTrack.texture = hudTexture("health_bar_frame")
        healthTrack.colorBlendFactor = 0
        healthTrack.name = "healthBarTrack"
        healthTrack.zPosition = 3
        addChild(healthTrack)

        healthFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthFill.texture = hudTexture("health_bar_fill")
        healthFill.colorBlendFactor = 0
        healthFill.name = "healthBarFill"
        healthFill.zPosition = 0
        healthFillCrop.name = "healthBarFillCrop"
        healthFillCrop.zPosition = 2
        healthFillMask.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthFillMask.position = .zero
        healthFillCrop.maskNode = healthFillMask
        healthFillCrop.addChild(healthFill)
        addChild(healthFillCrop)

        healthIcon.fillColor = SKColor(red: 1.0, green: 0.04, blue: 0.10, alpha: 1)
        healthIcon.strokeColor = SKColor(red: 0.32, green: 0.0, blue: 0.02, alpha: 1)
        healthIcon.name = "healthIcon"
        healthIcon.zPosition = 4
        healthIcon.isHidden = true
        addChild(healthIcon)

        healthValueLabel.root.name = "healthValueLabel"
        healthValueLabel.root.zPosition = 5
        healthValueLabel.setHorizontalAlignment(.right)
        addChild(healthValueLabel.root)

        levelLabel.root.name = "levelLabel"
        levelLabel.root.zPosition = 5
        levelLabel.setHorizontalAlignment(.right)
        addChild(levelLabel.root)

        stageLabel.setText("Stage")
        stageLabel.setHorizontalAlignment(.center)
        stageLabel.root.name = "stageLabel"
        stageLabel.root.zPosition = 2
        addChild(stageLabel.root)

        timerLabel.setText("00:00")
        timerLabel.setHorizontalAlignment(.center)
        timerLabel.root.name = "timerLabel"
        timerLabel.root.zPosition = 2
        addChild(timerLabel.root)

        guideRoot.name = "controlGuide"
        guideRoot.zPosition = 20
        guideRoot.addChild(moveGuide.root)
        guideRoot.addChild(aimGuide.root)
        addChild(guideRoot)
        configureGuideForCurrentInputMode()

        weaponSlots = makeItemSlots(count: GameConfig.maxWeaponSlots)
        powerUpSlots = makeItemSlots(count: GameConfig.maxPowerUpSlots)
        for slot in weaponSlots + powerUpSlots {
            addChild(slot.root)
        }
    }

    private func layout() {
        let visibleSize = screenSize
        let scale = layoutScale(for: visibleSize)
        currentLayoutScale = scale
        let left = -visibleSize.width / 2
        let right = visibleSize.width / 2
        let top = visibleSize.height / 2
        let edgePadding = scaled(Metrics.hudEdgePadding, scale)
        let hudLeft = left + edgePadding
        let hudRight = right - edgePadding
        let hudTop = top - edgePadding
        let avatarSize = scaled(Metrics.avatarSize)
        let essenceBarHeight = scaled(Metrics.essenceBarHeight, scale)

        avatarNode.size = fittedSize(for: avatarNode.texture, inside: avatarSize)
        avatarNode.position = CGPoint(
            x: hudLeft + avatarSize.width / 2,
            y: hudTop - avatarSize.height / 2
        )

        let essenceLeft = hudLeft + avatarSize.width + scaled(Metrics.barLeftGap, scale)
        let essenceSize = fittedSize(
            for: essenceTrack.texture,
            inside: CGSize(width: max(0, hudRight - essenceLeft), height: essenceBarHeight)
        )
        essenceTextureScale = textureScale(for: essenceTrack.texture, displayedSize: essenceSize)
        essenceTrack.position = CGPoint(x: essenceLeft, y: hudTop - essenceBarHeight / 2)
        essenceTrack.size = essenceSize
        let essenceFillSize = scaledTextureSize(for: essenceFill.texture, scale: essenceTextureScale)
        essenceFillCrop.position = CGPoint(
            x: essenceLeft + Metrics.xpFillInsetLeft * essenceTextureScale,
            y: essenceTrack.position.y
        )
        essenceFill.position = .zero
        essenceFill.size = essenceFillSize
        essenceFillMask.position = .zero

        levelLabel.setFontSize(scaled(21, scale))
        levelLabel.root.position = CGPoint(
            x: essenceLeft + essenceTrack.size.width - Metrics.levelRightInset * essenceTextureScale,
            y: essenceTrack.position.y
        )

        let healthLeft = essenceLeft
        let healthY = essenceTrack.position.y
            - (essenceBarHeight / 2)
            - scaled(Metrics.barRowGap, scale)
            - (scaled(Metrics.healthBarHeight, scale) / 2)
        let healthBarWidth = min(
            scaled(Metrics.healthBarMaxWidth, scale),
            max(0, hudRight - healthLeft - scaled(18, scale)),
            aspectWidth(for: healthTrack.texture, height: scaled(Metrics.healthBarHeight, scale))
        )
        let healthBarSize = fittedSize(
            for: healthTrack.texture,
            inside: CGSize(width: healthBarWidth, height: scaled(Metrics.healthBarHeight, scale))
        )
        healthTextureScale = textureScale(for: healthTrack.texture, displayedSize: healthBarSize)
        healthTrack.position = CGPoint(x: healthLeft, y: healthY)
        healthTrack.size = healthBarSize
        healthFillCrop.position = CGPoint(
            x: healthLeft + Metrics.healthFillInsetLeft * healthTextureScale,
            y: healthY
        )
        healthFill.position = .zero
        healthFill.size = scaledTextureSize(for: healthFill.texture, scale: healthTextureScale)
        healthFillMask.position = .zero
        healthValueLabel.setFontSize(scaled(healthValueFontSize, scale))
        healthValueLabel.root.position = CGPoint(
            x: healthLeft + healthBarSize.width - Metrics.healthValueRightInset * healthTextureScale,
            y: healthY
        )
        healthIcon.path = nil

        let frameSize = CGSize(
            width: healthBarSize.width,
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

        stageLabel.setFontSize(scaled(18, scale))
        timerLabel.setFontSize(scaled(32, scale))
        stageLabel.root.position = CGPoint(x: 0, y: top - scaled(128, scale))
        timerLabel.root.position = CGPoint(x: 0, y: top - scaled(156, scale))
        layoutGuide()

        layoutItemSlots(
            slotSize: scaled(Metrics.itemSlotSize, scale),
            origin: CGPoint(
                x: hudLeft + scaled(Metrics.itemSlotSize.width, scale) / 2,
                y: healthY
                    - healthBarSize.height / 2
                    - scaled(Metrics.itemSlotSize.height, scale) / 2
                    - scaled(Metrics.itemSlotGapY, scale)
            ),
            scale: scale
        )

        setEssenceFraction(player?.level.xpFraction ?? 0)
        setHealthFraction(player?.health.fraction ?? 0)
        if let player {
            updateItemSlots(for: player)
        }
    }

    private func layoutGuide() {
        let visibleSize = screenSize
        let scale = guideScale(for: visibleSize)
        let guideY = visibleSize.height * guideVerticalOffsetFactor
        let guideX = visibleSize.width * guideHorizontalInsetFactor
        let iconOffsetY = scaled(guideIconOffsetY, scale)
        let titleOffsetY = scaled(guideTitleOffsetY, scale)
        let subtitleOffsetY = scaled(guideSubtitleOffsetY, scale)
        let titleSize = scaled(guideTitleFontSize, scale)
        let subtitleSize = scaled(guideSubtitleFontSize, scale)

        moveGuide.root.position = CGPoint(x: -guideX, y: guideY)
        aimGuide.root.position = CGPoint(x: guideX, y: guideY)

        for guide in [moveGuide, aimGuide] {
            guide.iconRoot.position = CGPoint(x: 0, y: iconOffsetY)
            guide.title.root.position = CGPoint(x: 0, y: titleOffsetY)
            guide.subtitle.root.position = CGPoint(x: 0, y: subtitleOffsetY)
            guide.title.setFontSize(titleSize)
            guide.subtitle.setFontSize(subtitleSize)
        }

        switch controlGuideInputMode {
        case .keyboardMouse:
            layoutGuideAssetIcon(in: moveGuide.iconRoot, targetSize: guideKeyboardMoveIconSize, scale: scale)
            layoutGuideAssetIcon(in: aimGuide.iconRoot, targetSize: guideKeyboardAimIconSize, scale: scale)
        case .controller:
            layoutGuideAssetIcon(in: moveGuide.iconRoot, targetSize: guideControllerMoveIconSize, scale: scale)
            layoutGuideAssetIcon(in: aimGuide.iconRoot, targetSize: guideControllerAimIconSize, scale: scale)
        }
    }

    private func configureGuideForCurrentInputMode() {
        moveGuide.iconRoot.removeAllChildren()
        aimGuide.iconRoot.removeAllChildren()

        switch controlGuideInputMode {
        case .keyboardMouse:
            moveGuide.title.setText("W, A, S, D")
            aimGuide.title.setText("Move Mouse")
            setupGuideAssetIcon(named: "WASD", in: moveGuide.iconRoot)
            setupGuideAssetIcon(named: "Cursor", in: aimGuide.iconRoot)
        case .controller:
            moveGuide.title.setText("Left Stick")
            aimGuide.title.setText("Right Stick")
            setupGuideAssetIcon(named: "Left_analog", in: moveGuide.iconRoot)
            setupGuideAssetIcon(named: "Right_analog", in: aimGuide.iconRoot)
        }
    }

    private func setupGuideAssetIcon(named imageName: String, in root: SKNode) {
        let texture = SKTexture(imageNamed: imageName)
        texture.filteringMode = .nearest

        let icon = SKSpriteNode(texture: texture)
        icon.name = "guideAssetIcon"
        icon.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        icon.zPosition = 1
        root.addChild(icon)
    }

    private func layoutGuideAssetIcon(in root: SKNode, targetSize: CGSize, scale: CGFloat) {
        guard let icon = root.childNode(withName: "guideAssetIcon") as? SKSpriteNode,
              let textureSize = icon.texture?.size(),
              textureSize.width > 0,
              textureSize.height > 0
        else { return }

        let scaledTarget = scaled(targetSize, scale)
        let fitScale = min(
            scaledTarget.width / textureSize.width,
            scaledTarget.height / textureSize.height
        )
        icon.setScale(fitScale)
    }

    private func updateGuideVisibility() {
        guideRoot.alpha = isControlGuideDismissed ? 0 : 1
        guideRoot.isHidden = isControlGuideDismissed
    }

    private func setHealthFraction(_ fraction: CGFloat) {
        let availableWidth = max(
            0,
            healthTrack.size.width
                - Metrics.healthFillInsetLeft * healthTextureScale
                - Metrics.healthFillInsetRight * healthTextureScale
        )
        healthFillMask.size = CGSize(
            width: availableWidth * clampedFraction(fraction),
            height: max(0, healthTrack.size.height - Metrics.healthFillInsetY * 2 * healthTextureScale)
        )
    }

    private func setEssenceFraction(_ fraction: CGFloat) {
        let availableWidth = max(
            0,
            essenceTrack.size.width
                - Metrics.xpFillInsetLeft * essenceTextureScale
                - Metrics.xpFillInsetRight * essenceTextureScale
        )
        essenceFillMask.size = CGSize(
            width: availableWidth * clampedFraction(fraction),
            height: essenceFill.size.height
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
            slot.initials.fontSize = slotSize.height * 0.30 * 1.5
            slot.levelLabel.fontSize = slotSize.height * 0.26 * 1.5
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

    private func hudTexture(_ name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        return texture
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

    private func guideScale(for visibleSize: CGSize) -> CGFloat {
        min(layoutScale(for: visibleSize), guideMaxScale)
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

    private func fittedSize(for texture: SKTexture?, inside maxSize: CGSize) -> CGSize {
        guard let texture else { return maxSize }
        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return maxSize }
        let scale = min(maxSize.width / textureSize.width, maxSize.height / textureSize.height)
        return CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
    }

    private func aspectWidth(for texture: SKTexture?, height: CGFloat) -> CGFloat {
        guard let texture, height > 0 else { return 0 }
        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return 0 }
        return height * (textureSize.width / textureSize.height)
    }

    private func scaledTextureSize(for texture: SKTexture?, scale: CGFloat) -> CGSize {
        guard let texture else { return .zero }
        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return .zero }
        return CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
    }

    private func textureScale(for texture: SKTexture?, displayedSize: CGSize) -> CGFloat {
        guard let texture else { return 1 }
        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return 1 }
        return min(displayedSize.width / textureSize.width, displayedSize.height / textureSize.height)
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
