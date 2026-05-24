import SpriteKit
import MetalKit

private let visibilityCheckMargin: CGFloat = 100
private let levelUpOverlayDelay: TimeInterval = 0.35

/// Main gameplay scene that coordinates systems, entities, overlays, audio, and the update loop.
final class GameScene: SKScene {
    private(set) var cameraSystem: CameraSystem!
    /// Shared input router used by entities and overlays.
    var inputSystem: InputSystem { InputSystem.shared }
    private(set) var directorSystem: DirectorSystem!
    private var spawnSystem: SpawnSystem!
    private var collisionSystem: CollisionSystem!
    private var skillSystem: SkillSystem!
    private var skillRuntimeSystem: SkillRuntimeSystem!
    private var floorRenderer: FloorTileRenderer!
    private var environmentPropSystem: EnvironmentPropSystem!
    private var enemyAI: EnemyAI!
    private var playerProjectilePool: ProjectilePool!
    private var enemyProjectilePool: ProjectilePool!
    private var hud: HUD!
    private let audioManager = AudioManager.shared
    private let particleAssets = ParticleAssets.shared
    private var skillCardOverlay: SkillCardOverlay?
    private var gameOverOverlay: GameOverOverlay?
    private var startCountdownOverlay: StartCountdownOverlay?
    private weak var skillSelectionPlayer: PlayerEntity?
    private weak var pendingSkillSelectionPlayer: PlayerEntity?
    private var pendingSkillSelectionDelay: TimeInterval = 0
    private var wasSkillConfirmPressed = false
    /// Called when the game-over overlay requests a fresh run.
    var onReplayRequested: (() -> Void)?
    
    private var players: [PlayerEntity] = []
    private var enemies: [EnemyEntity] = []
    private var playerAttacks: [PlayerAttack] = []
    
    private let floorLayer = SKNode()
    private let propsLayer = SKNode()
    
    private var elapsedRunTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var lastReportedAimMode: InputSystem.AimMode?
    private var wasBossStageActive = false
    /// Called when cursor presentation should switch between manual and hidden aim modes.
    var onAimModeChanged: ((InputSystem.AimMode) -> Void)?
    /// Called once the game-over overlay takes control of input.
    var onGameOverPresented: (() -> Void)?

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

        if skillCardOverlay != nil {
            updateSkillSelectionInput()
            return
        }

        if gameOverOverlay != nil {
            updateGameOverInput()
            return
        }

        if let startCountdownOverlay {
            hud.updateViewport(size)
            hud.update(elapsedTime: elapsedRunTime)
            refreshWorldRenderers()
            updateYSort()

            if startCountdownOverlay.update(deltaTime: deltaTime) {
                self.startCountdownOverlay = nil
                lastUpdateTime = 0
            }
            return
        }

        elapsedRunTime += deltaTime

        let visibleEnemies = enemies.filter { isVisible($0.position) }
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

        let fraction = players.isEmpty ? 1.0 : players.map {
            Double($0.health.current) / Double($0.health.maximum)
        }.reduce(0, +) / Double(players.count)
        directorSystem.updatePlayerHealthFraction(fraction)
        
        let activeBudget = enemies.reduce(0) { $0 + $1.budgetWeight }
        directorSystem.update(deltaTime: deltaTime, activeBudgetUsed: activeBudget)
        updateBossStageAudio()

        spawnSystem.update(deltaTime: deltaTime, activeBudgetUsed: activeBudget)
        hud.updateViewport(size)
        updateControlGuideDismissal()
        updateAimCursorMode()
        hud.update(elapsedTime: elapsedRunTime)
        updatePendingSkillSelection(deltaTime: deltaTime)
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
        skillSystem = SkillSystem()
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
        skillCardOverlay?.updateViewport(size)
        gameOverOverlay?.updateViewport(size)
        startCountdownOverlay?.updateViewport(size)
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
        players.append(player)
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
        let overlay = StartCountdownOverlay(screenSize: size)
        cameraSystem.cameraNode.addChild(overlay)
        startCountdownOverlay = overlay
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
        let halfW = (cameraSystem.viewportSize.width / (GameConfig.cameraZoom * 2)) * 0.95
        let halfH = (cameraSystem.viewportSize.height / (GameConfig.cameraZoom * 2)) * 0.95

