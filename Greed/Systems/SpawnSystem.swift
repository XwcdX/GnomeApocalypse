import SpriteKit

private let bossMinionsSpawnRadius: CGFloat = 72

final class SpawnSystem {
    private weak var entityLayer: SKNode?
    private weak var cameraSystem: CameraSystem?
    private weak var directorSystem: DirectorSystem?
    private var orbs: [EssenceOrbComponent] = []
    private weak var activeBoss: Grand?
    
    private var spawnAccumulator: TimeInterval = 0
    private var waveAccumulator: TimeInterval = 0
    
    init(entityLayer: SKNode, cameraSystem: CameraSystem, directorSystem: DirectorSystem) {
        self.entityLayer = entityLayer
        self.cameraSystem = cameraSystem
        self.directorSystem = directorSystem
    }
    
    func update(deltaTime: TimeInterval, activeBudgetUsed: Int) {
        guard let director = directorSystem,
              let camera = cameraSystem,
              let layer = entityLayer else { return }
        
        var budgetUsed = activeBudgetUsed
        budgetUsed += updateOrbs(deltaTime: deltaTime, camera: camera, director: director, activeBudgetUsed: budgetUsed)

        if director.isBossStageActive {
            spawnBossIfNeeded(camera: camera, layer: layer)
            return
        }
        
        waveAccumulator += deltaTime
        spawnAccumulator += deltaTime
        if spawnAccumulator >= currentSpawnInterval {
            spawnAccumulator = 0
            spawnWave(camera: camera, layer: layer, director: director, activeBudgetUsed: budgetUsed)
        }
    }
    
    func spawnEssenceOrb(at position: CGPoint) {
        guard let layer = entityLayer else { return }
        
        let orb = EssenceOrbComponent()
        orb.position = position
        layer.addChild(orb)
        orbs.append(orb)
    }
    
    func removeOrb(_ orb: EssenceOrbComponent) {
        orbs.removeAll { $0 === orb }
        orb.cleanup()
    }

    func spawnBossMinions(count: Int, around position: CGPoint) {
        guard count > 0,
              let layer = entityLayer,
              let camera = cameraSystem,
              let scene = layer.scene as? GameScene else { return }

        let spawnRadius: CGFloat = bossMinionsSpawnRadius
        for index in 0..<count {
            let angle = (CGFloat(index) / CGFloat(count)) * .pi * 2
            var spawnPos = CGPoint(
                x: position.x + cos(angle) * spawnRadius,
                y: position.y + sin(angle) * spawnRadius
            )
            camera.clampToroidal(&spawnPos)

            let gnome = Grove()
            gnome.position = spawnPos
            gnome.gameScene = scene
            scene.register(enemy: gnome)
            layer.addChild(gnome)
            gnome.targetPosition = scene.nearestPlayerPosition(to: spawnPos)
        }
    }
    
    private func updateOrbs(
        deltaTime: TimeInterval,
        camera: CameraSystem,
        director: DirectorSystem,
        activeBudgetUsed: Int
    ) -> Int {
        var spawnedBudget = 0
        var explodedOrbs: [EssenceOrbComponent] = []
        for orb in orbs {
            if orb.update(deltaTime: deltaTime, cameraSystem: camera) {
                explodedOrbs.append(orb)
            }
        }

        for orb in explodedOrbs {
            let spawnPosition = orb.position
            if spawnGrumble(at: spawnPosition, director: director, activeBudgetUsed: activeBudgetUsed + spawnedBudget) {
                spawnedBudget += GameConfig.grumbleBudgetWeight
            }
            removeOrb(orb)
        }

        return spawnedBudget
    }

    var currentWaveIndex: Int {
        Int(waveAccumulator / GameConfig.spawnWaveEscalationInterval)
    }

    var currentSpawnInterval: TimeInterval {
        let reduction = TimeInterval(currentWaveIndex) * GameConfig.spawnIntervalReductionPerWave
        return max(GameConfig.minimumSpawnInterval, GameConfig.baseSpawnInterval - reduction)
    }

    var currentGnomesPerSpawn: Int {
        let count = GameConfig.baseGnomesPerSpawn + (currentWaveIndex * GameConfig.gnomesPerSpawnIncreasePerWave)
        return min(GameConfig.maximumGnomesPerSpawn, count)
    }

    private func spawnWave(camera: CameraSystem, layer: SKNode, director: DirectorSystem, activeBudgetUsed: Int) {
        var budgetUsed = activeBudgetUsed
        for _ in 0..<currentGnomesPerSpawn {
            guard attemptSpawn(camera: camera, layer: layer, director: director, activeBudgetUsed: budgetUsed) else { return }
            budgetUsed += GameConfig.smallGnomeBudgetWeight
        }
    }

    private func attemptSpawn(camera: CameraSystem, layer: SKNode, director: DirectorSystem, activeBudgetUsed: Int) -> Bool {
        let weight = GameConfig.smallGnomeBudgetWeight
        guard activeBudgetUsed + weight <= director.currentBudget else { return false }

        let spawnPos = randomPositionOutsideCamera(camera: camera)
        let gnome = Grove()
        gnome.position = spawnPos

        guard let scene = layer.scene as? GameScene else { return false }
        gnome.gameScene = scene
        scene.register(enemy: gnome)
        layer.addChild(gnome)
        gnome.targetPosition = scene.nearestPlayerPosition(to: spawnPos)
        return true
    }

    private func spawnGrumble(at spawnPos: CGPoint, director: DirectorSystem, activeBudgetUsed: Int) -> Bool {
        let weight = GameConfig.grumbleBudgetWeight
        guard activeBudgetUsed + weight <= director.currentBudget,
              let layer = entityLayer,
              let scene = layer.scene as? GameScene else { return false }

        let miniBoss = Grumble()
        miniBoss.position = spawnPos
        miniBoss.gameScene = scene
        scene.register(enemy: miniBoss)
        layer.addChild(miniBoss)
        miniBoss.targetPosition = scene.nearestPlayerPosition(to: spawnPos)
        return true
    }

    private func spawnBossIfNeeded(camera: CameraSystem, layer: SKNode) {
        if activeBoss?.parent != nil { return }
        guard let scene = layer.scene as? GameScene else { return }

        let spawnPos = randomPositionOutsideCamera(camera: camera)
        let boss = Grand()
        boss.position = spawnPos
        boss.gameScene = scene
        scene.register(enemy: boss)
        layer.addChild(boss)
        boss.targetPosition = scene.nearestPlayerPosition(to: spawnPos)
        activeBoss = boss
    }
    
    private func randomPositionOutsideCamera(camera: CameraSystem) -> CGPoint {
        let rect = camera.visibleRect
        let margin = GameConfig.spawnMarginOutsideCamera
        let side = Int.random(in: 0..<4)
        switch side {
        case 0: return CGPoint(x: CGFloat.random(in: rect.minX...rect.maxX), y: rect.maxY + margin)
        case 1: return CGPoint(x: CGFloat.random(in: rect.minX...rect.maxX), y: rect.minY - margin)
        case 2: return CGPoint(x: rect.maxX + margin, y: CGFloat.random(in: rect.minY...rect.maxY))
        default: return CGPoint(x: rect.minX - margin, y: CGFloat.random(in: rect.minY...rect.maxY))
        }
    }
}
