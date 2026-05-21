import SpriteKit
import MetalKit

private let visibilityCheckMargin: CGFloat = 100
private let referenceSpriteHeight: CGFloat = 48
private let lightningStrikeRadiusFactor: CGFloat = 0.8
private let lightningBoltHeightFactor: CGFloat = 1.5
private let lightningBoltOffsetFactor: CGFloat = 0.15
private let wardenThornAnimationKey = "wardenThornAnimation"
private let levelUpOverlayDelay: TimeInterval = 0.35

final class GameScene: SKScene {
    private struct ActiveMistCloud {
        weak var owner: PlayerEntity?
        let node: SKNode
        var position: CGPoint
        var radius: CGFloat
        var remainingDuration: TimeInterval
        var tickAccumulator: TimeInterval
    }

    private struct ActiveThorn {
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
    private weak var pendingSkillSelectionPlayer: PlayerEntity?
    private var pendingSkillSelectionDelay: TimeInterval = 0
    private var wasSkillConfirmPressed = false
    private var lightningCooldowns: [ObjectIdentifier: TimeInterval] = [:]
    private var activeMistClouds: [ObjectIdentifier: [ActiveMistCloud]] = [:]
    private var mistSpawnCooldowns: [ObjectIdentifier: TimeInterval] = [:]
    private var wardenThorns: [ObjectIdentifier: [ActiveThorn]] = [:]
    private var wardenThornHitCooldowns: [ObjectIdentifier: [Int: [ObjectIdentifier: TimeInterval]]] = [:]
    private let lightningAtlas = SKTextureAtlas(named: "lightning_strike")
    private let mistAtlas = SKTextureAtlas(named: "poisonous_mist")
    private let wardenThornsAtlas = SKTextureAtlas(named: "warden_thorns")
    private lazy var wardenThornFrames: [SKTexture] = (0..<SkillConfig.wardenThornFrameCount).map {
        wardenThornTexture(named: "weapon_warden_thorns_\(String(format: "%03d", $0))")
    }
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

