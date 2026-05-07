# Skill System Design Guide

## Overview

Skills and Power-ups are **two separate pools** with independent caps, but drawn together into a **single unified offer** each level-up.

| Pool | Cap | Max Level per Item | Total Max Level-ups |
|------|-----|--------------------|---------------------|
| Skills (Active) | 3 | 3 | 9 |
| Power-ups (Passive) | 3 | 3 | 9 |

**Level-3 cap:** Only `GameConfig.maxLevel3Items` (3) items across both pools combined can reach level 3. Once 3 items are maxed, no further upgrades to level 3 are offered — items at level 2 are treated as maxed for draw purposes.

- Player builds a loadout of up to 3 distinct skills + 3 distinct power-ups per run
- Once a pool's cap is reached, draws come exclusively from the other pool
- Player can **respin** if they dislike the current offer

---

## Skills (Active Weapons)

### 1. Orbiting Spell
**Behavior:** Orbs rotate clockwise around the player, dealing damage on collision.

| Level | Orbs |
|-------|------|
| 1 | 1 orb |
| 2 | 2 orbs |
| 3 | 3 orbs |

**Config:**
- Rotation speed: `GameConfig.orbitRotationSpeed` (2.0 rad/s)
- Orbit radius: `GameConfig.orbitRadius` (80px)
- Damage: `GameConfig.orbitDamage` (15)
- Per-enemy cooldown: `GameConfig.orbitCooldownPerEnemy` (1.0s)
  - After an orb hits an enemy, that enemy is immune to **that specific orb** for 1s
  - Other orbs can still hit the same enemy immediately
  - Same orb can hit other enemies immediately

---

### 2. Lightning Strike
**Behavior:** Auto-cast on a random enemy at set intervals.

| Level | Behavior |
|-------|----------|
| 1 | Single target, base AoE (100px) |
| 2 | Chains to 2 enemies, larger AoE (200px) |
| 3 | Chains to 3 enemies, largest AoE (300px) |

**Config:**
- Cooldown: `GameConfig.lightningCooldown` (3.0s)
- Base damage: `GameConfig.lightningBaseDamage` (50)
- AoE radius: `GameConfig.lightningAoERadius` × level (100 / 200 / 300)
- Targets random enemy using toroidal distance

---

### 3. Poisonous Mist
**Behavior:** Spawns at a random position in camera view, applying DoT to enemies inside.

| Level | Damage | Duration |
|-------|--------|----------|
| 1 | Base (5/tick) | Base (5.0s) |
| 2 | Base (5/tick) | +50% (7.5s) |
| 3 | 2× (10/tick) | +50% (7.5s) |

**Config:**
- Base damage: `GameConfig.mistBaseDamage` (5 per tick)
- Base duration: `GameConfig.mistBaseDuration` (5.0s)
- Tick interval: `GameConfig.mistTickInterval` (0.5s)
- Radius: `GameConfig.mistRadius` (120px)
- Spawns randomly within camera viewport
- After duration expires, a new mist spawns at a different location

---

## Power-ups (Passive Stats)

### 1. Ancient Tome — Attack Speed

| Level | Effect |
|-------|--------|
| 1 | +10% attack speed (1.1×) |
| 2 | +20% attack speed (1.2×) |
| 3 | +30% attack speed (1.3×) |

---

### 2. Spirit Fruit — Movement Speed

| Level | Effect |
|-------|--------|
| 1 | +10% movement speed (1.1×) |
| 2 | +20% movement speed (1.2×) |
| 3 | +30% movement speed (1.3×) |

---

### 3. Life Bloom — Max Health

| Level | Effect |
|-------|--------|
| 1 | +20 max health |
| 2 | +40 max health |
| 3 | +60 max health |

**Config:** `GameConfig.healthBoostPerLevel` (20)

---

## Draw Logic

### Unified Pool Draw

Every level-up, the system:
1. Collects all available candidates from **both** skill and power-up pools combined
2. Randomly picks **3** from that combined list
3. A candidate is available if: it is not maxed (level < 3) AND its pool cap is not exceeded by new unlocks

### Pool Cap Behavior

| Situation | Result |
|-----------|--------|
| Player has < 3 distinct skills | New skills can appear in draw |
| Player has = 3 distinct skills | No new skills offered; upgrades to owned skills still appear |
| Player has < 3 distinct power-ups | New power-ups can appear in draw |
| Player has = 3 distinct power-ups | No new power-ups offered; upgrades to owned power-ups still appear |
| 3 items already at level 3 (across both pools) | Items at level 2 treated as maxed; no level-3 upgrades offered |
| Both pools fully exhausted (all owned items treated as maxed) | No draw — game handles this edge case |

