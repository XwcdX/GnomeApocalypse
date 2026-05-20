import SpriteKit

final class GameAssetPreloader {
    static let shared = GameAssetPreloader()

    private(set) var isReady = false
    private var isPreloading = false
    private var completions: [() -> Void] = []

    private let atlasNames = [
        "luminous_wisp",
        "grove",
        "grumble",
        "grand",
        "player_projectile",
        "orbiting_knife",
        "lightning_strike",
        "poisonous_mist",
        "forest_essence_mutation",
        "environment_props"
    ]

    private let textureNames = [
        "tile_ground",
        "Icon_luminous_wisp",
        "xp_bar_frame",
        "xp_bar_fill",
        "health_bar_frame",
        "health_bar_fill",
        "WASD",
        "Cursor",
        "Left_analog",
        "Right_analog",
        "projectile_enemy_grove",
        "projectile_enemy_grumble",
        "forest_essence_small",
        "forest_essence_grown",
        "forest_essence_red",
        "icon_ancient_tome",
        "icon_life_bloom",
        "icon_lightning_strike",
        "icon_orbiting_weapon",
        "icon_poisonous_mist",
        "icon_spirit_fruit"
    ]

    private init() {}

    func preloadGameplayAssets(completion: (() -> Void)? = nil) {
        if isReady {
            completion?()
            return
        }

        if let completion {
            completions.append(completion)
        }

        guard !isPreloading else { return }
        isPreloading = true

        let atlases = atlasNames.map { SKTextureAtlas(named: $0) }
        SKTextureAtlas.preloadTextureAtlases(atlases) { [weak self] in
            guard let self else { return }
            let textures = self.textureNames.map { name -> SKTexture in
                let texture = SKTexture(imageNamed: name)
                texture.filteringMode = .nearest
                return texture
            }
            SKTexture.preload(textures) { [weak self] in
                DispatchQueue.main.async {
                    self?.finishPreloading()
                }
            }
        }
    }

    private func finishPreloading() {
        guard !isReady else { return }
        isReady = true
        isPreloading = false

        let pendingCompletions = completions
        completions.removeAll()
        pendingCompletions.forEach { $0() }
    }
}
