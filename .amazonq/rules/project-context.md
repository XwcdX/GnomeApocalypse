# Gnome Apocalypse — Project Context

## What Is This?

Gnome Apocalypse is a **hybrid offensive-defensive bullet hell** game exclusive to **macOS**. It is a survival-based game where the core tension is not just staying alive against enemies, but managing a dynamic Forest Essence economy that punishes passivity and rewards risk. Up to 4 players share the same screen using Bluetooth controllers.

The game is designed around a single, disciplined constraint called the **3-3-1 Rule**:
- **1 Game Loop:** Survival → Skill Selection → Death → Meta-Progression
- **3 Player Actions:** Move (WASD / left stick), Aim (mouse/trackpad / right stick), Select Skill (UI)
- **1 UVP:** The Exponential Greed System

---

## Setting & Lore

The grove has been consumed by a creeping supernatural **Mist**. Ancient gnomes that once lived peacefully within it have been awakened and corrupted by the Mist's influence, turning them hostile. Players take the role of **forest spirits** — luminous orbs, nymphs, and other manifestations of the grove's natural order — tasked with purifying the gnomes and restoring balance before the Mist spreads beyond recovery.

Gnomes are not destroyed when killed — they are purified. The Forest Essence they release is the residual Mist energy leaving their bodies. Left uncollected, that energy reconcentrates and erupts, spreading the Mist further and awakening something far worse.

---

## Unique Value Proposition: The Exponential Greed System

Forest Essence orbs dropped by defeated gnomes are not passive pickups. They are active threats if ignored.

```
Uncollected Forest Essence → grows larger → explodes into Mist → awakens a Mini-Boss gnome
```

This creates a **Dilemma of Self-Interest**: every player must constantly weigh whether to push into danger to collect Essence or let it grow and increase global threat. In multiplayer, this becomes a social negotiation — one player's greed decision affects the entire team's survival.

---

## Game World: The Toroidal Arena

The map is **infinite and wrapping (toroidal)**. There are no walls or edges. Crossing the north boundary places the entity on the south boundary. Crossing the west boundary places it on the east boundary.

This applies to:
- Players
- Enemies
- Projectiles
- XP orbs
- Side quest buttons and chest spawns

Enemy AI is aware of the toroidal space. It evaluates **9 possible sectors** (current + 8 wrapped neighbors) to find the shortest path to its target. An enemy may cross the map boundary if doing so is faster than crossing open ground.

---

## Layer System

The game world uses **2 dedicated layer nodes** plus **direct scene-root placement** for all world entities:

| Node | zPosition | Contents |
|---|---|---|
| `floorLayer` (`SKNode`) | 0 | `FloorTileRenderer` root — always behind everything |
| `propsLayer` (`SKNode`) | 1 | Background environment decorations, `EnvironmentPropSystem` nodes |
| Scene root (direct children) | y-sorted | Players, enemies, projectiles, Forest Essence orbs, effects, side quest buttons/chests |

**Y-sort rule:** All world entities are added directly to the scene (not to a container node). `GameScene.updateYSort()` runs every frame and assigns:

```
zPosition = Layer.world - footY * 0.001
```

Where `footY = sprite.position.y - sprite.size.height / 2`. This means entities higher on screen (larger y) render behind entities lower on screen (smaller y), producing correct top-down depth ordering — a player standing behind a tree appears behind it, a player in front appears in front.

**HUD** is a child of `SKCameraNode` at `Layer.hud = 10` — camera-space, never world-space.

---

## Side Quest System (V3)

The environment layer features a **button-and-chest side quest loop** that triggers as a special event during a run:

- The side quest event triggers at intervals or conditions defined in `GameConfig`
- When triggered, a set of **proximity buttons spawns scattered across the toroidal map** at random positions
- Players find and activate buttons by **standing near them for a short duration**
- When all buttons are activated, a **chest spawns** at a random location on the map
- The chest contains a guaranteed rare skill or Greed Essence
- The entire quest — buttons and potential chest — has a **global time limit**. If the timer expires before all buttons are activated or the chest is collected, everything despawns and the cycle waits for the next trigger
- **Enemies cannot interact with buttons in any way** — they cannot block, deactivate, or destroy them
- After the quest concludes (reward collected or timer expired), the map returns to normal until the next trigger

