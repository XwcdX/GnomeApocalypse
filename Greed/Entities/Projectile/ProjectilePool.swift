import SpriteKit

final class ProjectilePool {
    private var pool: [Projectile] = []
    private let texture: SKTexture
    private let size: CGSize
    
    init(size: Int, texture: SKTexture, projectileSize: CGSize) {
        self.texture = texture
        self.size = projectileSize
        
        for _ in 0..<size {
            let projectile = Projectile(texture: texture, color: .clear, size: projectileSize)
            projectile.isHidden = true
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
