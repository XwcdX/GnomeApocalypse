import SpriteKit

class PlayerEntity: SKSpriteNode {
    var health: HealthComponent
    var level: LevelComponent
    let toroidal = ToroidalPositionComponent()
    private var ghostRenderer: ToroidalRenderingComponent?
    
    var skillState = PlayerSkillState()
    
    var controllerIndex: Int?
    var aimDirection: CGVector = .zero
    
    private(set) var attackSpeedMultiplier: CGFloat = 1.0
    private(set) var movementSpeedMultiplier: CGFloat = 1.0
    private(set) var orbitCount: Int = 0
    private(set) var lightningChainCount: Int = 0
    private(set) var mistDamage: Int = 0
    private(set) var mistDuration: TimeInterval = 0
    
    var currentSpeed: CGFloat { GameConfig.basePlayerSpeed * movementSpeedMultiplier }

    init(texture: SKTexture, health: Int = GameConfig.basePlayerHealth) {
        self.health = HealthComponent(maximum: health)
        self.level = LevelComponent()
        super.init(texture: texture, color: .clear, size: texture.size())
        self.health.onDeath = { [weak self] in self?.die() }
        self.level.onLevelUp = { [weak self] newLevel in self?.handleLevelUp(newLevel) }
        setupPhysics()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(deltaTime: TimeInterval) {
        guard let scene = scene as? GameScene else { return }
        
        if ghostRenderer == nil {
            ghostRenderer = ToroidalRenderingComponent(owner: self, mapSize: GameConfig.mapSize)
        }
        
        let movement = scene.inputSystem.movementVector(for: controllerIndex ?? 0)
        position.x += movement.dx * currentSpeed * deltaTime
        position.y += movement.dy * currentSpeed * deltaTime
        
        toroidal.update(node: self)
        
        if let camera = scene.camera {
            ghostRenderer?.update(cameraPosition: camera.position, viewportSize: scene.size)
        }
    }

    func fireProjectile() {}

    func applySkill(_ skill: Skill) {
        skillState.upgrade(skill)
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
        case .increaseMaxHealth(let amount):
            health.increaseMaximum(amount)
        }
    }

    func die() {
        guard let scene = scene as? GameScene else { return }
        scene.handlePlayerDeath(self)
    }

    private func handleLevelUp(_ newLevel: Int) {
        guard let scene = scene as? GameScene else { return }
        scene.handleLevelUp(for: self)
    }

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: size.width / 2)
        body.categoryBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.enemyProjectile | PhysicsCategory.forestEssenceOrb
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = false
        body.allowsRotation = false
        physicsBody = body
    }
}
