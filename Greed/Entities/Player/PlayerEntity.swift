import SpriteKit

private let aimGuideLength: CGFloat = 170
private let aimGuideStartOffset: CGFloat = 20
private let aimGuideHeadLength: CGFloat = 24
private let aimGuideTailWidth: CGFloat = 3.5
private let aimGuideHeadWidth: CGFloat = 7
private let aimGuideLineWidth: CGFloat = 2.2
private let aimGuideSideLineWidth: CGFloat = 0.9

class PlayerEntity: SKSpriteNode {
    var health: HealthComponent
    var level: LevelComponent
    private var ghostRenderer: ToroidalRenderingComponent?

    var skillState = PlayerSkillState()

    var controllerIndex: Int?
    var aimDirection: CGVector = .zero
    weak var attack: PlayerAttack?
    var isMovementFrozen: Bool = false
    var isTargetingActive: Bool = true

    private let aimGuideRoot = SKNode()
    private let aimGuideBody = SKShapeNode()
    private let aimGuideCenterLine = SKShapeNode()
    private let aimGuideLeftEdge = SKShapeNode()
    private let aimGuideRightEdge = SKShapeNode()
    private var hasSetupAimGuide = false

    private(set) var attackSpeedMultiplier: CGFloat = 1.0
    private(set) var movementSpeedMultiplier: CGFloat = 1.0
    private(set) var wardenThornCount: Int = 0
    private(set) var lightningCooldown: TimeInterval = 0
    private(set) var lightningStrikeCount: Int = 0
    private(set) var mistCooldown: TimeInterval = 0
    private(set) var mistCloudCount: Int = 0
    private(set) var equippedWeapons: [Skill] = []
    private(set) var equippedPowerUps: [Skill] = []

    var currentSpeed: CGFloat { GameConfig.basePlayerSpeed * movementSpeedMultiplier }

