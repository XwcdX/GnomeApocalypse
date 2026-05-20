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

### 1. Warden Thorns
**Behavior:** Thorns rotate clockwise around the player, dealing damage on collision.

| Level | Thorns |
|-------|------|
| 1 | 1 thorn |
| 2 | 2 thorns |
| 3 | 3 thorns |

**Config:**
- Rotation speed: `GameConfig.wardenThornRotationSpeed` (2.0 rad/s)
- Thorn radius: `GameConfig.wardenThornRadius` (80px)
- Damage: `GameConfig.wardenThornDamage` (15)
- Per-enemy cooldown: `GameConfig.wardenThornCooldownPerEnemy` (1.0s)
  - After a thorn hits an enemy, that enemy is immune to **that specific thorn** for 1s
  - Other thorns can still hit the same enemy immediately
  - Same thorn can hit other enemies immediately

---

### 2. Lightning Strike
**Behavior:** Auto-cast on random enemies at intervals. Each strike is an independent AoE on a random target — no chaining.

| Level | Cooldown | Strikes per cast |
|-------|----------|------------------|
| 1 | base | 1 |
| 2 | reduced | 1 |
| 3 | reduced | multi-strike (2) |

**Config:**
- Per-level cooldown: `SkillConfig.lightningCooldownByLevel` (`[3.0, 2.0, 1.5]`)
- Per-level strike count: `SkillConfig.lightningStrikeCountByLevel` (`[1, 1, 2]`)
- Base damage: `SkillConfig.lightningBaseDamage` (50)
- AoE radius: `SkillConfig.lightningAoERadius` (100, flat — does not scale with level)
- Each strike picks an independent random enemy (no replacement; falls back to repeats if pool too small)
- Targets enemies using toroidal distance

---

### 3. Poisonous Mist
**Behavior:** Clouds spawn at random positions in camera view, applying DoT to enemies inside. Each cloud lasts a fixed duration; new clouds respawn after a per-player cooldown.

| Level | Cooldown | Concurrent clouds |
|-------|----------|-------------------|
| 1 | base | 1 |
| 2 | reduced | 1 |
| 3 | reduced | multi-cloud (2) |

**Config:**
- Per-level cooldown: `SkillConfig.mistCooldownByLevel` (`[5.0, 3.5, 2.5]`)
- Per-level cloud count: `SkillConfig.mistCountByLevel` (`[1, 1, 2]`)
- Base damage: `SkillConfig.mistBaseDamage` (5 per tick, flat)
- Base duration: `SkillConfig.mistBaseDuration` (5.0s, flat)
- Tick interval: `SkillConfig.mistTickInterval` (0.5s)
- Radius: `SkillConfig.mistRadius` (120px)
- Each spawn picks a fresh random viewport position; per-player cooldown gates the next spawn while concurrent count < cap

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
> ✅ Read that property whenever the game needs it (spawning thorns, firing lightning, etc.).  
> ❌ Do NOT store effects in a dictionary and recalculate from it every frame.

### PlayerEntity Properties

```swift
// Skills — set once on pick, read by GameScene
var wardenThornCount: Int = 0
var lightningCooldown: TimeInterval = 0   // 0 = inactive
var lightningStrikeCount: Int = 0
var mistCooldown: TimeInterval = 0        // 0 = inactive
var mistCloudCount: Int = 0

// Power-ups — set once on pick, read by movement/attack systems
var attackSpeedMultiplier: Float = 1.0
var movementSpeedMultiplier: Float = 1.0
// max health mutated directly on health component
```

### Applying on Pick

```swift
func applySkill(_ skill: Skill, at level: Int) {
    switch skill.effect(at: level) {
    case .wardenThorns(let count):
        wardenThornCount = count
    case .lightningStrike(let cooldown, let strikeCount):
        lightningCooldown = cooldown
        lightningStrikeCount = strikeCount
    case .poisonousMist(let cooldown, let cloudCount):
        mistCooldown = cooldown
        mistCloudCount = cloudCount
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
updateWardenThorns(count: player.wardenThornCount)
movePlayer(speed: baseSpeed * player.movementSpeedMultiplier)

// ❌ Wrong
let effect = player.activeSkills["warden_thorns"] // no dictionaries
```

---

## GameScene Responsibilities

- Spawn and update Warden Thorns positions each frame using `player.wardenThornCount`
- Auto-fire lightning at `player.lightningCooldown`, firing `player.lightningStrikeCount` independent strikes per cast
- Spawn mist clouds up to `player.mistCloudCount` concurrently, gated by `player.mistCooldown` (per-player); each cloud uses `SkillConfig.mistBaseDamage` + `SkillConfig.mistBaseDuration`
- Track per-(thorn, enemy) cooldowns
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
- [ ] Lightning level 2: cooldown shorter than level 1 (single strike still)
- [ ] Lightning level 3: multiple strikes per cast against independent random enemies
- [ ] Mist level 2: cooldown shorter than level 1 (single concurrent cloud still)
- [ ] Mist level 3: two concurrent clouds in view at once
- [ ] Life Bloom stacks health correctly across levels
- [ ] `attackSpeedMultiplier` applied to all attack timers in GameScene
- [ ] `movementSpeedMultiplier` applied to player movement in GameScene
