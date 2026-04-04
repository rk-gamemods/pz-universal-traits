# UT_idealweight

## Trait Summary

- UT trait id: UT_idealweight
- Source mod: MoreTraits (MoreTraits - Dynamic submod)
- Source trait id: `idealweight` (unnamespaced, registered via `ToadTraitsRegistries.idealweight`)
- Current cost: 4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42/media/lua/shared/MoreTraits - Dynamic.lua` (42.x runtime, `ToadTraitsRegistries` path)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42/media/lua/client/MoreTraits - Dynamic.lua` (42.x client runtime)
  - `research/installed-mods/EvolvingTraitsWorld/mods/Evolving Traits World - Mark Dynamic Traits/42/media/lua/shared/NPCs/ETWSubmodCreationMethods.lua` (confirms `idealweight` as a known dynamic-trait alias in the ETW ecosystem)
- Source trigger path:
  - Driven by `SandboxVars.MoreTraitsDynamic.IdealWeightDynamic` toggle (must be `true` to activate the system).
  - Checked on a per-hour game tick (the outer block runs in what appears to be a scheduled hourly callback).
  - Weight read via `player:getNutrition():getWeight()`.
- Source behavior (gaining):
  - The trait is NOT a character-creation trait in the source — it is **dynamically earned** during gameplay.
  - Ideal range: weight >= 78 and weight <= 82.
  - While the player does NOT have the trait and weight is in range: `WeightMaintainedHours` increments by 1 per hour.
  - While the player does NOT have the trait and weight is out of range: `WeightNotMaintainedHours` increments by 1 per hour. If `WeightNotMaintainedHours >= IdealWeightDynamicObtainGracePeriod`, both counters reset to 0.
  - Grant condition: `WeightMaintainedHours >= IdealWeightDynamicTargetDaysToObtain * 24`. On grant: `player:getTraits():add("idealweight")` (or client command in MP), counters reset, halo text shown.
- Source behavior (losing):
  - While the player HAS the trait and weight is in range (78–82): accrues grace hours at rate `0.0834 * IdealWeightDynamicLoseGracePeriodMultiplier` per hour, capped at `IdealWeightDynamicLoseGracePeriodCap`.
  - While the player HAS the trait and weight goes outside danger thresholds (<= 75 or >= 85): `WeightMaintainedHours` decrements by 1 per hour. If `WeightMaintainedHours <= 0`: trait removed, counters reset, halo text shown.
- Source effect (what the trait actually does once held): **not specified in the dynamic script.** The source mod uses `idealweight` purely as a status flag; any actual gameplay effect is not apparent in the reviewed files. The dynamic system only manages granting and removing it — the trait's runtime benefit (if any) is defined separately (e.g., in a base MoreTraits script not reviewed here, or applied via the character trait script definition).
- Source acquisition: entirely dynamic (earned in-game), NOT available at character creation.

**Key source-vs-UT divergence:** The source treats `idealweight` as a dynamic achievement badge earned by maintaining ideal weight for a configurable number of days. UT reimagines it as a **character-creation trait** (purchasable at game start, cost 4) with a **direct, always-on calorie-management mechanic** that makes the body fight to return toward a normal weight band — mechanically the opposite direction from the source (source: earn the badge after staying in range; UT: spend points at creation and the trait then actively helps maintain range).

## Current UT Evidence

### Structure
- Registered in registries.lua: **yes** — line 191: `UTTraitsRegistries.UT_idealweight = CharacterTrait.register("UniversalTraits:UT_idealweight")`
- Defined in UT_character_traits.txt: **yes** — lines 1359–1367
- Translation strings present: **yes** — `UI_UT_idealweight` and `UI_UT_idealweightDesc` both present in `UI_EN.txt` (lines 413–414)
- Exclusions/grants: **none** — no `MutuallyExclusiveTraits` line in the script definition
- Runtime Lua file exists: **yes** — 50 lines

### Script Definition (UT_character_traits.txt lines 1359–1367)

```
character_trait_definition UniversalTraits:UT_idealweight
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_idealweight,
    Cost = 4,
    UIName = UI_UT_idealweight,
    UIDescription = UI_UT_idealweightDesc,
}
```