        return enemies.contains { enemy in
            guard enemy.parent != nil else { return false }
            let camOffset = toroidalOffset(from: cameraSystem.cameraNode.position, to: enemy.position, mapSize: GameConfig.mapSize)
            return abs(camOffset.dx) <= halfW && abs(camOffset.dy) <= halfH
        }
    }

    /// Finds the nearest player within an orb's magnet radius.
    func magnetTargetForOrb(at orbPosition: CGPoint, radius: CGFloat) -> CGPoint? {
        let radiusSquared = radius * radius

        return players
            .filter { $0.parent != nil }
            .map { $0.position }
            .filter { position in
                let dx = position.x - orbPosition.x
                let dy = position.y - orbPosition.y
                return (dx * dx + dy * dy) <= radiusSquared
            }
            .min(by: { lhs, rhs in
                let ldx = lhs.x - orbPosition.x
                let ldy = lhs.y - orbPosition.y
                let rdx = rhs.x - orbPosition.x
                let rdy = rhs.y - orbPosition.y
                return (ldx * ldx + ldy * ldy) < (rdx * rdx + rdy * rdy)
            })
    }

    private func isVisible(_ position: CGPoint) -> Bool {
        let cameraPos = cameraSystem.cameraNode.position
        let viewport = GameConfig.cameraViewportSize
        let margin: CGFloat = visibilityCheckMargin
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

    /// Returns the closest player position to a world point using toroidal distance.
    func nearestPlayerPosition(to position: CGPoint) -> CGPoint {
        players.min {
            toroidalDistance(from: position, to: $0.position, mapSize: GameConfig.mapSize) <
            toroidalDistance(from: position, to: $1.position, mapSize: GameConfig.mapSize)
        }?.position ?? .zero
    }

    /// Starts tracking an enemy for updates, targeting, budget, and game-over cleanup.
    func register(enemy: EnemyEntity) {
        enemies.append(enemy)
    }

    /// Stops tracking an enemy after death or removal.
    func deregister(enemy: EnemyEntity) {
        enemies.removeAll { $0 === enemy }
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
        Log.debug("GameScene: player leveled up to \(player.level.currentLevel)")
        guard skillCardOverlay == nil, pendingSkillSelectionPlayer == nil else { return }
        audioManager.play(.levelUp)
        hud.showFullEssenceBriefly(duration: levelUpOverlayDelay)
        pendingSkillSelectionPlayer = player
        pendingSkillSelectionDelay = levelUpOverlayDelay
    }

    /// Routes a view-space mouse-down event to active camera-space overlays.
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

    /// Routes a view-space mouse-move event to active camera-space overlays.
    @discardableResult
    func handleMouseMoved(atViewPosition viewPosition: CGPoint, viewSize: CGSize) -> Bool {
        guard viewSize.width > 0, viewSize.height > 0 else { return true }

        let overlayPoint = CGPoint(
            x: (viewPosition.x / viewSize.width) * size.width - size.width / 2,
            y: (viewPosition.y / viewSize.height) * size.height - size.height / 2
        )

        if let gameOverOverlay {
            return gameOverOverlay.handleMouseMoved(at: overlayPoint)
        }

        guard let skillCardOverlay else { return false }
        return skillCardOverlay.handleMouseMoved(at: overlayPoint)
    }

    /// Routes key-down events to active overlays before gameplay input sees them.
    @discardableResult
    func handleKeyDown(_ event: NSEvent) -> Bool {
        if gameOverOverlay != nil {
            return true
        }
        guard let skillCardOverlay else { return false }

        let shortcutModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(shortcutModifiers).isEmpty else { return true }

        switch event.keyCode {
        case 0:
            skillCardOverlay.moveSelection(.left)
        case 2:
            skillCardOverlay.moveSelection(.right)
        case 36, 49:
            skillCardOverlay.selectHighlightedCard()
        default:
            break
        }
        return true
    }

    /// Freezes gameplay and presents game over for the dead player.
    func handlePlayerDeath(_ player: PlayerEntity) {
        Log.debug("GameScene: player died")
        pendingSkillSelectionPlayer = nil
        pendingSkillSelectionDelay = 0
        audioManager.stopAllMusic()
        audioManager.playDeathExclusively()
        presentGameOverOverlay(for: player)
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

        guard let player = players.min(by: {
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

    private func presentSkillCardOverlay() {
        guard let player = skillSelectionPlayer else { return }
        player.hideAimGuide()

        let skills = skillSystem.draw(for: player.skillState)
        guard !skills.isEmpty else {
            skillSelectionPlayer = nil
            return
        }

        let skillLevels = Dictionary(uniqueKeysWithValues: skills.map { skill in
            (skill.id, player.skillState.level(of: skill.id, type: skill.type))
        })

        let overlay = SkillCardOverlay(skills: skills, skillLevels: skillLevels, screenSize: size) { [weak self, weak player] skill in
            guard let self, let player else { return }
            self.completeSkillSelection(skill, for: player)
        }
        cameraSystem.cameraNode.addChild(overlay)
        skillCardOverlay = overlay
        wasSkillConfirmPressed = inputSystem.confirmPressed(for: player.controllerIndex ?? 0)
        lastReportedAimMode = .manual
        onAimModeChanged?(.manual)
    }

    private func updatePendingSkillSelection(deltaTime: TimeInterval) {
        guard skillCardOverlay == nil, gameOverOverlay == nil, let player = pendingSkillSelectionPlayer else { return }
        pendingSkillSelectionDelay = max(0, pendingSkillSelectionDelay - deltaTime)
        guard pendingSkillSelectionDelay == 0 else { return }

        pendingSkillSelectionPlayer = nil
        skillSelectionPlayer = player
        presentSkillCardOverlay()
    }

    private func presentGameOverOverlay(for player: PlayerEntity) {
        guard gameOverOverlay == nil else { return }
        skillCardOverlay?.removeFromParent()
        skillCardOverlay = nil
        skillSelectionPlayer = nil
        pendingSkillSelectionPlayer = nil
        pendingSkillSelectionDelay = 0
        players.forEach { $0.hideAimGuide() }
        physicsWorld.speed = 0
        onGameOverPresented?()

        let overlay = GameOverOverlay(
            survivedTime: elapsedRunTime,
            screenSize: size,
            stats: makeGameOverStats(for: player),
            usesControllerPrompt: inputSystem.hasConnectedController
        ) { [weak self] in
            self?.onReplayRequested?()
        }
        cameraSystem.cameraNode.addChild(overlay)
        gameOverOverlay = overlay
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

    private func completeSkillSelection(_ skill: Skill, for player: PlayerEntity) {
        player.applySkill(skill)
        audioManager.play(.pickPower)
        skillCardOverlay?.removeFromParent()
        skillCardOverlay = nil
        skillSelectionPlayer = nil
        wasSkillConfirmPressed = false
        lastUpdateTime = 0
        // Force cursor mode re-evaluation on the next gameplay frame.
        lastReportedAimMode = nil
    }

    private func updateSkillSelectionInput() {
        guard let player = skillSelectionPlayer else { return }
        if let direction = inputSystem.consumeMenuDirection(for: player.controllerIndex ?? 0) {
            skillCardOverlay?.moveSelection(direction)
        }
        if inputSystem.consumeMenuConfirm(for: player.controllerIndex ?? 0) {
            skillCardOverlay?.selectHighlightedCard()
            return
        }

        let isConfirmPressed = inputSystem.confirmPressed(for: player.controllerIndex ?? 0)
        if isConfirmPressed && !wasSkillConfirmPressed {
            skillCardOverlay?.selectHighlightedCard()
        }
        wasSkillConfirmPressed = isConfirmPressed
    }

    private func updateGameOverInput() {
        let playerIndex = players.first?.controllerIndex ?? 0
        if inputSystem.consumeAnyMenuButton(for: playerIndex) {
            gameOverOverlay?.replay()
        }
    }

    private func updateControlGuideDismissal() {
        guard players.contains(where: {
            inputSystem.hasControlGuideDismissInput(for: $0.controllerIndex ?? 0)
        }) else { return }
        hud.dismissControlGuide()
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
        let mode = inputSystem.aimMode(for: players.first?.controllerIndex ?? 0)
        guard mode != lastReportedAimMode else { return }
        lastReportedAimMode = mode
        onAimModeChanged?(mode)
    }
}
