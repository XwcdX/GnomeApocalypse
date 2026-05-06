import SpriteKit

final class Projectile: SKSpriteNode {
    let toroidal = ToroidalPositionComponent()
    
    var damage: Int = 0
    var velocity: CGVector = .zero
    var lifespan: TimeInterval = 0
    private var age: TimeInterval = 0
    
    var isActive: Bool = false
    
    func activate(at position: CGPoint, velocity: CGVector, damage: Int, lifespan: TimeInterval) {
        self.position = position
        self.velocity = velocity
        self.damage = damage
        self.lifespan = lifespan
        self.age = 0
        self.isActive = true
        self.isHidden = false
    }
    
    func deactivate() {
        isActive = false
        isHidden = true
        removeFromParent()
    }
    
    func update(deltaTime: TimeInterval) {
        guard isActive else { return }
        
        age += deltaTime
        if age >= lifespan {
            deactivate()
            return
        }
        
        position.x += velocity.dx * deltaTime
        position.y += velocity.dy * deltaTime
        toroidal.update(node: self)
    }
}