No `XPBoosts` line — correct, the trait has no skill bonuses.
No `MutuallyExclusiveTraits` line — no mutual exclusions defined (see Balance Review).

### Translation Strings (UI_EN.txt lines 413–414)

```
UI_UT_idealweight     = "Ideal Weight",
UI_UT_idealweightDesc = "You are in peak physical condition. Carry weight is increased by +1 and fatigue rate is reduced to 85% of normal.",
```

**CRITICAL BUG — Description does not match implementation.** The description claims two effects:
1. "Carry weight is increased by +1"
2. "Fatigue rate is reduced to 85% of normal"

Neither effect exists in the Lua implementation. The actual runtime behavior is a calorie-burn multiplier system (see Runtime Trace below). This is a stale description, likely copied from an earlier draft of the trait before the implementation was changed to the calorie approach.

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_idealweight.lua` (full file, 50 lines — source copy)
  - `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_idealweight.lua` (full file, 50 lines — release copy)
  - `media/scripts/UT_character_traits.txt` (lines 1359–1367)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 413–414)
  - `media/registries.lua` (line 191)
  - `test/run_tests.lua` (lines 254, 473, 1134–1158)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` (registerPeriodicHandler implementation)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_TraitChecks.lua` (getModData / setModData implementation)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (hasTrait implementation)

- Event registrations:
  1. `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", ...)` — fires every in-game minute
  2. `UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", ...)` — fires every player-update tick (every frame)

- Constants (source copy — `media/lua/shared`):
  - `TRAIT_ID = "UniversalTraits:UT_idealweight"`
  - `OVERWEIGHT_THRESHOLD = 84.0`
  - `UNDERWEIGHT_THRESHOLD = 76.0`

- Constants (release copy — `release/UniversalTraits/42/media/lua/shared`):
  - `TRAIT_ID = "UniversalTraits:UT_idealweight"`
  - `OVERWEIGHT_THRESHOLD = 85.0`
  - `UNDERWEIGHT_THRESHOLD = 75.0`

**THRESHOLD MISMATCH — source vs. release differ.** The source copy uses 84/76; the release copy uses 85/75. The release copy is what ships to players. The source copy's header comment also states incorrect thresholds (says "Weight >= 84" and "Weight <= 76" which match source but not release). See Bugs section.

- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe check: `player:getTraits():contains(traitId)`. Returns false if player or traits are nil.
  - `UTCore.getModData(player, key, default)` — reads `player:getModData()["UT_" .. key]`, returns `default` if nil.
  - `UTCore.setModData(player, key, value)` — writes `player:getModData()["UT_" .. key] = value`.

- ModData keys written:
  - `"UT_idealweightCache"` — cached weight value (number), refreshed every in-game minute
  - `"UT_idealweightPrevCal"` — calorie value at the previous tick (number or nil), updated every tick when trait is active and out of normal range; explicitly set to `nil` when returning to normal range

- Runtime chain — EveryOneMinute handler (weight caching):
  1. Fires once per in-game minute.
  2. Guards: `UTCore.hasTrait(player, TRAIT_ID)` — exits silently if trait absent.
  3. Writes `player:getNutrition():getWeight()` to `UT_idealweightCache`.
  4. This avoids calling `getNutrition():getWeight()` on every frame in the OnPlayerUpdate path.

- Runtime chain — OnPlayerUpdate handler (calorie multiplier):
  1. Fires every player-update frame.
  2. Guards: `UTCore.hasTrait(player, TRAIT_ID)` — exits silently if trait absent.
  3. Reads `weight` from `UT_idealweightCache` (default 80.0 if not yet set — i.e., before the first EveryOneMinute fires after loading).
  4. Determines multiplier:
     - `weight >= OVERWEIGHT_THRESHOLD` → `mult = 2.0` (overweight: 2x calorie burn)
     - `weight <= UNDERWEIGHT_THRESHOLD` → `mult = 0.5` (underweight: 0.5x calorie burn — body conserves calories)
     - Otherwise (normal range) → sets `UT_idealweightPrevCal` to `nil` and returns immediately (no effect)
  5. If mult is set, reads `current = nutrition:getCalories()` and `prev = UT_idealweightPrevCal`.
  6. Writes `UT_idealweightPrevCal = current` (always, even on the first tick where prev is nil).
  7. If `prev == nil` (first tick after entering an out-of-range zone, or after returning to normal): returns early. This skips one tick to establish a baseline — safe and correct.
  8. Computes `delta = prev - current`. This is the calories actually burned by the game engine this tick (positive when the game reduced calories naturally).
  9. If `delta <= 0` (game added calories this tick — eating, resting recovery, etc.): returns early. Eating is NOT amplified.
  10. Applies extra drain (or reduction): `nutrition:setCalories(current - delta * (mult - 1.0))`.
      - Overweight (mult=2.0): `current - delta * 1.0` → removes an additional `delta` calories on top of what the game already removed. Net burn = `2 * delta`.
      - Underweight (mult=0.5): `current - delta * (−0.5)` = `current + delta * 0.5` → adds back half the calories the game removed. Net burn = `0.5 * delta`.

