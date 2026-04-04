# UT_injured_II

## Trait Summary

- UT trait id: UT_injured_II
- Source mod: SomewhatTraits (SomewhatTraits by author unknown)
- Source trait id: SWInjured (trait key: `"SWInjured"`)
- Current cost: -8
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (lines 121, 582–599, 1080–1081)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.13/media/lua/server/SWTraitsCore_server.lua` (lines 326–344)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` (lines 326–344)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (lines 34, 104)
- Source display name: "Injured"
- Source description: "spawns with a various severity fracture in random lower body part"
- Source cost: -4 (confirmed: `TraitFactory.addTrait("SWInjured", ..., -4, ...)`)
- Source multiplayer: not verified from script file; UT sets `DisabledInMultiplayer = true`.
- Source mutual exclusion: none. `SWInjured` exists as a single trait with no tier system in SomewhatTraits. There is no `SWInjured_II` counterpart.
- Source trigger path:
  - Client (pre-42.13): `SWInjured()` called at line 1081 during the new-game initialization block, after the trait flag is set at line 1080. Registered via `Events.OnTick.Add(SWInjured)` implicitly through the tick handler.
  - Server (42.13+, 42.15): `Events.OnNewGame.Add(SWInjured)` (line 344).
- Source behavior: on new game, if the player has the `SWInjured` trait, one body part is randomly selected from a fixed pool of seven lower-body parts: `BodyPartType.Groin`, `BodyPartType.UpperLeg_L`, `BodyPartType.UpperLeg_R`, `BodyPartType.LowerLeg_L`, `BodyPartType.LowerLeg_R`, `BodyPartType.Foot_L`, `BodyPartType.Foot_R`. A fracture is applied to the selected part via `bodyPart:setFractureTime(severity)`. Severity defaults to 50; it is reduced to `ZombRand(30, 50)` if the player has FastHealer, or increased to `ZombRand(50, 80)` if they have SlowHealer. In the client version, the trait is then removed from the character (`characterTraits:remove("SWInjured")`) after application. The 42.13 and 42.15 server versions do not remove the trait. No stress, fatigue, or multi-part component exists in the source — the source is strictly one random fracture to one lower-body part.

Note: `UT_injured_II` has no distinct source trait. It is an original UT escalation tier invented to pair with `UT_injured_I`. Both UT traits share the single `SWInjured` source concept, but UT_injured_II is a UT-original design that is not a direct port of any source trait.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — line 239 of `UniversalTraits/media/registries.lua`:
  `UTTraitsRegistries.UT_injured_II = CharacterTrait.register("UniversalTraits:UT_injured_II")`
  Appears in the Phase 3a Spawn-With-Condition block, immediately after `UT_injured_I` and before `UT_broke`.
- Defined in UT_character_traits.txt: yes — lines 1616–1625 of `media/scripts/UT_character_traits.txt`:
  ```
  character_trait_definition UniversalTraits:UT_injured_II
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_injured_II,
      Cost = -8,
      UIName = UI_UT_injured_II,
      UIDescription = UI_UT_injured_IIDesc,
      MutuallyExclusiveTraits = UniversalTraits:UT_injured_I,
  }
  ```
- Translation strings present: yes — lines 503–504 of `media/lua/shared/Translate/EN/UI_EN.txt`:
  - `UI_UT_injured_II = "Seriously Injured"`
  - `UI_UT_injured_IIDesc = "Something went very wrong before the end. You spawn with injuries to both hands and your left foot and upper torso, stress at 0.6, and fatigue at 0.4."`
- Exclusions/grants declared in script definition:
  - `MutuallyExclusiveTraits = UniversalTraits:UT_injured_I`
  - Mutual exclusion is bidirectional: `UT_injured_I` also declares `MutuallyExclusiveTraits = UniversalTraits:UT_injured_II` (line 1613). A player can only hold one severity tier of the injured trait.
  - No mutual exclusion exists in the source. The two-tier system with bidirectional exclusion is a UT-original design.
