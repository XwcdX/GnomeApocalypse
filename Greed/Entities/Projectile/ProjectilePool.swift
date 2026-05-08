import SpriteKit

final class ProjectilePool {
    private var pool: [Projectile] = []
    
    init(
        size: Int,
        atlasName: String,
        frameNames: [String],
        projectileSize: CGSize,
        category: UInt32,
        contactTestBitMask: UInt32,
        frameTime: TimeInterval
    ) {
        let atlas = SKTextureAtlas(named: atlasName)
        let frames = frameNames.map { frameName in
            let texture = atlas.textureNamed(frameName)
            texture.filteringMode = .nearest
            return texture
        }
        
        for _ in 0..<size {
            let projectile = Projectile(texture: frames.first, color: .clear, size: projectileSize)
            projectile.name = "\(atlasName)Projectile"
            projectile.zPosition = Layer.projectile
            projectile.isHidden = true
            projectile.configurePhysics(category: category, contactTestBitMask: contactTestBitMask)
            projectile.configureAnimation(frames: frames, frameTime: frameTime)
            pool.append(projectile)
        }
    }
    
    func dequeue() -> Projectile? {
        pool.first { !$0.isActive }
    }
    
    func enqueue(_ projectile: Projectile) {
        projectile.deactivate()
    }
    
    func updateAll(deltaTime: TimeInterval) {
        for projectile in pool where projectile.isActive {
            projectile.update(deltaTime: deltaTime)
        }
    }
    
    func attachAll(to parent: SKNode) {
        for projectile in pool {
            parent.addChild(projectile)
        }
    }
}
