import SpriteKit
import MetalKit

private let visibilityCheckMargin: CGFloat = 100
private let referenceSpriteHeight: CGFloat = 48
private let lightningStrikeRadiusFactor: CGFloat = 0.8
private let lightningBoltHeightFactor: CGFloat = 1.5
private let lightningBoltOffsetFactor: CGFloat = 0.15

final class GameScene: SKScene {
    private struct ActiveMistCloud {
        weak var owner: PlayerEntity?
        let node: SKNode
        var position: CGPoint
        var radius: CGFloat
        var remainingDuration: TimeInterval
        var tickAccumulator: TimeInterval
    }

    private struct ActiveOrb {
        let sprite: SKSpriteNode
        var angle: CGFloat
    }

    private(set) var cameraSystem: CameraSystem!
    var inputSystem: InputSystem { InputSystem.shared }
    private(set) var directorSystem: DirectorSystem!
    private var spawnSystem: SpawnSystem!
    private var collisionSystem: CollisionSystem!
    private var skillSystem: SkillSystem!
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
    private weak var skillSelectionPlayer: PlayerEntity?
    private var wasSkillConfirmPressed = false
    private var lightningCooldowns: [ObjectIdentifier: TimeInterval] = [:]
    private var activeMistClouds: [ObjectIdentifier: [ActiveMistCloud]] = [:]
    private var mistSpawnCooldowns: [ObjectIdentifier: TimeInterval] = [:]
    private var orbitOrbs: [ObjectIdentifier: [ActiveOrb]] = [:]
    private var orbitHitCooldowns: [ObjectIdentifier: [Int: [ObjectIdentifier: TimeInterval]]] = [:]
    private let lightningAtlas = SKTextureAtlas(named: "LightningEffect")
    private let mistAtlas = SKTextureAtlas(named: "MistEffect")
    private let orbitAtlas = SKTextureAtlas(named: "OrbitingSpell")
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
    var onAimModeChanged: ((InputSystem.AimMode) -> Void)?
    var onGameOverPresented: (() -> Void)?

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

        cameraSystem.isLocked = directorSystem.isBossStageActive
        elapsedRunTime += deltaTime

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

        updateLightningSkills(deltaTime: deltaTime)
        updateMistSkills(deltaTime: deltaTime)
        updateOrbitingSpells(deltaTime: deltaTime)

        for attack in playerAttacks { attack.update(deltaTime: deltaTime) }
        playerProjectilePool.updateAll(deltaTime: deltaTime)

        for enemy in enemies { enemy.update(deltaTime: deltaTime) }
        enemyProjectilePool.updateAll(deltaTime: deltaTime)

        enemyAI.update(enemies: enemies, players: players)

        let activeBudget = enemies.reduce(0) { $0 + $1.budgetWeight }
        directorSystem.update(deltaTime: deltaTime, activeBudgetUsed: activeBudget)
        updateBossStageAudio()

