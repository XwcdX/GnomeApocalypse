import CoreGraphics

/// Snapshot of run stats shown on the game-over overlay.
struct GameOverStats {
    /// One equipped item entry shown in the item summary.
    struct Item {
        let name: String
        let level: Int
        let iconName: String
    }

    let playerLevel: Int
    let maxHealth: Int
    let attackSpeedMultiplier: CGFloat
    let movementSpeed: CGFloat
    let items: [Item]
}
