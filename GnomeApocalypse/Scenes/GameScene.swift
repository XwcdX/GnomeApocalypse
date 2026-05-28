import SpriteKit
import MetalKit

private let visibilityCheckMargin: CGFloat = 100

/// Main gameplay scene that coordinates systems, entities, overlays, audio, and the update loop.
final class GameScene: SKScene {
    private(set) var cameraSystem: CameraSystem!
    /// Shared input router used by entities and overlays.
    var inputSystem: InputSystem { InputSystem.shared }
    private(set) var directorSystem: DirectorSystem!
    private var spawnSystem: SpawnSystem!
    private var collisionSystem: CollisionSystem!
    private var skillRuntimeSystem: SkillRuntimeSystem!
    private let overlayFlow = OverlayFlowController()
    private var floorRenderer: FloorTileRenderer!
    private var environmentPropSystem: EnvironmentPropSystem!
    private var enemyAI: EnemyAI!
    private var playerProjectilePool: ProjectilePool!
    private var enemyProjectilePool: ProjectilePool!
    private var hud: HUD!
    private let entityStore = GameSceneEntityStore()
    private let audioManager = AudioManager.shared
    private let particleAssets = ParticleAssets.shared
    /// Called when the game-over overlay requests a fresh run.
    var onReplayRequested: (() -> Void)? {
        didSet { overlayFlow.onReplayRequested = onReplayRequested }
    }
    
    private var playerAttacks: [PlayerAttack] = []
    
    private let floorLayer = SKNode()
    private let propsLayer = SKNode()
    
    private var elapsedRunTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var wasBossStageActive = false
    /// Called when cursor presentation should switch between manual and hidden aim modes.
    var onAimModeChanged: ((InputSystem.AimMode) -> Void)? {
        didSet { overlayFlow.onAimModeChanged = onAimModeChanged }
    }
    /// Called once the game-over overlay takes control of input.
    var onGameOverPresented: (() -> Void)? {
        didSet { overlayFlow.onGameOverPresented = onGameOverPresented }
    }

    /// Initializes scene systems and spawns the first player.
    func setup(view: MTKView) {
        let viewSize = view.bounds.size
        size = viewSize
        setupLayers()
        setupCamera(viewSize: viewSize)
        setupSystems(viewSize: viewSize)
        setupPhysics()
        preloadAssets()
        spawnPlayer()
    }
    
    override func update(_ currentTime: TimeInterval) {
        let deltaTime = computeDeltaTime(currentTime)
        guard deltaTime > 0 else { return }

        let players = entityStore.players
        switch overlayFlow.updateBeforeGameplay(
            deltaTime: deltaTime,
            screenSize: size,
            elapsedRunTime: elapsedRunTime,
            hud: hud,
            players: players,
            refreshWorldRenderers: { [weak self] in self?.refreshWorldRenderers() },
            updateYSort: { [weak self] in self?.updateYSort() }
        ) {
        case .none:
            break
        case .blocked:
            return
        case .resetGameplayClock:
            lastUpdateTime = 0
            return
        }

        elapsedRunTime += deltaTime

        let enemies = entityStore.enemies
        let visibleEnemies = entityStore.visibleEnemies(
            cameraPosition: cameraSystem.cameraNode.position,
            margin: visibilityCheckMargin
        )
        for player in players {
            player.aimDirection = inputSystem.aimVector(
                for: player.controllerIndex ?? 0,
                playerWorldPos: player.position,
                gnomes: visibleEnemies
            )
            player.update(deltaTime: deltaTime)
            cameraSystem.enforceLeash(for: player)
        }

        skillRuntimeSystem.update(
            deltaTime: deltaTime,
            players: players,
            enemies: enemies,
            scene: self,
            cameraSystem: cameraSystem
        )

        for attack in playerAttacks { attack.update(deltaTime: deltaTime) }
        playerProjectilePool.updateAll(deltaTime: deltaTime)

        for enemy in enemies { enemy.update(deltaTime: deltaTime) }
        enemyProjectilePool.updateAll(deltaTime: deltaTime)

        enemyAI.update(enemies: enemies, players: players)

        directorSystem.updatePlayerHealthFraction(entityStore.averagePlayerHealthFraction)
        
        let activeBudget = entityStore.activeEnemyBudget
        directorSystem.update(deltaTime: deltaTime, activeBudgetUsed: activeBudget)
        updateBossStageAudio()

        spawnSystem.update(deltaTime: deltaTime, activeBudgetUsed: activeBudget)
        hud.updateViewport(size)
        updateControlGuideDismissal()
        updateAimCursorMode()
        hud.update(elapsedTime: elapsedRunTime)
        overlayFlow.updatePendingSkillSelection(
            deltaTime: deltaTime,
            screenSize: size,
            cameraNode: cameraSystem.cameraNode
        )
        cameraSystem.update(deltaTime: deltaTime)
        refreshWorldRenderers()
        updateYSort()
    }

