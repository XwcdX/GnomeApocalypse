import Foundation

/// Dynamic difficulty controller for enemy budget and time-based boss-stage activation.
final class DirectorSystem {
    /// Current enemy budget that spawning systems must respect for regular enemies.
    private(set) var currentBudget: Int
    /// Whether the boss stage is active and regular spawning should pause.
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

    /// Advances budget timers and boss-stage state; `activeBudgetUsed` is currently informational.
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

    /// Records an enemy kill at the Director's internal clock for rolling-window kill rate.
    func recordKill() {
        killTimestamps.append(clock)
    }

    /// Ends the current boss stage so regular spawning and camera follow can resume.
    func recordBossDeath() {
        isBossStageActive = false
    }
    
    /// Updates the average player health fraction used as the current damage-pressure proxy.
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
