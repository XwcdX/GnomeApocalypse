import SpriteKit
import MetalKit

final class GameScene: SKScene {
    private(set) var cameraSystem: CameraSystem!
    private(set) var inputSystem: InputSystem!
    private(set) var directorSystem: DirectorSystem!
    private var spawnSystem: SpawnSystem!
    private var collisionSystem: CollisionSystem!
    private var skillSystem: SkillSystem!
    private var floorRenderer: FloorTileRenderer!
    private var enemyAI: EnemyAI!
    private var playerProjectilePool: ProjectilePool!
    private var enemyProjectilePool: ProjectilePool!
    private var hud: HUD!
    private let audioManager = AudioManager.shared
    private let particleAssets = ParticleAssets.shared
    private var skillCardOverlay: SkillCardOverlay?
    private var gameOverOverlay: GameOverOverlay?
    private weak var skillSelectionPlayer: PlayerEntity?
    private var wasSkillConfirmPressed = false
    var onReplayRequested: (() -> Void)?
    
    private var players: [PlayerEntity] = []
    private var enemies: [EnemyEntity] = []
    private var playerAttacks: [PlayerAttack] = []
    
    private let groundLayer = SKNode()
    private let environmentLayer = SKNode()
    private let entityLayer = SKNode()
    
    private var elapsedRunTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    func setup(view: MTKView) {
        let renderSize = view.drawableSize == .zero ? view.bounds.size : view.drawableSize
        size = renderSize
        setupLayers()
        setupCamera(viewSize: renderSize)
        setupSystems(viewSize: renderSize)
        setupPhysics()
        preloadAssets()
        spawnPlayer()
    }
    
    override func update(_ currentTime: TimeInterval) {
        let deltaTime = computeDeltaTime(currentTime)
        guard deltaTime > 0 else { return }

        if skillCardOverlay != nil {
            updateSkillSelectionInput()
            return
        }

        if gameOverOverlay != nil { return }

        cameraSystem.isLocked = directorSystem.isBossStageActive
        elapsedRunTime += deltaTime

        // Players move and wrap first
        let visibleEnemies = enemies.filter { isVisible($0.position) }
        for player in players {
            player.aimDirection = inputSystem.aimVector(
                for: player.controllerIndex ?? 0,
                playerWorldPos: player.position,
                gnomes: visibleEnemies
            )
            player.update(deltaTime: deltaTime)
            enforceBossCameraLeash(for: player)
        }

        for attack in playerAttacks { attack.update(deltaTime: deltaTime) }
        playerProjectilePool.updateAll(deltaTime: deltaTime)

        // Enemies move and wrap
        for enemy in enemies { enemy.update(deltaTime: deltaTime) }
        enemyProjectilePool.updateAll(deltaTime: deltaTime)

        // AI runs after move+wrap so offsets are computed from correct wrapped positions
        enemyAI.update(enemies: enemies, players: players)

        let activeBudget = enemies.reduce(0) { $0 + $1.budgetWeight }
        directorSystem.update(deltaTime: deltaTime, activeBudgetUsed: activeBudget)

        spawnSystem.update(deltaTime: deltaTime, activeBudgetUsed: activeBudget)
        hud.updateViewport(size)
        hud.update(elapsedTime: elapsedRunTime)
        cameraSystem.update(deltaTime: deltaTime)
        floorRenderer.update(cameraPosition: cameraSystem.cameraNode.position)
    }

    private func setupLayers() {
        groundLayer.zPosition     = Layer.ground
        environmentLayer.zPosition = Layer.environment
        entityLayer.zPosition     = Layer.entities

        addChild(groundLayer)
        addChild(environmentLayer)
        addChild(entityLayer)
    }

    private func setupCamera(viewSize: CGSize) {
        let cam = SKCameraNode()
        addChild(cam)
        camera = cam
        cameraSystem = CameraSystem(cameraNode: cam, viewportSize: viewSize)
    }

