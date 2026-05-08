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
    
    private var players: [PlayerEntity] = []
    private var enemies: [EnemyEntity] = []
    private var playerAttacks: [PlayerAttack] = []
    
    private let groundLayer = SKNode()
    private let environmentLayer = SKNode()
    private let entityLayer = SKNode()
    
    private var lastUpdateTime: TimeInterval = 0

    func setup(view: MTKView) {
        setupLayers()
        setupCamera(viewSize: view.bounds.size)
        setupSystems(viewSize: view.bounds.size)
        setupPhysics()
        spawnPlayer()
    }
    
    override func update(_ currentTime: TimeInterval) {
        let deltaTime = computeDeltaTime(currentTime)
        guard deltaTime > 0 else { return }

        // Players move and wrap first
        let visibleEnemies = enemies.filter { isVisible($0.position) }
        for player in players {
            player.aimDirection = inputSystem.aimVector(
                for: player.controllerIndex ?? 0,
                playerWorldPos: player.position,
                gnomes: visibleEnemies
            )
            player.update(deltaTime: deltaTime)
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

        spawnSystem.update(deltaTime: deltaTime)
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

    func updateViewport(_ size: CGSize) {
        cameraSystem.updateViewport(size)
        floorRenderer.updateViewport(size)
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
    }
    func handlePlayerDeath(_ player: PlayerEntity) {
        Log.debug("GameScene: player died")
        isPaused = true
    }
    
    func handleBossDeath() {
        directorSystem.recordBossDeath()
    }
    
    func spawnBossMinions(count: Int, around position: CGPoint) {
        Log.debug("GameScene: spawning \(count) boss minions")
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
}
