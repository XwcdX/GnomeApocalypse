import SpriteKit

/// Creates transient ghost sprites so wrapped world entities remain visible across map edges.
final class ToroidalRenderingComponent {
    private weak var owner: SKNode?
    private var ghosts: [SKSpriteNode] = []
    private let mapSize: CGSize
    
    init(owner: SKNode, mapSize: CGSize) {
        self.owner = owner
        self.mapSize = mapSize
    }
    
    /// Rebuilds visible ghost nodes around the camera; existing ghosts are removed each call.
    func update(cameraPosition: CGPoint, viewportSize: CGSize) {
        guard let owner = owner,
              let sprite = owner as? SKSpriteNode,
              let parent = owner.parent else {
            clearGhosts()
            return
        }

        clearGhosts()

        let pos = owner.position
        let margin: CGFloat = max(sprite.size.width, sprite.size.height)
        let cameraRect = CGRect(
            x: cameraPosition.x - viewportSize.width / 2 - margin,
            y: cameraPosition.y - viewportSize.height / 2 - margin,
            width: viewportSize.width + margin * 2,
            height: viewportSize.height + margin * 2
        )

        let nearestX = pos.x + round((cameraPosition.x - pos.x) / mapSize.width) * mapSize.width
        let nearestY = pos.y + round((cameraPosition.y - pos.y) / mapSize.height) * mapSize.height

        for dx in -1...1 {
            for dy in -1...1 {
                if dx == 0 && dy == 0 { continue }
                let ghostPos = CGPoint(
                    x: nearestX + CGFloat(dx) * mapSize.width,
                    y: nearestY + CGFloat(dy) * mapSize.height
                )
                if cameraRect.contains(ghostPos) {
                    createGhost(sprite: sprite, at: ghostPos, parent: parent)
                }
            }
        }

        let nearestPos = CGPoint(x: nearestX, y: nearestY)
        if (abs(nearestX - pos.x) > 1 || abs(nearestY - pos.y) > 1),
           cameraRect.contains(nearestPos) {
            createGhost(sprite: sprite, at: nearestPos, parent: parent)
        }
    }
    
    /// Removes every ghost owned by this component.
    func clear() {
        clearGhosts()
    }
    
    private func createGhost(sprite: SKSpriteNode, at position: CGPoint, parent: SKNode) {
        let ghost: SKSpriteNode
        if let texture = sprite.texture {
            ghost = SKSpriteNode(texture: texture, size: sprite.size)
        } else {
            ghost = SKSpriteNode(color: sprite.color, size: sprite.size)
            ghost.colorBlendFactor = sprite.colorBlendFactor
        }
        ghost.position = position
        ghost.zPosition = sprite.zPosition
        ghost.alpha = sprite.alpha
        ghost.xScale = sprite.xScale
        ghost.yScale = sprite.yScale
        ghost.name = "ghost"

        if let ownerBody = sprite.physicsBody {
            let radius = max(sprite.size.width, sprite.size.height) / 2
            let ghostBody = SKPhysicsBody(circleOfRadius: radius)
            ghostBody.categoryBitMask = ownerBody.categoryBitMask
            ghostBody.contactTestBitMask = ownerBody.contactTestBitMask
            ghostBody.collisionBitMask = PhysicsCategory.none
            ghostBody.isDynamic = false
            ghostBody.affectedByGravity = false
            ghostBody.allowsRotation = false
            ghost.physicsBody = ghostBody
            ghost.userData = NSMutableDictionary(dictionary: ["ghostOf": sprite])
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
