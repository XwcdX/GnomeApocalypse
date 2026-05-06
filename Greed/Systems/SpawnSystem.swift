import SpriteKit

final class SpawnSystem {
    private weak var entityLayer: SKNode?
    private weak var cameraSystem: CameraSystem?
    private weak var directorSystem: DirectorSystem?
    
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
    }
    
    func spawnForestEssenceOrb(at position: CGPoint) {
        guard let layer = entityLayer else { return }
        
        let orb = SKSpriteNode(color: .green, size: CGSize(width: 16, height: 16))
        orb.position = position
        
        let body = SKPhysicsBody(circleOfRadius: 8)
        body.categoryBitMask = PhysicsCategory.forestEssenceOrb
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = false
        orb.physicsBody = body
        
        layer.addChild(orb)
    }
    
    private func attemptSpawn(camera: CameraSystem, layer: SKNode, director: DirectorSystem) {
        let weight = GameConfig.smallGnomeBudgetWeight
        
        guard director.currentBudget >= weight else { return }
        
        let spawnPos = randomPositionOutsideCamera(camera: camera)
        
        let texture = SKTexture(imageNamed: "gnome_small")
        let gnome = SmallGnome(texture: texture)
        gnome.position = spawnPos
        
        layer.addChild(gnome)
        
        if let scene = layer.scene as? GameScene {
            gnome.gameScene = scene
            scene.register(enemy: gnome)
        }
    }
    
    private func randomPositionOutsideCamera(camera: CameraSystem) -> CGPoint {
        let rect = camera.visibleRect
        let margin = GameConfig.spawnMarginOutsideCamera
        
        let side = Int.random(in: 0..<4)
        let position: CGPoint
        switch side {
        case 0:
            position = CGPoint(x: CGFloat.random(in: rect.minX...rect.maxX), y: rect.maxY + margin)
        case 1:
            position = CGPoint(x: CGFloat.random(in: rect.minX...rect.maxX), y: rect.minY - margin)
        case 2:
            position = CGPoint(x: rect.maxX + margin, y: CGFloat.random(in: rect.minY...rect.maxY))
        default:
            position = CGPoint(x: rect.minX - margin, y: CGFloat.random(in: rect.minY...rect.maxY))
        }
        
        return toroidalWrap(position, mapSize: GameConfig.mapSize)
    }
}