- DisabledInMultiplayer: `true`. Consistent with the entire Phase 3a Spawn-With-Condition group.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_injured_II.lua` (19 lines)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_injured_II.lua` (all 19 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_SpawnEffects.lua` (all 69 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 1–16)
  - `media/scripts/UT_character_traits.txt` (lines 1616–1625)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 503–504)
  - `media/registries.lua` (line 239)
  - `test/run_tests.lua` (line 279)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait guard
  - `UTCore.applySpawnCondition(player, { injuries = {BodyPartType.Hand_L, BodyPartType.Hand_R, BodyPartType.Foot_L, BodyPartType.Torso_Upper} })` — injury application
  - `UTCore.applySpawnStats(player, { stress = 0.6, fatigue = 0.4 })` — stat application
- Runtime chain (plain language):
  1. On new game, `onNewGame(player)` fires via `Events.OnNewGame`.
  2. `UTCore.hasTrait(player, "UniversalTraits:UT_injured_II")` is called. Implementation (UTCore_API.lua lines 11–16): nil-checks `player` and `player:getTraits()`, then calls `traits:contains(traitId)`. If the player does not have the trait, returns `false` and the function exits immediately with no side effects.
  3. If the trait is present, `UTCore.applySpawnCondition` is called with a `conditionTable` containing `injuries = {BodyPartType.Hand_L, BodyPartType.Hand_R, BodyPartType.Foot_L, BodyPartType.Torso_Upper}`. Implementation (UTCore_SpawnEffects.lua lines 34–58): retrieves `player:getBodyDamage()`, then iterates `conditionTable.injuries` with `ipairs`. For each `partId`, calls `bodyDamage:getBodyPart(partId):setHealth(0.5)`. The `conditionTable` does not contain `fractures` or `burnSeverity` keys, so those branches are skipped.
  4. Exact injury state applied:
     - `BodyPartType.Hand_L` — health set to 0.5
     - `BodyPartType.Hand_R` — health set to 0.5
     - `BodyPartType.Foot_L` — health set to 0.5
     - `BodyPartType.Torso_Upper` — health set to 0.5
  5. `UTCore.applySpawnStats` is called with `{ stress = 0.6, fatigue = 0.4 }`. Implementation (UTCore_SpawnEffects.lua lines 9–28): retrieves `player:getStats()`, iterates the stat table. `stress = 0.6` calls `stats:setStress(0.6)`. `fatigue = 0.4` calls `stats:setFatigue(0.4)`. No other keys are present in the call; `carryDelta`, `panic`, `hunger`, `thirst`, and `endurance` branches are not entered.
  6. Function returns. No further logic. The trait is not removed from the character.
- Actual behavior (exact values):
  - Left hand (`BodyPartType.Hand_L`): health set to 0.5 at spawn.
  - Right hand (`BodyPartType.Hand_R`): health set to 0.5 at spawn.
  - Left foot (`BodyPartType.Foot_L`): health set to 0.5 at spawn.
  - Upper torso (`BodyPartType.Torso_Upper`): health set to 0.5 at spawn.
  - Stress set to 0.6 at spawn (via `stats:setStress(0.6)`).
  - Fatigue set to 0.4 at spawn (via `stats:setFatigue(0.4)`).
  - The trait persists on the character indefinitely. All effects are one-time spawn modifications. No tick handler, no ongoing modifier, no periodic check.
- Cadence: spawn-once only. No periodic component.

## Description Integrity

- Display name check: "Seriously Injured" — accurate to the severity tier. Clearly distinguishes from `UT_injured_I` ("Lightly Injured"). Both names are UT-originated; the source ("Injured") had no tier distinction.
- Description check: `UI_UT_injured_IIDesc` reads: "Something went very wrong before the end. You spawn with injuries to both hands and your left foot and upper torso, stress at 0.6, and fatigue at 0.4."
- Description accuracy vs. UT implementation:
  - "injuries to both hands" — accurate. `BodyPartType.Hand_L` and `BodyPartType.Hand_R` are both present in the injuries table.
  - "your left foot" — accurate. `BodyPartType.Foot_L` is in the injuries table. Right foot is not affected.
  - "upper torso" — accurate. `BodyPartType.Torso_Upper` is in the injuries table.
  - "stress at 0.6" — accurate. `applySpawnStats` is called with `stress = 0.6`, which calls `stats:setStress(0.6)`.
  - "fatigue at 0.4" — accurate. `applySpawnStats` is called with `fatigue = 0.4`, which calls `stats:setFatigue(0.4)`.
  - The description is fully accurate. No hidden effects. No omissions detected. All six spawn-time modifications (four injuries, stress, fatigue) are correctly named and quantified.
- Source divergence: `UT_injured_II` is not a direct port — it is an original UT-created tier. The source `SWInjured` applies one random fracture (`setFractureTime`) to one randomly chosen lower-body part (from a 7-part pool), with no stress or fatigue. UT_injured_II replaces this with four deterministic injuries (`setHealth(0.5)`) to specific upper and lower body parts (both hands, left foot, upper torso) and adds stress at 0.6 and fatigue at 0.4. Injury type differs (fracture via `setFractureTime` in source vs. health-at-0.5 via `setHealth` in UT), body part pool is categorically different (lower body only in source vs. both upper extremities and mixed lower in UT), and the stat components are entirely UT-original.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside:
  - Left hand injury (`Hand_L`, health 0.5) at spawn: impairs tasks requiring the left hand — weapon grip, construction, crafting, item interaction. Pain likely.
  - Right hand injury (`Hand_R`, health 0.5) at spawn: both hands injured simultaneously. Any task requiring either hand is affected. This is a materially stronger start penalty than UT_injured_I (which injures only the left hand).
  - Left foot injury (`Foot_L`, health 0.5) at spawn: movement impairment, pain when walking or running.
  - Upper torso injury (`Torso_Upper`, health 0.5) at spawn: pain, potential endurance impact, vulnerability to subsequent hits in the torso.
  - Stress 0.6 at spawn: significantly elevated. Approaching the range where moodle effects begin compounding. Requires active management (reading, comfort food, rest) in the early game.
  - Fatigue 0.4 at spawn: moderate start fatigue. The player is already tired on day one. Not critical alone, but combined with the stress and injuries it compounds early-game difficulty.
  - All effects are one-time spawn penalties. Once injuries heal and stats normalize, the trait has no further mechanical effect.
- Uptime: low — all penalties are temporary. Injuries heal over in-game time with rest and medical supplies; stress and fatigue normalize through gameplay. The four injuries will require more medical attention than the two in UT_injured_I, and stress 0.6 is harder to reduce quickly than 0.3. Realistic recovery window is longer than UT_injured_I, potentially spanning two or more in-game days with active healing effort.
- Peer comparison:
  - `UT_injured_I` (-4): two injuries (left hand, left foot), stress 0.3, no fatigue. Half the point cost, half the injury count, significantly lower stress, no fatigue penalty. The step from I to II doubles cost and materially triples the spawn-time burden.
  - `UT_broke` (-10): one injury and one fracture to `Foot_L`, stress 0.5, fatigue 0.3. More points but only one body part involved (albeit fractured, which is more severe than injured). `UT_broke` targets only a single limb; UT_injured_II hits four parts across both extremities and the torso. Despite `UT_broke` costing 2 more points, the injury spread of UT_injured_II may be subjectively more disabling in early combat and crafting scenarios.
  - `UT_burned` (cost unknown from this audit): burn severity applied globally to all body parts, injuries to both hands and upper torso. Burns are potentially more severe than `setHealth(0.5)` wounds depending on UTCore's burn implementation. UT_burned likely outpaces UT_injured_II in raw severity.
  - Source `SWInjured` (-4): one random fracture to one lower-body part — far less severe. UT_injured_II is not comparable to the source in terms of mechanical weight.
- Cost verdict: plausible. At -8 points, UT_injured_II represents a genuine multi-system early-game challenge: four injuries including dominant hand, movement impairment via foot, torso vulnerability, significant stress, and baseline fatigue. The combined penalty requires the player to dedicate early resources to healing and stress management simultaneously. The -8 cost is double `UT_injured_I`'s -4, which matches the roughly doubled mechanical severity (two extra injuries, doubled stress, added fatigue). The same concern from the UT_injured_I audit applies here: all effects are transient, and a skilled player can clear the penalties within the first one to two in-game days. At -8, however, the recovery investment is meaningfully larger than at -4, which makes the cost harder to argue as "free." The -8 cost is defensible. A potential concern is that `UT_broke` at -10 (fracture vs. simple injury, only one limb) may be slightly underpriced relative to UT_injured_II at -8 given four-limb coverage — but that is a `UT_broke` audit concern, not an UT_injured_II cost problem.

## Regression Proof

- Existing test: `"UniversalTraits:UT_injured_II"` appears at line 279 of `test/run_tests.lua`, in the Phase 3a Spawn-With-Condition registration list alongside `UT_injured_I`, `UT_broke`, and `UT_burned`. This is the same registration-list smoke test that covers all UT traits.
- What it proves: registration succeeds (CharacterTrait.register resolves without error) and the Lua file (`UT_injured_II.lua`) loads without a parse or runtime error at module load time.
- Missing proof:
  1. No test for spawn-condition application — no test verifies that `applySpawnCondition` is called with all four expected `BodyPartType` values (`Hand_L`, `Hand_R`, `Foot_L`, `Torso_Upper`) when the trait is present.
  2. No test for the stat assignment — no test confirms `applySpawnStats` is called with `stress = 0.6` and `fatigue = 0.4`.
  3. No test for the guard path — no test confirms that a player without the trait exits cleanly with no state modifications.
  4. No test for differential correctness vs. UT_injured_I — nothing enforces that UT_injured_II applies more injuries or higher stats than UT_injured_I. A merge error swapping injury lists between the two files would not be caught.
- Minimum next test if needed: "injured_II: applies four-part injuries and stress+fatigue on new game" — create a MockPlayer with the trait present, fire `Events.OnNewGame`, assert `applySpawnCondition` was called with `{BodyPartType.Hand_L, BodyPartType.Hand_R, BodyPartType.Foot_L, BodyPartType.Torso_Upper}` and `applySpawnStats` was called with `stress = 0.6` and `fatigue = 0.4`. Mirror with a MockPlayer lacking the trait to assert no calls are made. Add a differential assertion confirming UT_injured_II's injury count (4) is strictly greater than UT_injured_I's (2).

## Final Verdict

- Source origin: traced to `SWInjured` from SomewhatTraits as the conceptual source. However, `UT_injured_II` is not a direct port of `SWInjured` — it is an original UT-created tier that escalates the injured concept beyond what any single source trait provides. SomewhatTraits has only one `SWInjured` tier. UT_injured_I ports the core mechanism (spawn with injury) and UT_injured_II is a new severity level invented for UT's two-tier system.
- UT implementation: original UT design — four deterministic injuries (`setHealth(0.5)`) to `Hand_L`, `Hand_R`, `Foot_L`, and `Torso_Upper`, plus `stress = 0.6` and `fatigue = 0.4` applied at spawn via `UTCore.applySpawnCondition` and `UTCore.applySpawnStats`. Fires exactly once on `Events.OnNewGame`. No ongoing component. Trait persists on the character permanently as a descriptor.
- Description: accurate and complete — the description correctly identifies all four injured body parts ("both hands", "left foot", "upper torso") and the exact values of both stat modifications (stress 0.6, fatigue 0.4). No hidden effects or omissions detected.
- Balance: defensible at -8. The four-part injury spread, high stress, and baseline fatigue create a meaningful early-game challenge. The penalties are temporary but require more recovery investment than UT_injured_I. The -8 cost is proportional to the roughly doubled severity versus UT_injured_I (-4). Comparative concern with UT_broke (-10) pricing is noted but is a concern for the UT_broke audit, not this trait.
- Multiplayer flag: `DisabledInMultiplayer = true` — consistent with the entire Phase 3a Spawn-With-Condition group. Appropriate given that spawn conditions applied once on new-game would not function correctly in multiplayer's player-join flow.
- Mutual exclusion: bidirectional with `UT_injured_I`. Not present in the source. Appropriate UT-originated design for a two-tier injury system; prevents stacking both tiers.
- Regression proof: minimal — only a registration-list check exists. Spawn-condition and stat assignment paths are untested.
- Action needed:
  1. **No description fix required**: description is accurate as written.
  2. **Balance watch**: all four injuries heal over time. Monitor whether injury recovery speed at default PZ settings makes the -8 cost feel generous by mid-early game. If a player can fully heal within a single in-game day with standard medical supplies, -6 or -7 could be reconsidered. Current -8 is defensible.
  3. **Test gap**: add functional tests for the four-body-part spawn-condition call and the dual-stat assignment (stress + fatigue), using mock UTCore hooks. Include a differential check against UT_injured_I to guard against injury-list swap regressions.
- Open gaps:
  - `UTCore.applySpawnCondition` uses `setHealth(0.5)` for the `injuries` key. This sets health to 50%, which in PZ represents a wound/damaged state rather than a fracture. The source `SWInjured` used `setFractureTime(50)` — a fracture. The UT implementation is deliberately not a fracture, but the description says "injuries" without specifying wound type. If players interpret "injuries" as fractures, there is a mild expectation mismatch. The description is technically accurate (health-at-0.5 is an injury) but does not call out that these are not fractures. Compare with `UT_broke` which explicitly produces a fracture. No change required, but a follow-up note in the design rationale for the Spawn-With-Condition group would clarify the distinction between wound-type and fracture-type injuries across the four Phase 3a traits.
  - The trait remains on the character sheet permanently after all physical penalties have resolved. Players will see "Seriously Injured" indefinitely even when fully healed. This is consistent with all UT Spawn-With-Condition traits and is presumably intentional, but it may confuse players who expect the label to reflect their current state. A tooltip clarification ("This trait reflects your starting condition — it does not change as injuries heal") could improve player-facing clarity.
  - Right foot (`Foot_R`) is not injured, only left foot (`Foot_L`). The description says "your left foot" — correctly specific. This is intentional asymmetry matching UT_injured_I (which also targets `Foot_L` only). The design choice to leave the right foot uninjured while both hands are injured is noted as an intentional asymmetry, not a bug.