        updateLightningSkills(deltaTime: deltaTime)
        updateMistSkills(deltaTime: deltaTime)
        updateWardenThorns(deltaTime: deltaTime)

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
            let wrappedY = footY - mapH * floor((footY + mapH / 2) / mapH)
            node.zPosition = Layer.world - wrappedY / mapH
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
        enemy.takeDamage(damage)
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
            enemy.takeDamage(damage)
        }
    }

    private func removeAllMistClouds(for playerID: ObjectIdentifier) {
        guard let clouds = activeMistClouds.removeValue(forKey: playerID) else { return }
        clouds.forEach { $0.node.removeFromParent() }
    }

    private func updateWardenThorns(deltaTime: TimeInterval) {
        for player in players {
            let playerID = ObjectIdentifier(player)
            let desired = player.wardenThornCount

            guard desired > 0 else {
                removeAllThorns(for: playerID)
                wardenThornHitCooldowns.removeValue(forKey: playerID)
                continue
            }

            reconcileThornCount(for: playerID, desired: desired)
            advanceThornAngles(for: playerID, deltaTime: deltaTime)
            updateThornPositions(for: player)
            decayWardenThornCooldowns(for: playerID, deltaTime: deltaTime)
            applyThornCollisions(for: player)
        }
    }

    private func reconcileThornCount(for playerID: ObjectIdentifier, desired: Int) {
        var thorns = wardenThorns[playerID] ?? []
        if thorns.count == desired {
            wardenThorns[playerID] = thorns
            return
        }

        let existingAngles = thorns.map(\.angle)
        let phase = existingAngles.first ?? 0

        if thorns.count > desired {
            for thorn in thorns.suffix(thorns.count - desired) {
                thorn.sprite.removeFromParent()
            }
            thorns.removeLast(thorns.count - desired)
        }

        while thorns.count < desired {
            let sprite = SKSpriteNode(texture: wardenThornFrames.first, size: SkillConfig.wardenThornSize)
            sprite.zPosition = Layer.world
            animateWardenThorn(sprite)
            addChild(sprite)
            thorns.append(ActiveThorn(sprite: sprite, angle: phase))
        }

        let angles = WardenThornsLayout.reconciledAngles(existing: existingAngles, desiredCount: desired)
        for index in thorns.indices {
            thorns[index].angle = angles[index]
        }
        wardenThorns[playerID] = thorns
    }

    private func advanceThornAngles(for playerID: ObjectIdentifier, deltaTime: TimeInterval) {
        guard var thorns = wardenThorns[playerID] else { return }
        let delta = SkillConfig.wardenThornRotationSpeed * CGFloat(deltaTime)
        for index in thorns.indices {
            thorns[index].angle += delta
        }
        wardenThorns[playerID] = thorns
    }

    private func updateThornPositions(for player: PlayerEntity) {
        let playerID = ObjectIdentifier(player)
        guard let thorns = wardenThorns[playerID] else { return }
        for thorn in thorns {
            thorn.sprite.position = CGPoint(
                x: player.position.x + cos(thorn.angle) * SkillConfig.wardenThornRadius,
                y: player.position.y + sin(thorn.angle) * SkillConfig.wardenThornRadius
            )
            thorn.sprite.zRotation = WardenThornsLayout.spriteRotation(forThornAngle: thorn.angle)
        }
    }

    private func decayWardenThornCooldowns(for playerID: ObjectIdentifier, deltaTime: TimeInterval) {
        guard var perThorn = wardenThornHitCooldowns[playerID] else { return }
        let aliveEnemyIDs = Set(enemies.compactMap { $0.parent != nil ? ObjectIdentifier($0) : nil })

        for (thornIndex, enemyMap) in perThorn {
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
                perThorn.removeValue(forKey: thornIndex)
            } else {
                perThorn[thornIndex] = updated
            }
        }
        wardenThornHitCooldowns[playerID] = perThorn.isEmpty ? nil : perThorn
    }

    private func applyThornCollisions(for player: PlayerEntity) {
        let playerID = ObjectIdentifier(player)
        guard let thorns = wardenThorns[playerID] else { return }

        let thornHitRadius = SkillConfig.wardenThornHitRadius

        for (thornIndex, thorn) in thorns.enumerated() {
            let thornPosition = thorn.sprite.position
            for enemy in enemies where enemy.parent != nil {
                let enemyID = ObjectIdentifier(enemy)
                let cooldown = wardenThornHitCooldowns[playerID]?[thornIndex]?[enemyID]
                guard cooldown == nil else { continue }

                let enemyRadius = enemy.size.width * 0.5
                let distance = toroidalDistance(from: thornPosition, to: enemy.position, mapSize: GameConfig.mapSize)
                guard distance <= enemyRadius + thornHitRadius else { continue }

                enemy.takeDamage(SkillConfig.wardenThornDamage)
                particleAssets.emit(.wardenThornsHit, at: enemy.position, in: self)

                var perThorn = wardenThornHitCooldowns[playerID] ?? [:]
                var perEnemy = perThorn[thornIndex] ?? [:]
                perEnemy[enemyID] = SkillConfig.wardenThornCooldownPerEnemy
                perThorn[thornIndex] = perEnemy
                wardenThornHitCooldowns[playerID] = perThorn
            }
        }
    }

    private func removeAllThorns(for playerID: ObjectIdentifier) {
        guard let thorns = wardenThorns.removeValue(forKey: playerID) else { return }
        thorns.forEach { $0.sprite.removeFromParent() }
    }

    private func animateWardenThorn(_ sprite: SKSpriteNode) {
        guard wardenThornFrames.count > 1 else { return }

        let animate = SKAction.animate(
            with: wardenThornFrames,
            timePerFrame: SkillConfig.wardenThornAnimFrameTime
        )
        sprite.run(.repeatForever(animate), withKey: wardenThornAnimationKey)
    }

    private func wardenThornTexture(named name: String) -> SKTexture {
        let texture = wardenThornsAtlas.textureNamed(name)
        texture.filteringMode = .nearest
        return texture
    }

    private func makeMistCloudNode(radius: CGFloat) -> SKNode {
        let node = SKNode()
        let sprite = SKSpriteNode(texture: mistTexture(named: "vfx_poisonous_mist_000"))
        sprite.zPosition = 0
        sprite.alpha = SkillConfig.mistCloudAlpha
        sprite.size = CGSize(width: radius * 2, height: radius * 2)
        node.addChild(sprite)

        let frames = (0..<3).map { mistTexture(named: "vfx_poisonous_mist_\(String(format: "%03d", $0))") }
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
        let bolt = SKSpriteNode(texture: lightningTexture(named: "vfx_lightning_strike_002"))
        bolt.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        bolt.position = CGPoint(x: 0, y: -referenceSpriteHeight * lightningBoltOffsetFactor)
        bolt.size = CGSize(width: max(SkillConfig.lightningBoltMinWidth, radius * SkillConfig.lightningBoltWidthFactor), height: boltHeight)
        bolt.alpha = SkillConfig.lightningBoltAlpha
        strikeNode.addChild(bolt)

        let frames = [
            lightningTexture(named: "vfx_lightning_strike_001"),
            lightningTexture(named: "vfx_lightning_strike_002"),
            lightningTexture(named: "vfx_lightning_strike_003"),
            lightningTexture(named: "vfx_lightning_strike_002")
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
        guard skillCardOverlay == nil, pendingSkillSelectionPlayer == nil else { return }
        audioManager.play(.levelUp)
        hud.showFullEssenceBriefly(duration: levelUpOverlayDelay)
        pendingSkillSelectionPlayer = player
        pendingSkillSelectionDelay = levelUpOverlayDelay
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
    func handleMouseMoved(atViewPosition viewPosition: CGPoint, viewSize: CGSize) -> Bool {
        guard viewSize.width > 0, viewSize.height > 0 else { return true }
        guard let skillCardOverlay else { return gameOverOverlay != nil }

        let overlayPoint = CGPoint(
            x: (viewPosition.x / viewSize.width) * size.width - size.width / 2,
            y: (viewPosition.y / viewSize.height) * size.height - size.height / 2
        )
        return skillCardOverlay.handleMouseMoved(at: overlayPoint)
    }

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

    func handlePlayerDeath(_ player: PlayerEntity) {
        Log.debug("GameScene: player died")
        pendingSkillSelectionPlayer = nil
        pendingSkillSelectionDelay = 0
        audioManager.stopAllMusic()
        audioManager.playDeathExclusively()
        presentGameOverOverlay(for: player)
    }
    
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
        smashNode.zPosition = 1.0 // Render on top of floor tiles
        floorLayer.addChild(smashNode)

        let animate = SKAction.animate(with: frames, timePerFrame: 0.08)
        let fadeOut = SKAction.fadeOut(withDuration: 0.25)
        let remove = SKAction.removeFromParent()

        smashNode.run(SKAction.sequence([animate, fadeOut, remove]))
        cameraSystem.shakeCamera(duration: 0.25, amplitude: 8.0)
    }

    func dealMeleeDamageToNearestPlayer(from position: CGPoint, damage: Int, range: CGFloat) {
        spawnSmashEffect(at: position)

        guard let player = players.min(by: {
            toroidalDistance(from: position, to: $0.position, mapSize: GameConfig.mapSize) <
            toroidalDistance(from: position, to: $1.position, mapSize: GameConfig.mapSize)
        }) else { return }

        let dist = toroidalDistance(from: position, to: player.position, mapSize: GameConfig.mapSize)
        guard dist <= range else { return }

        player.takeDamage(damage)
        directorSystem.recordDamageTaken(damage)
        AudioManager.shared.play(.hit)
    }

    func spawnBossMinions(count: Int, around position: CGPoint) {
        spawnSystem.spawnBossMinions(count: count, around: position)
    }
    
    func spawnEnemyProjectile(
        at position: CGPoint,
        direction: CGVector,
        damage: Int,
        textureName: String = "projectile_enemy_grumble",
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
            // Kunci kamera tepat saat boss stage mulai
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
