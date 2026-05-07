import SpriteKit
import MetalKit

final class GameScene: SKScene {
    private var cameraSystem: CameraSystem!
    private(set) var inputSystem: InputSystem!
    private(set) var directorSystem: DirectorSystem!
    private var spawnSystem: SpawnSystem!
    private var collisionSystem: CollisionSystem!
    private var skillSystem: SkillSystem!
    private var floorRenderer: FloorTileRenderer!
    private var enemyAI: EnemyAI!
    private var playerProjectilePool: ProjectilePool!
    
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
        
        enemyAI.update(enemies: enemies, players: players)
        
        for player in players {
            player.aimDirection = inputSystem.aimVector(
                for: player.controllerIndex ?? 0,
                playerWorldPos: player.position,
                gnomes: enemies
            )
            player.update(deltaTime: deltaTime)
        }
        
        for attack in playerAttacks {
            attack.update(deltaTime: deltaTime)
        }
        
        playerProjectilePool.updateAll(deltaTime: deltaTime)
        
        for enemy in enemies {
            enemy.update(deltaTime: deltaTime)
        }
        
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
        
        let tileTexture = SKTexture(imageNamed: "tile_ground")
        let tileSize = CGSize(width: 128, height: 128)
        floorRenderer = FloorTileRenderer(tileTexture: tileTexture, tileSize: tileSize, viewportSize: viewSize)
        groundLayer.addChild(floorRenderer.rootNode)
    }

    private func setupPhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.speed   = 1.0
    }

    private func spawnPlayer() {
        let player = LuminousWisp(inputIndex: 0)
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        entityLayer.addChild(player)
        players.append(player)
        cameraSystem.addPlayer(player)
        playerAttacks.append(PlayerAttack(owner: player, pool: playerProjectilePool, entityLayer: entityLayer))
        
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
    func register(enemy: EnemyEntity) {
        enemies.append(enemy)
    }
    func deregister(enemy: EnemyEntity) {
        enemies.removeAll { $0 === enemy }
    }
    
    func spawnForestEssenceOrb(at position: CGPoint) {
        spawnSystem.spawnForestEssenceOrb(at: position)
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
        Log.debug("GameScene: spawning enemy projectile")
    }
}
