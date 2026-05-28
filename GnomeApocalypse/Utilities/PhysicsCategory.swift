import Foundation

/// SpriteKit physics bit masks shared by entities, projectiles, pickups, and collisions.
enum PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 0b00000001
    static let enemy: UInt32 = 0b00000010
    static let playerProjectile: UInt32 = 0b00000100
    static let enemyProjectile: UInt32 = 0b00001000
    static let forestEssenceOrb: UInt32 = 0b00010000
    static let shield: UInt32 = 0b00100000
    static let sideQuestButton: UInt32 = 0b01000000
    static let decoration:       UInt32 = 0b10000000
}