This loop is interruptible — enemies do not pause during the side quest — and reinforces the core greed dilemma by forcing the team to split focus between fighting and exploration.

---

## Director System

The **Director** is an autonomous background system that continuously monitors player performance and dynamically adjusts gnome spawn pressure to keep the game in a challenging but fair difficulty range. It has no fixed difficulty levels — it operates as a continuous slider under the hood. Additionally, as time progresses, gnomes naturally grow stronger regardless of Director adjustments — the grove's corruption deepens the longer the Mist remains.

### Gnome Spawn Positioning

All gnomes spawn **outside the current camera view**. No gnome ever appears within the visible screen area at the moment of spawning. This ensures players always have a moment to react and prevents gnomes from materializing on top of a player.

### What the Director Measures

The Director tracks two metrics over a **rolling time window** (window duration defined in `GameConfig`):

| Metric | Description |
|---|---|
| **Kill rate** | Gnomes purified per second within the rolling window |
| **Damage taken rate** | Damage received per second within the rolling window |

Forest Essence collection is intentionally excluded from metrics. The Greed system makes Essence collection an unreliable signal — a cautious player and a struggling player can look identical by Essence data alone.

### Enemy Budget System

The Director manages a **dynamic enemy budget** — a point cap representing the total weight of gnomes allowed on the map simultaneously. The budget is not a fixed number; the Director raises or lowers it based on performance data.

**Gnome weight table:**

| Gnome Type | Budget Weight |
|---|---|
| Small Gnome | 1 |
| Mini-Boss Gnome | 10 |
| Swarm (V3+) | 20 (group of ~20 small gnomes treated as one spawn unit) |
| Boss | Enters a separate **Boss Stage** — see below |

**Budget logic:**
- Mini-Boss gnomes spawned from Forest Essence explosion still consume budget — the Director accounts for them
- The Director never spawns gnomes that would exceed the current budget cap
- The budget has a floor (`GameConfig.directorMinBudget`) so the grove never feels empty, and a soft ceiling (`GameConfig.directorMaxBudget`) so the screen never becomes an unreadable mess. The ceiling is approached gradually — the Director slows its budget increases as it nears the cap rather than hard-clamping

### How the Director Adjusts

Every polling interval (defined in `GameConfig.directorPollInterval`), the Director evaluates the rolling window metrics and shifts the budget up or down:

| Signal | Director Response |
|---|---|
| High kill rate + low damage taken rate | Player is dominating → increase budget cap, escalate spawn rate |
| Low kill rate + high damage taken rate | Player is struggling → decrease budget cap, reduce spawn pressure |
| Low kill rate + low damage taken rate | Player is playing safely/passively → slight budget increase to apply pressure |
| High kill rate + high damage taken rate | Player is in a frantic, high-intensity fight → hold budget steady, do not pile on |

### Boss Stage

Bosses are not part of the normal Director budget. They operate on a separate **time-based trigger**: every interval defined in `GameConfig.bossSpawnInterval` (e.g. every 10 minutes), a Boss erupts from the Mist regardless of current budget state.

**When a Boss is triggered:**
- The camera locks to its current position — players cannot move far enough to shift the camera view
- Players cannot escape the current camera bounds during the Boss stage; the leash system tightens to enforce this
- All regular gnome spawning pauses — no budget gnomes spawn while the Boss is alive
- The Boss is **not constrained by the budget system**. It operates outside the Director's cap entirely
- The Boss **may spawn its own mini gnomes** independently — these mini spawns are the Boss's own ability and are not subject to the Director budget either
- The Boss stage ends only when the Boss is defeated. There is no timer — if the players cannot kill it, the Boss remains indefinitely
- Once the Boss dies, the camera lock releases, regular spawning resumes, and the Director recalibrates from the current rolling window state

### Tuning Notes

