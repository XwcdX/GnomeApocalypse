import CoreGraphics

protocol WorldLayerSortable {
    var worldSortPriority: CGFloat { get }
}

enum Layer {
    // MARK: - Scene layer nodes
    static let floor: CGFloat = 0
    static let props: CGFloat = 1
    static let world: CGFloat = 2
    static let groundPickupSortPriority: CGFloat = -0.02

    // MARK: - HUD (camera-space, not world-space)
    static let hud: CGFloat = 10

    static func worldZPosition(forFootY footY: CGFloat, mapHeight: CGFloat, sortPriority: CGFloat = 0) -> CGFloat {
        let halfMapHeight = mapHeight / 2
        let wrapCount = ((footY + halfMapHeight) / mapHeight).rounded(.down)
        let wrappedY = footY - mapHeight * wrapCount
        return world - wrappedY / mapHeight + sortPriority
    }
}
