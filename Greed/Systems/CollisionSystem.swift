import SpriteKit

final class CollisionSystem: NSObject, SKPhysicsContactDelegate {
    private var playerHealthCallbacks: [SKNode: (Int) -> Void] = [:]
    
    func register(player: PlayerEntity, directorSystem: DirectorSystem) {
        playerHealthCallbacks[player] = { [weak player, weak directorSystem] damage in
            player?.health.takeDamage(damage)
            directorSystem?.recordDamageTaken(damage)
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB
        
        if matches(a, b, PhysicsCategory.playerProjectile, PhysicsCategory.enemy) {
            handlePlayerProjectileHitsEnemy(contact)
        } else if matches(a, b, PhysicsCategory.enemyProjectile, PhysicsCategory.player) {
            handleEnemyProjectileHitsPlayer(contact)
        } else if matches(a, b, PhysicsCategory.player, PhysicsCategory.forestEssenceOrb) {
            handlePlayerCollectsOrb(contact)
        }
    }
    
    private func matches(_ a: SKPhysicsBody, _ b: SKPhysicsBody, _ cat1: UInt32, _ cat2: UInt32) -> Bool {
        (a.categoryBitMask == cat1 && b.categoryBitMask == cat2) ||
        (a.categoryBitMask == cat2 && b.categoryBitMask == cat1)
    }
    
    private func handlePlayerProjectileHitsEnemy(_ contact: SKPhysicsContact) {
        guard let projectile = (contact.bodyA.node as? Projectile) ?? (contact.bodyB.node as? Projectile) else { return }
        
        var enemyNode = (contact.bodyA.node as? EnemyEntity) ?? (contact.bodyB.node as? EnemyEntity)
        
        if enemyNode == nil {
            let ghostNode = contact.bodyA.node?.name == "ghost" ? contact.bodyA.node : contact.bodyB.node
            if let realEnemy = ghostNode?.userData?["ghostOf"] as? EnemyEntity {
                enemyNode = realEnemy
            }
        }
        
        guard let enemy = enemyNode else { return }
        
        enemy.health.takeDamage(projectile.damage)
        projectile.deactivate()
    }
    
    private func handleEnemyProjectileHitsPlayer(_ contact: SKPhysicsContact) {
        guard let projectile = (contact.bodyA.node as? Projectile) ?? (contact.bodyB.node as? Projectile) else { return }
        
        var playerNode = (contact.bodyA.node as? PlayerEntity) ?? (contact.bodyB.node as? PlayerEntity)
        
        if playerNode == nil {
            let ghostNode = contact.bodyA.node?.name == "ghost" ? contact.bodyA.node : contact.bodyB.node
            if let realPlayer = ghostNode?.userData?["ghostOf"] as? PlayerEntity {
                playerNode = realPlayer
            }
        }
        
        guard let player = playerNode else { return }
        
        playerHealthCallbacks[player]?(projectile.damage)
        projectile.deactivate()
    }
    
    private func handlePlayerCollectsOrb(_ contact: SKPhysicsContact) {
        var playerNode = (contact.bodyA.node as? PlayerEntity) ?? (contact.bodyB.node as? PlayerEntity)
        
        if playerNode == nil {
            let ghostNode = contact.bodyA.node?.name == "ghost" ? contact.bodyA.node : contact.bodyB.node
            if let realPlayer = ghostNode?.userData?["ghostOf"] as? PlayerEntity {
                playerNode = realPlayer
            }
        }
        
        guard let player = playerNode,
              let orb = contact.bodyA.node ?? contact.bodyB.node else { return }
        
        player.level.addXP(GameConfig.orbBaseEssenceValue)
        orb.removeFromParent()
    }
}
