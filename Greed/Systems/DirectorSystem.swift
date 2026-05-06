import Foundation
import QuartzCore

final class DirectorSystem {
    private(set) var currentBudget: Int
    private(set) var isBossStageActive: Bool = false
    
    private var killTimestamps: [TimeInterval] = []
    private var damageEvents: [(time: TimeInterval, amount: Int)] = []
    
    private var pollAccumulator: TimeInterval = 0
    private var bossAccumulator: TimeInterval = 0
    
    init() {
        currentBudget = GameConfig.directorMinBudget
    }
    
    func update(deltaTime: TimeInterval, activeBudgetUsed: Int) {
        pollAccumulator += deltaTime
        bossAccumulator += deltaTime
        
        if pollAccumulator >= GameConfig.directorPollInterval {
            pollAccumulator = 0
            evaluateAndAdjust()
        }
        
        if bossAccumulator >= GameConfig.bossSpawnInterval && !isBossStageActive {
            bossAccumulator = 0
            isBossStageActive = true
        }
    }
    
    func recordKill() {
        killTimestamps.append(CACurrentMediaTime())
    }
    
    func recordDamageTaken(_ amount: Int) {
        damageEvents.append((CACurrentMediaTime(), amount))
    }
    
    func recordBossDeath() {
        isBossStageActive = false
    }
    
    private func evaluateAndAdjust() {
        let now = CACurrentMediaTime()
        let cutoff = now - GameConfig.directorRollingWindowDuration
        
        killTimestamps.removeAll { $0 < cutoff }
        damageEvents.removeAll { $0.time < cutoff }
        
        let killRate = Double(killTimestamps.count) / GameConfig.directorRollingWindowDuration
        let totalDamage = damageEvents.reduce(0) { $0 + $1.amount }
        let damageRate = Double(totalDamage) / GameConfig.directorRollingWindowDuration
        
        let highKills = killRate > GameConfig.directorKillRateThreshold
        let highDamage = damageRate > GameConfig.directorDamageRateThreshold
        
        if highKills && !highDamage {
            currentBudget += GameConfig.directorBudgetStep
        } else if !highKills && highDamage {
            currentBudget -= GameConfig.directorBudgetStep
        } else if !highKills && !highDamage {
            currentBudget += GameConfig.directorPassiveStep
        }
        
        currentBudget = max(GameConfig.directorMinBudget, currentBudget)
        
        if currentBudget > GameConfig.directorMaxBudget - GameConfig.directorBudgetStep {
            let excess = currentBudget - GameConfig.directorMaxBudget
            if excess > 0 {
                currentBudget = GameConfig.directorMaxBudget
            }
        }
    }
}