    private func setupSystems(viewSize: CGSize) {
        inputSystem = InputSystem.shared
        inputSystem.setup()
        directorSystem = DirectorSystem()
        collisionSystem = CollisionSystem()
        physicsWorld.contactDelegate = collisionSystem
        skillSystem = SkillSystem()
        enemyAI = EnemyAI()
        spawnSystem = SpawnSystem(entityLayer: entityLayer, cameraSystem: cameraSystem, directorSystem: directorSystem)
        playerProjectilePool = ProjectilePool(
            size: GameConfig.projectilePoolSize,
            atlasName: "PlayerProjectile",
            frameNames: ["tile000", "tile001", "tile002", "tile003"],
            projectileSize: GameConfig.playerProjectileSize,
            category: PhysicsCategory.playerProjectile,
            contactTestBitMask: PhysicsCategory.enemy,
            frameTime: GameConfig.playerProjectileFrameTime
        )
        enemyProjectilePool = ProjectilePool(
            size: GameConfig.projectilePoolSize,
            atlasName: "PlayerProjectile",
            frameNames: ["tile000", "tile001", "tile002", "tile003"],
            projectileSize: GameConfig.playerProjectileSize,
            category: PhysicsCategory.enemyProjectile,
            contactTestBitMask: PhysicsCategory.player,
            frameTime: GameConfig.playerProjectileFrameTime
        )
        
        let tileTexture = SKTexture(imageNamed: "tile_ground")
        tileTexture.filteringMode = .nearest
        let tileSize = CGSize(width: 1440, height: 810)
        floorRenderer = FloorTileRenderer(tileTexture: tileTexture, tileSize: tileSize, viewportSize: viewSize)
        groundLayer.addChild(floorRenderer.rootNode)
    }

