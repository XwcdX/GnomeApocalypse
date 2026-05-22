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
        case boss = "sfx_boss_appear"
    }

    enum SFX: String, CaseIterable {
        case hit = "sfx_hit"
        case death = "sfx_death"
        case levelUp = "sfx_level_up"
        case orbCollect = "sfx_orb_collect"
        case mistExplosion = "sfx_mist_explosion"
        case bossAppear = "sfx_boss_appear"
        case pickPower = "sfx_pick_power"
        case lightning = "sfx_lightning"
        case bossAttack = "sfx_boss_attack"
    }

    private var musicPlayers: [Music: AVAudioPlayer] = [:]
    private var sfxPlayers: [SFX: AVAudioPlayer] = [:]
    private var currentMusic: Music?
    private var isSFXEnabled = true
    private var isDeathExclusiveMode = false

    // Centralized mix values (0.0...1.0). Tune these to balance each sound.
    private var musicVolumes: [Music: Float] = [
        .background: 0.45,
        .boss: 0.60
    ]

    private var sfxVolumes: [SFX: Float] = [
        .hit: 0.55,
        .death: 1.0,
        .levelUp: 0.90,
        .orbCollect: 0.15,
        .mistExplosion: 0.10,
        .bossAppear: 0.85,
        .pickPower: 0.90,
        .lightning: 0.20
        .bossAttack: 0.80
    ]

    private init() {}

    func preloadAll(bundle: Bundle = .main) {
        Music.allCases.forEach { preloadMusic($0, bundle: bundle) }
        SFX.allCases.forEach { preloadSFX($0, bundle: bundle) }
    }

    func playBackgroundMusic() {
        playMusic(.background)
    }

    func playMusic(_ music: Music) {
        guard currentMusic != music else { return }

        stopAllMusic()

        guard let player = musicPlayers[music] else {
            Log.warning("AudioManager: missing preloaded music \(music.rawValue)")
            return
        }

        player.numberOfLoops = -1
        player.currentTime = 0
        player.play()
        currentMusic = music
    }

    func stopBackgroundMusic() {
        if currentMusic == .background {
            stopAllMusic()
            return
        }

        guard let player = musicPlayers[.background] else { return }
        player.stop()
        player.currentTime = 0
    }

    func play(_ sfx: SFX) {
        guard isSFXEnabled,
              (!isDeathExclusiveMode || sfx == .death),
              let player = sfxPlayers[sfx]
        else { return }

        player.currentTime = 0
        player.play()
    }

    func playDeathExclusively() {
        guard let deathPlayer = sfxPlayers[.death] else { return }

        for player in sfxPlayers.values where player !== deathPlayer {
            if player.isPlaying {
                player.stop()
                player.currentTime = 0
            }
        }

        isDeathExclusiveMode = true
        isSFXEnabled = true
        deathPlayer.currentTime = 0
        deathPlayer.play()
    }

    func setSFXEnabled(_ isEnabled: Bool) {
        isSFXEnabled = isEnabled
        if isEnabled {
            isDeathExclusiveMode = false
            return
        }

        for player in sfxPlayers.values {
            if player.isPlaying {
                player.stop()
                player.currentTime = 0
            }
        }
    }

    func setMusicVolume(_ volume: Float, for music: Music) {
        let clamped = max(0, min(volume, 1))
        musicVolumes[music] = clamped
        musicPlayers[music]?.volume = clamped
    }

    func setSFXVolume(_ volume: Float, for sfx: SFX) {
        let clamped = max(0, min(volume, 1))
        sfxVolumes[sfx] = clamped
        sfxPlayers[sfx]?.volume = clamped
    }

    func setMasterVolumes(music: Float, sfx: Float) {
        let musicClamped = max(0, min(music, 1))
        let sfxClamped = max(0, min(sfx, 1))

        for key in musicVolumes.keys {
            setMusicVolume(musicClamped, for: key)
        }
        for key in sfxVolumes.keys {
            setSFXVolume(sfxClamped, for: key)
        }
    }

    func stopAllMusic() {
        for player in musicPlayers.values {
            player.stop()
            player.currentTime = 0
        }
        currentMusic = nil
    }

    private func preloadMusic(_ music: Music, bundle: Bundle) {
        guard musicPlayers[music] == nil,
              let player = makePlayer(assetName: music.rawValue, bundle: bundle)
        else { return }

        player.numberOfLoops = -1
        player.volume = musicVolumes[music] ?? 1
        musicPlayers[music] = player
    }

    private func preloadSFX(_ sfx: SFX, bundle: Bundle) {
        guard sfxPlayers[sfx] == nil,
              let player = makePlayer(assetName: sfx.rawValue, bundle: bundle)
        else { return }

        player.volume = sfxVolumes[sfx] ?? 1
        sfxPlayers[sfx] = player
    }

    private func makePlayer(assetName: String, bundle: Bundle) -> AVAudioPlayer? {
        guard let asset = NSDataAsset(name: assetName, bundle: bundle) else {
            Log.warning("AudioManager: missing audio asset \(assetName) in app bundle")
            return nil
        }

        do {
            let player = try AVAudioPlayer(data: asset.data)
            player.prepareToPlay()
            return player
        } catch {
            Log.warning("AudioManager: failed to preload \(assetName): \(error.localizedDescription)")
            return nil
        }
    }
}
