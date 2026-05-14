import CoreGraphics

enum Layer {
    // MARK: - Scene layer nodes
    static let floor: CGFloat = 0
    static let props: CGFloat = 1
    static let world: CGFloat = 2

    // MARK: - HUD (camera-space, not world-space)
    static let hud: CGFloat = 10
}
