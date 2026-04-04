# UT_batteringram

## Trait Summary
- UT trait id: UT_batteringram
- Source mod: More Traits (ToadTraits)
- Source trait id: ToadTraits:batteringram
- Current cost: 7
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/scripts/ToadTraits.txt` (lines 89–97)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` (lines 3666–3764, `BatteringRam` function)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` (lines 221–222)
- Source trigger path: OnPlayerUpdate tick loop → `BatteringRam(player, playerData)` called every frame when trait is present; evaluates `player:isSprinting()` and scans `player:getSpottedList()` for zombies within distance 1.0.
- Source behavior:
  - While sprinting (not running) AND legs are uninjured (no fractures on upper/lower legs or feet): enables ghost mode so the player passes through zombies; disables ghost mode when no zombies are within 2 tiles or the player is in a tree tile.
  - For each spotted zombie within distance 1.0 that has not been hit in the last 5 seconds: calls `setKnockedDown(true)`, `setStaggerBack(true)`, `setHitForce(2.0)`, `reportEvent("wasHit")`; drains endurance by `(10 / fitness) * 0.01` per zombie hit (at Fitness 1: 0.10/hit; at Fitness 5: 0.02/hit; at Fitness 10: 0.01/hit).
  - Martial combo (gated by sandbox var `BatteringRamMartialCombo` AND trait `ToadTraits:martial`): deals `(ZombRand(10,61)/100) * damageMult` damage; damageMult tiers: 1.0 (endurance ≥ 0.75), 0.75 (< 0.75), 0.5 (< 0.5), 0.25 (< 0.25).
  - Disabled if any leg body part has a fracture.
  - Description in source: "While Sprinting (not running), you knockdown zombies in your path. Every zombie you knockdown depletes some endurance depending upon your Fitness level. Note: This trait overrides the Spear's charge ability."

## Current UT Evidence
### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: N/A (no MutuallyExclusiveTraits block in UT definition; source also had none)
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_batteringram.lua`
  - `test/run_tests.lua` (lines 883–949)
- Event registrations: `UTCore.declareZombieCollisionHandler(TRAIT_ID, onZombieCollision)` — registered via UTCore on `OnCreatePlayer`; deregistered when trait is absent.
- UT_CORE hooks used: `UTCore_ZombieCollisionHook` (rising-edge detection of `player:isBumped()` + `player:getBumpedChr() == zombie`); `UTCore.hasTrait`; `UTCore.declareZombieCollisionHandler`.
- Runtime chain (plain language):
  1. On player creation, UTCore registers `onZombieCollision` as the collision callback for this trait (only if the player has the trait).
  2. Each time UTCore_ZombieCollisionHook fires (player physically bumps a zombie), `onZombieCollision(player, zombie)` is called.
  3. If the player is neither sprinting nor running, the function returns immediately — no effect.
  4. Otherwise: clears `setBumpType("")` and `setBumpFall(false)` to cancel the native stagger/trip animation; calls `zombie:knockDown(false)` to knock the zombie down.
  5. Drains endurance by a fixed 0.05 per collision (`stats:setEndurance(math.max(0, endurance - 0.05))`).
  6. If the player also has `UT_martial`, delegates to `UT_martial.applyBonusDamage(player, zombie, endurance)` for collision damage.
- Actual behavior (exact values): endurance drain = 0.05 per collision (flat, not fitness-scaled; ~20 collisions before fully exhausted from full endurance). Knockdown fires on actual physics bump, not on proximity scan. Ghost mode is not used. No fracture gate.

## Description Integrity
- Display name check: "Battering Ram" — matches intent.
- Description check: "You hit like a freight train. Push force on shoves and knockbacks is increased by +50%." — this description is entirely wrong. The UT implementation does not modify push force or shove/knockback at all. The actual behavior is: while sprinting or running, physially bumping a zombie knocks it down instead of staggering the player, at a cost of 0.05 endurance per collision.
- Missing or misleading details: (1) The description claims "+50% push force on shoves and knockbacks" which is not implemented anywhere in the Lua file. (2) The actual mechanics — collision knockdown, stagger/trip immunity, endurance drain per collision, UT_martial synergy — are completely absent from the description. (3) The UT removes the fracture gate and ghost-mode mechanic that the source had; the description does not acknowledge this simplification. (4) The endurance cost (0.05/hit, flat, ~20 hits) is not mentioned.

