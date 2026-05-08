import SpriteKit

final class SpawnSystem {
    private weak var entityLayer: SKNode?
    private weak var cameraSystem: CameraSystem?
    private weak var directorSystem: DirectorSystem?
    private var orbs: [ForestEssenceOrb] = []
    
    private var spawnAccumulator: TimeInterval = 0
    private let spawnInterval: TimeInterval = 2.0
    
    init(entityLayer: SKNode, cameraSystem: CameraSystem, directorSystem: DirectorSystem) {
        self.entityLayer = entityLayer
        self.cameraSystem = cameraSystem
        self.directorSystem = directorSystem
    }
    
    func update(deltaTime: TimeInterval) {
        guard let director = directorSystem,
              let camera = cameraSystem,
              let layer = entityLayer else { return }
        
        if director.isBossStageActive { return }
        
        spawnAccumulator += deltaTime
        if spawnAccumulator >= spawnInterval {
            spawnAccumulator = 0
            attemptSpawn(camera: camera, layer: layer, director: director)
        }
        
        for orb in orbs {
            orb.update(cameraSystem: camera)
        }
    }
    
    func spawnForestEssenceOrb(at position: CGPoint) {
        guard let layer = entityLayer else { return }
        
        let orb = ForestEssenceOrb(essenceValue: GameConfig.orbBaseEssenceValue)
        orb.position = position
        layer.addChild(orb)
        orbs.append(orb)
    }
    
    func removeOrb(_ orb: ForestEssenceOrb) {
        orbs.removeAll { $0 === orb }
        orb.cleanup()
    }
    
    private func attemptSpawn(camera: CameraSystem, layer: SKNode, director: DirectorSystem) {
        let weight = GameConfig.smallGnomeBudgetWeight
        guard director.currentBudget >= weight else { return }

        let spawnPos = randomPositionOutsideCamera(camera: camera)
        let gnome = SmallGnome()
        gnome.position = spawnPos

        guard let scene = layer.scene as? GameScene else { return }
        gnome.gameScene = scene
        scene.register(enemy: gnome)
        layer.addChild(gnome)
        gnome.targetPosition = scene.nearestPlayerPosition(to: spawnPos)
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
