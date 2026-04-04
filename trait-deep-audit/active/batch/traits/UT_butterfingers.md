# UT_butterfingers

## Trait Summary

- UT trait id: UT_butterfingers
- Source mod: More Traits (ToadTraitButter)
- Source trait id: `butterfingers` (registered as `ToadTraits:butterfingers` via `ToadTraitsRegistries.butterfingers`)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (runtime implementation — `ToadTraitButter`, lines 870–918)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (trait registration, line 104)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/Translate/EN/UI_EN.txt` (source strings)
- Source trigger path: `Events.OnPlayerUpdate.Add(OnPlayerUpdate)` — fires every game tick; `ToadTraitButter` is called from inside the master `OnPlayerUpdate` handler (line 5382)
- Source behavior:
  - Guards: requires `player:hasTrait(ToadTraitsRegistries.butterfingers)` AND `player:isPlayerMoving()` — fires only while the player is in motion.
  - Computes `basechance = 3`. Modifies it based on other traits:
    - `ALL_THUMBS` (vanilla): +1
    - `DEXTROUS` (vanilla): -1
    - `packmule` (MoreTraits): -1
    - `packmouse` (MoreTraits): +1
    - `lucky` (MoreTraits): -1 × luckimpact
    - `unlucky` (MoreTraits): +1 × luckimpact
  - Computes weight bonus: `chancemod = math.floor(inventoryWeight / 5)`. Adds +10 if sprinting, +5 if running.
  - Rolls `ZombRand(chanceinx)` where `chanceinx = SandboxVars.MoreTraits.ButterfingersChance or 2000`. Drop triggers if `totalChance >= ZombRand(chanceinx)`.
  - At defaults: `totalChance = 3 + chancemod`, roll range = 0–1999 (~0.15% chance per tick at minimum, scaling with encumbrance and speed).
  - On trigger: calls `player:dropHandItems()` (drops both primary and secondary hand items), shows a halo text `UI_butterfingers_triggered` in red, plays `UIUnEquipItem` sound. Fires only if at least one hand slot is occupied.
  - Source description: "Sometimes, you may drop something you're holding. The chance is based on the weight carried and other traits, such as Luck or Nimble Fingers."

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_butterfingers = CharacterTrait.register("UniversalTraits:UT_butterfingers")` (line 285 of `UniversalTraits/media/registries.lua`)
- Defined in UT_character_traits.txt: yes (lines 2010–2018)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_butterfingers`
  - `Cost = -4`
  - No `MutuallyExclusiveTraits` declared
  - No `GrantedTraits` declared
- Translation strings present: yes
  - `UI_UT_butterfingers = "Butterfingers"`
  - `UI_UT_butterfingersDesc = "Things slip out of your hands at the worst moments. No matter how careful you try to be, stuff just ends up on the floor."`
- Exclusions/grants correct: N/A — none declared; acceptable for a standalone negative trait
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_butterfingers.lua`)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_butterfingers.lua` (full file, 25 lines)
  - `media/scripts/UT_character_traits.txt` (lines 2010–2018)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 623–624)
  - `test/run_tests.lua` (line 295)
- Event registrations:
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` — the only UT_CORE call in the file
- Runtime chain (plain language):
  1. Every game tick, `onPlayerUpdate` fires for each player.
  2. Guard: returns immediately if the player does not have `UniversalTraits:UT_butterfingers`.
  3. Reads `player:getPlayerNum()` and `getGameTime():getTicks()`.
  4. Initialises `lastCheckTick[playerId]` to 0 if not set.
  5. Throttle: returns immediately if fewer than 300 ticks have elapsed since the last check.
  6. Updates `lastCheckTick[playerId]` to the current tick.
  7. Rolls `ZombRand(100) < 3` — a 3% chance.
  8. On a hit: sets `player:getModData()["UT_dropNext"] = true`.
  9. The handler does NOT drop anything directly. It sets a flag in modData. No further code in this file reads or acts on that flag.
- Actual behavior (exact values):
  - Cadence: checked every 300 ticks (approximately 5 real-time seconds at 60 ticks/sec, or less if the game tick rate differs)
  - Drop probability: 3% chance per 300-tick window
  - Movement requirement: none — fires unconditionally for any player with the trait, regardless of movement state
  - Actual drop action: **none confirmed in this file** — the flag `UT_dropNext` is written to modData but no code in `UT_butterfingers.lua` acts on it; the drop must be handled elsewhere or is currently dead/incomplete
  - No halo text, no sound, no direct `dropHandItems()` call in this file
  - No trait interactions (no ALL_THUMBS, DEXTROUS, weight, speed modifiers)

## Description Integrity

- Display name check: "Butterfingers" — matches the trait concept; acceptable
- Description check: "Things slip out of your hands at the worst moments. No matter how careful you try to be, stuff just ends up on the floor." — the description implies that items are actually dropped during play. The runtime sets a modData flag (`UT_dropNext = true`) but does not itself drop anything. Whether items ever actually drop depends entirely on whether something else reads and acts on `UT_dropNext`. That secondary actor was not located in any UT file reviewed.
- Missing or misleading details:
  - The description states items drop but the confirmed runtime only sets a flag — the actual drop is unverified.
  - No mention of the 300-tick cooldown window (roughly every 5 seconds at standard tick rate).
  - No mention of the 3% per-window probability.
  - No mention that the source's movement gate, weight scaling, hand-slot check, and sound cue are all absent in the UT version.
  - `DisabledInMultiplayer = true` is unexplained. A trait that only writes a modData flag would not be obviously harmful in multiplayer.

