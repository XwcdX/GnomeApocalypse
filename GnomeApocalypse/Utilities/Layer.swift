import CoreGraphics

/// Optional sort hook for world nodes that need deterministic ordering around their foot position.
protocol WorldLayerSortable {
    var worldSortPriority: CGFloat { get }
}

/// Z-position bands shared by world, prop, pickup, and camera-space HUD nodes.
enum Layer {
    static let floor: CGFloat = 0
    static let props: CGFloat = 1
    static let world: CGFloat = 2
    static let groundPickupSortPriority: CGFloat = -0.02

    static let hud: CGFloat = 10

    /// Computes y-sort ordering for world nodes whose visual base is at `footY`.
    static func worldZPosition(forFootY footY: CGFloat, mapHeight: CGFloat, sortPriority: CGFloat = 0) -> CGFloat {
        let halfMapHeight = mapHeight / 2
        let wrapCount = ((footY + halfMapHeight) / mapHeight).rounded(.down)
        let wrappedY = footY - mapHeight * wrapCount
        return world - wrappedY / mapHeight + sortPriority
    }
}
