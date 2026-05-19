import SpriteKit

private let propScale: CGFloat = 0.27
private let solidPropBodyWidthFactor: CGFloat = 0.6
private let solidPropBodyHeightFactor: CGFloat = 0.4
private let solidPropBodyOffsetFactor: CGFloat = 0.3

private let propDefinitions: [(name: String, solid: Bool, count: Int)] = [
    ("prop_flower_red", false, 3),
    ("prop_flower_white", false, 3),
    ("prop_mushroom", false, 3),
    ("prop_rock_small", false, 3),
    ("prop_tree_pine", true, 2),
    ("prop_tree_round", true, 2),
    ("prop_rock_arch_large", true, 1),
]

final class EnvironmentPropSystem {
    private var props: [SKSpriteNode] = []
    private let atlas = SKTextureAtlas(named: "environment_props")
    private let seed: UInt64

    init(seed: UInt64 = 42) {
        self.seed = seed
    }

    func setup(
        inBackground backgroundLayer: SKNode,
        inForeground foregroundLayer: SKNode
    ) {
        var rng = SeededRandom(seed: seed)
        let map = GameConfig.mapSize

        let totalPerTile = propDefinitions.reduce(0) { $0 + $1.count }

        var propSlots: [String] = []
        for def in propDefinitions {
            for _ in 0..<def.count { propSlots.append(def.name) }
        }
        propSlots.shuffle(using: &rng)

        let cols = Int(
            ceil(
                sqrt(
                    Double(totalPerTile) * Double(map.width)
                        / Double(map.height)
                )
            )
        )
        let rows = Int(ceil(Double(totalPerTile) / Double(cols)))
        let cellW = map.width / CGFloat(cols)
        let cellH = map.height / CGFloat(rows)

        for (i, propName) in propSlots.enumerated() {
            let col = i % cols
            let row = i / cols

            let jitterX =
                (CGFloat(rng.next() % 10000) / 10000.0 - 0.5) * cellW * 0.8
            let jitterY =
                (CGFloat(rng.next() % 10000) / 10000.0 - 0.5) * cellH * 0.8

            let x = -map.width / 2 + (CGFloat(col) + 0.5) * cellW + jitterX
            let y = -map.height / 2 + (CGFloat(row) + 0.5) * cellH + jitterY

            let texture = atlas.textureNamed(propName)
            texture.filteringMode = .nearest
            let size = texture.size()
            let scaledSize = CGSize(
                width: size.width * propScale,
                height: size.height * propScale
            )

            let sprite = SKSpriteNode(texture: texture, size: scaledSize)
            sprite.position = CGPoint(x: x, y: y)

            guard let def = propDefinitions.first(where: { $0.name == propName }) else { continue }
            let targetLayer = def.solid ? foregroundLayer : backgroundLayer
            sprite.zPosition = def.solid ? Layer.world : 0
            if def.solid {
                let body = SKPhysicsBody(
                    rectangleOf: CGSize(
                        width: scaledSize.width * solidPropBodyWidthFactor,
                        height: scaledSize.height * solidPropBodyHeightFactor
                    ),
                    center: CGPoint(x: 0, y: -scaledSize.height * solidPropBodyOffsetFactor)
                )
                body.isDynamic = false
                body.categoryBitMask = PhysicsCategory.decoration
                body.collisionBitMask =
                    PhysicsCategory.player | PhysicsCategory.enemy
                body.contactTestBitMask =
                    PhysicsCategory.playerProjectile
                    | PhysicsCategory.enemyProjectile
                sprite.physicsBody = body
            }

            targetLayer.addChild(sprite)
            props.append(sprite)
        }
    }

    func update(cameraPosition: CGPoint) {
        let hw = GameConfig.mapSize.width / 2
        let hh = GameConfig.mapSize.height / 2
        for prop in props {
            if prop.position.x - cameraPosition.x > hw {
                prop.position.x -= GameConfig.mapSize.width
            }
            if prop.position.x - cameraPosition.x < -hw {
                prop.position.x += GameConfig.mapSize.width
            }
            if prop.position.y - cameraPosition.y > hh {
                prop.position.y -= GameConfig.mapSize.height
            }
            if prop.position.y - cameraPosition.y < -hh {
                prop.position.y += GameConfig.mapSize.height
            }
        }
    }
}

private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
