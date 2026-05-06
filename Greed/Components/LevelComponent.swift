import Foundation

struct LevelComponent {
    private(set) var currentLevel: Int = 1
    private(set) var currentXP: Int = 0
    private(set) var xpThreshold: Int
    var onLevelUp: ((_ newLevel: Int) -> Void)?

    init(xpThreshold: Int = GameConfig.baseXPThreshold) {
        self.xpThreshold = xpThreshold
    }

    @discardableResult
    mutating func addXP(_ amount: Int) -> Bool {
        guard amount > 0 else { return false }
        currentXP += amount
        
        var didLevelUp = false
        while currentXP >= xpThreshold {
            currentXP -= xpThreshold
            currentLevel += 1
            xpThreshold = Int(Double(xpThreshold) * GameConfig.xpThresholdGrowthFactor)
            onLevelUp?(currentLevel)
            didLevelUp = true
        }
        return didLevelUp
    }

    var xpFraction: CGFloat { CGFloat(currentXP) / CGFloat(xpThreshold) }
}
