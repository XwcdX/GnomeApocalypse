import Foundation

/// Mutable health state for entities that can be damaged, healed, or die.
struct HealthComponent {
    private(set) var current: Int
    var maximum: Int
    init(maximum: Int) {
        self.maximum = maximum
        self.current = maximum
    }

    /// Applies positive damage and returns `true` only when this hit reaches zero health.
    @discardableResult
    mutating func takeDamage(_ amount: Int) -> Bool {
        guard amount > 0, !isDead else { return false }
        current = max(0, current - amount)
        return isDead
    }
    
    /// Restores health up to `maximum`; dead entities cannot be healed by this component.
    mutating func heal(_ amount: Int) {
        guard amount > 0, !isDead, current < maximum else { return }
        current = min(maximum, current + amount)
    }
    
    /// Raises maximum and current health by the same positive amount.
    mutating func increaseMaximum(_ amount: Int) {
        guard amount > 0 else { return }
        maximum += amount
        current += amount
    }
    
    var isDead: Bool { current <= 0 }
    var fraction: CGFloat { CGFloat(current) / CGFloat(maximum) }
    var isFullHealth: Bool { current == maximum }
}
