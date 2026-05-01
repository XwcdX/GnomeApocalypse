// All UInt32 bitmask constants for SpriteKit physics collision and contact
// detection. Every entity and the CollisionSystem reference these constants.
//
// Collision matrix intent (CollisionSystem handles all routing):
//   playerProjectile  ↔ enemy            → damage enemy
//   enemyProjectile   ↔ player           → damage player (shield blocks)
//   player            ↔ forestEssenceOrb → collect orb
//   shield            ↔ enemy            → physics push impulse
//   shield            ↔ player           → physics push impulse (other players)
//   shield            ↔ enemyProjectile  → destroy projectile
//   sideQuestButton   ↔ player           → begin proximity activation timer
//   sideQuestButton   has NO collision with enemy - enemies cannot block or deactivate buttons

import Foundation

struct PhysicsCategory {
    /// No collision category.
    static let none: UInt32 = 0

    /// The player-controlled forest spirit entity.
    static let player: UInt32 = 0b00000001

    /// Any gnome entity (SmallGnome, MiniBossGnome, BossGnome).
    static let enemy: UInt32 = 0b00000010

    /// Projectiles fired by the player.
    static let playerProjectile: UInt32 = 0b00000100

    /// Projectiles fired by gnomes.
    static let enemyProjectile: UInt32 = 0b00001000

    /// Forest Essence orbs dropped by purified gnomes.
    static let forestEssenceOrb: UInt32 = 0b00010000

    /// The expanding shield radius generated during a player's level-up sequence.
    static let shield: UInt32 = 0b00100000

    /// Proximity activation buttons placed by the SideQuestComponent.
    static let sideQuestButton: UInt32 = 0b01000000
}
