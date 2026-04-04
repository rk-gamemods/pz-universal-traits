# UT_expertdriver
## Trait Summary
- UT trait id: UT_expertdriver
- Source mod: More Traits (ToadTraits / MoreTraits by Toad)
- Source trait id: ToadTraits:expertdriver
- Current cost: 5
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (trait definition)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (B42 implementation)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits.lua` (old B41 implementation)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (trait registration)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/Translate/EN/UI_EN.txt` (EN strings)
- Source trigger path: `Events.OnPlayerUpdate` (polled each tick) → `vehicleCheck(player)` → if `player:hasTrait(ToadTraitsRegistries.expertdriver)` and state is not already `"ExpertDriver"`, applies all multipliers and calls `vehicle:update()`.
- Source behavior (B42, `MoreTraits .lua`):
  - `vehicle:setBrakingForce(base * 2)` — braking force doubled
  - `vehicle:setEngineFeature(quality * 2, loudness * 0.25, power * 3)` — engine quality 2×, loudness 75% quieter, engine power 3×
  - `vehicle:setMaxSpeed(base * 1.25)` — top speed +25%
  - `vehicle:setMass(base * 0.5)` and `vehicle:setInitialMass(base * 0.5)` — both mass fields halved; `vehicle:updateTotalMass()` called
  - `vehicle:getScript():setOffroadEfficiency(base * 2)` — off-road efficiency doubled
  - `vehicle:setRegulatorSpeed(base * 2)` — regulator speed doubled
  - State is tracked via a `vmd.sState` field set to `"ExpertDriver"`; same vehicleCheck function handles poordriver and normal restore.
  - B41 version (`MoreTraits.lua`) is mechanically identical but uses `player:HasTrait("expertdriver")` (unnamespaced string) and polls on `OnPlayerUpdate`.
- Source trait definition (`ToadTraits.txt`): Cost = 5, `MutuallyExclusiveTraits = ToadTraits:poordriver`. Note: `ToadTraits:motionsickness` exclusion is commented out in the source script.
- Source registration (`registries.lua`): `ToadTraitsRegistries.expertdriver = CharacterTrait.register("ToadTraits:expertdriver")` is guarded by `if getActivatedMods():contains("DrivingSkill") == false` — trait is suppressed when the Driving Skill mod is active.
- Source EN strings: `UI_trait_expertdriver = "Expert Driver"` / `UI_trait_expertdriverdesc = "You drive cars much more effectively.<br>Vehicles move faster, make less noise, and handle more efficiently."`

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_expertdriver = CharacterTrait.register("UniversalTraits:UT_expertdriver")` at line 224, under the PHASE 2 — LUA-DRIVEN: VEHICLE block. No DrivingSkill guard in UT (divergence from source).
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_expertdriver`, `Cost = 5`, `DisabledInMultiplayer = true`, `MutuallyExclusiveTraits = UniversalTraits:UT_driver;UniversalTraits:UT_poordriver;UniversalTraits:UT_vehophobic`.
- Translation strings present: yes — `UI_UT_expertdriver = "Expert Driver"` and `UI_UT_expertdriverDesc = "Years behind the wheel have made you one of the best. Improves vehicle handling while driving."` in `media/lua/shared/Translate/EN/UI_EN.txt`.
- Exclusions/grants correct: partially — `UT_expertdriver` excludes `UT_driver`, `UT_poordriver`, and `UT_vehophobic`. `UT_driver` excludes `UT_expertdriver` and `UT_poordriver`. `UT_poordriver` excludes `UT_driver` and `UT_expertdriver`. `UT_vehophobic` excludes `UT_expertdriver`. All reciprocal entries present. Source only excluded `poordriver`; UT adds `UT_driver` and `UT_vehophobic` exclusions, which are UT-original design choices and are internally consistent.
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_expertdriver.lua`

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_expertdriver.lua`
  - `UniversalTraits/media/registries.lua`
  - `UniversalTraits/media/scripts/UT_character_traits.txt`
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `UniversalTraits/test/run_tests.lua`
  - `UniversalTraits/test/UTTestMocks.lua` (for UTCore vehicle dispatch implementation)
- Event registrations: `UTCore.registerVehicleTrait` is called once at module load time. In the mock runtime (and mirrored in the real runtime via `UTCore._vehicleTraitEventsRegistered` guard in `UTTestMocks.lua` lines 700–710), three events are registered globally once: `Events.OnVehicleEnter.Add(syncVehicleTrait)`, `Events.OnVehicleExit.Add(restoreVehicleMod)`, `Events.OnCreatePlayer.Add(syncVehicleTrait)`.
- UTCore vehicle dispatch mechanism:
  - `UTCore._vehicleTraitDefs` is a list of registered vehicle trait definitions (traitId, stateKey, mods table, priority).
  - `UTCore.syncVehicleTrait(player, vehicle)` iterates `_vehicleTraitDefs`, finds the highest-priority matching trait the player has, and calls `UTCore.applyVehicleMod(player, stateKey, mods)`.
  - `UTCore.applyVehicleMod` caches baseline vehicle stats into `vehicle:getModData()` on first call, then sets all vehicle stats using the multiplier table. `mass` multiplier applies to both `setMass` and `setInitialMass`.
  - `UTCore.restoreVehicleMod` restores all baseline stats from moddata and clears `UT_vehicleTraitState`.