- Behavior summary:
  - **Overweight (>= 85.0 release / >= 84.0 source):** Every frame in which the game naturally burns calories, the trait doubles that burn. The body burns through excess fat faster, pushing weight downward toward the normal range.
  - **Underweight (<= 75.0 release / <= 76.0 source):** Every frame in which the game naturally burns calories, the trait halves that burn. The body conserves calories to avoid further weight loss.
  - **Normal range (75 < weight < 85 release):** No effect. `UT_idealweightPrevCal` is cleared to nil on every tick in normal range, so the baseline resets cleanly when the player re-enters an out-of-range zone.
  - **Eating (delta <= 0):** No amplification — gaining calories is never doubled or reduced by this trait.

## Description Integrity

- Display name: "Ideal Weight" — thematically appropriate for a trait about metabolic self-regulation; accurate.
- Description: `"You are in peak physical condition. Carry weight is increased by +1 and fatigue rate is reduced to 85% of normal."` — **WRONG on both counts.**
  - "Carry weight is increased by +1" — **false.** No carry weight modification exists anywhere in the Lua file. No `applyStrengthCarryWeight` call, no `setMaxWeightBase`, nothing.
  - "Fatigue rate is reduced to 85% of normal" — **false.** No fatigue stat modification exists. No `CharacterStat.FATIGUE` reference, no stats manipulation of any kind.
  - The actual effect (calorie-burn multiplier that accelerates loss when overweight, decelerates it when underweight) is **entirely absent from the description.**
- This appears to be a description written for a different, earlier design of the trait that was never updated when the implementation was changed.

## Balance Review

- Upside:
  - When overweight: automatic 2x calorie burn rate, proportional to whatever the player is doing. More active play = faster correction. Passive idle burn is also doubled.
  - When underweight: automatic 0.5x calorie burn rate, extending the survival window on low food.
  - Symmetrical design: the trait fights both directions of weight deviation.
- Downside: none directly. The trait has no costs to activate, no failure states, and no stat penalties.
- Uptime: 100% — the handlers fire every frame unconditionally (subject to the trait presence guard). The calorie multiplier only applies when out of range, but the handlers are always registered.
- Cost: 4 points (positive trait).
- No mutual exclusions defined. Candidates that might logically conflict:
  - `UT_adaptivemetabolism` — if it also modifies calorie burn rate, stacking with `UT_idealweight` could produce compounding multipliers. This should be checked.
  - `UT_accmetabolism` — similar concern.
  - Any trait that modifies `player:getNutrition():setCalories(...)` directly could interfere with the delta-diff approach used here: if another trait's handler fires between the "read current" and "write setCalories" calls in the same frame, the delta may be calculated on stale data, or the setCalories write from one handler may overwrite another's.
- Frame-order sensitivity: The `OnPlayerUpdate` handler reads `prev` (set last frame), reads `current` (this frame), then writes `setCalories`. If another UT trait also calls `setCalories` on `OnPlayerUpdate` in the same frame, the order of execution determines whether the calorie values are read before or after that other trait's write. This is a latent race condition among calorie-affecting traits.
- Default weight assumption: The weight cache defaults to 80.0 if `UT_idealweightCache` has not yet been set (i.e., before the first `EveryOneMinute` fires). Weight 80.0 is in the normal range for both source and release thresholds, so the OnPlayerUpdate handler will return early on the very first tick after load — safe default behavior.
- Cost verdict: 4 points for an unconditional double-speed calorie correction system is arguably low if the correction rate is significant in practice. At 4 points it competes with traits that offer modest stat bonuses. The practical impact depends heavily on how fast the game's baseline calorie burn is — if the engine burns ~10 cal/tick when running, the trait doubles that during overweight periods, which may be a strong effect. Without benchmarking the base calorie burn rate, the cost is difficult to evaluate precisely, but 4 points is on the low end for a trait with no downside and always-on behavior.

