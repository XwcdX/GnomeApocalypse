import Testing
import CoreGraphics

@testable import Greed

@Suite("LevelComponent")
struct LevelComponentTests {
    @Test("initialization sets level 1 with zero XP")
    func initializationSetsDefaults() {
        let level = LevelComponent(xpThreshold: 100)
        #expect(level.currentLevel == 1)
        #expect(level.currentXP == 0)
        #expect(level.xpThreshold == 100)
    }
    
    @Test("addXP increases current XP")
    func addXPIncreasesCurrentXP() {
        var level = LevelComponent(xpThreshold: 100)
        let leveledUp = level.addXP(50)
        #expect(level.currentXP == 50)
        #expect(leveledUp == false)
    }
    
    @Test("addXP triggers level up when threshold reached")
    func addXPTriggersLevelUp() {
        var level = LevelComponent(xpThreshold: 100)
        level.addXP(80)
        
        let leveledUp = level.addXP(30)
        #expect(leveledUp == true)
        #expect(level.currentLevel == 2)
        #expect(level.currentXP == 10)
    }
    
    @Test("addXP returns true on level up")
    func addXPReturnsTrueOnLevelUp() {
        var level = LevelComponent(xpThreshold: 100)
        let result = level.addXP(100)
        #expect(result == true)
        #expect(level.currentLevel == 2)
    }
    
    @Test("addXP increases threshold after level up")
    func addXPIncreasesThreshold() {
        var level = LevelComponent(xpThreshold: 100)
        level.addXP(100)
        
        let expectedThreshold = Int(100.0 * 1.4)
        #expect(level.xpThreshold == expectedThreshold)
    }
    
    @Test("addXP handles multiple level ups in one call")
    func addXPHandlesMultipleLevelUps() {
        var level = LevelComponent(xpThreshold: 100)
        level.addXP(250)
        
        #expect(level.currentLevel == 3)
        #expect(level.currentXP == 10)
        #expect(level.xpThreshold == 196)
    }
    
    @Test("addXP ignores zero or negative amounts")
    func addXPIgnoresInvalidAmounts() {
        var level = LevelComponent(xpThreshold: 100)
        
        var result = level.addXP(0)
        #expect(result == false)
        #expect(level.currentXP == 0)
        
        result = level.addXP(-10)
        #expect(result == false)
        #expect(level.currentXP == 0)
    }
    
    @Test("xpFraction returns correct progress")
    func xpFractionReturnsCorrectProgress() {
        var level = LevelComponent(xpThreshold: 100)
        #expect(level.xpFraction == 0.0)
        
        level.addXP(25)
        #expect(level.xpFraction == 0.25)
        
        level.addXP(50)
        #expect(level.xpFraction == 0.75)
        
        level.addXP(25)
        let expectedFraction = CGFloat(0) / CGFloat(140)
        #expect(level.xpFraction == expectedFraction)
    }
    
    @Test("level progression increases threshold exponentially")
    func levelProgressionIncreasesThresholdExponentially() {
        var level = LevelComponent(xpThreshold: 100)
        
        level.addXP(100)
        let threshold2 = level.xpThreshold
        #expect(threshold2 == 140)
        
        level.addXP(140)
        let threshold3 = level.xpThreshold
        #expect(threshold3 == 196)
    }
}