- Runtime chain (plain language):
  1. At module load, `UTCore.registerVehicleTrait("UniversalTraits:UT_expertdriver", "UT_expertState", { ... }, 2)` inserts the expertdriver definition into `UTCore._vehicleTraitDefs` with priority 2.
  2. On player entering a vehicle: `Events.OnVehicleEnter` fires → `syncVehicleTrait(player, vehicle)` → scans all registered vehicle trait defs → player has `UT_expertdriver` (priority 2) and no higher-priority trait → calls `applyVehicleMod(player, "UT_expertState", mods)`.
  3. `applyVehicleMod` caches baseline vehicle stats (max speed, braking force, engine quality/loudness/power, mass, initial mass) into vehicle moddata if not already cached.
  4. Applies all multipliers from the `mods` table against cached baselines; sets `UT_vehicleTraitState = "UT_expertState"`.
  5. On player exiting the vehicle: `Events.OnVehicleExit` fires → `restoreVehicleMod(vehicle)` → all cached baselines are written back to the vehicle; `UT_vehicleTraitState` cleared.
  6. `OnCreatePlayer` also fires `syncVehicleTrait` — covers cases where the player loads into a save already in a vehicle.
- Actual behavior (exact multipliers from `UT_expertdriver.lua`):
  - `maxSpeed = 1.25` → top speed +25%
  - `brakingForce = 2.0` → braking force 2× (doubled)
  - `engineQuality = 2.0` → engine quality 2× (doubled)
  - `engineLoudness = 0.25` → engine loudness 75% quieter (0.25× original)
  - `enginePower = 3.0` → engine power 3× (tripled)
  - `mass = 0.5` → both vehicle mass and initial mass halved (0.5×); `updateTotalMass()` called
- UT divergences from source:
  1. `offroadEfficiency` multiplier (2×) from source is **absent** in UT — not in the `mods` table and `applyVehicleMod` does not set off-road efficiency.
  2. `regulatorSpeed` multiplier (2×) from source is **absent** in UT — not supported by `applyVehicleMod`.
  3. UT applies on `OnVehicleEnter` (event-driven, once per entry) and restores on `OnVehicleExit`. Source applies in `OnPlayerUpdate` every tick with a state guard. The net result for a single-trait player is functionally identical for the six shared stats, but source's tick-poll would catch mid-session trait changes; UT's approach is cleaner but would not update if the trait were granted while the player is already in a vehicle.
  4. No DrivingSkill guard in UT; source suppresses the trait when the DrivingSkill mod is loaded.

## Description Integrity
- Display name check: `"Expert Driver"` — identical to source name; accurate to intent.
- Description check: `"Years behind the wheel have made you one of the best. Improves vehicle handling while driving."` — vague and underspecified. It does not state any of the six actual multipliers applied. Source description (`"You drive cars much more effectively. Vehicles move faster, make less noise, and handle more efficiently."`) is also vague but at least lists three of the five visible improvement axes. UT description reduces to a single generic clause ("Improves vehicle handling while driving") that is accurate but provides zero numeric information.
- Missing details: The description is silent on all of the following effects that are implemented: +25% top speed, 2× braking force, 2× engine quality, 75% noise reduction, 3× engine power, 50% mass reduction. It is also silent on the two source effects that were dropped (off-road efficiency, regulator speed). A player reading the description cannot form any expectation of magnitude for any stat.

## Balance Review
- Upside: Six vehicle stats improved simultaneously, all while driving. Magnitudes are large — engine power at 3× is extreme; braking force 2× and mass halved meaningfully change vehicle feel and acceleration. Engine loudness at 0.25× (75% quieter) is relevant for stealth. Effects are applied on enter and removed on exit, so they are active 100% of the time the player is driving.
- Downside: None (pure positive trait). `DisabledInMultiplayer = true` limits scope to singleplayer.
- Uptime: 100% while driving; 0% otherwise. Trait has no out-of-vehicle effect.
- Peer comparison:
  - `UT_driver` (cost 2): +20% max speed, +20% braking, +20% engine power, 20% quieter engine — four stats, mild multipliers.
  - `UT_expertdriver` (cost 5): +25% max speed, 2× braking, 2× engine quality, 75% noise reduction, 3× engine power, half mass — six stats, extreme multipliers.
  - `UT_poordriver` (cost -5): mirror penalties, symmetric cost.
  - Cost delta from `UT_driver` to `UT_expertdriver` is 3 points. The jump from UT_driver's mild bonuses to expertdriver's 3× engine power and 2× braking is non-linear — the magnitude increase far exceeds the cost increase. At 5 points, the trait delivers disproportionate vehicle performance relative to its cost in the UT economy.
