import SpriteKit

final class FloorTileRenderer {
    let rootNode: SKNode = SKNode()

    private let tileSize: CGSize
    private let tileTexture: SKTexture
    private var tiles: [SKSpriteNode] = []
    private let columns: Int
    private let rows: Int

    init(tileTexture: SKTexture, tileSize: CGSize, viewportSize: CGSize) {
        self.tileTexture = tileTexture
        self.tileSize = tileSize
        columns = Int(ceil(viewportSize.width  / tileSize.width))  + 3
        rows    = Int(ceil(viewportSize.height / tileSize.height)) + 3

        buildTileGrid()
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

    private func buildTileGrid() {
        tiles.reserveCapacity(columns * rows)
        for _ in 0..<(columns * rows) {
            let tile = SKSpriteNode(texture: tileTexture, size: tileSize)
            tile.zPosition = Layer.ground
            rootNode.addChild(tile)
            tiles.append(tile)
        }
    }
}
