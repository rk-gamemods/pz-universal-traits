# UT_burned

## Trait Summary
- UT trait id: UT_burned
- Source mod: unknown — no direct source trait found in installed-mods research; MoreTraits references "burned" only in dynamic injury-tracking code (`getBurnTime()` checks during periodic updates), not as a spawn-condition trait; no installed mod defines a spawn-with-burns trait
- Source trait id: unknown
- Current cost: -8
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreTraits/mods/More Traits - Dynamic/media/lua/client/MoreTraits - Dynamic.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt`
- Source trigger path: none found — MoreTraits - Dynamic tracks whether a body part has `getBurnTime() ~= 0` during periodic checks to increment an `InjuredTime` counter, but this is gameplay tracking, not a character-creation spawn trait; no mod in the research folder defines a trait that applies burn damage at spawn
- Source behavior: none found — the spawn-with-burns concept does not have an identifiable precursor in the researched installed-mods; the design appears original to UTMods

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_burned = CharacterTrait.register("UniversalTraits:UT_burned")` at line 241
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_burned` block at lines 1637–1645
- Translation strings present: yes — `UI_UT_burned` and `UI_UT_burnedDesc` both defined in `UI_EN.txt`
- Exclusions/grants correct: N/A — no `MutuallyExclusiveTraits` or grants defined in the script block; none are expected for a spawn-condition trait of this type
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_burned.lua`