    init(texture: SKTexture, health: Int = GameConfig.basePlayerHealth) {
        self.health = HealthComponent(maximum: health)
        self.level = LevelComponent()
        super.init(texture: texture, color: .clear, size: texture.size())
        self.zPosition = Layer.world
        setupPhysics()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(deltaTime: TimeInterval) {
        guard let scene = scene as? GameScene else { return }
        if ghostRenderer == nil {
            ghostRenderer = ToroidalRenderingComponent(owner: self, mapSize: GameConfig.mapSize)
        }
        let movement = isMovementFrozen ? .zero : scene.inputSystem.movementVector(for: controllerIndex ?? 0)
        position.x += movement.dx * currentSpeed * deltaTime
        position.y += movement.dy * currentSpeed * deltaTime
        scene.cameraSystem.clampToroidal(&position)
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        ghostRenderer?.update(cameraPosition: scene.cameraSystem.cameraNode.position, viewportSize: GameConfig.cameraViewportSize)
        updateAimGuide(using: scene.inputSystem)
    }

    func takeDamage(_ amount: Int) {
        if health.takeDamage(amount) { die() }
    }

    func addXP(_ amount: Int) {
        if level.addXP(amount) {
            guard let scene = scene as? GameScene else { return }
            scene.handleLevelUp(for: self)
        }
    }

    func applySkill(_ skill: Skill) {
        guard !skillState.isMaxed(skill) else { return }

        skillState.upgrade(skill)
        rememberEquipped(skill)
        let currentLevel = skillState.level(of: skill.id, type: skill.type)
        let effect = skill.effect(at: currentLevel)

        switch effect {
        case .wardenThorns(let count):
            wardenThornCount = count
        case .lightningStrike(let cooldown, let strikeCount):
            lightningCooldown = cooldown
            lightningStrikeCount = strikeCount
        case .poisonousMist(let cooldown, let cloudCount):
            mistCooldown = cooldown
            mistCloudCount = cloudCount
        case .increaseAttackSpeed(let bonusRate):
            attackSpeedMultiplier *= 1.0 + bonusRate
        case .increaseMovementSpeed(let bonusRate):
            movementSpeedMultiplier *= 1.0 + bonusRate
        case .increaseMaxHealth(let bonusRate):
            let delta = Int((CGFloat(health.maximum) * bonusRate).rounded())
            health.increaseMaximum(delta)
        }
    }

    private func rememberEquipped(_ skill: Skill) {
        switch skill.type {
        case .weapon:
            guard !equippedWeapons.contains(where: { $0.id == skill.id }) else { return }
            equippedWeapons.append(skill)
        case .powerUp:
            guard !equippedPowerUps.contains(where: { $0.id == skill.id }) else { return }
            equippedPowerUps.append(skill)
        }
    }

    func die() {
        guard let scene = scene as? GameScene else { return }
        scene.handlePlayerDeath(self)
    }

    func hideAimGuide() {
        aimGuideRoot.isHidden = true
    }

    private func setupPhysics() {
        let footRadius = size.width * 0.25
        let body = SKPhysicsBody(circleOfRadius: footRadius, center: CGPoint(x: 0, y: -size.height * 0.3))
        body.categoryBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.enemyProjectile | PhysicsCategory.forestEssenceOrb
        body.collisionBitMask = PhysicsCategory.decoration
        body.affectedByGravity = false
        body.allowsRotation = false
        physicsBody = body
    }

    private func setupAimGuideIfNeeded() {
        guard !hasSetupAimGuide else { return }
        hasSetupAimGuide = true

        aimGuideRoot.name = "controllerAimGuide"
        aimGuideRoot.zPosition = 8
        aimGuideRoot.isHidden = true
        addChild(aimGuideRoot)

        aimGuideBody.name = "controllerAimGuideBody"
        aimGuideBody.fillColor = SKColor(red: 0.18, green: 1.0, blue: 0.92, alpha: 0.22)
        aimGuideBody.strokeColor = SKColor(red: 0.26, green: 1.0, blue: 0.95, alpha: 0.95)
        aimGuideBody.lineWidth = aimGuideSideLineWidth
        aimGuideBody.lineJoin = .round
        aimGuideBody.lineCap = .round
        aimGuideRoot.addChild(aimGuideBody)

        aimGuideCenterLine.name = "controllerAimGuideCenter"
        aimGuideCenterLine.strokeColor = SKColor(red: 0.30, green: 1.0, blue: 0.95, alpha: 0.92)
        aimGuideCenterLine.lineWidth = aimGuideLineWidth
        aimGuideCenterLine.lineCap = .round
        aimGuideCenterLine.zPosition = 2
        aimGuideRoot.addChild(aimGuideCenterLine)

        for edge in [aimGuideLeftEdge, aimGuideRightEdge] {
            edge.strokeColor = SKColor(red: 0.30, green: 1.0, blue: 0.95, alpha: 0.42)
            edge.lineWidth = aimGuideSideLineWidth
            edge.lineCap = .round
            edge.zPosition = 1
            aimGuideRoot.addChild(edge)
        }

        rebuildAimGuidePath()
    }

    private func updateAimGuide(using inputSystem: InputSystem) {
        setupAimGuideIfNeeded()
        let playerIndex = controllerIndex ?? 0
        let isControllerManualAim = inputSystem.hasConnectedController
            && inputSystem.aimMode(for: playerIndex) == .manual
            && aimDirection != .zero

        aimGuideRoot.isHidden = !isControllerManualAim
        guard isControllerManualAim else { return }

        aimGuideRoot.zRotation = atan2(aimDirection.dy, aimDirection.dx)
    }

    private func rebuildAimGuidePath() {
        let tailX = aimGuideStartOffset
        let tipX = aimGuideLength
        let headBaseX = tipX - aimGuideHeadLength

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: tailX, y: 0))
        bodyPath.addLine(to: CGPoint(x: tailX + aimGuideHeadLength * 0.45, y: aimGuideTailWidth))
        bodyPath.addLine(to: CGPoint(x: headBaseX, y: aimGuideTailWidth))
        bodyPath.addLine(to: CGPoint(x: headBaseX, y: aimGuideHeadWidth))
        bodyPath.addLine(to: CGPoint(x: tipX, y: 0))
        bodyPath.addLine(to: CGPoint(x: headBaseX, y: -aimGuideHeadWidth))
        bodyPath.addLine(to: CGPoint(x: headBaseX, y: -aimGuideTailWidth))
        bodyPath.addLine(to: CGPoint(x: tailX + aimGuideHeadLength * 0.45, y: -aimGuideTailWidth))
        bodyPath.closeSubpath()
        aimGuideBody.path = bodyPath

        let centerPath = CGMutablePath()
        centerPath.move(to: CGPoint(x: tailX + aimGuideHeadLength * 0.25, y: 0))
        centerPath.addLine(to: CGPoint(x: tipX - aimGuideHeadLength * 0.18, y: 0))
        aimGuideCenterLine.path = centerPath

        let leftPath = CGMutablePath()
        leftPath.move(to: CGPoint(x: tailX + aimGuideHeadLength * 0.15, y: aimGuideTailWidth * 1.65))
        leftPath.addLine(to: CGPoint(x: headBaseX - aimGuideHeadLength * 0.15, y: aimGuideTailWidth * 2.4))
        aimGuideLeftEdge.path = leftPath

        let rightPath = CGMutablePath()
        rightPath.move(to: CGPoint(x: tailX + aimGuideHeadLength * 0.15, y: -aimGuideTailWidth * 1.65))
        rightPath.addLine(to: CGPoint(x: headBaseX - aimGuideHeadLength * 0.15, y: -aimGuideTailWidth * 2.4))
        aimGuideRightEdge.path = rightPath
    }
}
