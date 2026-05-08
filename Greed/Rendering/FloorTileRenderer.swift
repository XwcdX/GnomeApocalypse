import SpriteKit

final class FloorTileRenderer {
    let rootNode: SKNode = SKNode()

    private let tileSize: CGSize
    private let tileTexture: SKTexture
    private var tiles: [SKSpriteNode] = []
    private var columns: Int = 0
    private var rows: Int = 0
    private var viewportSize: CGSize

    init(tileTexture: SKTexture, tileSize: CGSize, viewportSize: CGSize) {
        self.tileTexture = tileTexture
        self.tileSize = tileSize
        self.viewportSize = viewportSize
        rebuildGrid(for: viewportSize)
    }

    func updateViewport(_ size: CGSize) {
        guard size != viewportSize else { return }
        viewportSize = size
        tiles.forEach { $0.removeFromParent() }
        tiles.removeAll()
        rebuildGrid(for: size)
    }

    func update(cameraPosition: CGPoint) {
        let tw = tileSize.width
        let th = tileSize.height

        let gridOriginX = (cameraPosition.x / tw).rounded(.down) * tw - tw * CGFloat(columns / 2)
        let gridOriginY = (cameraPosition.y / th).rounded(.down) * th - th * CGFloat(rows / 2)

        for row in 0..<rows {
            for col in 0..<columns {
                let tile = tiles[row * columns + col]
                tile.position = CGPoint(
                    x: gridOriginX + CGFloat(col) * tw + tw / 2,
                    y: gridOriginY + CGFloat(row) * th + th / 2
                )
            }
        }
    }

    private func rebuildGrid(for size: CGSize) {
        columns = Int(ceil(size.width  / tileSize.width))  + 3
        rows    = Int(ceil(size.height / tileSize.height)) + 3

        tiles.reserveCapacity(columns * rows)
        for _ in 0..<(columns * rows) {
            let tile = SKSpriteNode(texture: tileTexture, size: tileSize)
            rootNode.addChild(tile)
            tiles.append(tile)
        }
    }
}
