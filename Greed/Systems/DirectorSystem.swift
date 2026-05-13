import Foundation

final class DirectorSystem {
    private(set) var currentBudget: Int
    private(set) var isBossStageActive: Bool = false

    private var killTimestamps: [TimeInterval] = []
    private var damageEvents: [(time: TimeInterval, amount: Int)] = []

    private var pollAccumulator: TimeInterval = 0
    private var bossAccumulator: TimeInterval = 0
    private var clock: TimeInterval = 0

    init() {
        currentBudget = GameConfig.directorMinBudget
    }

    func update(deltaTime: TimeInterval, activeBudgetUsed: Int) {
        clock += deltaTime
        pollAccumulator += deltaTime
        bossAccumulator += deltaTime

        while pollAccumulator >= GameConfig.directorPollInterval {
            pollAccumulator -= GameConfig.directorPollInterval
            evaluateAndAdjust()
        }

        if bossAccumulator >= GameConfig.bossSpawnInterval && !isBossStageActive {
            bossAccumulator = 0
            isBossStageActive = true
        }
    }

    func recordKill() {
        killTimestamps.append(clock)
    }

    func recordDamageTaken(_ amount: Int) {
        damageEvents.append((clock, amount))
    }

    func recordBossDeath() {
        isBossStageActive = false
    }

    private func evaluateAndAdjust() {
        let cutoff = clock - GameConfig.directorRollingWindowDuration

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