## Source/Release Threshold Discrepancy

This is a confirmed bug requiring action:

| Copy | File path | OVERWEIGHT_THRESHOLD | UNDERWEIGHT_THRESHOLD | Header comment |
|------|-----------|----------------------|-----------------------|----------------|
| Source (dev) | `media/lua/shared/UniversalTraits/traits/UT_idealweight.lua` | 84.0 | 76.0 | "Weight >= 84 ... Weight <= 76" |
| Release | `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_idealweight.lua` | 85.0 | 75.0 | "Weight >= 85 ... Weight <= 75" |

The release copy was intentionally updated (thresholds widened by 1 in each direction), but the source copy was not synced. The source header comment still reflects the source values — internally consistent within each file, but the two copies are now diverged. The tests use weight=85.0 (overweight) and weight=75.0 (underweight) — both values sit on the boundary of the release thresholds, and both also satisfy the source thresholds (85 >= 84; 75 <= 76), so the tests pass against either copy but do not catch the off-by-one gap between normal and active zones.

**Normal range per copy:**
- Source: 76.0 < weight < 84.0 (8-unit band, e.g., 77–83)
- Release: 75.0 < weight < 85.0 (10-unit band, e.g., 76–84)

The source copy needs to be updated to match release (85.0 / 75.0) and synced via the release sync process.

## Regression Proof

- Registration smoke-test: `"UniversalTraits:UT_idealweight"` appears in the exhaustive trait-ID list in `test/run_tests.lua` at line 254. This verifies `CharacterTrait.register(...)` was called with the correct ID.
- Trait file loaded: `dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_idealweight.lua")` at line 473 of `run_tests.lua` — the file is exercised in the test run.
- Behavioral tests (lines 1134–1158):
  - `"idealweight doubles calorie burn when overweight"` — MockPlayer with weight=85.0 and calories=2000.0. Fires EveryOneMinute (caches weight), fires OnPlayerUpdate (sets prev=2000), sets calories to 1990.0 (simulates 10-calorie game burn), fires OnPlayerUpdate again. Asserts final calories ≈ 1980.0. Arithmetic: delta = 2000 - 1990 = 10; extra drain = 10 * (2.0 - 1.0) = 10; final = 1990 - 10 = 1980. Correct.
  - `"idealweight halves calorie burn when underweight"` — MockPlayer with weight=75.0 and calories=2000.0. Same sequence, calories set to 1990.0. Asserts final calories ≈ 1995.0. Arithmetic: delta = 2000 - 1990 = 10; calorie-back = 10 * (0.5 - 1.0) = -5; setCalories(1990 - (-5)) = 1995. Correct.
- What the tests prove:
  - The delta-diff calorie mechanic works correctly for both overweight (2x) and underweight (0.5x) cases.
  - The `EveryOneMinute` weight cache is written and read correctly.
  - The two-tick sequence (first tick sets prev, second tick applies mult) functions as intended.
- What the tests do NOT prove:
  - No test verifies the early-return when weight is in the normal range (e.g., weight=80.0 should produce no calorie change).
  - No test verifies that `delta <= 0` (calorie-gaining tick) is correctly skipped.
  - No test verifies the `prev == nil` first-tick skip.
  - No test verifies the guard `UTCore.hasTrait` early-return when the player lacks the trait.
  - No test covers the specific threshold boundaries (e.g., weight=84.9 release: normal, no effect; weight=85.0: overweight, effect active).
  - No test catches the source/release threshold divergence — both test weights (85.0 / 75.0) satisfy both threshold sets.

## Bugs

