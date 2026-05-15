import AVFoundation
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

final class AudioManager {
    static let shared = AudioManager()

    enum Music: String, CaseIterable {
        case background = "music_background"
    }

    enum SFX: String, CaseIterable {
        case hit = "sfx_hit"
        case death = "sfx_death"
        case levelUp = "sfx_level_up"
        case orbCollect = "sfx_orb_collect"
        case mistExplosion = "sfx_mist_explosion"
        case bossAppear = "sfx_boss_appear"
        case lightningStrike = "sfx_lightning_strike"
        case orbitingSpellHit = "sfx_orbiting_spell_hit"
    }

    private var musicPlayers: [Music: AVAudioPlayer] = [:]
    private var sfxPlayers: [SFX: AVAudioPlayer] = [:]

    private init() {}

    func preloadAll(bundle: Bundle = .main) {
        Music.allCases.forEach { preloadMusic($0, bundle: bundle) }
        SFX.allCases.forEach { preloadSFX($0, bundle: bundle) }
    }

    func playBackgroundMusic() {
        guard let player = musicPlayers[.background], !player.isPlaying else { return }
        player.numberOfLoops = -1
        player.currentTime = 0
        player.play()
    }

    func stopBackgroundMusic() {
        guard let player = musicPlayers[.background] else { return }
        player.stop()
        player.currentTime = 0
    }

    func play(_ sfx: SFX) {
        guard let player = sfxPlayers[sfx] else { return }
        player.currentTime = 0
        player.play()
    }

    private func preloadMusic(_ music: Music, bundle: Bundle) {
        guard musicPlayers[music] == nil,
              let player = makePlayer(assetName: music.rawValue, bundle: bundle)
        else { return }

        player.numberOfLoops = -1
        musicPlayers[music] = player
    }

    private func preloadSFX(_ sfx: SFX, bundle: Bundle) {
        guard sfxPlayers[sfx] == nil,
              let player = makePlayer(assetName: sfx.rawValue, bundle: bundle)
        else { return }

        sfxPlayers[sfx] = player
    }

    private func makePlayer(assetName: String, bundle: Bundle) -> AVAudioPlayer? {
        guard let asset = NSDataAsset(name: assetName, bundle: bundle) else { return nil }

        do {
            let player = try AVAudioPlayer(data: asset.data)
            player.prepareToPlay()
            return player
        } catch {
            Log.error("AudioManager: failed to load \(assetName): \(error.localizedDescription)")
            return nil
        }
    }
}
