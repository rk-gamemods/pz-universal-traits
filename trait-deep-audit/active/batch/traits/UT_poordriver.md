# UT_poordriver
## Trait Summary
- UT trait id: UT_poordriver
- Source mod: More Traits (ToadTraits / MoreTraits by Toad)
- Source trait id: ToadTraits:poordriver
- Current cost: -5
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (trait definition)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits.lua` (client-side vehicle hook)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (EN strings)
- Source trigger path: `Events.OnVehicleEnter` (vehicle check loop) → `vehicleCheck(player, vehicle)` → checks `player:HasTrait("poordriver")` and applies multipliers if `vmd.sState ~= "PoorDriver"`.
- Source behavior: On vehicle enter, the following multipliers are applied to the active vehicle:
  - `brakingForce × 0.5` (half braking force)
  - `engineQuality × 0.5` (half engine quality)
  - `engineLoudness × 1.5` (50% louder engine)
  - `enginePower × 0.66` (~34% power penalty)
  - `maxSpeed × 0.75` (25% slower top speed)
  - `mass × 1.33` (33% heavier / worse handling)
  - `offroadEfficiency × 0.5` (half off-road efficiency)
  - `regulatorSpeed × 0.66` (~34% slower cruise control)
  - State is set to `"PoorDriver"` and `vehicle:update()` is called to apply.
  - On exit (no-trait restore branch), if neither expertdriver nor poordriver is present, all stats are restored to baseline.
- Source cost: -5, mutually exclusive with `ToadTraits:expertdriver` only (no exclusion with `ToadTraits:driver` in source script).
- Source display name: "Student Driver"
- Source description: "You have limited experience with vehicles. Vehicles move slowly, make more noise, and handle less efficiently."

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — present in the trait ID list in `run_tests.lua` line 274 under `-- Phase 2 — Vehicle (3)`; loaded via `dofile` at line 465.
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_poordriver` at line 1546, Cost = -5.
- Translation strings present: yes — `UI_UT_poordriver = "Student Driver"` and `UI_UT_poordriverDesc = "You never quite got the hang of driving. Worsens vehicle handling while driving."` in `UI_EN.txt` lines 479-480.
- Exclusions/grants correct: yes — `MutuallyExclusiveTraits = UniversalTraits:UT_driver;UniversalTraits:UT_expertdriver` in `UT_character_traits.txt` line 1554. UT adds mutual exclusion with `UT_driver` (not present in source), which is a UT-specific design decision to prevent stacking with the mild positive driver trait. `UT_driver` (line 837) and `UT_expertdriver` (line 1543) both list `UT_poordriver` in their mutual exclusion lists, so all three sides of the relationship are consistent.
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_poordriver.lua`

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_poordriver.lua`
  - `UniversalTraits/media/scripts/UT_character_traits.txt`
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `UniversalTraits/test/run_tests.lua`
- UT_CORE hooks used: `UTCore.registerVehicleTrait(TRAIT_ID, "UT_poorState", multipliers, priority=2)`
- Runtime chain (plain language):
  1. `registerVehicleTrait` registers the trait ID with the state key `"UT_poorState"` and the multiplier table, at priority 2.
  2. UTCore's `OnVehicleEnter` handler fires when the player enters a vehicle.
  3. The handler checks whether the player has `UniversalTraits:UT_poordriver`.
  4. If present and the vehicle's state key is not already `"UT_poorState"`, UTCore applies all multipliers in the registered table to the vehicle's baseline stats.
  5. UTCore's `OnVehicleExit` handler fires when the player exits. Because no other vehicle trait is active, the vehicle stats are restored to their captured baseline.
- Actual behavior (exact values from `UT_poordriver.lua` lines 4-11):
  - `maxSpeed × 0.75` — 25% top speed reduction
  - `brakingForce × 0.5` — braking force halved
  - `engineQuality × 0.5` — engine quality halved
  - `engineLoudness × 1.5` — engine 50% louder
  - `enginePower × 0.66` — engine power reduced by ~34%
  - `mass × 1.33` — vehicle mass increased by ~33%
- Omitted from source: `offroadEfficiency × 0.5` and `regulatorSpeed × 0.66` — present in MoreTraits source `vehicleCheck()` but absent from `registerVehicleTrait` parameters and not implemented anywhere in the UTCore vehicle system.

## Description Integrity
- Display name check: "Student Driver" — matches source name exactly; appropriate and clear.
- Description check: `"You never quite got the hang of driving. Worsens vehicle handling while driving."` — vague. The source description ("Vehicles move slowly, make more noise, and handle less efficiently") names three categories of effect. The UT description gives none of the specific stat penalties and does not quantify any effect. The word "handling" is an informal umbrella that technically covers braking, mass, and offroad efficiency, but the player cannot determine the magnitude of any penalty from this description.
- Missing or misleading details: No numeric values are stated. The description does not mention that engine power is also reduced (~34%), that the engine becomes 50% louder, or that top speed is cut by 25%. "Worsens vehicle handling" understates a six-axis penalty package including engine quality, engine power, braking, mass, loudness, and top speed.