- Stack or exclusion notes: Mutually exclusive with `UT_driver`, `UT_poordriver`, and `UT_vehophobic`. Cannot combine with weaker driver tier or with vehicle phobia. No stacking scenario possible within the vehicle trait group.
- Cost verdict: defensible but leaning strong — 5 points matches source cost, but the two dropped effects (off-road efficiency 2×, regulator speed 2×) were not compensated by a cost reduction. The trait is weaker than source on those two axes, but the retained effects are still powerful. Cost 5 is at the edge of reasonable for a driving-only trait.

## Regression Proof
- Existing tests (run_tests.lua):
  1. `"expertdriver applies the full vehicle bonus package"` (lines 1002–1013): fires `OnVehicleEnter` with a mock vehicle and asserts exact values — `getMaxSpeed() == 125`, `getBrakingForce() == 20`, `getEngineQuality() == 200`, `getEngineLoudness() == 25`, `getEnginePower() == 300`, `getMass() == 500`. All six implemented stats are pinned with exact-value assertions against a baseline-100/1000-mass mock.
  2. `"vehicle traits restore the baseline stats on exit"` (lines 1028–1040): fires `OnVehicleEnter` then `OnVehicleExit` with an expertdriver player; asserts all six stats return to baseline. Proves restoration wiring is not broken.
- What they prove:
  - All six multipliers in `UT_expertdriver.lua` are exactly correct at the time the tests pass.
  - The `applyVehicleMod` → `restoreVehicleMod` round-trip is clean.
  - The priority dispatch (`priority = 2`) is indirectly proven to not block the single-trait case.
- Missing proof:
  - The `getMass()` test asserts `== 500` but there is no assertion for `getInitialMass()` — the restore test also does not assert initial mass returns to baseline. If `setInitialMass` stopped being called in `applyVehicleMod`, the mass test would still pass via `getMass()`.
  - No test covers the priority arbitration: no test confirms that a player with both `UT_driver` (priority 1) and `UT_expertdriver` (priority 2) results in the expertdriver stats being applied (they are mutually exclusive in the script, but a unit test of the priority logic would be independent of the exclusion rule).
  - No test covers `OnCreatePlayer` sync path.
  - No test verifies that off-road efficiency and regulator speed are **not** modified (i.e., that the UT impl does not accidentally apply source values for those fields).
- Minimum next tests if needed:
  - Add `assert_eq(vehicle:getInitialMass(), 500, ...)` to the bonus test and `assert_eq(vehicle:getInitialMass(), 1000, ...)` to the restore test.
  - Add a priority conflict test: register a mock player with both `UT_driver` and `UT_expertdriver` (bypassing exclusion at test level) and verify `getMaxSpeed() == 125` (expertdriver wins) not `120` (driver wins).

## Final Verdict
- Source origin: proven — trait originates from More Traits (ToadTraits:expertdriver), cost 5, mutually exclusive with poordriver. Name and cost are preserved exactly. Source also provides DrivingSkill mod guard and off-road efficiency + regulator speed multipliers.
- UT implementation: partial port — the six core vehicle multipliers (max speed, braking, engine quality, loudness, power, mass) are ported faithfully and exactly match source values. Two source multipliers are dropped: off-road efficiency (2×) and regulator speed (2×). These omissions are not documented. The architecture switches from tick-poll with state guard (source) to event-driven OnVehicleEnter/OnVehicleExit dispatch (UT), which is cleaner but loses mid-session trait change responsiveness. The DrivingSkill mod guard is not ported.
- Description: inadequate — the description provides no numeric information about any of the implemented effects. It correctly conveys that the trait improves driving but gives the player no basis to evaluate the magnitude or scope of changes. Source description was also vague but listed more axes. Needs a rewrite that names at least the headline numbers.
- Balance: defensible — source cost 5 is preserved; the two dropped effects (off-road, regulator) slightly weaken the trait relative to source without a corresponding cost reduction, which is acceptable. The retained effects remain strong, particularly 3× engine power and 2× braking.
- Regression proof: mostly strong — all six implemented stats are pinned with exact values for both enter and exit; initial-mass assertion is missing from both tests.
- Action needed: doc fix, test fix
- Open gaps:
  - Description gives zero numeric information; rewrite should surface at least the headline effects (e.g., +25% top speed, 3× engine power, 2× braking, 75% quieter, half mass).
  - Off-road efficiency (2×) and regulator speed (2×) from source are silently dropped; either implement them or note the omission in a code comment.
  - No DrivingSkill mod guard; if DrivingSkill mod is active alongside UT, both traits are available and may conflict. Evaluate whether UT should suppress or integrate.
  - `getInitialMass()` is not asserted in either vehicle test; add exact-value assertions to pin the full mass behavior.
  - Priority arbitration logic has no dedicated test.
