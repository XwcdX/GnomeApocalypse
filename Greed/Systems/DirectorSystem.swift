import Foundation

final class DirectorSystem {
    private(set) var currentBudget: Int
    private(set) var isBossStageActive: Bool = false

    private var killTimestamps: [TimeInterval] = []
    private var damageEvents: [(time: TimeInterval, amount: Int)] = []

    private var timePressureAccumulator: TimeInterval = 0
    
    private var pollAccumulator: TimeInterval = 0
    private var bossAccumulator: TimeInterval = 0
    private var clock: TimeInterval = 0
    
    private var playerHealthFraction: Double = 1.0

    init() {
        currentBudget = GameConfig.directorMinBudget
    }

    func update(deltaTime: TimeInterval, activeBudgetUsed: Int) {
        clock += deltaTime
        pollAccumulator += deltaTime
        bossAccumulator += deltaTime
        timePressureAccumulator += deltaTime
        
        if timePressureAccumulator >= GameConfig.directorTimePressureInterval {
            timePressureAccumulator = 0
            currentBudget = min(currentBudget + GameConfig.directorTimePressureStep, GameConfig.directorMaxBudget)
        }
        
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

    func recordBossDeath() {
        isBossStageActive = false
    }
    
    func updatePlayerHealthFraction(_ fraction: Double) {
        playerHealthFraction = fraction
    }

    private func evaluateAndAdjust() {
        let cutoff = clock - GameConfig.directorRollingWindowDuration

        killTimestamps.removeAll { $0 < cutoff }

        let killRate = Double(killTimestamps.count) / GameConfig.directorRollingWindowDuration
        let highKills = killRate > GameConfig.directorKillRateThreshold
        let playerIsHurt = playerHealthFraction < GameConfig.directorHealthThreshold

        if highKills && !playerIsHurt {
            currentBudget += GameConfig.directorBudgetStep
        } else if highKills && playerIsHurt {
            currentBudget += GameConfig.directorPassiveStep
        } else if !highKills && !playerIsHurt {
            currentBudget += GameConfig.directorPassiveStep
        } else if !highKills && playerIsHurt {
            currentBudget -= GameConfig.directorBudgetStep
        }

        let minBudget = GameConfig.directorMinBudget
        let maxBudget = GameConfig.directorMaxBudget
        currentBudget = min(max(currentBudget, minBudget), maxBudget)
    }
}
