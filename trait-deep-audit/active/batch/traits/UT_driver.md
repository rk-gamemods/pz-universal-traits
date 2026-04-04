# UT_driver
## Trait Summary
- UT trait id: UT_driver
- Source mod: UT-original (no direct source trait — intermediate driving tier invented for UT; closest source is MoreTraits `expertdriver` which is the tier above)
- Source trait id: n/a (UT-original)
- Current cost: 2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (B42 vehicleCheck, for context on tier above)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (trait registration, for tier above)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (registration context)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/Translate/EN/UI_EN.txt` (EN strings for tier above)
- Source trait: There is no "driver" (mid-tier) trait in MoreTraits or any other installed mod in the research corpus. MoreTraits provides only `expertdriver` (cost 5, positive) and `poordriver` (cost -5, negative) as a binary pair. `UT_driver` is a UT-original middle tier created to provide a weaker positive driving option at a lower point cost. The file header `-- Source: MoreTraits vehicleCheck()` documents design inspiration (the vehicleCheck pattern) but not a source trait being ported.
- Source vehicleCheck behavior (MoreTraits B42, for context only):
  - `expertdriver`: `brakingForce × 2`, `engineQuality × 2`, `engineLoudness × 0.25`, `enginePower × 3`, `maxSpeed × 1.25`, `mass × 0.5`, `initialMass × 0.5`, `offroadEfficiency × 2`, `regulatorSpeed × 2`. All applied on `OnPlayerUpdate` with a `vmd.sState` guard.
  - `poordriver`: mirror penalties — `brakingForce × 0.5`, `engineQuality × 0.5`, `engineLoudness × 1.5`, `enginePower × 0.66`, `maxSpeed × 0.75`, `mass × 1.33`, `initialMass × 1.33`, `offroadEfficiency × 0.5`, `regulatorSpeed × 0.66`.
  - There is no middle tier in source. `UT_driver` multipliers (all 1.2 / 0.8) are original UT design choices, presumably chosen as half the expertdriver step at cost 2 (versus expertdriver at 5).

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_driver = CharacterTrait.register("UniversalTraits:UT_driver")` at line 106. **Placement issue:** line 106 is in the general pre-phase block between `UT_prodigy` and `UT_amateurelectrician`, above the `-- PHASE 1 --` section banners. The PHASE 2 — LUA-DRIVEN: VEHICLE block (lines 220–225) contains `UT_expertdriver` and `UT_poordriver` but does not include `UT_driver`. `UT_driver` is a runtime Lua vehicle trait and belongs in the PHASE 2 VEHICLE block alongside its tier-mates.
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_driver`, `Cost = 2`, `IsProfessionTrait = false`, `DisabledInMultiplayer = true`, `MutuallyExclusiveTraits = UniversalTraits:UT_expertdriver;UniversalTraits:UT_poordriver`. No `XPBoosts` line in the script block.
- Translation strings present: yes — `UI_UT_driver = "Driver"` and `UI_UT_driverDesc = "Countless hours behind the wheel have made you a natural. Gain ×2 XP in Driving."` in `media/lua/shared/Translate/EN/UI_EN.txt` lines 239–240.
- Exclusions correct: partially — `UT_driver` excludes `UT_expertdriver` and `UT_poordriver`. `UT_expertdriver` excludes `UT_driver`, `UT_poordriver`, and `UT_vehophobic`. `UT_poordriver` excludes `UT_driver` and `UT_expertdriver`. All reciprocal pairs are present. `UT_driver` does not exclude `UT_vehophobic` (the vehicle phobia trait), while `UT_expertdriver` does. This asymmetry means a player could in theory hold both `UT_driver` and `UT_vehophobic` simultaneously; whether this is intentional is unclear.
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_driver.lua`
- Release copy matches: yes — `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_driver.lua` is byte-for-byte identical to the working file.

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_driver.lua`
  - `UniversalTraits/media/registries.lua`
  - `UniversalTraits/media/scripts/UT_character_traits.txt`
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `UniversalTraits/test/run_tests.lua`
  - `UniversalTraits/test/UTTestMocks.lua` (for UTCore vehicle dispatch implementation)
  - `UniversalTraits/media/lua/shared/UniversalTraits/UT_MET.lua` (for MET group membership)
- Event registrations: `UTCore.registerVehicleTrait` is called once at module load time. In the mock runtime (and mirrored in the real runtime via `UTCore._vehicleTraitEventsRegistered` guard), three events are registered globally once: `Events.OnVehicleEnter.Add(syncVehicleTrait)`, `Events.OnVehicleExit.Add(restoreVehicleMod)`, `Events.OnCreatePlayer.Add(syncVehicleTrait)`. These registrations are shared with `UT_expertdriver` and `UT_poordriver` — the guard prevents duplicate registration regardless of load order.
- MET group: `UT_driver` is in `UT_MET.Driving = { "UniversalTraits:UT_driver", "UniversalTraits:UT_expertdriver", "UniversalTraits:UT_poordriver" }` (`UT_MET.lua` line 52). This is consistent with the script-level mutual exclusion.
- UTCore vehicle dispatch mechanism:
  - `UTCore._vehicleTraitDefs` is a module-level list populated by each `registerVehicleTrait` call. Each entry holds `{ traitId, stateKey, mods, priority }`.
  - `UTCore.syncVehicleTrait(player, vehicle)` iterates `_vehicleTraitDefs`, finds the single highest-priority trait the player has, and calls `UTCore.applyVehicleMod(player, stateKey, mods)`. If the player is not driving, it calls `restoreVehicleMod` instead.
  - `UTCore.applyVehicleMod(player, stateKey, mods)`: caches baseline vehicle stats into `vehicle:getModData()` on first call (max speed, braking force, engine quality, engine loudness, engine power, mass, initial mass). Guards on `vmd.UT_vehicleTraitState == stateKey` to avoid redundant re-application. Applies all multipliers from the `mods` table against cached baselines. Sets `vmd.UT_vehicleTraitState = stateKey`.
  - `UTCore.restoreVehicleMod(vehicle)`: restores all seven cached baseline values and clears `UT_vehicleTraitState`.
- Runtime chain (plain language):
  1. At module load, `UTCore.registerVehicleTrait("UniversalTraits:UT_driver", "UT_driverState", { maxSpeed=1.2, enginePower=1.2, brakingForce=1.2, engineLoudness=0.8 }, 1)` inserts the driver definition into `UTCore._vehicleTraitDefs` with priority 1.
  2. On player entering a vehicle: `Events.OnVehicleEnter` fires → `syncVehicleTrait(player, vehicle)` → scans all registered vehicle trait defs → player has `UT_driver` (priority 1) and no higher-priority vehicle trait → calls `applyVehicleMod(player, "UT_driverState", mods)`.
  3. `applyVehicleMod` caches vehicle baselines into moddata if not already cached.
  4. Applies the four multipliers: `maxSpeed × 1.2`, `brakingForce × 1.2`, `enginePower × 1.2`, `engineLoudness × 0.8`. `engineQuality` and `mass`/`initialMass` are not in the mods table; `applyVehicleMod` uses `mods.engineQuality or 1.0` and `mods.mass or 1.0`, so those fields are unchanged from baseline.
  5. On player exiting: `Events.OnVehicleExit` fires → `restoreVehicleMod(vehicle)` → all cached baselines are restored; `UT_vehicleTraitState` cleared.
  6. `OnCreatePlayer` fires `syncVehicleTrait` — handles the player loading into a save already in a vehicle.
- Actual behavior (exact multipliers from `UT_driver.lua`):
  - `maxSpeed = 1.2` → top speed +20%
  - `brakingForce = 1.2` → braking force +20%
  - `enginePower = 1.2` → engine power +20%
  - `engineLoudness = 0.8` → engine 20% quieter (0.8× original)
  - `engineQuality` — **not modified** (no entry in mods table; defaults to 1.0×)
  - `mass` / `initialMass` — **not modified** (no `mass` entry in mods table; defaults to 1.0×)
- Priority: `priority = 1`. `UT_expertdriver` is registered with `priority = 2`. If priority arbitration were tested outside mutual exclusion, expertdriver would win. Within normal gameplay the mutual exclusion prevents co-occurrence.

### Description vs. Implementation Mismatch — CRITICAL
- The UI description states: `"Countless hours behind the wheel have made you a natural. Gain ×2 XP in Driving."`
- The script block (`UT_character_traits.txt`) has **no `XPBoosts` line** — there is no Driving XP boost defined in the script.
- The Lua file (`UT_driver.lua`) applies **vehicle stat multipliers only** — no XP boost of any kind is registered or applied. `UTCore.registerVehicleTrait` does not touch XP systems.
- **The description claims an XP effect that does not exist anywhere in the implementation.** The actual effect (four vehicle stat multipliers applied while driving) is not mentioned in the description at all.
- This is a description-implementation mismatch in both directions: the description advertises a non-existent effect and is completely silent on the four effects that are actually active.

## Balance Review
- Upside: Four vehicle stats improved while driving — top speed +20%, braking force +20%, engine power +20%, engine 20% quieter. Effects are applied on vehicle enter and removed on exit; active 100% of the time the player is driving.
- Downside: None (pure positive trait). `DisabledInMultiplayer = true` limits scope to singleplayer.
- Uptime: 100% while driving; 0% otherwise. No out-of-vehicle effect whatsoever.
- Peer comparison:
  - `UT_driver` (cost 2): four stats at ×1.2 / ×0.8. No engine quality change. No mass change.
  - `UT_expertdriver` (cost 5): six stats at much larger multipliers — ×1.25 max speed, ×2.0 braking, ×2.0 engine quality, ×0.25 loudness, ×3.0 engine power, ×0.5 mass.
  - `UT_poordriver` (cost -5): mirror of expertdriver in the negative direction.
  - The cost ladder is: -5 (poordriver) → 0 (no trait) → 2 (driver) → 5 (expertdriver). The gap from driver to expertdriver is 3 points of cost for a dramatic jump in effect magnitude — expertdriver's engine power is 3× vs. driver's 1.2×, braking is 2× vs. 1.2×, and expertdriver adds engine quality improvement and mass reduction that driver entirely lacks. The cost curve is arguably non-linear: driver at 2 points is weak relative to its price given expertdriver's value at 5.
- Stack or exclusion notes: Mutually exclusive with `UT_expertdriver` and `UT_poordriver`. Not mutually exclusive with `UT_vehophobic` (possible design gap; see above). Cannot combine with other vehicle tier traits.
- Cost verdict: borderline undervalued for what it actually does (four mild stat boosts while driving) — 2 points is low for a clean driving improvement. However, the description advertises an XP benefit that doesn't exist; if the XP boost were intended and implemented, cost 2 would be more appropriate.

## Regression Proof
- Existing tests (`run_tests.lua`):
  1. `"driver applies mild vehicle bonuses"` (lines 991–1000): creates a `MockVehicle()`, creates a `MockPlayer` with `"UniversalTraits:UT_driver"`, calls `player:setVehicle(vehicle)`, fires `Events.OnVehicleEnter`, then asserts:
     - `vehicle:getMaxSpeed() == 120` (baseline 100 × 1.2 = 120) — passes
     - `vehicle:getBrakingForce() == 12` (baseline 10 × 1.2 = 12) — passes
     - `vehicle:getEnginePower() == 120` (baseline 100 × 1.2 = 120) — passes
     - `vehicle:getEngineLoudness() == 80` (baseline 100 × 0.8 = 80) — passes
- What the test proves:
  - All four mods-table multipliers are wired correctly to the `applyVehicleMod` path and applied to the right vehicle API calls.
  - `OnVehicleEnter` → `syncVehicleTrait` → `applyVehicleMod` dispatch chain is functional for a single-vehicle-trait player.
- Missing proof:
  - No restore test for `UT_driver` — the restore test in the file covers `UT_expertdriver` (lines 1028–1040) but there is no equivalent for `UT_driver`. If `restoreVehicleMod` were broken specifically for the "UT_driverState" stateKey, the driver restore path would be untested.
  - No assertion for `getEngineQuality()` — correct behavior is that quality is unchanged (1.0× = baseline), but nothing pins this. If `applyVehicleMod` accidentally applied a non-1.0 quality multiplier, the test would not catch it.
  - No assertion for `getMass()` or `getInitialMass()` — correct behavior is unchanged (1.0×), same gap as quality.
  - No test covers the `OnCreatePlayer` sync path for the driver trait.
  - No test covers priority arbitration in isolation (would require bypassing the mutual exclusion rule at test level, same gap noted in expertdriver audit).
- Minimum next tests if needed:
  - Add a restore test: fire `OnVehicleEnter` then `OnVehicleExit` for a driver player; assert all four modified stats return to baseline (100, 10, 100, 100).
  - Add `assert_eq(vehicle:getEngineQuality(), 100, "expected engine quality unchanged")` and mass equivalents to the existing bonus test to pin the no-op fields.

## Final Verdict
- Source origin: UT-original — there is no mid-tier driver trait in any installed source mod. `UT_driver` was created by the UT author to fill the gap between the bare baseline and `expertdriver`. Multiplier values (1.2 / 0.8) are original design choices.
- UT implementation: functional — the four vehicle multipliers in `UT_driver.lua` are correctly registered, dispatched via `UTCore.registerVehicleTrait` with priority 1, and applied through the standard `syncVehicleTrait` → `applyVehicleMod` chain on `OnVehicleEnter`. Restoration on `OnVehicleExit` is wired correctly (via the shared `restoreVehicleMod` path). The implementation does exactly what the code says; the problem is entirely in the description.
- Description: **critically wrong** — the description (`"Gain ×2 XP in Driving"`) advertises an XP boost that does not exist in the script definition or the Lua runtime. The actual behavior (four vehicle stat multipliers while driving) is completely absent from the description. This is the highest-severity documentation gap in this audit.
- Balance: defensible at cost 2 for a mild, driving-only, four-stat improvement. The ×1.2 multipliers are modest. If the XP boost were intended to be real, cost 2 would be appropriate for a mixed benefit; as a pure vehicle-stats trait it is borderline weak relative to the point cost.
- Regression proof: partial — the four implemented multipliers are pinned with exact-value assertions; restore path is untested for this specific trait; no-op fields (quality, mass) are unasserted.
- registries.lua placement: `UT_driver` is registered at line 106 in the pre-phase general block, not in the `-- PHASE 2 -- LUA-DRIVEN: VEHICLE --` section (lines 220–225) where `UT_expertdriver` and `UT_poordriver` live. This is a structural inconsistency.
- Action needed: critical fix (description), structural fix (registries placement), test fix
- Open gaps:
  1. **CRITICAL — Description/implementation mismatch:** `UI_UT_driverDesc` claims `"Gain ×2 XP in Driving"` — no XP boost exists anywhere (not in `UT_character_traits.txt`, not in `UT_driver.lua`). Either implement the XP boost (add `XPBoosts = Driving=1` to the script block) or rewrite the description to accurately describe the vehicle stat multipliers that are actually applied.
  2. **Missing vehophobic exclusion:** `UT_driver` does not exclude `UT_vehophobic`; `UT_expertdriver` does. Evaluate whether `UT_driver` should also exclude `UT_vehophobic` for consistency.
  3. **registries.lua misplacement:** `UT_driver` is in the pre-phase block at line 106; it belongs in the `PHASE 2 — LUA-DRIVEN: VEHICLE` block alongside `UT_expertdriver` and `UT_poordriver`.
  4. **No restore test:** add a `OnVehicleExit` restore test for `UT_driver` to pin the round-trip behavior.
  5. **Unasserted no-op fields:** `engineQuality`, `mass`, `initialMass` are correctly left at baseline but are not asserted in the test — add assertions to prevent accidental regression.
  6. **No `OnCreatePlayer` test** for the driver path (shared gap with expertdriver).
