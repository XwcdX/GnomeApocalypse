import SpriteKit

final class CollisionSystem: NSObject, SKPhysicsContactDelegate {
    private let areShieldHandlersEnabled = false
    private var playerHealthCallbacks: [SKNode: (Int) -> Void] = [:]
    
    func register(player: PlayerEntity, directorSystem: DirectorSystem) {
        playerHealthCallbacks[player] = { [weak player, weak directorSystem] damage in
            player?.takeDamage(damage)
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
        } else if matches(a, b, PhysicsCategory.shield, PhysicsCategory.enemy) {
            handleShieldPushesEnemyIfEnabled(contact)
        } else if matches(a, b, PhysicsCategory.shield, PhysicsCategory.enemyProjectile) {
            handleShieldBlocksEnemyProjectileIfEnabled(contact)
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
        if enemy.health.isDead { enemy.die() }
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
        let nodeA = contact.bodyA.node
        let nodeB = contact.bodyB.node

        var playerNode = (nodeA as? PlayerEntity) ?? (nodeB as? PlayerEntity)
        var orbNode: SKNode? = playerNode === nodeA ? nodeB : nodeA

        if playerNode == nil {
            let ghostNode = nodeA?.name == "ghost" ? nodeA : nodeB
            if let realPlayer = ghostNode?.userData?["ghostOf"] as? PlayerEntity {
                playerNode = realPlayer
                orbNode = ghostNode === nodeA ? nodeB : nodeA
            }
        }

        guard let player = playerNode,
              let orb = orbNode as? ForestEssenceOrb,
              let scene = player.scene as? GameScene else { return }

        player.addXP(orb.essenceValue)
        scene.removeOrb(orb)
    }

    private func handleShieldPushesEnemyIfEnabled(_ contact: SKPhysicsContact) {
        guard areShieldHandlersEnabled else { return }
        guard let shield = shieldNode(from: contact),
              let enemy = enemyNode(from: contact) else { return }

        let offset = toroidalOffset(from: shield.position, to: enemy.position, mapSize: GameConfig.mapSize)
        let distance = sqrt(offset.dx * offset.dx + offset.dy * offset.dy)
        guard distance > 0.1 else { return }

        let direction = CGVector(dx: offset.dx / distance, dy: offset.dy / distance)
        enemy.physicsBody?.applyImpulse(
            CGVector(
                dx: direction.dx * GameConfig.shieldPushForce,
                dy: direction.dy * GameConfig.shieldPushForce
            )
        )
    }

    private func handleShieldBlocksEnemyProjectileIfEnabled(_ contact: SKPhysicsContact) {
        guard areShieldHandlersEnabled else { return }
        let projectile = (contact.bodyA.node as? Projectile) ?? (contact.bodyB.node as? Projectile)
        projectile?.deactivate()
    }

    private func shieldNode(from contact: SKPhysicsContact) -> SKNode? {
        if contact.bodyA.categoryBitMask == PhysicsCategory.shield { return contact.bodyA.node }
        if contact.bodyB.categoryBitMask == PhysicsCategory.shield { return contact.bodyB.node }
        return nil
    }

    private func enemyNode(from contact: SKPhysicsContact) -> EnemyEntity? {
        var enemy = (contact.bodyA.node as? EnemyEntity) ?? (contact.bodyB.node as? EnemyEntity)

        if enemy == nil {
            let ghostNode = contact.bodyA.node?.name == "ghost" ? contact.bodyA.node : contact.bodyB.node
            enemy = ghostNode?.userData?["ghostOf"] as? EnemyEntity
        }

        return enemy
    }
}