## Balance Review

- Upside: none — pure negative trait, returns -4 points at character creation
- Downside (intended): occasional loss of held items during play
- Downside (confirmed): the Lua file sets `UT_dropNext = true` in modData at 3% per 300-tick window. Whether this flag ever causes an actual item drop is unknown without locating the consumer of this flag. If the consumer is missing, the trait has no effective downside at all.
- Uptime: the check fires every ~300 ticks unconditionally (no movement guard, no hand-slot guard, no weight check). At 3% per window this produces a flag roughly once every ~167 windows (~833 seconds or ~14 real-time minutes at 60 ticks/sec, ignoring engine variation).
- Peer comparison:
  - Source MoreTraits version: movement-gated, weight-scaled, hand-slot-checked, sound-cued, and directly drops items — immediate and tangible.
  - UT version (if the flag consumer exists and works): unconditional movement, flat 3% chance, no weight scaling, no trait interactions. Significantly simpler.
  - UT version (if flag consumer is missing): the trait has zero functional downside while still costing -4 character points — a free point gain.
- Stack or exclusion notes: no exclusions declared; no interactions with ALL_THUMBS, DEXTROUS, or any other trait
- Cost verdict: `blocked` — the cost cannot be fairly assessed until the `UT_dropNext` flag consumer is identified and confirmed to work. If the drop is broken, -4 is wrong (should be 0 or the trait should be disabled). If the drop works but the consumer is elsewhere, -4 may be appropriate or slightly generous given the simplified mechanics.

## Regression Proof

- Existing tests:
  - `test/run_tests.lua` line 295: `"UniversalTraits:UT_butterfingers"` appears in the `expected_ids` registration list; the registration test (confirmed passing in the test harness) verifies the trait ID is registered with `CharacterTrait`
  - The `"script trait definitions resolve cleanly"` test implicitly covers the script block structure
- What the tests prove: the trait is registered and the script block is structurally valid
- Missing proof:
  - No test verifies the `onPlayerUpdate` handler fires and correctly sets `UT_dropNext = true`
  - No test verifies the 300-tick throttle (that the flag is not set before 300 ticks have elapsed)
  - No test verifies the 3% roll (that `ZombRand(100) < 3` produces the flag at the expected rate)
  - No test verifies the flag consumer — whatever reads `UT_dropNext` and calls `dropHandItems()` is entirely unverified
  - No test verifies that a player without the trait is unaffected (guard path)
  - No test verifies save/load persistence of `lastCheckTick` (it is a module-local table, not stored in modData, meaning it resets on reload)
- Minimum next test if needed:
  - Construct a mock player with `TRAIT_ID` and `lastCheckTick[id] = 0`. Set `getGameTime():getTicks()` to return 301. Fire `onPlayerUpdate`. Assert `player:getModData()["UT_dropNext"] == true`.
  - Throttle test: set `lastCheckTick[id]` to current tick. Fire handler. Assert `UT_dropNext` is nil (throttle suppresses roll).
  - Guard test: player without trait. Fire handler. Assert `UT_dropNext` is nil.
  - Locate and test the `UT_dropNext` consumer: mock a player with the flag set, trigger whatever event reads it, assert `dropHandItems()` is called.

## Final Verdict

- Source origin: proven — More Traits `ToadTraitButter` confirmed in source runtime (`42.15/media/lua/shared/MoreTraits .lua` lines 870–918) and registration (`42.15/media/registries.lua` line 104)
- UT implementation: drifted — the source drops items directly via `player:dropHandItems()` with movement gating, weight scaling, speed modifiers, trait interactions, hand-slot checking, halo text, and sound. The UT version replaces all of this with a modData flag (`UT_dropNext = true`) set at a flat 3% per 300-tick window with no movement guard, no weight scaling, and no direct drop. The actual drop mechanism — whatever reads `UT_dropNext` — was not found in any UT file reviewed. The implementation is either split across an unlocated file or the drop half is missing entirely.
- Description: misleading — states items drop but the confirmed runtime only sets a flag; the actual drop effect is unverified. Numbers, conditions, and probability are omitted.
- Balance: blocked — cannot assess cost until the `UT_dropNext` consumer is found and confirmed working. If the drop is non-functional, the trait is a free -4 points (broken in the player's favor).
- Regression proof: missing — registration is verified; runtime behavior (flag set, throttle, guard, and especially the drop consumer) is completely untested.
- Action needed: code fix + test fix + doc fix
- Open gaps:
  - **Critical**: locate the consumer of `player:getModData()["UT_dropNext"]`. Search all UT Lua files for `UT_dropNext`. If no consumer exists, the drop mechanic is broken and must be implemented or the trait must be flagged as non-functional.
  - **Critical**: `lastCheckTick` is a module-local table (not persisted in modData). On game save/load it resets to `{}`, meaning the 300-tick cooldown restarts from zero after every reload. Decide whether this is intentional.
  - **Code**: if the drop consumer is found and correct, consider whether the 3% per 300-tick flat rate (no movement guard, no weight scaling) is the intended design difference from the source, and document it explicitly.
  - **Description**: once the drop mechanic is confirmed working, rewrite `UI_UT_butterfingersDesc` to include the actual probability window and conditions (e.g., approximate frequency, whether movement matters).
  - **Tests**: add runtime unit tests for the flag-set path, throttle path, guard path, and the drop consumer path.
  - **Balance**: re-evaluate -4 cost after the drop mechanic is confirmed; compare to peers such as `UT_acrophobic` and `UT_vehophobic` (both -4) which have confirmed scripted effects.
