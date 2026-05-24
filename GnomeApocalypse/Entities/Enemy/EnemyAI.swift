import SpriteKit

/// Updates enemies to target the nearest active player using toroidal distance.
final class EnemyAI {
    /// Recomputes each enemy's target position from the currently targetable players.
    func update(enemies: [EnemyEntity], players: [PlayerEntity]) {
        let targets = players.filter { !$0.health.isDead && $0.isTargetingActive }
        guard !targets.isEmpty else { return }

        for enemy in enemies {
            guard let nearest = nearestPlayer(to: enemy.position, among: targets) else { continue }
            enemy.targetPosition = nearest.position
        }
    }

    private func nearestPlayer(to origin: CGPoint, among players: [PlayerEntity]) -> PlayerEntity? {
        players.min {
            toroidalDistance(from: origin, to: $0.position, mapSize: GameConfig.mapSize) <
            toroidalDistance(from: origin, to: $1.position, mapSize: GameConfig.mapSize)
        }
    }
}