    private func updateYSort() {
        let mapH = GameConfig.mapSize.height
        for node in children where node !== floorLayer && node !== propsLayer {
            guard let camera = self.camera, node !== camera else { continue }
            let footY: CGFloat
            if let sprite = node as? SKSpriteNode {
                footY = sprite.position.y - sprite.size.height / 2
            } else {
                footY = node.position.y
            }
            let sortPriority = (node as? WorldLayerSortable)?.worldSortPriority ?? 0
            node.zPosition = Layer.worldZPosition(
                forFootY: footY,
                mapHeight: mapH,
                sortPriority: sortPriority
            )
        }
    }

    private func setupLayers() {
        floorLayer.zPosition   = Layer.floor
        propsLayer.zPosition   = Layer.props
        addChild(floorLayer)
        addChild(propsLayer)
    }

    private func setupCamera(viewSize: CGSize) {
        let cam = SKCameraNode()
        addChild(cam)
        camera = cam
        cameraSystem = CameraSystem(cameraNode: cam, viewportSize: viewSize)
    }

    private func setupSystems(viewSize: CGSize) {
        InputSystem.shared.setup()
        InputSystem.shared.resetControlGuideTracking()
        directorSystem = DirectorSystem()
        collisionSystem = CollisionSystem()
        physicsWorld.contactDelegate = collisionSystem
        skillRuntimeSystem = SkillRuntimeSystem()
        enemyAI = EnemyAI()
        spawnSystem = SpawnSystem(entityLayer: self, cameraSystem: cameraSystem, directorSystem: directorSystem)
        playerProjectilePool = ProjectilePool(
            size: GameConfig.projectilePoolSize,
            atlasName: "player_projectile",
            frameNames: ["projectile_player_000", "projectile_player_001", "projectile_player_002", "projectile_player_003"],
            projectileSize: GameConfig.playerProjectileSize,
            category: PhysicsCategory.playerProjectile,
            contactTestBitMask: PhysicsCategory.enemy,
            frameTime: GameConfig.playerProjectileFrameTime
        )
        enemyProjectilePool = ProjectilePool(
            size: GameConfig.projectilePoolSize,
            textureNames: ["projectile_enemy_grumble"],
            projectileSize: GameConfig.playerProjectileSize,
            category: PhysicsCategory.enemyProjectile,
            contactTestBitMask: PhysicsCategory.player,
            frameTime: GameConfig.playerProjectileFrameTime
        )
        
        let tileTexture = SKTexture(imageNamed: "tile_ground")
        tileTexture.filteringMode = .nearest
        floorRenderer = FloorTileRenderer(tileTexture: tileTexture, tileSize: GameConfig.mapSize, viewportSize: viewSize)
        floorLayer.addChild(floorRenderer.rootNode)
        setupEnvironmentProps(viewSize: viewSize)
    }

    private func setupEnvironmentProps(viewSize: CGSize) {
        environmentPropSystem = EnvironmentPropSystem()
        environmentPropSystem.setup(inBackground: propsLayer, inForeground: self)
    }

