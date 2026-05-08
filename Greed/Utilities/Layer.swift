import CoreGraphics

enum Layer {
    // MARK: - Scene layers (set on layer SKNode)
    static let ground: CGFloat = 0
    static let environment: CGFloat = 1
    static let entities: CGFloat = 2

    // MARK: - Entity sub-layers (set on individual nodes within entityLayer)
    static let orb: CGFloat = 0
    static let enemy: CGFloat = 1
    static let player: CGFloat = 2
    static let projectile: CGFloat = 3
    static let hud: CGFloat = 10
}
