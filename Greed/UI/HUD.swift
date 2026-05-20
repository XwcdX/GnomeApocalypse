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
private let guideKeyWidth: CGFloat = 72
private let guideKeyHeight: CGFloat = 58
private let guideKeyGap: CGFloat = 10
private let guideKeyCornerRadius: CGFloat = 4
private let guideKeyFontSize: CGFloat = 34
private let guideKeyBorderWidth: CGFloat = 2
private let guideStickBaseRadius: CGFloat = 66
private let guideStickKnobRadius: CGFloat = 22
private let guideStickOffset: CGFloat = 20
private let guideStickLabelFontSize: CGFloat = 28
private let guideCursorLineWidth: CGFloat = 5
private let guideCursorPoints: [CGPoint] = [
    CGPoint(x: -38, y: 64), CGPoint(x: -38, y: -58),
    CGPoint(x: 58, y: 6),   CGPoint(x: 12, y: 13),
    CGPoint(x: 34, y: 58),  CGPoint(x: 13, y: 66),
    CGPoint(x: -12, y: 25)
]
private let guideCursorRays: [(name: String, start: CGPoint, end: CGPoint)] = [
    ("guideAimRay_0", CGPoint(x: -88, y: 68),  CGPoint(x: -120, y: 100)),
    ("guideAimRay_1", CGPoint(x: -6,  y: 106), CGPoint(x: -6,   y: 145)),
    ("guideAimRay_2", CGPoint(x: 80,  y: 67),  CGPoint(x: 113,  y: 99)),
    ("guideAimRay_3", CGPoint(x: 94,  y: -15), CGPoint(x: 138,  y: -15))
]
private let guideCursorRayWidth: CGFloat = 9
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
    private let stageLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let timerLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let guideRoot = SKNode()
    private let moveGuide = GuidePromptVisual(title: "W, A, S, D", subtitle: "to move")
    private let aimGuide = GuidePromptVisual(title: "Move Mouse", subtitle: "to aim")

    private final class ItemSlotVisual {
        let root = SKNode()
        let background = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.34), size: .zero)
        let frame = SKShapeNode()
        let icon = SKSpriteNode(color: .clear, size: .zero)
        let initials = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        let levelLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
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
                let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
                label.text = text
                label.fontColor = SKColor.black.withAlphaComponent(0.78)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.position = offset
                label.zPosition = 0
                return label
            }
            foreground = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
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
        timerLabel.text = formatElapsedTime(elapsedTime)
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

        levelLabel.setFontSize(scaled(healthValueFontSize, scale))
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

        stageLabel.fontSize = scaled(18, scale)
        timerLabel.fontSize = scaled(32, scale)
        stageLabel.position = CGPoint(x: 0, y: top - scaled(128, scale))
        timerLabel.position = CGPoint(x: 0, y: top - scaled(156, scale))
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
            layoutKeyCaps(scale: scale)
            layoutCursorIcon(scale: scale)
        case .controller:
            layoutControllerStickIcon(in: moveGuide.iconRoot, scale: scale, label: "L", isAimStick: false)
            layoutControllerStickIcon(in: aimGuide.iconRoot, scale: scale, label: "R", isAimStick: true)
        }
    }

    private func configureGuideForCurrentInputMode() {
        moveGuide.iconRoot.removeAllChildren()
        aimGuide.iconRoot.removeAllChildren()

        switch controlGuideInputMode {
        case .keyboardMouse:
            moveGuide.title.setText("W, A, S, D")
            aimGuide.title.setText("Move Mouse")
            setupMoveGuideIcon()
            setupAimGuideIcon()
        case .controller:
            moveGuide.title.setText("Left Stick")
            aimGuide.title.setText("Right Stick")
            setupControllerStickIcon(in: moveGuide.iconRoot, isAimStick: false)
            setupControllerStickIcon(in: aimGuide.iconRoot, isAimStick: true)
        }
    }

    private func setupMoveGuideIcon() {
        for key in ["W", "A", "S", "D"] {
            let root = SKNode()
            root.name = "guideKey_\(key)"

            let background = SKShapeNode()
            background.name = "guideKeyBackground"
            background.fillColor = SKColor.white.withAlphaComponent(0.92)
            background.strokeColor = SKColor.black.withAlphaComponent(0.74)
            background.lineWidth = 2
            background.zPosition = 0
            root.addChild(background)

            let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            label.text = key
            label.name = "guideKeyLabel"
            label.fontColor = SKColor.black.withAlphaComponent(0.88)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = 1
            root.addChild(label)

            moveGuide.iconRoot.addChild(root)
        }
    }

    private func setupAimGuideIcon() {
        let cursor = SKShapeNode()
        cursor.name = "guideCursor"
        cursor.fillColor = .white
        cursor.strokeColor = SKColor.black.withAlphaComponent(0.78)
        cursor.lineJoin = .round
        cursor.lineCap = .round
        cursor.lineWidth = 2
        cursor.zPosition = 2
        aimGuide.iconRoot.addChild(cursor)

        for index in 0..<4 {
            let ray = SKShapeNode()
            ray.name = "guideAimRay_\(index)"
            ray.strokeColor = .white
            ray.lineCap = .round
            ray.lineWidth = 4
            ray.zPosition = 1
            aimGuide.iconRoot.addChild(ray)
        }
    }

    private func setupControllerStickIcon(in root: SKNode, isAimStick: Bool) {
        let base = SKShapeNode()
        base.name = "guideStickBase"
        base.fillColor = SKColor.white.withAlphaComponent(0.16)
        base.strokeColor = .white
        base.lineCap = .round
        base.zPosition = 0
        root.addChild(base)

        let knob = SKShapeNode()
        knob.name = "guideStickKnob"
        knob.fillColor = SKColor.white.withAlphaComponent(0.92)
        knob.strokeColor = SKColor.black.withAlphaComponent(0.74)
        knob.lineCap = .round
        knob.zPosition = 2
        root.addChild(knob)

        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.name = "guideStickLabel"
        label.fontColor = SKColor.black.withAlphaComponent(0.84)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 3
        root.addChild(label)

        for index in 0..<4 {
            let tick = SKShapeNode()
            tick.name = "guideStickTick_\(index)"
            tick.strokeColor = .white
            tick.lineCap = .round
            tick.zPosition = 1
            root.addChild(tick)
        }

        guard isAimStick else { return }
        for index in 0..<4 {
            let ray = SKShapeNode()
            ray.name = "guideStickAimRay_\(index)"
            ray.strokeColor = .white
            ray.lineCap = .round
            ray.zPosition = 1
            root.addChild(ray)
        }
    }

    private func layoutKeyCaps(scale: CGFloat) {
        let keySize = scaled(CGSize(width: guideKeyWidth, height: guideKeyHeight), scale)
        let gap = scaled(guideKeyGap, scale)
        let positions: [CGPoint] = [
            CGPoint(x: 0, y: keySize.height + gap),
            CGPoint(x: -(keySize.width + gap), y: 0),
            .zero,
            CGPoint(x: keySize.width + gap, y: 0)
        ]

        for (index, node) in moveGuide.iconRoot.children.enumerated() {
            guard index < positions.count else { continue }
            node.position = positions[index]
            guard let background = node.childNode(withName: "guideKeyBackground") as? SKShapeNode,
                  let label = node.childNode(withName: "guideKeyLabel") as? SKLabelNode
            else { continue }

            let corner = scaled(guideKeyCornerRadius, scale)
            background.path = CGPath(
                roundedRect: CGRect(
                    x: -keySize.width / 2, y: -keySize.height / 2,
                    width: keySize.width,  height: keySize.height
                ),
                cornerWidth: corner, cornerHeight: corner, transform: nil
            )
            background.lineWidth = scaled(guideKeyBorderWidth, scale)
            label.fontSize = scaled(guideKeyFontSize, scale)
        }
    }

    private func layoutCursorIcon(scale: CGFloat) {
        guard let cursor = aimGuide.iconRoot.childNode(withName: "guideCursor") as? SKShapeNode else { return }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: scaled(guideCursorPoints[0].x, scale), y: scaled(guideCursorPoints[0].y, scale)))
        for point in guideCursorPoints.dropFirst() {
            path.addLine(to: CGPoint(x: scaled(point.x, scale), y: scaled(point.y, scale)))
        }
        path.closeSubpath()
        cursor.path = path
        cursor.lineWidth = scaled(guideCursorLineWidth, scale)

        for ray in guideCursorRays {
            guard let rayNode = aimGuide.iconRoot.childNode(withName: ray.name) as? SKShapeNode else { continue }
            let rayPath = CGMutablePath()
            rayPath.move(to: CGPoint(x: scaled(ray.start.x, scale), y: scaled(ray.start.y, scale)))
            rayPath.addLine(to: CGPoint(x: scaled(ray.end.x, scale), y: scaled(ray.end.y, scale)))
            rayNode.path = rayPath
            rayNode.lineWidth = scaled(guideCursorRayWidth, scale)
        }
    }

    private func layoutControllerStickIcon(in root: SKNode, scale: CGFloat, label: String, isAimStick: Bool) {
        let baseRadius = scaled(guideStickBaseRadius, scale)
        let knobRadius = scaled(guideStickKnobRadius, scale)
        let knobOffset = scaled(guideStickOffset, scale)

        if let base = root.childNode(withName: "guideStickBase") as? SKShapeNode {
            base.path = CGPath(
                ellipseIn: CGRect(
                    x: -baseRadius, y: -baseRadius,
                    width: baseRadius * 2, height: baseRadius * 2
                ),
                transform: nil
            )
            base.lineWidth = scaled(guideKeyBorderWidth, scale)
        }

        if let knob = root.childNode(withName: "guideStickKnob") as? SKShapeNode {
            knob.position = CGPoint(x: isAimStick ? knobOffset : -knobOffset, y: knobOffset)
            knob.path = CGPath(
                ellipseIn: CGRect(
                    x: -knobRadius, y: -knobRadius,
                    width: knobRadius * 2, height: knobRadius * 2
                ),
                transform: nil
            )
            knob.lineWidth = scaled(guideKeyBorderWidth, scale)
        }

        if let stickLabel = root.childNode(withName: "guideStickLabel") as? SKLabelNode {
            stickLabel.text = label
            stickLabel.fontSize = scaled(guideStickLabelFontSize, scale)
            stickLabel.position = CGPoint(x: isAimStick ? knobOffset : -knobOffset, y: knobOffset)
        }

        let tickRadius = baseRadius + scaled(14, scale)
        let tickLength = scaled(20, scale)
        let tickPoints: [(CGPoint, CGPoint)] = [
            (CGPoint(x: -tickLength / 2, y: tickRadius), CGPoint(x: tickLength / 2, y: tickRadius)),
            (CGPoint(x: -tickLength / 2, y: -tickRadius), CGPoint(x: tickLength / 2, y: -tickRadius)),
            (CGPoint(x: -tickRadius, y: -tickLength / 2), CGPoint(x: -tickRadius, y: tickLength / 2)),
            (CGPoint(x: tickRadius, y: -tickLength / 2), CGPoint(x: tickRadius, y: tickLength / 2))
        ]
        for (index, points) in tickPoints.enumerated() {
            guard let tick = root.childNode(withName: "guideStickTick_\(index)") as? SKShapeNode else { continue }
            let path = CGMutablePath()
            path.move(to: points.0)
            path.addLine(to: points.1)
            tick.path = path
            tick.lineWidth = scaled(guideCursorRayWidth * 0.65, scale)
        }

        guard isAimStick else { return }
        let rays: [(CGPoint, CGPoint)] = [
            (CGPoint(x: -baseRadius * 0.9, y: baseRadius * 0.9), CGPoint(x: -baseRadius * 1.28, y: baseRadius * 1.28)),
            (CGPoint(x: 0, y: baseRadius * 1.05), CGPoint(x: 0, y: baseRadius * 1.55)),
            (CGPoint(x: baseRadius * 0.9, y: baseRadius * 0.9), CGPoint(x: baseRadius * 1.28, y: baseRadius * 1.28)),
            (CGPoint(x: baseRadius * 1.08, y: 0), CGPoint(x: baseRadius * 1.58, y: 0))
        ]
        for (index, ray) in rays.enumerated() {
            guard let rayNode = root.childNode(withName: "guideStickAimRay_\(index)") as? SKShapeNode else { continue }
            let path = CGMutablePath()
            path.move(to: ray.0)
            path.addLine(to: ray.1)
            rayNode.path = path
            rayNode.lineWidth = scaled(guideCursorRayWidth, scale)
        }
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
