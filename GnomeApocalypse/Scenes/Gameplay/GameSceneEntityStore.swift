import SpriteKit

/// Owns gameplay entity collections and common queries for the SpriteKit scene facade.
final class GameSceneEntityStore {
    private(set) var players: [PlayerEntity] = []
    private(set) var enemies: [EnemyEntity] = []

    var averagePlayerHealthFraction: Double {
        guard !players.isEmpty else { return 1.0 }
        let total = players.reduce(0.0) { sum, player in
            sum + Double(player.health.current) / Double(player.health.maximum)
        }
        return total / Double(players.count)
    }

    var activeEnemyBudget: Int {
        enemies.reduce(0) { $0 + $1.budgetWeight }
    }

    func register(player: PlayerEntity) {
        players.append(player)
    }

    func register(enemy: EnemyEntity) {
        enemies.append(enemy)
    }

    func deregister(enemy: EnemyEntity) {
        enemies.removeAll { $0 === enemy }
    }

    func visibleEnemies(
        cameraPosition: CGPoint,
        viewportSize: CGSize = GameConfig.cameraViewportSize,
        margin: CGFloat
    ) -> [EnemyEntity] {
        enemies.filter { enemy in
            guard enemy.parent != nil else { return false }
            return containsToroidalPosition(
                enemy.position,
                cameraPosition: cameraPosition,
                viewportSize: viewportSize,
                margin: margin
            )
        }
    }

    func canPlayerShoot(
        cameraPosition: CGPoint,
        viewportSize: CGSize,
        zoom: CGFloat = GameConfig.cameraZoom
    ) -> Bool {
        let halfW = (viewportSize.width / (zoom * 2)) * 0.95
        let halfH = (viewportSize.height / (zoom * 2)) * 0.95

        return enemies.contains { enemy in
            guard enemy.parent != nil else { return false }
            let camOffset = toroidalOffset(from: cameraPosition, to: enemy.position, mapSize: GameConfig.mapSize)
            return abs(camOffset.dx) <= halfW && abs(camOffset.dy) <= halfH
        }
    }

    func magnetTargetForOrb(at orbPosition: CGPoint, radius: CGFloat) -> CGPoint? {
        let radiusSquared = radius * radius

        return players
            .filter { $0.parent != nil }
            .map { $0.position }
            .filter { position in
                let dx = position.x - orbPosition.x
                let dy = position.y - orbPosition.y
                return (dx * dx + dy * dy) <= radiusSquared
            }
            .min(by: { lhs, rhs in
                let ldx = lhs.x - orbPosition.x
                let ldy = lhs.y - orbPosition.y
                let rdx = rhs.x - orbPosition.x
                let rdy = rhs.y - orbPosition.y
                return (ldx * ldx + ldy * ldy) < (rdx * rdx + rdy * rdy)
            })
    }

    func nearestPlayerPosition(to position: CGPoint) -> CGPoint {
        players.min {
            toroidalDistance(from: position, to: $0.position, mapSize: GameConfig.mapSize) <
            toroidalDistance(from: position, to: $1.position, mapSize: GameConfig.mapSize)
        }?.position ?? .zero
    }

    private func containsToroidalPosition(
        _ position: CGPoint,
        cameraPosition: CGPoint,
        viewportSize: CGSize,
        margin: CGFloat
    ) -> Bool {
        let rect = CGRect(
            x: cameraPosition.x - viewportSize.width / 2 - margin,
            y: cameraPosition.y - viewportSize.height / 2 - margin,
            width: viewportSize.width + margin * 2,
            height: viewportSize.height + margin * 2
        )
        for dx: CGFloat in [-GameConfig.mapSize.width, 0, GameConfig.mapSize.width] {
            for dy: CGFloat in [-GameConfig.mapSize.height, 0, GameConfig.mapSize.height] {
                if rect.contains(CGPoint(x: position.x + dx, y: position.y + dy)) { return true }
            }
        }
        return false
    }
}
