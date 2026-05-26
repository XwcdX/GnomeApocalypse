import SpriteKit

/// Shared preloader for gameplay atlases and one-off textures used after the home screen.
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
        "warden_thorns",
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
        "guide_wasd",
        "guide_cursor",
        "guide_controller_arrow",
        "guide_left_analog",
        "guide_right_analog",
        "projectile_enemy_grove",
        "projectile_enemy_grumble",
        "forest_essence_blue",
        "forest_essence_purple",
        "forest_essence_red",
        "icon_ancient_tome",
        "icon_life_bloom",
        "icon_lightning_strike",
        "icon_warden_thorns",
        "icon_poisonous_mist",
        "icon_spirit_fruit",
        "game_over_score_bg",
        "game_over_restart_button"
    ]

    private init() {}

    /// Starts one preload pass and calls every queued completion on the main queue when ready.
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