1. **CRITICAL — Description does not match implementation.**
   - `UI_UT_idealweightDesc` claims "+1 carry weight" and "85% fatigue rate." Neither effect exists in the Lua.
   - Actual effect: calorie-burn rate doubled when overweight (>= 85), halved when underweight (<= 75), no effect in normal range.
   - Fix: rewrite the description to accurately describe the calorie mechanic.
   - Example corrected text: `"Your metabolism actively fights to maintain a healthy weight. When overweight, calorie burn is doubled. When underweight, calorie burn is halved. No effect at normal weight (75–85)."`

2. **MEDIUM — Source/release threshold mismatch (off-by-one in each direction).**
   - Source uses OVERWEIGHT=84.0, UNDERWEIGHT=76.0.
   - Release uses OVERWEIGHT=85.0, UNDERWEIGHT=75.0.
   - Source copy header comment reflects the source values, not release values.
   - Fix: update source copy to match release (85.0 / 75.0), update header comment, then sync release.

3. **LOW — Source header comment "normal range" note is inconsistent with code.**
   - Source comment line 5: `"-- Weight 75-85 (normal): no effect."` but source thresholds define normal as 76–83 (exclusive). The 75–85 description matches the release thresholds, not the source code thresholds. Suggests the comment was updated for release but the constants were not (or vice versa).

4. **LOW — No mutual exclusion with other calorie-modifying traits.**
   - If `UT_adaptivemetabolism` or similar traits also manipulate calorie values via `setCalories`, stacking with `UT_idealweight` could produce unintended compounding effects. Exclusion set needs audit against all calorie-modifying UT traits.

5. **LOW — Frame-order race condition with other calorie-writing traits.**
   - The delta-diff approach reads `prev` (written last frame), reads `current`, then writes via `setCalories`. Any other UT trait that writes `setCalories` on `OnPlayerUpdate` in the same frame could cause the delta to be computed against a post-other-trait calorie value, resulting in double-counting or no-counting of the other trait's effect depending on execution order. Lua event handlers execute in registration order, which is determined by load order. This is latent and only manifests if a second calorie-writing OnPlayerUpdate handler exists.

## Final Verdict

- Source origin: confirmed — `idealweight` trait from MoreTraits Dynamic submod; source behavior (dynamic acquisition by maintaining weight in 78–82 range over configurable days) is thoroughly traced. UT fundamentally reinterprets the concept: instead of a badge earned by already maintaining ideal weight, UT turns it into a metabolic self-correction mechanic purchasable at character creation.
- UT implementation (Lua): **correct mechanics, wrong constants in source copy.** The calorie-delta approach is clean, well-guarded, and handles both overweight and underweight cases symmetrically. The two-handler architecture (weight cached on EveryOneMinute, calorie effect applied on OnPlayerUpdate) is efficient and consistent with other UT traits. The source copy has thresholds that diverge from release by ±1.
- Description: **critically wrong.** The description describes a completely different trait (carry weight + fatigue). Must be rewritten before this trait ships or is reviewed by players.
- Balance: reasonable design concept; cost (4) may be slightly low for an unconditional double-burn mechanic with no downside, but this cannot be confirmed without benchmarking the base calorie burn rate. No mutual exclusions are defined; potential stacking with calorie-modifying peers needs audit.
- Regression proof: two behavioral tests cover the core overweight and underweight cases correctly. Several gap cases are untested (normal-range no-op, eating skip, first-tick skip, trait-absent guard, boundary values).
- Action needed: **description fix (critical) | source sync (medium) | test additions (low) | exclusion audit (low)**
  - Rewrite `UI_UT_idealweightDesc` to describe the actual calorie mechanic.
  - Sync source copy thresholds (84→85, 76→75) to match release; update header comment.
  - Add tests: normal-range no-op, delta<=0 skip, trait-absent guard, boundary weight values.
  - Audit `UT_adaptivemetabolism`, `UT_accmetabolism`, and any other calorie-affecting trait for exclusion need.
- Open gaps:
  - Description is critically wrong — describes non-existent carry weight and fatigue effects.
  - Source copy thresholds do not match release copy.
  - No mutual exclusions defined — calorie-modifying trait stacking unaudited.
  - Normal-range no-op, eating skip, first-tick skip, and trait-absent guard are all untested.
  - Frame-order race condition with concurrent calorie-writing traits is latent.
