import SpriteKit

private let aimGuideVisibleLength: CGFloat = 75
private let aimGuideStartOffset: CGFloat = 8
private let aimGuideScaleMultiplier: CGFloat = 0.5
private let aimGuideTextureVisibleHeight: CGFloat = 29

/// Base player node that owns movement, health, XP, skill state, and toroidal rendering.
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
    private let aimGuideSprite = SKSpriteNode(imageNamed: "guide_controller_arrow")
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

    /// Current movement speed after power-up multipliers.
    var currentSpeed: CGFloat { GameConfig.basePlayerSpeed * movementSpeedMultiplier }

    init(texture: SKTexture, health: Int = GameConfig.basePlayerHealth) {
        self.health = HealthComponent(maximum: health)
        self.level = LevelComponent()
        super.init(texture: texture, color: .clear, size: texture.size())
        self.zPosition = Layer.world
        setupPhysics()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Advances movement, camera leash/wrap rules, ghost rendering, and aim guide state.
    func update(deltaTime: TimeInterval) {
        guard let scene = scene as? GameScene else { return }
        if ghostRenderer == nil {
            ghostRenderer = ToroidalRenderingComponent(owner: self, mapSize: GameConfig.mapSize)
        }
        let movement = isMovementFrozen ? .zero : scene.inputSystem.movementVector(for: controllerIndex ?? 0)
        position.x += movement.dx * currentSpeed * deltaTime
        position.y += movement.dy * currentSpeed * deltaTime
        if !scene.directorSystem.isBossStageActive {
            scene.cameraSystem.clampToroidal(&position)
        }
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        ghostRenderer?.update(cameraPosition: scene.cameraSystem.cameraNode.position, viewportSize: GameConfig.cameraViewportSize)
        updateAimGuide(using: scene.inputSystem)
    }

    /// Applies incoming damage and notifies the scene when health reaches zero.
    func takeDamage(_ amount: Int) {
        if health.takeDamage(amount) { die() }
    }

    /// Adds essence XP and asks the scene to present skill selection on level-up.
    func addXP(_ amount: Int) {
        if level.addXP(amount) {
            guard let scene = scene as? GameScene else { return }
            scene.handleLevelUp(for: self)
        }
    }

    /// Upgrades a skill and applies its gameplay effect to this player.
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

    /// Routes player death handling through the owning `GameScene`.
    func die() {
        guard let scene = scene as? GameScene else { return }
        scene.handlePlayerDeath(self)
    }

    /// Hides the controller aim guide while overlays are active.
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

        aimGuideSprite.name = "controllerAimGuideArrow"
        aimGuideSprite.texture?.filteringMode = .nearest
        aimGuideSprite.zPosition = 1
        aimGuideSprite.zRotation = -.pi / 2
        rebuildAimGuideSprite()
        aimGuideRoot.addChild(aimGuideSprite)
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

    private func rebuildAimGuideSprite() {
        guard let texture = aimGuideSprite.texture else { return }
        let textureSize = texture.size()
        let scale = aimGuideVisibleLength / aimGuideTextureVisibleHeight * aimGuideScaleMultiplier
        aimGuideSprite.size = CGSize(
            width: textureSize.width * scale,
            height: textureSize.height * scale
        )
        aimGuideSprite.position = CGPoint(x: aimGuideStartOffset + aimGuideVisibleLength / 2, y: 0)
    }
}