### Natural Weighting

With a large pool (e.g. 10 skills, 5 power-ups) the draw is naturally weighted by availability:

- Early game: lots of new skills and power-ups available → diverse offers
- Mid game: skill cap hit → draws shift toward power-up unlocks + owned upgrades
- Late game: only upgrades remain → offers concentrate on deepening your build

No artificial balancing needed — the math handles it.

### Respin

- Player may respin the current offer to get a new random draw from the same available pool
- Respin can be limited (e.g. 1 free per level-up, extras cost a resource) or unlimited — designer's choice
- Respin does **not** reset or change what is available, only re-rolls which 3 are shown

---

## Applying Effects — Direct Mutation Pattern

> ✅ Apply the effect **once** when the player picks a skill or power-up.  
> ✅ Store the result as a **plain property** on `PlayerEntity`.  
> ✅ Read that property whenever the game needs it (spawning orbs, firing lightning, etc.).  
> ❌ Do NOT store effects in a dictionary and recalculate from it every frame.

### PlayerEntity Properties

```swift
// Skills — set once on pick, read by GameScene
var orbitCount: Int = 0
var lightningChainCount: Int = 0
var mistDamage: Int = 0
var mistDuration: TimeInterval = 0

// Power-ups — set once on pick, read by movement/attack systems
var attackSpeedMultiplier: Float = 1.0
var movementSpeedMultiplier: Float = 1.0
// max health mutated directly on health component
```

### Applying on Pick

```swift
func applySkill(_ skill: Skill, at level: Int) {
    switch skill.effect(at: level) {
    case .orbitingSpell(let count):
        orbitCount = count
    case .lightningStrike(let chain):
        lightningChainCount = chain
    case .poisonousMist(let dmg, let dur):
        mistDamage = dmg
        mistDuration = dur
    case .increaseAttackSpeed(let m):
        attackSpeedMultiplier = m
    case .increaseMovementSpeed(let m):
        movementSpeedMultiplier = m
    case .increaseMaxHealth(let amount):
        health.maximum += amount
        health.current += amount
    }
}
```

### GameScene reads properties, never recalculates

```swift
// ✅ Correct
updateOrbitingSpells(count: player.orbitCount)
movePlayer(speed: baseSpeed * player.movementSpeedMultiplier)

// ❌ Wrong
let effect = player.activeSkills["orbiting_spell"] // no dictionaries
```

---

## GameScene Responsibilities

- Spawn and update orbiting spell positions each frame using `player.orbitCount`
- Auto-fire lightning at intervals using `player.lightningChainCount`
- Spawn/respawn mist clouds using `player.mistDamage` and `player.mistDuration`
- Track per-enemy orbit cooldowns
- Apply `player.attackSpeedMultiplier` to all relevant attack timers

---

## Scaling Guide

| Situation | Action |
|-----------|--------|
| Add a new skill | Add to skill pool — cap stays at 3 |
| Add a new power-up | Add to power-up pool — cap stays at 3 |
| Raise cap later | Bump `GameConfig.maxSkillSlots` or `GameConfig.maxPowerUpSlots` |
| Add rare/exclusive skills | Add a rarity tier to draw logic |

---

## Testing Checklist

- [ ] Draw never offers a 4th new skill when player already has 3 distinct skills
- [ ] Draw never offers a 4th new power-up when player already has 3 distinct power-ups
- [ ] Draw never offers a maxed item (level 3, or level 2 when `maxLevel3Items` cap is reached)
- [ ] Draw correctly pulls from combined pool when both pools have availability
- [ ] Draw pulls only from power-up pool when skill cap is hit
- [ ] Draw pulls only from skill pool when power-up cap is hit
- [ ] Draw returns empty when all owned items are maxed (respecting `maxLevel3Items` cap)
- [ ] Respin produces a different draw from the same available pool
- [ ] Skill properties on `PlayerEntity` update correctly on pick
- [ ] Power-up properties on `PlayerEntity` update correctly on pick
- [ ] No per-frame recalculation — properties mutated once on pick
- [ ] Mist level 2: base damage, 1.5× duration ✓
- [ ] Mist level 3: 2× damage AND 1.5× duration ✓
- [ ] Life Bloom stacks health correctly across levels
- [ ] `attackSpeedMultiplier` applied to all attack timers in GameScene
- [ ] `movementSpeedMultiplier` applied to player movement in GameScene