import Testing
import CoreGraphics

@testable import Greed

@Suite("HealthComponent")
struct HealthComponentTests {
    @Test("initialization sets current to maximum")
    func initializationSetsCurrentToMaximum() {
        let health = HealthComponent(maximum: 100)
        #expect(health.current == 100)
        #expect(health.maximum == 100)
        #expect(health.isDead == false)
        #expect(health.isFullHealth == true)
    }
    
    @Test("takeDamage reduces current health")
    func takeDamageReducesCurrentHealth() {
        var health = HealthComponent(maximum: 100)
        health.takeDamage(30)
        #expect(health.current == 70)
        #expect(health.isDead == false)
    }
    
    @Test("takeDamage clamps at zero")
    func takeDamageClamps() {
        var health = HealthComponent(maximum: 100)
        health.takeDamage(150)
        #expect(health.current == 0)
        #expect(health.isDead == true)
    }
    
    @Test("takeDamage triggers onDeath when health reaches zero")
    func takeDamageTriggersOnDeath() {
        var health = HealthComponent(maximum: 50)
        var deathCalled = false
        health.onDeath = { deathCalled = true }
        
        health.takeDamage(50)
        #expect(deathCalled == true)
        #expect(health.isDead == true)
    }
    
    @Test("takeDamage ignores zero or negative amounts")
    func takeDamageIgnoresInvalidAmounts() {
        var health = HealthComponent(maximum: 100)
        health.takeDamage(0)
        #expect(health.current == 100)
        
        health.takeDamage(-10)
        #expect(health.current == 100)
    }
    
    @Test("takeDamage does nothing when already dead")
    func takeDamageIgnoresWhenDead() {
        var health = HealthComponent(maximum: 100)
        health.takeDamage(100)
        #expect(health.isDead == true)
        
        health.takeDamage(50)
        #expect(health.current == 0)
    }
    
    @Test("heal increases current health")
    func healIncreasesCurrentHealth() {
        var health = HealthComponent(maximum: 100)
        health.takeDamage(40)
        health.heal(20)
        #expect(health.current == 80)
    }
    
    @Test("heal clamps at maximum")
    func healClampsAtMaximum() {
        var health = HealthComponent(maximum: 100)
        health.takeDamage(30)
        health.heal(50)
        #expect(health.current == 100)
        #expect(health.isFullHealth == true)
    }
    
    @Test("heal ignores zero or negative amounts")
    func healIgnoresInvalidAmounts() {
        var health = HealthComponent(maximum: 100)
        health.takeDamage(30)
        
        health.heal(0)
        #expect(health.current == 70)
        
        health.heal(-10)
        #expect(health.current == 70)
    }
    
    @Test("heal does nothing when dead")
    func healIgnoresWhenDead() {
        var health = HealthComponent(maximum: 100)
        health.takeDamage(100)
        health.heal(50)
        #expect(health.current == 0)
        #expect(health.isDead == true)
    }
    
    @Test("heal does nothing when at full health")
    func healIgnoresWhenFullHealth() {
        var health = HealthComponent(maximum: 100)
        health.heal(10)
        #expect(health.current == 100)
    }
    
    @Test("fraction returns correct percentage")
    func fractionReturnsCorrectPercentage() {
        var health = HealthComponent(maximum: 100)
        #expect(health.fraction == 1.0)
        
        health.takeDamage(50)
        #expect(health.fraction == 0.5)
        
        health.takeDamage(25)
        #expect(health.fraction == 0.25)
        
        health.takeDamage(25)
        #expect(health.fraction == 0.0)
    }
}
