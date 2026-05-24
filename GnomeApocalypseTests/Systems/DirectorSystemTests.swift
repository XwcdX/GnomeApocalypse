import Testing
import Foundation
@testable import GnomeApocalypse

@Suite("DirectorSystem")
struct DirectorSystemTests {
    @Test("initialises at minimum budget")
    func initialisesAtMinBudget() {
        let director = DirectorSystem()
        #expect(director.currentBudget == GameConfig.directorMinBudget)
        #expect(director.isBossStageActive == false)
    }

    @Test("high kills + low damage increases budget")
    func highKillsLowDamageIncreasesBudget() {
        let director = makeDirectorWithSignal(kills: highKillCount(), isHurt: false)
        let before = director.currentBudget
        director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        #expect(director.currentBudget > before)
    }

    @Test("low kills + high damage decreases budget")
    func lowKillsHighDamageDecreasesBudget() {
        let director = DirectorSystem()
        for _ in 0..<5 {
            for _ in 0..<highKillCount() { director.recordKill() }
            director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        }
        let before = director.currentBudget
        #expect(before > GameConfig.directorMinBudget)
        for _ in 0..<Int(GameConfig.directorRollingWindowDuration / GameConfig.directorPollInterval) {
            director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        }
        director.updatePlayerHealthFraction(0.1) // Player is hurt
        let beforeDecrease = director.currentBudget
        director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        #expect(director.currentBudget < beforeDecrease)
    }

    @Test("low kills + low damage increases budget by passive step")
    func lowKillsLowDamageIncreasesByPassiveStep() {
        let director = DirectorSystem()
        let before = director.currentBudget
        director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        #expect(director.currentBudget == before + GameConfig.directorPassiveStep)
    }

    @Test("high kills + player is hurt increases budget by passive step")
    func highKillsPlayerIsHurtIncreasesByPassiveStep() {
        let director = makeDirectorWithSignal(kills: highKillCount(), isHurt: true)
        let before = director.currentBudget
        director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        #expect(director.currentBudget == before + GameConfig.directorPassiveStep)
    }

    @Test("budget never drops below minimum")
    func budgetNeverDropsBelowMinimum() {
        let director = DirectorSystem()
        director.updatePlayerHealthFraction(0.1) // Player is hurt
        for _ in 0..<20 {
            director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        }
        #expect(director.currentBudget >= GameConfig.directorMinBudget)
    }

    @Test("budget never exceeds maximum")
    func budgetNeverExceedsMaximum() {
        let director = DirectorSystem()
        for _ in 0..<100 {
            for _ in 0..<highKillCount() { director.recordKill() }
            director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        }
        #expect(director.currentBudget <= GameConfig.directorMaxBudget)
    }

    @Test("old kill events outside rolling window are evicted")
    func oldKillEventsAreEvicted() {
        let director = DirectorSystem()
        for _ in 0..<highKillCount() { director.recordKill() }
        
        // Update 4 times to reach 20.0s (just before eviction of kills recorded at 0s)
        for _ in 0..<4 {
            director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        }
        let budgetBeforeEviction = director.currentBudget
        
        // Update 5th time to reach 25.0s (eviction occurs because 0s < 25.0s - 20.0s = 5.0s)
        director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        
        // Check that budget increased only by the passive step (1) rather than the active step (20)
        #expect(director.currentBudget == budgetBeforeEviction + GameConfig.directorPassiveStep)
    }

    @Test("boss stage activates after bossSpawnInterval")
    func bossStageActivatesAfterInterval() {
        let director = DirectorSystem()
        #expect(director.isBossStageActive == false)
        director.update(deltaTime: GameConfig.bossSpawnInterval, activeBudgetUsed: 0)
        #expect(director.isBossStageActive == true)
    }

    @Test("boss stage deactivates on recordBossDeath")
    func bossStageDeactivatesOnBossDeath() {
        let director = DirectorSystem()
        director.update(deltaTime: GameConfig.bossSpawnInterval, activeBudgetUsed: 0)
        #expect(director.isBossStageActive == true)
        director.recordBossDeath()
        #expect(director.isBossStageActive == false)
    }

    @Test("boss stage does not re-trigger while already active")
    func bossStageDoesNotRetriggerWhileActive() {
        let director = DirectorSystem()
        director.update(deltaTime: GameConfig.bossSpawnInterval, activeBudgetUsed: 0)
        #expect(director.isBossStageActive == true)
        director.update(deltaTime: GameConfig.bossSpawnInterval, activeBudgetUsed: 0)
        #expect(director.isBossStageActive == true)
    }

    private func makeDirectorWithSignal(kills: Int, isHurt: Bool) -> DirectorSystem {
        let director = DirectorSystem()
        for _ in 0..<kills { director.recordKill() }
        director.updatePlayerHealthFraction(isHurt ? 0.1 : 1.0)
        return director
    }

    private func highKillCount() -> Int {
        Int(ceil(GameConfig.directorKillRateThreshold * GameConfig.directorRollingWindowDuration)) + 1
    }
}