    private func setupPhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.speed   = 1.0
    }

    private func preloadAssets() {
        audioManager.setSFXEnabled(true)
        audioManager.preloadAll()
        audioManager.playBackgroundMusic()
        particleAssets.preloadAll()
    }

    /// Propagates a logical viewport change to camera-space and world renderers.
    func updateViewport(_ size: CGSize) {
        cameraSystem.updateViewport(size)
        floorRenderer.updateViewport(size)
        refreshWorldRenderers()
        hud?.updateViewport(size)
        overlayFlow.updateViewport(size)
    }

    private func refreshWorldRenderers() {
        let cameraPosition = cameraSystem.cameraNode.position
        floorRenderer.update(cameraPosition: cameraPosition)
        environmentPropSystem.update(cameraPosition: cameraPosition)
    }

    private func spawnPlayer() {
        let player = LuminousWisp(inputIndex: 0)
        player.position = .zero
        addChild(player)
        entityStore.register(player: player)
        cameraSystem.addPlayer(player)
        let playerAttack = PlayerAttack(owner: player, pool: playerProjectilePool, entityLayer: self)
        player.attack = playerAttack
        playerAttacks.append(playerAttack)
        collisionSystem.register(player: player)
        setupHUD(for: player)
        presentStartCountdown()
    }

    private func setupHUD(for player: PlayerEntity) {
        let hud = HUD(player: player, screenSize: size)
        cameraSystem.cameraNode.addChild(hud)
        self.hud = hud
    }

    private func presentStartCountdown() {
        overlayFlow.presentStartCountdown(screenSize: size, cameraNode: cameraSystem.cameraNode)
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
    /// Returns whether there is at least one shootable enemy in the visible camera bounds.
    func canPlayerShoot(from playerPosition: CGPoint) -> Bool {
        return entityStore.canPlayerShoot(
            cameraPosition: cameraSystem.cameraNode.position,
            viewportSize: cameraSystem.viewportSize
        )
    }

    /// Finds the nearest player within an orb's magnet radius.
    func magnetTargetForOrb(at orbPosition: CGPoint, radius: CGFloat) -> CGPoint? {
        entityStore.magnetTargetForOrb(at: orbPosition, radius: radius)
    }

    /// Returns the closest player position to a world point using toroidal distance.
    func nearestPlayerPosition(to position: CGPoint) -> CGPoint {
        entityStore.nearestPlayerPosition(to: position)
    }

    /// Starts tracking an enemy for updates, targeting, budget, and game-over cleanup.
    func register(enemy: EnemyEntity) {
        entityStore.register(enemy: enemy)
    }

    /// Stops tracking an enemy after death or removal.
    func deregister(enemy: EnemyEntity) {
        entityStore.deregister(enemy: enemy)
    }
    
    /// Delegates essence-orb spawning to `SpawnSystem`.
    func spawnEssenceOrb(at position: CGPoint) {
        spawnSystem.spawnEssenceOrb(at: position)
    }

    /// Removes an essence orb through `SpawnSystem` so tracking and node state stay aligned.
    func removeOrb(_ orb: EssenceOrbComponent) {
        spawnSystem.removeOrb(orb)
    }
    
    /// Starts the delayed level-up card flow for a player.
    func handleLevelUp(for player: PlayerEntity) {
        overlayFlow.handleLevelUp(for: player, hud: hud)
    }

    /// Routes a view-space mouse-down event to active camera-space overlays.
    @discardableResult
    func handleMouseDown(atViewPosition viewPosition: CGPoint, viewSize: CGSize) -> Bool {
        let handled = overlayFlow.handleMouseDown(atViewPosition: viewPosition, viewSize: viewSize, screenSize: size)
        resetGameplayClockIfNeeded()
        return handled
    }

    /// Routes a view-space mouse-move event to active camera-space overlays.
    @discardableResult
    func handleMouseMoved(atViewPosition viewPosition: CGPoint, viewSize: CGSize) -> Bool {
        overlayFlow.handleMouseMoved(atViewPosition: viewPosition, viewSize: viewSize, screenSize: size)
    }

    /// Routes key-down events to active overlays before gameplay input sees them.
    @discardableResult
    func handleKeyDown(_ event: NSEvent) -> Bool {
        let handled = overlayFlow.handleKeyDown(event)
        resetGameplayClockIfNeeded()
        return handled
    }

    /// Freezes gameplay and presents game over for the dead player.
    func handlePlayerDeath(_ player: PlayerEntity) {
        Log.debug("GameScene: player died")
        audioManager.stopAllMusic()
        audioManager.playDeathExclusively()
        overlayFlow.presentGameOver(
            for: player,
            players: entityStore.players,
            physicsWorld: physicsWorld,
            elapsedRunTime: elapsedRunTime,
            screenSize: size,
            cameraNode: cameraSystem.cameraNode,
            stats: makeGameOverStats(for: player)
        )
    }
    
    /// Ends boss-stage systems after the active boss dies.
    func handleBossDeath() {
        directorSystem.recordBossDeath()
        cameraSystem.unlockCamera()
    }

    private func spawnSmashEffect(at position: CGPoint) {
        audioManager.play(.bossAttack)
        
        let atlas = SKTextureAtlas(named: "boss_smash")
        let frames = (0..<6).compactMap { index -> SKTexture? in
            let frameName = "boss_smash_\(String(format: "%03d", index))"
            let texture = atlas.textureNamed(frameName)
            texture.filteringMode = .nearest
            return texture
        }
        
        guard !frames.isEmpty else {
            Log.warning("GameScene: No frames loaded for boss_smash animation")
            return
        }
        
        let smashNode = SKSpriteNode(texture: frames[0])
        smashNode.position = position
        smashNode.size = CGSize(width: 140, height: 140)
        smashNode.zPosition = 1.0
        floorLayer.addChild(smashNode)

        let animate = SKAction.animate(with: frames, timePerFrame: 0.08)
        let fadeOut = SKAction.fadeOut(withDuration: 0.25)
        let remove = SKAction.removeFromParent()

        smashNode.run(SKAction.sequence([animate, fadeOut, remove]))
        cameraSystem.shakeCamera(duration: 0.25, amplitude: 8.0)
    }

    /// Applies boss melee damage to the nearest player when that player is inside range.
    func dealMeleeDamageToNearestPlayer(from position: CGPoint, damage: Int, range: CGFloat) {
        spawnSmashEffect(at: position)

        guard let player = entityStore.players.min(by: {
            toroidalDistance(from: position, to: $0.position, mapSize: GameConfig.mapSize) <
            toroidalDistance(from: position, to: $1.position, mapSize: GameConfig.mapSize)
        }) else { return }

        let dist = toroidalDistance(from: position, to: player.position, mapSize: GameConfig.mapSize)
        guard dist <= range else { return }

        player.takeDamage(damage)
        AudioManager.shared.play(.hit)
    }

    /// Delegates budget-exempt boss minion spawning to `SpawnSystem`.
    func spawnBossMinions(count: Int, around position: CGPoint) {
        spawnSystem.spawnBossMinions(count: count, around: position)
    }
    
    /// Spawns an enemy projectile from the pooled enemy projectile set.
    func spawnEnemyProjectile(
        at position: CGPoint,
        direction: CGVector,
        damage: Int,
        textureName: String = "projectile_enemy_grumble",
        speed: CGFloat? = nil,
        lifespan: TimeInterval = GameConfig.projectileLifeSpan
    ) {
        guard let projectile = enemyProjectilePool.dequeue() else { return }
        
        let magnitude = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        guard magnitude > 0 else { return }
        
        let normalisedDirection = CGVector(dx: direction.dx / magnitude, dy: direction.dy / magnitude)
        let actualSpeed = speed ?? GameConfig.projectileSpeed
        let velocity = CGVector(
            dx: normalisedDirection.dx * actualSpeed,
            dy: normalisedDirection.dy * actualSpeed
        )

        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        projectile.texture = texture

        projectile.activate(at: position, velocity: velocity, damage: damage, lifespan: lifespan)
        addChild(projectile)
    }

    private func makeGameOverStats(for player: PlayerEntity) -> GameOverStats {
        let items = (player.equippedWeapons + player.equippedPowerUps).map { skill in
            GameOverStats.Item(
                name: skill.name,
                level: player.skillState.level(of: skill.id, type: skill.type),
                iconName: skill.iconName
            )
        }

        return GameOverStats(
            playerLevel: player.level.currentLevel,
            maxHealth: player.health.maximum,
            attackSpeedMultiplier: player.attackSpeedMultiplier,
            movementSpeed: player.currentSpeed,
            items: items
        )
    }

    private func updateControlGuideDismissal() {
        guard entityStore.players.contains(where: {
            inputSystem.hasControlGuideDismissInput(for: $0.controllerIndex ?? 0)
        }) else { return }
        hud.dismissControlGuide()
    }

    private func resetGameplayClockIfNeeded() {
        if overlayFlow.consumeNeedsGameplayClockReset() {
            lastUpdateTime = 0
        }
    }

    private func updateBossStageAudio() {
        let isBossStageActive = directorSystem.isBossStageActive
        guard isBossStageActive != wasBossStageActive else { return }

        if isBossStageActive {
            cameraSystem.lockCamera(at: cameraSystem.cameraNode.position)
            audioManager.playMusic(.boss)
        } else {
            cameraSystem.unlockCamera()
            audioManager.playBackgroundMusic()
        }

        wasBossStageActive = isBossStageActive
    }

    private func updateAimCursorMode() {
        overlayFlow.updateAimCursorMode(players: entityStore.players)
    }
}