    private func setupPhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.speed   = 1.0
    }

    private func preloadAssets() {
        audioManager.preloadAll()
        audioManager.playBackgroundMusic()
        particleAssets.preloadAll()
    }

    func updateViewport(_ size: CGSize) {
        cameraSystem.updateViewport(size)
        floorRenderer.updateViewport(size)
        hud?.updateViewport(size)
        skillCardOverlay?.updateViewport(size)
        gameOverOverlay?.updateViewport(size)
    }

    private func spawnPlayer() {
        let player = LuminousWisp(inputIndex: 0)
        player.position = .zero
        entityLayer.addChild(player)
        players.append(player)
        cameraSystem.addPlayer(player)
        let playerAttack = PlayerAttack(owner: player, pool: playerProjectilePool, entityLayer: entityLayer)
        player.attack = playerAttack
        playerAttacks.append(playerAttack)
        collisionSystem.register(player: player, directorSystem: directorSystem)
        setupHUD(for: player)
    }

    private func setupHUD(for player: PlayerEntity) {
        let hud = HUD(player: player, screenSize: size)
        cameraSystem.cameraNode.addChild(hud)
        self.hud = hud
    }

    private func computeDeltaTime(_ currentTime: TimeInterval) -> TimeInterval {
        guard lastUpdateTime > 0 else {
            lastUpdateTime = currentTime
            return 0
        }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        return min(dt, 1.0 / 20.0)
    }
    private func isVisible(_ position: CGPoint) -> Bool {
        let cameraPos = cameraSystem.cameraNode.position
        let viewport = GameConfig.cameraViewportSize
        let margin: CGFloat = 100
        let rect = CGRect(
            x: cameraPos.x - viewport.width / 2 - margin,
            y: cameraPos.y - viewport.height / 2 - margin,
            width: viewport.width + margin * 2,
            height: viewport.height + margin * 2
        )
        for dx: CGFloat in [-GameConfig.mapSize.width, 0, GameConfig.mapSize.width] {
            for dy: CGFloat in [-GameConfig.mapSize.height, 0, GameConfig.mapSize.height] {
                if rect.contains(CGPoint(x: position.x + dx, y: position.y + dy)) { return true }
            }
        }
        return false
    }

    func nearestPlayerPosition(to position: CGPoint) -> CGPoint {
        players.min {
            toroidalDistance(from: position, to: $0.position, mapSize: GameConfig.mapSize) <
            toroidalDistance(from: position, to: $1.position, mapSize: GameConfig.mapSize)
        }?.position ?? .zero
    }

    func register(enemy: EnemyEntity) {
        enemies.append(enemy)
    }
    func deregister(enemy: EnemyEntity) {
        enemies.removeAll { $0 === enemy }
    }
    
    func spawnForestEssenceOrb(at position: CGPoint) {
        spawnSystem.spawnForestEssenceOrb(at: position)
    }

    func removeOrb(_ orb: ForestEssenceOrb) {
        spawnSystem.removeOrb(orb)
    }
    
    func handleLevelUp(for player: PlayerEntity) {
        Log.debug("GameScene: player leveled up to \(player.level.currentLevel)")
        guard skillCardOverlay == nil else { return }
        audioManager.play(.levelUp)
        skillSelectionPlayer = player
        presentSkillCardOverlay()
    }

    @discardableResult
    func handleMouseDown(atViewPosition viewPosition: CGPoint, viewSize: CGSize) -> Bool {
        guard viewSize.width > 0, viewSize.height > 0 else { return true }

        let overlayPoint = CGPoint(
            x: (viewPosition.x / viewSize.width) * size.width - size.width / 2,
            y: (viewPosition.y / viewSize.height) * size.height - size.height / 2
        )

        if let gameOverOverlay {
            return gameOverOverlay.handleMouseDown(at: overlayPoint)
        }

        guard let skillCardOverlay else { return false }
        return skillCardOverlay.handleMouseDown(at: overlayPoint)
    }

    @discardableResult
    func handleKeyDown(_ event: NSEvent) -> Bool {
        if gameOverOverlay != nil {
            if event.keyCode == 36 || event.keyCode == 49 {
                gameOverOverlay?.replay()
            }
            return true
        }
        return skillCardOverlay != nil
    }

    func handlePlayerDeath(_ player: PlayerEntity) {
        Log.debug("GameScene: player died")
        presentGameOverOverlay()
    }
    
    func handleBossDeath() {
        directorSystem.recordBossDeath()
        cameraSystem.isLocked = false
    }
    
    func spawnBossMinions(count: Int, around position: CGPoint) {
        spawnSystem.spawnBossMinions(count: count, around: position)
    }
    
    func spawnEnemyProjectile(at position: CGPoint, direction: CGVector, damage: Int) {
        guard let projectile = enemyProjectilePool.dequeue() else { return }
        
        let magnitude = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        guard magnitude > 0 else { return }
        
        let normalisedDirection = CGVector(dx: direction.dx / magnitude, dy: direction.dy / magnitude)
        let velocity = CGVector(
            dx: normalisedDirection.dx * GameConfig.projectileSpeed,
            dy: normalisedDirection.dy * GameConfig.projectileSpeed
        )
        
        projectile.activate(at: position, velocity: velocity, damage: damage, lifespan: GameConfig.projectileLifeSpan)
        entityLayer.addChild(projectile)
    }

    private func presentSkillCardOverlay() {
        guard let player = skillSelectionPlayer else { return }

        let skills = skillSystem.draw(for: player.skillState)
        guard !skills.isEmpty else {
            skillSelectionPlayer = nil
            return
        }

        let overlay = SkillCardOverlay(skills: skills, screenSize: size) { [weak self, weak player] skill in
            guard let self, let player else { return }
            self.completeSkillSelection(skill, for: player)
        }
        cameraSystem.cameraNode.addChild(overlay)
        skillCardOverlay = overlay
        wasSkillConfirmPressed = inputSystem.confirmPressed(for: player.controllerIndex ?? 0)
    }

    private func presentGameOverOverlay() {
        guard gameOverOverlay == nil else { return }
        skillCardOverlay?.removeFromParent()
        skillCardOverlay = nil
        skillSelectionPlayer = nil
        physicsWorld.speed = 0

        let overlay = GameOverOverlay(survivedTime: elapsedRunTime, screenSize: size) { [weak self] in
            self?.onReplayRequested?()
        }
        cameraSystem.cameraNode.addChild(overlay)
        gameOverOverlay = overlay
    }

    private func completeSkillSelection(_ skill: Skill, for player: PlayerEntity) {
        player.applySkill(skill)
        skillCardOverlay?.removeFromParent()
        skillCardOverlay = nil
        skillSelectionPlayer = nil
        wasSkillConfirmPressed = false
        lastUpdateTime = 0
    }

    private func updateSkillSelectionInput() {
        guard let player = skillSelectionPlayer else { return }
        let isConfirmPressed = inputSystem.confirmPressed(for: player.controllerIndex ?? 0)
        if isConfirmPressed && !wasSkillConfirmPressed {
            skillCardOverlay?.selectHighlightedCard()
        }
        wasSkillConfirmPressed = isConfirmPressed
    }

    private func enforceBossCameraLeash(for player: PlayerEntity) {
        guard directorSystem.isBossStageActive else { return }

        let centre = cameraSystem.cameraNode.position
        let halfWidth = cameraSystem.worldViewportSize.width * GameConfig.cameraLeashFactor / 2
        let halfHeight = cameraSystem.worldViewportSize.height * GameConfig.cameraLeashFactor / 2
        player.position.x = min(max(player.position.x, centre.x - halfWidth), centre.x + halfWidth)
        player.position.y = min(max(player.position.y, centre.y - halfHeight), centre.y + halfHeight)
    }
}