### Runtime Trace
- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_burned.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UT_CORE/media/lua/shared/UTCore/UTCore_SpawnEffects.lua`
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — guards execution
  - `UTCore.applySpawnCondition(player, { burnSeverity = 0.6, injuries = { BodyPartType.Hand_L, BodyPartType.Hand_R, BodyPartType.Torso_Upper } })` — applies burn and injury state
  - `UTCore.applySpawnStats(player, { stress = 0.7, fatigue = 0.5, panic = 0.3 })` — applies stat penalties
- Runtime chain (plain language):
  1. On new game start, `onNewGame` fires for the player.
  2. `UTCore.hasTrait` checks whether the player has `UniversalTraits:UT_burned`; returns immediately if not.
  3. `UTCore.applySpawnCondition` is called with `burnSeverity = 0.6` and three injury targets.
     - The `burnSeverity` path iterates all body parts via `bodyDamage:getBodyParts()` and calls `setBurnDamage(0.6)` on each one.
     - The `injuries` path calls `setHealth(0.5)` on `BodyPartType.Hand_L`, `BodyPartType.Hand_R`, and `BodyPartType.Torso_Upper`.
  4. `UTCore.applySpawnStats` calls `stats:setStress(0.7)`, `stats:setFatigue(0.5)`, and `stats:setPanic(0.3)`.
- Actual behavior (exact values):
  - All body parts receive `setBurnDamage(0.6)` — 60% burn severity across the entire body.
  - Left hand, right hand, and upper torso receive `setHealth(0.5)` — marked as injured at half health.
  - Stress set to 0.7, fatigue to 0.5, panic to 0.3 at spawn.

## Description Integrity
- Display name check: "Burned" — accurate; concise and unambiguous.
- Description check: "Fire got to you before you got away. You spawn with 60% burn severity on your upper torso and both hands, stress at 0.7, fatigue at 0.5, and panic at 0.3."
- Accuracy assessment:
  - The description states "60% burn severity on your upper torso and both hands." The code applies `setBurnDamage(0.6)` to **all body parts**, not only the torso and hands. The description is partially correct about the body parts receiving injuries (the `injuries` array targets those three parts) but understates the burn scope — every limb and body segment receives 60% burn damage, not just the named ones.
  - The stat values (stress 0.7, fatigue 0.5, panic 0.3) match the code exactly.
- Missing or misleading details: The description implies burns are limited to the upper torso and both hands. In reality, `setBurnDamage(0.6)` is applied to all body parts via the loop in `UTCore.applySpawnCondition`. The injuries (health set to 0.5) are correctly scoped to those three parts, but the burn damage is body-wide. This is a factual inaccuracy in the description.

## Balance Review
- Upside: none
- Downside: 60% burn damage on all body parts (severe, body-wide); health reduced to 50% on both hands and upper torso; stress 0.7; fatigue 0.5; panic 0.3 — an extremely harsh spawn state
- Uptime: N/A — spawn-condition trait; effects apply once at new-game and persist as game state
- Peer comparison:
  - `UT_broke` (-10 cost): fractured and injured left foot, stress 0.5, fatigue 0.3 — a single-limb fracture with moderate stat penalties
  - `UT_injured_I` (cost unverified here): injuries to hand and foot, stress 0.3
  - `UT_injured_II` (-8 cost): four injured body parts, higher stress/fatigue — comparable point cost but no burn damage and no panic
  - `UT_burned` at -8 is priced the same as `UT_injured_II` but delivers body-wide 60% burns on top of three injuries plus panic; the burn state in PZ is significantly more debilitating than raw injuries (burns impede healing, cause ongoing pain, and persist longer); -8 may be an undercharge relative to the actual severity
- Stack or exclusion notes: no mutual exclusions defined; can be selected alongside any other trait; combining with `UT_injured_I` or `UT_injured_II` would stack injury effects but the burn is already body-wide so injury overlap is cosmetic
- Cost verdict: potentially underpriced — body-wide 60% burns plus three specific injuries plus stress 0.7, fatigue 0.5, and panic 0.3 represents a heavier combined spawn penalty than `UT_broke` at -10 or `UT_injured_II` at -8; the cost should be re-evaluated once burn mechanics are confirmed to behave as intended in B42

## Regression Proof
- Existing test: `UT_burned` appears in the Phase 3a block of the batch trait list in `run_tests.lua` at line 274, confirming it is included in the batch registration sweep.
- What it proves: The trait ID `UniversalTraits:UT_burned` is registered in `UTTraitsRegistries`. The registration call does not error. Nothing about runtime behavior is verified.
- Missing proof:
  - No test confirms `applySpawnCondition` is called with the correct `burnSeverity` and `injuries` values when the trait is present.
  - No test confirms the hook is a no-op when the player does not have the trait.
  - No test confirms `applySpawnStats` applies the correct stress, fatigue, and panic values.
  - The mock `UTCore.applySpawnCondition` in `UTTestMocks.lua` (line 125) writes the condition table to `player:getModData()["_spawnCond"]`, which would support assertions — but no test exercises this for `UT_burned`.
- Minimum next test if needed:
  1. Mock `Events.OnNewGame`; fire it with a player who has `UniversalTraits:UT_burned`; assert `player:getModData()["_spawnCond"].burnSeverity == 0.6` and that the `injuries` array contains exactly `BodyPartType.Hand_L`, `BodyPartType.Hand_R`, and `BodyPartType.Torso_Upper`.
  2. Assert `player:getModData()["_spawn_stress"] == 0.7`, `_spawn_fatigue == 0.5`, `_spawn_panic == 0.3`.
  3. Fire with a player who does not have the trait; assert `_spawnCond` is nil.

## Final Verdict
- Source origin: unknown — no source trait in installed-mods research applies burn damage at character creation; concept appears original to UTMods
- UT implementation: functional — the full event-to-effect chain is present and correct; `OnNewGame` fires, guard checks the trait, `applySpawnCondition` sets burn damage and injuries via `UTCore_SpawnEffects`, `applySpawnStats` sets stat penalties; all hooks resolve to real PZ API calls
- Description: partially inaccurate — the description correctly states the injured body parts and all stat values, but incorrectly implies burns are limited to the upper torso and both hands; the actual burn (`setBurnDamage(0.6)`) is applied to every body part; description must be corrected to reflect body-wide burns
- Balance: potentially underpriced — body-wide 60% burn severity combined with three injuries and elevated stress, fatigue, and panic is a harsher combined penalty than peer Phase 3a traits at the same or higher cost; warrants review
- Regression proof: missing — batch registration sweep confirms ID validity only; no behavioral assertions exist
- Action needed:
  1. Fix description to state that burn damage applies to all body parts, not only the torso and hands
  2. Re-evaluate cost in the context of B42 burn-severity behavior; consider -10 or -12
  3. Add unit tests covering the new-game hook (presence and absence of trait, correct condition values, correct stat values)
- Open gaps:
  - No source mod identified; origin of spawn-with-burns concept is unconfirmed
  - `setBurnDamage` scope is body-wide but the description scope is three parts — this discrepancy may be intentional design (burns spread from initial contact) or a code bug; intent should be confirmed before the description fix is finalized
  - `OnNewGame` fires only for new saves; no `OnGameStart`/`OnLoad` fallback means players who add the trait via a dynamic grant system mid-save would not have burn or stat state applied
  - No mutual exclusion with `UT_injured_I` or `UT_injured_II` despite overlapping injury targets; stacking all three would triple-wound the hands but the burn is already body-wide so the practical stacking impact is minor
