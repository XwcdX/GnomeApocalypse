import SpriteKit

final class ToroidalRenderingComponent {
    private weak var owner: SKNode?
    private var ghosts: [SKSpriteNode] = []
    private let mapSize: CGSize
    
    init(owner: SKNode, mapSize: CGSize) {
        self.owner = owner
        self.mapSize = mapSize
    }
    
    func update(cameraPosition: CGPoint, viewportSize: CGSize) {
        guard let owner = owner,
              let sprite = owner as? SKSpriteNode,
              let parent = owner.parent else { return }
        
        clearGhosts()
        
        let pos = owner.position
        let cameraRect = CGRect(
            x: cameraPosition.x - viewportSize.width / 2 - 100,
            y: cameraPosition.y - viewportSize.height / 2 - 100,
            width: viewportSize.width + 200,
            height: viewportSize.height + 200
        )
        
        for x in -1...1 {
            for y in -1...1 {
                if x == 0 && y == 0 { continue }
                
                let offset = CGPoint(
                    x: CGFloat(x) * mapSize.width,
                    y: CGFloat(y) * mapSize.height
                )
                let ghostPos = CGPoint(x: pos.x + offset.x, y: pos.y + offset.y)
                
                if cameraRect.contains(ghostPos) {
                    createGhost(sprite: sprite, at: ghostPos, parent: parent)
                }
            }
        }
    }
    
    func clear() {
        clearGhosts()
    }
    
    private func createGhost(sprite: SKSpriteNode, at position: CGPoint, parent: SKNode) {
        let ghost = SKSpriteNode(texture: sprite.texture, size: sprite.size)
        ghost.position = position
        ghost.zPosition = sprite.zPosition
        ghost.alpha = sprite.alpha
        ghost.xScale = sprite.xScale
        ghost.yScale = sprite.yScale
        ghost.name = "ghost"
        
        if let ownerBody = sprite.physicsBody {
            let ghostBody = ownerBody.copy() as! SKPhysicsBody
            ghostBody.isDynamic = false
            ghostBody.collisionBitMask = PhysicsCategory.none
            ghost.physicsBody = ghostBody
            ghost.userData = ["ghostOf": sprite]
        }
        
        parent.addChild(ghost)
        ghosts.append(ghost)
    }
    
    private func clearGhosts() {
        for ghost in ghosts {
            ghost.removeFromParent()
        }
        ghosts.removeAll()
    }
    
    deinit {
        clearGhosts()
    }
}