## Balance Review
- Upside: Grants -5 points (negative cost, so player earns 5 points on character creation).
- Downside: Six vehicle stat multipliers, all penalties, applied every time the player enters a vehicle. All effects persist for the entire driving session and are removed only on exit.
  - Top speed: -25%
  - Braking force: -50%
  - Engine quality: -50%
  - Engine loudness: +50% (draws more zombie attention)
  - Engine power: -34%
  - Vehicle mass: +33%
- Uptime: 100% whenever driving. Effects are zero when not in a vehicle.
- Peer comparison: `UT_expertdriver` costs +5 and grants symmetric but stronger improvements (maxSpeed +25%, brakingForce +100%, engineQuality +100%, engineLoudness -75%, enginePower +200%, mass -50%). The magnitudes are deliberately asymmetric: the positive version is much stronger in the beneficial direction than the negative version is in the harmful direction for most stats. The loudness penalty (+50% vs. -75% for expert) is comparatively mild. The mass penalty (+33% vs. -50% for expert) is also less severe proportionally.
- Stack or exclusion notes: Mutually exclusive with both `UT_driver` and `UT_expertdriver`. Cannot stack with any positive vehicle handling trait. UT adds the `UT_driver` exclusion beyond what the source did — prevents combining a mild positive with the negative.
- Source also penalized `offroadEfficiency` and `regulatorSpeed` (cruise control). UT omits both. This makes the UT implementation slightly weaker than the source at -5 cost.
- Cost verdict: reasonable, possibly one point generous to the player (the penalty package is real but the omission of offroadEfficiency and regulatorSpeed from the source reduces effective cost). The vehicle system is situationally relevant — players who never drive are unaffected by a -5 penalty trait. However, this is a known UT vehicle trait design tradeoff.

## Regression Proof
- Existing test: yes — `run_tests.lua` lines 1015-1026: `"poordriver applies the full vehicle penalty package"` — creates a MockPlayer with `UniversalTraits:UT_poordriver`, fires `Events.OnVehicleEnter`, then asserts all six stat values:
  - `vehicle:getMaxSpeed() == 75` (expected -25% from baseline 100)
  - `vehicle:getBrakingForce() == 5` (expected half from baseline 10)
  - `vehicle:getEngineQuality() == 50` (expected half from baseline 100)
  - `vehicle:getEngineLoudness() == 150` (expected +50% from baseline 100)
  - `vehicle:getEnginePower() == 66` (expected -34% from baseline 100)
  - `math.abs(vehicle:getMass() - 1330) < 0.1` (expected +33% from baseline 1000)
- Additional coverage: `run_tests.lua` lines 1028-1040: `"vehicle traits restore the baseline stats on exit"` tests the exit-restore path using `UT_expertdriver`; the same UTCore restore handler is shared by all vehicle traits including `UT_poordriver`.
- What it proves: All six registered multipliers apply correctly on `OnVehicleEnter`. Exact numeric values are pinned for every stat. The mass assertion uses a float-safe tolerance check.
- Missing proof: The exit-restore test uses `UT_expertdriver`, not `UT_poordriver`. There is no dedicated test confirming that `UT_poorState` is correctly cleared and stats are restored to baseline after a poordriver session. The omitted `offroadEfficiency` and `regulatorSpeed` effects are not tested (and are not implemented), so a future addition of those fields would require new test cases.
- Minimum next test if needed: Add a `"poordriver restores baseline stats on exit"` test that fires both `OnVehicleEnter` and `OnVehicleExit` with the poordriver trait and asserts all six stats return to their baseline values.

## Final Verdict
- Source origin: proven — trait originates from More Traits (ToadTraits:poordriver), cost -5, mutually exclusive with expertdriver. Display name, cost, and all six core stat multipliers are preserved exactly from source.
- UT implementation: partially complete — six of the eight source multipliers are implemented via `UTCore.registerVehicleTrait`. The two omitted effects (`offroadEfficiency × 0.5` and `regulatorSpeed × 0.66`) are not implemented and have no UTCore support. This is a known gap in the vehicle trait system, not a bug in the poordriver file itself. The exclusion set is widened (adds `UT_driver`) beyond source.
- Description: insufficient — "Worsens vehicle handling while driving" is too vague for a six-axis penalty package. No numeric values, no mention of engine power, engine loudness, or top speed penalties. Players cannot make an informed cost/benefit decision.
- Balance: reasonable — -5 points for a real six-stat vehicle penalty is consistent with the source cost. The two omitted effects (offroad efficiency, cruise control speed) mean UT is slightly weaker than the source for the same price, which marginally favors the player.
- Regression proof: strong for entry path — all six multipliers have exact-value assertions. Exit-restore path is tested only indirectly via expertdriver.
- Action needed: doc fix, test addition (exit restore)
- Open gaps:
  - Description is too vague; should enumerate at least the major penalty categories and magnitudes (top speed -25%, engine louder, braking halved).
  - No dedicated test for stat restoration on vehicle exit with the poordriver trait specifically.
  - `offroadEfficiency` and `regulatorSpeed` are not implemented anywhere in UTCore or in this trait file; if UTCore vehicle trait support is ever extended to cover these fields, poordriver should receive them as `offroadEfficiency = 0.5` and `regulatorSpeed = 0.66`.
  - UT adds mutual exclusion with `UT_driver` that source did not have — this is a valid design choice but is undocumented in any trait description or changelog.
