import SpriteKit

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

    private(set) var attackSpeedMultiplier: CGFloat = 1.0
    private(set) var movementSpeedMultiplier: CGFloat = 1.0
    private(set) var orbitCount: Int = 0
    private(set) var lightningChainCount: Int = 0
    private(set) var mistDamage: Int = 0
    private(set) var mistDuration: TimeInterval = 0
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
        skillState.upgrade(skill)
        rememberEquipped(skill)
        let currentLevel = skillState.level(of: skill.id, type: skill.type)
        let effect = skill.effect(at: currentLevel)

        switch effect {
        case .orbitingSpell(let count):
            orbitCount = count
        case .lightningStrike(let chainCount):
            lightningChainCount = chainCount
        case .poisonousMist(let damage, let duration):
            mistDamage = damage
            mistDuration = duration
        case .increaseAttackSpeed(let multiplier):
            attackSpeedMultiplier = CGFloat(multiplier)
        case .increaseMovementSpeed(let multiplier):
            movementSpeedMultiplier = CGFloat(multiplier)
        case .increaseMaxHealth(let totalBonus):
            let previousLevel = currentLevel - 1
            let previousTotal: Int = previousLevel >= 1
                ? SkillConfig.lifeBloomMaxHealthBonuses[previousLevel - 1]
                : 0
            let delta = totalBonus - previousTotal
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
}