## Balance Review
- Upside: Converts all sprint/run zombie collisions from stagger-the-player into knockdown-the-zombie; player is immune to bump stagger and fall animation during these. Enables offense-through-crowd navigation. With UT_martial synergy, also deals bonus damage on each collision.
- Downside: 0.05 endurance drain per collision; at full endurance (1.0) the player can absorb ~20 collisions before exhaustion. No fracture gate (source had one). Only active while sprinting or running — walking into zombies does nothing.
- Uptime: 100% while trait is equipped and player is sprinting/running and bumps a zombie. Endurance is the limiting resource.
- Peer comparison: Cost 7 points. Other 7-cost offensive traits (if any exist at that tier) should provide comparable or lesser combat advantage. Knocking down zombies on collision and negating the stagger-trip penalty is a strong defensive-offensive hybrid effect. The UT_martial synergy adds free damage on every eligible collision. The cost of 7 appears reasonable for a sprint-combat rework trait, but the description mismatch makes comparison unreliable for players.
- Stack or exclusion notes: No mutual exclusions declared. Stacks with UT_martial for bonus collision damage. No cap on how many zombies can be knocked down per sprint.
- Cost verdict: justified (behavior is consistent with a 7-point trait, but the description mismatch must be fixed before this can be confirmed definitively)

## Regression Proof
- Existing test: 5 tests in `test/run_tests.lua` (lines 883–949):
  1. "batteringram: NOT registered when player lacks the trait" — verifies callback is absent without the trait.
  2. "batteringram knocks zombie down when player is sprinting" — verifies `knockDown` is called once.
  3. "batteringram cancels bump state when player is sprinting" — verifies `bumpType` is cleared to `""`.
  4. "batteringram drains endurance on each collision" — verifies endurance < 1.0 after one collision.
  5. "batteringram with UT_martial damages zombie on collision" — verifies zombie health reduced when both traits are active.
- What it proves: Registration gating, knockdown on sprint, stagger cancellation, endurance drain, and UT_martial synergy are all exercised.
- Missing proof: (1) No test verifies the "not running" branch (running but not sprinting should also trigger — test only uses `_sprinting`). (2) No test verifies behavior at endurance = 0 (floor clamping). (3) No test covers the case where `player:getStats()` returns nil (early return guard). (4) No test verifies the callback is deregistered on trait removal (only absence-at-creation is tested).
- Minimum next test if needed: Add a test for `player._running = true` (not sprinting) to confirm the running branch also fires knockdown; and a test at endurance 0.02 to confirm `math.max(0, ...)` clamps correctly.

## Final Verdict
- Source origin: proven (ToadTraits:batteringram from More Traits mod, cost 7, same name)
- UT implementation: simplified (ghost-mode collision pass-through replaced with UTCore_ZombieCollisionHook; fracture gate removed; fitness-scaled endurance drain replaced with flat 0.05; proximity scan replaced with engine bump event; sandbox-var gating on martial combo removed)
- Description: misleading (claims "+50% push force on shoves and knockbacks" — this is not implemented; actual behavior is sprint collision knockdown with endurance drain)
- Balance: justified
- Regression proof: partially protected (core happy path covered; running-not-sprinting branch, endurance floor, nil-stats guard, and deregistration on removal are untested)
- Action needed: doc fix, test fix
- Open gaps:
  - Description must be rewritten to reflect actual behavior: sprint/run collision knockdown, stagger/trip immunity, 0.05 endurance drain per hit, UT_martial synergy.
  - The "+50% push force" claim in the current description has no backing code — its origin is unknown; either it was carried over from an unrelated draft or it describes a mechanic that was never implemented.
  - Tests for the running (non-sprint) branch, endurance floor clamping, nil-stats guard, and trait-removal deregistration are missing.
  - The source fracture gate (disabled when legs are fractured) was not ported; it is unclear whether this was intentional. No documentation of the omission exists.