        spawnSystem.update(deltaTime: deltaTime, activeBudgetUsed: activeBudget)
        hud.updateViewport(size)
        updateControlGuideDismissal()
        updateAimCursorMode()
        hud.update(elapsedTime: elapsedRunTime)
        cameraSystem.update(deltaTime: deltaTime)
        refreshWorldRenderers()
        updateYSort()
    }

    private func updateYSort() {
        for node in children where node !== floorLayer && node !== propsLayer {
            guard let camera = self.camera, node !== camera else { continue }
            guard let sprite = node as? SKSpriteNode else {
                node.zPosition = Layer.world - node.position.y * 0.001
                continue
            }
            let footY = sprite.position.y - sprite.size.height / 2
            node.zPosition = Layer.world - footY * 0.001
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
        enemyAI = EnemyAI()
        spawnSystem = SpawnSystem(entityLayer: self, cameraSystem: cameraSystem, directorSystem: directorSystem)
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
            textureNames: ["GrumbleBullet"],
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

    func updateViewport(_ size: CGSize) {
        cameraSystem.updateViewport(size)
        floorRenderer.updateViewport(size)
        refreshWorldRenderers()
        hud?.updateViewport(size)
        skillCardOverlay?.updateViewport(size)
        gameOverOverlay?.updateViewport(size)
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
        collisionSystem.register(player: player, directorSystem: directorSystem)
        setupHUD(for: player)
    }

    private func setupHUD(for player: PlayerEntity) {
        let hud = HUD(player: player, screenSize: size)
        cameraSystem.cameraNode.addChild(hud)
        self.hud = hud
    }

    private func updateLightningSkills(deltaTime: TimeInterval) {
        for player in players {
            let playerID = ObjectIdentifier(player)
            guard player.lightningCooldown > 0, player.lightningStrikeCount > 0 else {
                lightningCooldowns.removeValue(forKey: playerID)
                continue
            }

            let updatedCooldown = max(0, (lightningCooldowns[playerID] ?? 0) - deltaTime)
            lightningCooldowns[playerID] = updatedCooldown

            guard updatedCooldown == 0 else { continue }
            guard castLightning(for: player) else { continue }
            lightningCooldowns[playerID] = player.lightningCooldown
        }
    }

    private func castLightning(for player: PlayerEntity) -> Bool {
        let inset = referenceSpriteHeight * lightningBoltHeightFactor + 8
        let aliveEnemies = enemies.filter { $0.parent != nil && isInsideCamera($0.position, inset: inset) }
        guard !aliveEnemies.isEmpty else { return false }

        let strikeCount = max(1, player.lightningStrikeCount)
        var pool = aliveEnemies

        audioManager.play(.lightning)

        for _ in 0..<strikeCount {
            let target: EnemyEntity
            if !pool.isEmpty {
                guard let picked = pool.randomElement() else { break }
                pool.removeAll { $0 === picked }
                target = picked
            } else {
                guard let picked = aliveEnemies.randomElement() else { break }
                target = picked
            }
            strikeLightning(on: target, damage: SkillConfig.lightningBaseDamage)
        }

        return true
    }

    private func strikeLightning(on enemy: EnemyEntity, damage: Int) {
        let position = enemy.position
        let strike = makeLightningStrikeNode(at: position, radius: referenceSpriteHeight * lightningStrikeRadiusFactor)
        addChild(strike)
        particleAssets.emit(.lightningImpact, at: position, in: self)
        enemy.health.takeDamage(damage)
        if enemy.health.isDead { enemy.die() }
    }

    private func updateMistSkills(deltaTime: TimeInterval) {
        for player in players {
            let playerID = ObjectIdentifier(player)
            guard player.mistCloudCount > 0, player.mistCooldown > 0 else {
                removeAllMistClouds(for: playerID)
                mistSpawnCooldowns.removeValue(forKey: playerID)
                continue
            }

            tickMistClouds(for: playerID, deltaTime: deltaTime)

            let cooldown = max(0, (mistSpawnCooldowns[playerID] ?? 0) - deltaTime)
            mistSpawnCooldowns[playerID] = cooldown

            let activeCount = activeMistClouds[playerID]?.count ?? 0
            if activeCount < player.mistCloudCount, cooldown == 0 {
                spawnMistCloud(for: player)
                mistSpawnCooldowns[playerID] = player.mistCooldown
            }
        }
    }

    private func tickMistClouds(for playerID: ObjectIdentifier, deltaTime: TimeInterval) {
        guard var clouds = activeMistClouds[playerID] else { return }

        for index in clouds.indices {
            clouds[index].remainingDuration -= deltaTime
            clouds[index].tickAccumulator += deltaTime
            while clouds[index].tickAccumulator >= SkillConfig.mistTickInterval {
                clouds[index].tickAccumulator -= SkillConfig.mistTickInterval
                applyMistDamage(from: clouds[index])
            }
        }

        let expired = clouds.filter { $0.remainingDuration <= 0 }
        expired.forEach { $0.node.removeFromParent() }
        clouds.removeAll { $0.remainingDuration <= 0 }

        if clouds.isEmpty {
            activeMistClouds.removeValue(forKey: playerID)
        } else {
            activeMistClouds[playerID] = clouds
        }
    }

    private func spawnMistCloud(for player: PlayerEntity) {
        let playerID = ObjectIdentifier(player)
        let position = randomPointInCameraView()
        let cloudNode = makeMistCloudNode(radius: SkillConfig.mistRadius)
        audioManager.play(.mistExplosion)
        cloudNode.position = position
        cloudNode.zPosition = Layer.world
        addChild(cloudNode)

        let cloud = ActiveMistCloud(
            owner: player,
            node: cloudNode,
            position: position,
            radius: SkillConfig.mistRadius,
            remainingDuration: SkillConfig.mistBaseDuration,
            tickAccumulator: 0
        )

        activeMistClouds[playerID, default: []].append(cloud)
        audioManager.play(.mistExplosion)
        particleAssets.emit(.mistExplosion, at: position, in: self)
    }

    private func applyMistDamage(from cloud: ActiveMistCloud) {
        let damage = SkillConfig.mistBaseDamage
        for enemy in enemies where enemy.parent != nil {
            let distance = toroidalDistance(from: cloud.position, to: enemy.position, mapSize: GameConfig.mapSize)
            guard distance <= cloud.radius else { continue }
            enemy.health.takeDamage(damage)
            if enemy.health.isDead { enemy.die() }
        }
    }

    private func removeAllMistClouds(for playerID: ObjectIdentifier) {
        guard let clouds = activeMistClouds.removeValue(forKey: playerID) else { return }
        clouds.forEach { $0.node.removeFromParent() }
    }

    private func updateOrbitingSpells(deltaTime: TimeInterval) {
        for player in players {
            let playerID = ObjectIdentifier(player)
            let desired = player.orbitCount

            guard desired > 0 else {
                removeAllOrbs(for: playerID)
                orbitHitCooldowns.removeValue(forKey: playerID)
                continue
            }

            reconcileOrbCount(for: playerID, desired: desired)
            advanceOrbAngles(for: playerID, deltaTime: deltaTime)
            updateOrbPositions(for: player)
            decayOrbitCooldowns(for: playerID, deltaTime: deltaTime)
            applyOrbCollisions(for: player)
        }
    }

    private func reconcileOrbCount(for playerID: ObjectIdentifier, desired: Int) {
        var orbs = orbitOrbs[playerID] ?? []
        if orbs.count == desired {
            orbitOrbs[playerID] = orbs
            return
        }

        let existingAngles = orbs.map(\.angle)
        let phase = existingAngles.first ?? 0

        if orbs.count > desired {
            for orb in orbs.suffix(orbs.count - desired) {
                orb.sprite.removeFromParent()
            }
            orbs.removeLast(orbs.count - desired)
        }

        let texture = orbitAtlas.textureNamed("orbiting_knife_000")
        texture.filteringMode = .nearest
        while orbs.count < desired {
            let sprite = SKSpriteNode(texture: texture, size: SkillConfig.orbitKnifeSize)
            sprite.zPosition = Layer.world
            addChild(sprite)
            orbs.append(ActiveOrb(sprite: sprite, angle: phase))
        }

        let angles = OrbitingSpellLayout.reconciledAngles(existing: existingAngles, desiredCount: desired)
        for index in orbs.indices {
            orbs[index].angle = angles[index]
        }
        orbitOrbs[playerID] = orbs
    }

    private func advanceOrbAngles(for playerID: ObjectIdentifier, deltaTime: TimeInterval) {
        guard var orbs = orbitOrbs[playerID] else { return }
        let delta = SkillConfig.orbitRotationSpeed * CGFloat(deltaTime)
        for index in orbs.indices {
            orbs[index].angle += delta
        }
        orbitOrbs[playerID] = orbs
    }

    private func updateOrbPositions(for player: PlayerEntity) {
        let playerID = ObjectIdentifier(player)
        guard let orbs = orbitOrbs[playerID] else { return }
        for orb in orbs {
            orb.sprite.position = CGPoint(
                x: player.position.x + cos(orb.angle) * SkillConfig.orbitRadius,
                y: player.position.y + sin(orb.angle) * SkillConfig.orbitRadius
            )
            orb.sprite.zRotation = OrbitingSpellLayout.spriteRotation(forOrbitAngle: orb.angle)
        }
    }

    private func decayOrbitCooldowns(for playerID: ObjectIdentifier, deltaTime: TimeInterval) {
        guard var perOrb = orbitHitCooldowns[playerID] else { return }
        let aliveEnemyIDs = Set(enemies.compactMap { $0.parent != nil ? ObjectIdentifier($0) : nil })

        for (orbIndex, enemyMap) in perOrb {
            var updated = enemyMap
            for (enemyID, remaining) in updated {
                if !aliveEnemyIDs.contains(enemyID) {
                    updated.removeValue(forKey: enemyID)
                    continue
                }
                let next = remaining - deltaTime
                if next <= 0 {
                    updated.removeValue(forKey: enemyID)
                } else {
                    updated[enemyID] = next
                }
            }
            if updated.isEmpty {
                perOrb.removeValue(forKey: orbIndex)
            } else {
                perOrb[orbIndex] = updated
            }
        }
        orbitHitCooldowns[playerID] = perOrb.isEmpty ? nil : perOrb
    }

    private func applyOrbCollisions(for player: PlayerEntity) {
        let playerID = ObjectIdentifier(player)
        guard let orbs = orbitOrbs[playerID] else { return }

        let orbHitRadius = SkillConfig.orbitHitRadius

        for (orbIndex, orb) in orbs.enumerated() {
            let orbPos = orb.sprite.position
            for enemy in enemies where enemy.parent != nil {
                let enemyID = ObjectIdentifier(enemy)
                let cooldown = orbitHitCooldowns[playerID]?[orbIndex]?[enemyID]
                guard cooldown == nil else { continue }

                let enemyRadius = enemy.size.width * 0.5
                let distance = toroidalDistance(from: orbPos, to: enemy.position, mapSize: GameConfig.mapSize)
                guard distance <= enemyRadius + orbHitRadius else { continue }

                enemy.health.takeDamage(SkillConfig.orbitDamage)
                particleAssets.emit(.orbitingSpellHit, at: enemy.position, in: self)
                if enemy.health.isDead { enemy.die() }

                var perOrb = orbitHitCooldowns[playerID] ?? [:]
                var perEnemy = perOrb[orbIndex] ?? [:]
                perEnemy[enemyID] = SkillConfig.orbitCooldownPerEnemy
                perOrb[orbIndex] = perEnemy
                orbitHitCooldowns[playerID] = perOrb
            }
        }
    }

    private func removeAllOrbs(for playerID: ObjectIdentifier) {
        guard let orbs = orbitOrbs.removeValue(forKey: playerID) else { return }
        orbs.forEach { $0.sprite.removeFromParent() }
    }

    private func makeMistCloudNode(radius: CGFloat) -> SKNode {
        let node = SKNode()
        let sprite = SKSpriteNode(texture: mistTexture(named: "mist_000"))
        sprite.zPosition = 0
        sprite.alpha = SkillConfig.mistCloudAlpha
        sprite.size = CGSize(width: radius * 2, height: radius * 2)
        node.addChild(sprite)

        let frames = (0..<3).map { mistTexture(named: "mist_\(String(format: "%03d", $0))") }
        let animate = SKAction.repeatForever(.animate(with: frames, timePerFrame: SkillConfig.mistCloudAnimFrameTime))
        sprite.run(animate)

        return node
    }

    private func mistTexture(named name: String) -> SKTexture {
        let texture = mistAtlas.textureNamed(name)
        texture.filteringMode = .nearest
        return texture
    }

    private func makeLightningStrikeNode(at position: CGPoint, radius: CGFloat) -> SKNode {
        let strikeNode = SKNode()
        strikeNode.position = position
        strikeNode.zPosition = Layer.world

        let boltHeight = max(radius * 1.6, referenceSpriteHeight * lightningBoltHeightFactor)
        let bolt = SKSpriteNode(texture: lightningTexture(named: "lightning_002"))
        bolt.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        bolt.position = CGPoint(x: 0, y: -referenceSpriteHeight * lightningBoltOffsetFactor)
        bolt.size = CGSize(width: max(SkillConfig.lightningBoltMinWidth, radius * SkillConfig.lightningBoltWidthFactor), height: boltHeight)
        bolt.alpha = SkillConfig.lightningBoltAlpha
        strikeNode.addChild(bolt)

        let frames = [
            lightningTexture(named: "lightning_001"),
            lightningTexture(named: "lightning_002"),
            lightningTexture(named: "lightning_003"),
            lightningTexture(named: "lightning_002")
        ]
        bolt.run(.animate(with: frames, timePerFrame: SkillConfig.lightningBoltAnimFrameTime))

        let impact = SKShapeNode(circleOfRadius: max(SkillConfig.lightningImpactMinRadius, radius * SkillConfig.lightningImpactRadiusFactor))
        impact.fillColor = SKColor(red: 0.72, green: 0.96, blue: 1.0, alpha: 0.9)
        impact.strokeColor = .white
        impact.lineWidth = 1.5
        impact.position = bolt.position
        strikeNode.addChild(impact)

        impact.run(.sequence([
            .group([
                .scale(to: SkillConfig.lightningImpactScale, duration: SkillConfig.lightningImpactDuration),
                .fadeOut(withDuration: SkillConfig.lightningImpactDuration)
            ]),
            .removeFromParent()
        ]))

        strikeNode.run(.sequence([
            .wait(forDuration: SkillConfig.lightningStrikeLifetime),
            .removeFromParent()
        ]))
        return strikeNode
    }

    private func lightningTexture(named name: String) -> SKTexture {
        let baseTexture = lightningAtlas.textureNamed(name)
        baseTexture.filteringMode = .nearest

        let visibleRect = SkillConfig.lightningTextureCropRect
        let texture = SKTexture(rect: visibleRect, in: baseTexture)
        texture.filteringMode = .nearest
        return texture
    }

    private func randomPointInCameraView() -> CGPoint {
        let rect = cameraSystem.visibleRect
        return CGPoint(
            x: CGFloat.random(in: rect.minX...rect.maxX),
            y: CGFloat.random(in: rect.minY...rect.maxY)
        )
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
    private func isInsideCamera(_ position: CGPoint, inset: CGFloat) -> Bool {
        let cameraPos = cameraSystem.cameraNode.position
        let viewport = GameConfig.cameraViewportSize
        let rect = CGRect(
            x: cameraPos.x - viewport.width / 2 + inset,
            y: cameraPos.y - viewport.height / 2 + inset,
            width: max(0, viewport.width - inset * 2),
            height: max(0, viewport.height - inset * 2)
        )
        for dx: CGFloat in [-GameConfig.mapSize.width, 0, GameConfig.mapSize.width] {
            for dy: CGFloat in [-GameConfig.mapSize.height, 0, GameConfig.mapSize.height] {
                if rect.contains(CGPoint(x: position.x + dx, y: position.y + dy)) { return true }
            }
        }
        return false
    }

    func canPlayerShoot(from playerPosition: CGPoint) -> Bool {
        let halfViewport = CGSize(
            width: cameraSystem.worldViewportSize.width / 2,
            height: cameraSystem.worldViewportSize.height / 2
        )
        let shootRadius = sqrt(halfViewport.width * halfViewport.width + halfViewport.height * halfViewport.height) * 0.6

        return enemies.contains { enemy in
            enemy.parent != nil
                && toroidalDistance(from: playerPosition, to: enemy.position, mapSize: GameConfig.mapSize) <= shootRadius
        }
    }

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
    
    func spawnEssenceOrb(at position: CGPoint) {
        spawnSystem.spawnEssenceOrb(at: position)
    }

    func removeOrb(_ orb: EssenceOrbComponent) {
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
            gameOverOverlay?.replay()
            return true
        }
        return skillCardOverlay != nil
    }

    func handlePlayerDeath(_ player: PlayerEntity) {
        Log.debug("GameScene: player died")
        audioManager.stopBackgroundMusic()
        audioManager.playDeathExclusively()
        presentGameOverOverlay(for: player)
    }
    
    func handleBossDeath() {
        directorSystem.recordBossDeath()
        cameraSystem.isLocked = false
    }
    
    func spawnBossMinions(count: Int, around position: CGPoint) {
        spawnSystem.spawnBossMinions(count: count, around: position)
    }
    
    func spawnEnemyProjectile(
        at position: CGPoint,
        direction: CGVector,
        damage: Int,
        textureName: String = "GrumbleBullet",
        lifespan: TimeInterval = GameConfig.projectileLifeSpan
    ) {
        guard let projectile = enemyProjectilePool.dequeue() else { return }
        
        let magnitude = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        guard magnitude > 0 else { return }
        
        let normalisedDirection = CGVector(dx: direction.dx / magnitude, dy: direction.dy / magnitude)
        let velocity = CGVector(
            dx: normalisedDirection.dx * GameConfig.projectileSpeed,
            dy: normalisedDirection.dy * GameConfig.projectileSpeed
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

        let overlay = SkillCardOverlay(skills: skills, screenSize: size) { [weak self, weak player] skill in
            guard let self, let player else { return }
            self.completeSkillSelection(skill, for: player)
        }
        cameraSystem.cameraNode.addChild(overlay)
        skillCardOverlay = overlay
        wasSkillConfirmPressed = inputSystem.confirmPressed(for: player.controllerIndex ?? 0)
        lastReportedAimMode = .manual
        onAimModeChanged?(.manual)
    }

    private func presentGameOverOverlay(for player: PlayerEntity) {
        guard gameOverOverlay == nil else { return }
        skillCardOverlay?.removeFromParent()
        skillCardOverlay = nil
        skillSelectionPlayer = nil
        players.forEach { $0.hideAimGuide() }
        physicsWorld.speed = 0
        onGameOverPresented?()

        let overlay = GameOverOverlay(
            survivedTime: elapsedRunTime,
            screenSize: size,
            stats: makeGameOverStats(for: player)
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
        lastReportedAimMode = nil  // force re-evaluate on next frame
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
            audioManager.playMusic(.boss)
        } else {
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

    private func enforceBossCameraLeash(for player: PlayerEntity) {
        guard directorSystem.isBossStageActive else { return }

        let centre = cameraSystem.cameraNode.position
        let halfWidth = cameraSystem.worldViewportSize.width * GameConfig.cameraLeashFactor / 2
        let halfHeight = cameraSystem.worldViewportSize.height * GameConfig.cameraLeashFactor / 2
        player.position.x = min(max(player.position.x, centre.x - halfWidth), centre.x + halfWidth)
        player.position.y = min(max(player.position.y, centre.y - halfHeight), centre.y + halfHeight)
    }
}
