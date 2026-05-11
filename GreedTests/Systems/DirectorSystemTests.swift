import Testing
import Foundation
@testable import Greed

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
        let director = makeDirectorWithSignal(kills: highKillCount(), damage: 0)
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
        director.recordDamageTaken(highDamageAmount())
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

    @Test("high kills + high damage holds budget steady")
    func highKillsHighDamageHoldsBudget() {
        let director = makeDirectorWithSignal(kills: highKillCount(), damage: highDamageAmount())
        let before = director.currentBudget
        director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        #expect(director.currentBudget == before)
    }

    @Test("budget never drops below minimum")
    func budgetNeverDropsBelowMinimum() {
        let director = DirectorSystem()
        for _ in 0..<20 {
            director.recordDamageTaken(highDamageAmount())
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
        let pollsToEvict = Int(GameConfig.directorRollingWindowDuration / GameConfig.directorPollInterval) + 1
        for _ in 0..<pollsToEvict {
            director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        }
        let budgetAfterEviction = director.currentBudget
        director.update(deltaTime: GameConfig.directorPollInterval, activeBudgetUsed: 0)
        #expect(director.currentBudget == budgetAfterEviction + GameConfig.directorPassiveStep)
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

    private func makeDirectorWithSignal(kills: Int, damage: Int) -> DirectorSystem {
        let director = DirectorSystem()
        for _ in 0..<kills { director.recordKill() }
        if damage > 0 { director.recordDamageTaken(damage) }
        return director
    }

    private func highKillCount() -> Int {
        Int(ceil(GameConfig.directorKillRateThreshold * GameConfig.directorRollingWindowDuration)) + 1
    }

    private func highDamageAmount() -> Int {
        Int(ceil(GameConfig.directorDamageRateThreshold * GameConfig.directorRollingWindowDuration)) + 1
    }
}
