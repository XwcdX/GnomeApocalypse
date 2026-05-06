import Foundation

struct HealthComponent {
    private(set) var current: Int
    let maximum: Int
    var onDeath: (() -> Void)?
    
    init(maximum: Int) {
        self.maximum = maximum
        self.current = maximum
    }
    
    mutating func takeDamage(_ amount: Int) {
        guard amount > 0, !isDead else { return }
        current = max(0, current - amount)
        if isDead { onDeath?() }
    }
    
    mutating func heal(_ amount: Int) {
        guard amount > 0, !isDead, current < maximum else { return }
        current = min(maximum, current + amount)
    }
    
    var isDead: Bool { current <= 0 }
    var fraction: CGFloat { CGFloat(current) / CGFloat(maximum) }
    var isFullHealth: Bool { current == maximum }
}
