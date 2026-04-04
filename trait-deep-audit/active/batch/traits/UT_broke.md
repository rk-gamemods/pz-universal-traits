# UT_broke

## Trait Summary
- UT trait id: UT_broke
- Source mod: unknown — no source mod in installed-mods research implements a spawn-with-fractured-foot trait; the concept is original to UT or drawn from an unresearched mod
- Source trait id: unknown
- Current cost: -10
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreTraits/mods/More Traits - Dynamic/media/lua/client/MoreTraits - Dynamic.lua` — references `BodyPartType.Foot_L` in injury-check logic for the Unwavering dynamic trait; no spawn-fracture or spawn-condition trait found
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTexpandedActionsEffects.lua` — "broke" appears only as a comment about weapon breakage; no body-fracture trait found
  - No other installed-mod Lua file implements a broken-leg or fractured-foot spawn condition trait
- Source trigger path: unknown — no matching source behavior identified in any researched mod
- Source behavior: unknown — the spawn-with-fracture approach is original to this UT implementation or sourced from an unresearched mod

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_broke = CharacterTrait.register("UniversalTraits:UT_broke")` (registries.lua line 240)
- Defined in UT_character_traits.txt: yes — lines 1627–1635; `IsProfessionTrait = false`, `DisabledInMultiplayer = true`, `Cost = -10`, `UIName = UI_UT_broke`, `UIDescription = UI_UT_brokeDesc`
- Translation strings present: yes — `UI_UT_broke = "Broken"` and `UI_UT_brokeDesc = "Your leg snapped before you even got started. You spawn with a fractured and injured left foot, stress at 0.5, and fatigue at 0.3."` (UI_EN.txt lines 506–507)
- Exclusions/grants correct: N/A — no `MutuallyExclusiveTraits` or grants defined in the script block
- Runtime Lua file exists: yes — `UT_broke.lua`

### Runtime Trace
- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_broke.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/test/UTTestMocks.lua`
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait`, `UTCore.applySpawnCondition`, `UTCore.applySpawnStats`
- Runtime chain (plain language):
  1. On new game start, `onNewGame` fires for the player.
  2. `UTCore.hasTrait` checks whether the player has `UniversalTraits:UT_broke`; returns early if not.
  3. `UTCore.applySpawnCondition` is called with `fractures = {BodyPartType.Foot_L}` and `injuries = {BodyPartType.Foot_L}`, applying a fracture and injury to the left foot at spawn.
  4. `UTCore.applySpawnStats` is called with `stress = 0.5` and `fatigue = 0.3`, setting those stats at spawn.
  5. `player:getModData()["UT_brokenLeg"] = true` is written to player mod data.
- Actual behavior (exact values): At new-game start, the player receives a fractured and injured left foot (`BodyPartType.Foot_L`), spawn stress of 0.5, and spawn fatigue of 0.3. The mod data key `UT_brokenLeg` is set to `true` but is not read by any other script in the UTMods codebase.

## Description Integrity
- Display name check: "Broken" — matches the fractured-foot concept; name is accurate.
- Description check: "Your leg snapped before you even got started. You spawn with a fractured and injured left foot, stress at 0.5, and fatigue at 0.3." — all three stated effects (fracture, injury, stress 0.5, fatigue 0.3) are present and exactly match the runtime code. Description is accurate.
- Missing or misleading details: none — the description faithfully enumerates every applied effect. The `UT_brokenLeg` mod data flag is an internal detail with no player-facing consequence and does not require description coverage.

## Balance Review
- Upside: none
- Downside: fractured and injured left foot at spawn (severe mobility penalty; fractures require splinting and significantly impair movement and combat), stress 0.5 (moderate; will degrade mood and trigger related moodles quickly), fatigue 0.3 (moderate; player starts meaningfully tired)
- Uptime: permanent spawn condition — the fracture and injury are applied once at new-game start and persist until healed through normal game mechanics; stress and fatigue are one-time starting values that decay normally
- Peer comparison: UT_injured_I at -4 cost applies injuries to two body parts with stress 0.4 and fatigue 0.2; UT_injured_II at -8 applies injuries to four body parts with stress 0.6 and fatigue 0.4. UT_broke at -10 applies a fracture plus an injury to one body part with stress 0.5 and fatigue 0.3. A fracture is categorically more severe than an injury — it requires a splint and extends recovery significantly — so the cost is in the right range relative to the injured tiers, and the -10 premium over UT_injured_II is defensible.
- Stack or exclusion notes: no mutual exclusion defined; UT_broke could be selected alongside UT_injured_I or UT_injured_II, compounding spawn injuries. Whether simultaneous fracture and injury to the same body part via multiple traits causes duplication issues depends on `applySpawnCondition` internals and has not been verified.
- Cost verdict: plausible — -10 for a fracture-plus-injury spawn condition with moderate stat penalties is consistent with the severity of a foot fracture and the cost tier of the adjacent injured traits; no strong case for change without further playtesting data

## Regression Proof
- Existing test: `UniversalTraits:UT_broke` appears in the batch trait list in `run_tests.lua` (line 280, Phase 3a — Spawn-With-Condition), confirming it is included in the batch registration sweep. No dedicated behavioral test exists.
- What it proves: The trait ID is registered in UTTraitsRegistries and is recognized by the test harness. Nothing about runtime behavior is verified.
- Missing proof: No test confirms that (a) `applySpawnCondition` is called with `fractures = {BodyPartType.Foot_L}` and `injuries = {BodyPartType.Foot_L}` when the trait is present, (b) `applySpawnStats` is called with `stress = 0.5` and `fatigue = 0.3`, (c) `UT_brokenLeg` is set to `true` in mod data, or (d) none of the above occurs when the trait is absent.
- Minimum next test if needed: A unit test that mocks `Events.OnNewGame`, fires it with a player who has the trait, then asserts `player:getModData()["_spawnCond"]` contains `fractures` and `injuries` both pointing to `BodyPartType.Foot_L`, `player:getModData()["_spawn_stress"] == 0.5`, `player:getModData()["_spawn_fatigue"] == 0.3`, and `player:getModData()["UT_brokenLeg"] == true`; plus a mirror test that fires with a player who lacks the trait and asserts none of those keys are set.

## Final Verdict
- Source origin: unknown — no matching source trait found in any installed-mod research file
- UT implementation: sound — all stated effects are applied by the runtime code; `applySpawnCondition` and `applySpawnStats` are called with values that exactly match the description
- Description: accurate — all three stated effects correspond to actual code behavior
- Balance: plausible — -10 cost is consistent with fracture severity and the adjacent injured-trait cost tier; worth re-evaluating after extended playtesting
- Regression proof: missing
- Action needed: tests only — add behavioral unit tests to cover the spawn condition, spawn stats, and mod data flag; no code or description changes required
- Open gaps:
  - `UT_brokenLeg` mod data flag is written but has no consumer anywhere in UTMods; it is either a dead stub for a future hook or a leftover from a discarded design; if no consumer is planned it should be removed to avoid confusion
  - No mutual exclusion with UT_injured_I or UT_injured_II; stacking these traits could produce overlapping spawn conditions on the same body part — the interaction of `applySpawnCondition` when called multiple times for the same body part has not been verified
  - OnNewGame only fires for new saves; no load-game hook exists, which is consistent with the other spawn-condition traits but means a player who somehow acquires the trait post-spawn (e.g., via a future dynamic grant system) would not receive the fracture
  - No source mod identified; concept origin is unconfirmed