- The Director's aggressiveness is bounded by `GameConfig.directorMinBudget` (floor) and `GameConfig.directorMaxBudget` (soft ceiling). Budget increases slow as they approach the ceiling; the Director does not snap to it
- Budget changes are **gradual, not instant** — the Director steps up or down by a delta per poll rather than snapping to a target, preventing jarring difficulty spikes
- V1 launches with conservative tuning. All Director constants live in `GameConfig` and must be adjusted through playtesting. The Director is expected to require several tuning passes before it feels natural
- The passive-play signal (low kill + low damage) exists specifically because the toroidal map and Greed system allow players to run indefinitely if they choose. The Director should not permit indefinite passive survival
- A player learning the game will naturally take high damage and kill slowly. The Director will ease off on a new player. This is correct behavior — but it means early-run difficulty will feel softer than mid-run. Expect this and do not over-correct the tuning toward aggression

---

## Level-Up and Skill Selection

When a player levels up, the following sequence occurs:

1. The player **freezes in place** (cannot move)
2. A **shield radius expands outward** from the player over ~1.5 seconds
3. The expanding shield **pushes gnomes and other players away** — it is a physical collidable object
4. Other players may use the shield as **temporary cover** against projectiles
5. The **AI removes the leveling player from its targeting list** for the duration (treated as absent)
6. Once the radius reaches full size, **3 skill cards appear** as large icons with short names inside the radius, anchored to and moving with the player
7. The player selects one skill; on selection, the shield **bursts outward** dealing a knockback pulse to nearby gnomes, then dissipates

**Solo behavior:** Game fully pauses during skill selection. Full-screen overlay.

**Multiplayer behavior:** Only the leveling player freezes. All other players, enemies, and projectiles continue in real time. The 3 skill cards appear inside the player's shield radius — not in a fixed screen position — so they never overlap another player's view regardless of positioning.

**Simultaneous level-up (2+ players at once):** Each player's shield expands independently. Overlapping shields push each other's owners apart. Each player selects from their own 3-card pool.

**Skill card design requirement:** Icon-forward, 2–3 word name maximum. Readable at couch distance on a shared display. Tooltip detail only on held selection.

---

## Camera

A **midpoint camera** tracks the center point of all active players. Designed from V1 with a player list architecture so that adding more players in V2 requires minimal adjustment. The camera is an `SKCameraNode` tracking a computed anchor.

In multiplayer, players are **leashed to the camera view** — the group must cross a world boundary together to trigger a toroidal wrap. A player cannot individually wrap while others remain on the opposite side.

---

## Meta-Progression (V4)

Players accumulate **Forest Essence** across runs. Between runs, they spend Forest Essence in a permanent upgrade shop to boost base stats: Speed, Luck, Health. Progression is stored via **Game Center** (no custom backend).

---

## Platform

**macOS exclusive.** Built on Apple Silicon (M-series). SpriteKit, Metal, GameController, and GameKit are all native to macOS and require no platform bridging.

| Concern | Why macOS on Apple Silicon |
|---|---|
| Sustained GPU load | M-series chips sustain GPU load without thermal throttling |
| 4-player input | macOS Bluetooth stack supports multiple concurrent HID controllers |
| Display flexibility | Native display or external monitor via HDMI/DisplayPort |
| Rendering | Metal-backed GPU instancing via `SKRenderer` handles high projectile counts at 120+ FPS |
| Market | Mac install base is substantially larger than Apple TV; genre precedent exists (Vampire Survivors, Brotato) |

---

## Development Phases

| Phase | Name | Core Addition |
|---|---|---|
| V1 | Technical MVP | Toroidal world, 1 forest spirit character, WASD move + mouse/trackpad aim + auto-aim, Forest Essence evolution, 3 gnome types, skill system, Director, time-based Boss stage |
| V2 | Shared-Screen Multiplayer | Up to 4 controllers, midpoint camera, leashing |
| V3 | Environmental Strategy | Side quest button/chest loop, proximity detection, Swarm gnome type |
| V4 | Home Loop & Persistence | Home menu, meta-progression shop, Game Center leaderboards and achievements |

---

## Research References

- **UX / Flow State:** doi:10.13140/RG.2.2.11010.75209 — shared-screen approach maintains flow state and minimizes cognitive load in high-density visual environments
- **Spatial Dynamics:** doi:10.1109/GEM.2014.7048110 — manual aim and spatial navigation challenge spatial management rather than pure reflex
- **Player Dilemma:** Zagal et al. (2006) — the Exponential Greed system creates mandatory social negotiation between players, elevating the game from a shooter to a collaborative survival experience