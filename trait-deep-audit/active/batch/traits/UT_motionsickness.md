# UT_motionsickness
## Trait Summary
- UT trait id: UT_motionsickness
- Source mod: More Traits (ToadTraits / MoreTraits by Toad)
- Source trait id: motionsickness (unnamespaced, B41)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits.lua` (B41 implementation, lines 3787–3848)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits - Dynamic.lua` (Dynamic extension, lines 583–590)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/Translate/EN/UI_EN.txt` (EN strings — not confirmed separately but corroborated by TR/RU/PTBR/PL/KO translations)
- Source behavior (B41, `MoreTraits.lua`):
  - Two separate functions handle the trait: `MotionSickness(player)` and `MotionSicknessHealthLoss(player)`.
  - `MotionSickness(player)` (lines 3787–3825):
    - Checks `player:HasTrait("motionsickness")` (unnamespaced string).
    - If the player is driving and `FakeInfectionLevel < 90.0`, reads vehicle speed in km/h and increments fake infection level per tick on a graduated scale:
      - Speed < 16 km/h: no increase (return early)
      - 16–30 km/h and Sickness < 21: +0.005 per tick
      - 31–40 km/h and Sickness < 26: +0.01 per tick
      - 41–50 km/h and Sickness < 38: +0.02 per tick
      - 51–55 km/h and Sickness < 48: +0.03 per tick
      - 56–60 km/h and Sickness < 73: +0.04 per tick
      - 61–90 km/h and Sickness < 80: +0.05 per tick
      - >= 91 km/h: +0.1 per tick (no cap until hard 90 limit)
    - Also sets `playerdata.MotionActive = true` when driving and `false` when not.
    - When the player is not driving and `FakeInfectionLevel != 0` and not already fakeInfected, decrements fake infection by 0.1 per tick (recovery).
  - `MotionSicknessHealthLoss(player)` (lines 3827–3848):
    - Checks `player:HasTrait("MotionSickness")` (mixed case — note inconsistency with lowercase "motionsickness" in the sibling function) and `playerdata.MotionActive == true`.
    - If `Health >= 100 - Sickness` and `Health > 35.0 (MaxHealth)`, applies body part damage to all body parts per tick:
      - Sickness < 40: no damage (return early)
      - Sickness 40–49 and Health > 90: +0.001 per tick per body part
      - Sickness 50–74 and Health > 75: +0.002 per tick per body part
      - Sickness >= 75: +0.005 per tick per body part
    - Note: the `HasTrait` case inconsistency between the two functions (`"motionsickness"` vs `"MotionSickness"`) means `MotionSicknessHealthLoss` would fail silently if PZ's `HasTrait` is case-sensitive.
  - More Traits Dynamic (`MoreTraits - Dynamic.lua`, lines 583–590): if the DrivingSkill mod is active and the player's Driving perk level reaches `MotionSickenssDynamicSkill` threshold, calls `player:getTraits():remove("motionsickness")` — the trait can be trained away. Not relevant to UT (UT has no DrivingSkill integration).
- Source trigger path: `Events.OnPlayerUpdate` (polled each tick, no interval throttle in source) → `MotionSickness(player)` and `MotionSicknessHealthLoss(player)`.
- Source mechanism: `getFakeInfectionLevel` / `setFakeInfectionLevel` — this is the "nausea/sickness" display stat used in PZ for non-zombie-bite illness. Distinct from actual zombie infection.
- Source EN strings (inferred from translations): `UI_trait_motionsickness = "Motion Sickness"` / `UI_trait_motionsicknessdesc` describes getting sick while driving, with severity dependent on vehicle speed.

## Current UT Evidence
### Structure
- Registered in run_tests.lua: yes — `"UniversalTraits:UT_motionsickness"` appears at line 302 in the Phase 3c — Event-Driven block, alongside `UT_vehophobic` and other vehicle-adjacent traits.
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_motionsickness`, `IsProfessionTrait = false`, `DisabledInMultiplayer = true`, `Cost = -4`. No `MutuallyExclusiveTraits` field present.
- Translation strings present: yes — `UI_UT_motionsickness = "Motion Sickness"` and `UI_UT_motionsicknessDesc = "Vehicles do not agree with you. Even short drives leave you nauseous and desperate for still ground."` in `media/lua/shared/Translate/EN/UI_EN.txt` (lines 632–633).
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_motionsickness.lua`

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_motionsickness.lua`
  - `UniversalTraits/media/scripts/UT_character_traits.txt`
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `UniversalTraits/test/run_tests.lua`
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits.lua` (source for comparison)
- Event registrations: `Events.OnPlayerUpdate.Add(onPlayerUpdate)` — registered once at module load time. No guard against multiple registrations.
- Runtime chain (plain language):
  1. Every game tick, `onPlayerUpdate(player)` fires.
  2. Checks `UTCore.hasTrait(player, "UniversalTraits:UT_motionsickness")`. If not present, returns immediately.
  3. Reads `playerId = player:getPlayerNum()` and `currentTick = getGameTime():getTicks()`.
  4. If fewer than 60 ticks have elapsed since the last check for this player, returns (throttle).
  5. Otherwise, records `lastCheckTick[playerId] = currentTick`.
  6. If `player:getVehicle() ~= nil` (player is in any vehicle, not necessarily driving), reads `stats = player:getStats()` and sets `stats:setStress(math.min(1, stats:getStress() + 0.01))`.
- Actual behavior (UT implementation, exact from source):
  - Fires every 60 ticks while the player has the trait.
  - If the player is in any vehicle (passenger or driver): adds +0.01 stress per 60-tick window, capped at 1.0 (max stress).
  - No recovery logic — stress does not decrease when the player leaves the vehicle (relies on the game's native stress decay).
  - No speed scaling — stress increment is flat +0.01 regardless of vehicle speed.
  - No fake infection / nausea mechanic — stat used is `stress`, not `FakeInfectionLevel`.

## UT Divergences from Source
1. **Stat used**: Source uses `FakeInfectionLevel` (nausea/sickness display). UT uses `stress`. These are completely different player stats with different UI representations and different gameplay effects.
2. **Speed scaling**: Source scales severity by vehicle speed across seven speed brackets (no effect below 16 km/h, escalating increments up to +0.1/tick at 91+ km/h). UT applies a flat +0.01 regardless of speed, with no minimum-speed threshold.
3. **Driving vs. passenger**: Source checks `player:isDriving()` — only the driver is affected. UT checks `player:getVehicle() ~= nil` — any occupant (driver or passenger) is affected.
4. **Recovery**: Source decrements `FakeInfectionLevel` by 0.1 per tick when not driving and not already fakeInfected, providing explicit recovery. UT has no recovery logic; stress decays via native game mechanics on its own schedule.
5. **Health damage**: Source includes a second function (`MotionSicknessHealthLoss`) that applies body-part damage when sickness reaches high levels (>= 40, escalating). UT has no health damage component.
6. **Throttle**: Source polls every tick with no throttle. UT throttles to once every 60 ticks, which reduces CPU load but coarsens the speed-bucket logic (moot since UT has no speed buckets).
7. **Trait check string**: Source uses unnamespaced `"motionsickness"` (B41 era). UT uses the namespaced `"UniversalTraits:UT_motionsickness"` via `UTCore.hasTrait`.
8. **Dynamic removal**: Source Dynamic extension allows the trait to be removed when Driving skill reaches a threshold. UT has no such mechanic and no `MutuallyExclusiveTraits` interactions.
9. **Cap**: Source hard-caps `FakeInfectionLevel` at 90.0 (and per-bracket sub-caps). UT caps stress at 1.0 via `math.min(1, ...)`, which is correct for the stress stat range.

## Description Integrity
- Display name check: `"Motion Sickness"` — identical to source name; accurate.
- Description check: `"Vehicles do not agree with you. Even short drives leave you nauseous and desperate for still ground."` — thematically accurate to the concept, but factually inconsistent with the implementation on two counts:
  1. The description says "even short drives leave you nauseous" — implies nausea/sickness. The implementation raises `stress`, not any nausea stat. A player reading the description would expect the nausea/illness display to fill, not the stress bar.
  2. "Even short drives" implies no speed threshold — which is true for the UT implementation (no speed minimum), but is the opposite of source (no effect below 16 km/h). The description accidentally matches UT behavior but not source intent.
- Missing details: The description does not state the actual mechanical effect (stress buildup), does not mention that passengers are affected (not just drivers), and gives no indication of severity or rate.

## Balance Review
- Downside: +0.01 stress per 60 ticks while in a vehicle. At 60 ticks per in-game minute (approximate), this is roughly +0.01 stress per in-game minute of vehicle travel. Reaching max stress (1.0) from zero would take ~100 in-game minutes of continuous vehicle travel. Stress at high levels increases panic, reduces combat effectiveness, and can cause unhappiness, but stress is also reduced by many in-game activities (reading, resting, eating, etc.).
- Upside: None. Pure negative trait.
- Severity assessment: mild to moderate. The +0.01/60-tick rate is slow enough that short trips cause negligible stress. Extended driving sessions (long-distance looting runs) could push stress meaningfully high, but the flat rate with no speed dependency makes it predictable and easily managed. Compare to source: source's `FakeInfectionLevel` mechanic at high speeds (+0.1/tick at 91+ km/h, no throttle) would visibly fill the sickness bar within seconds at highway speed — substantially more punishing and more cinematic. UT's stress approach is noticeably weaker in perceived severity.
- Cost: -4 points. Source cost is not directly confirmed from the MoreTraits B42 script definition (which was not reviewed), but the UT cost of -4 matches the cost visible in `UT_character_traits.txt`. For a trait with mild, slow-building stress buildup and no health damage or nausea, -4 is generous (favorable for the player choosing it). If the source's full severity (nausea + health damage + speed scaling) were implemented, -4 would be more appropriate.
- Peer comparison:
  - `UT_vehophobic` (cost -4): `DisabledInMultiplayer = true`, no runtime Lua reviewed in this audit — but structurally a sibling trait at the same cost tier in the vehicle-anxiety category.
  - `UT_expertdriver` (cost +5): purely positive vehicle trait at five points. Motion sickness at -4 for stress-only buildup is on the soft end of negative-trait value.
- Uptime: 100% while in any vehicle (driver or passenger); 0% otherwise.
- Stack or exclusion notes: No `MutuallyExclusiveTraits` defined. Nothing prevents taking `UT_motionsickness` alongside `UT_expertdriver` or `UT_vehophobic` from a script-definition standpoint. This is a gap — at minimum, `UT_vehophobic` (fear of vehicles) and `UT_motionsickness` (sickness in vehicles) are thematically redundant negative traits that could reasonably be mutually exclusive.

## Regression Proof
- Existing tests (run_tests.lua): `"UniversalTraits:UT_motionsickness"` appears only in the trait registration list at line 302 — it is included in the batch registration test (`"all 198 trait IDs registered with CharacterTrait"`, line 312). No dedicated behavior test exists for this trait.
- What the registration test proves: the trait ID is registered with `CharacterTrait.register` without error at load time. It does not test any runtime behavior.
- Missing proof:
  - No test verifies that stress increases when the player is in a vehicle.
  - No test verifies that stress does not increase when the player is not in a vehicle.
  - No test verifies the 60-tick throttle (only one increment per 60-tick window, not per tick).
  - No test verifies the stress cap at 1.0.
  - No test distinguishes driver vs. passenger (UT affects both; source affects only driver).
  - No test verifies that `lastCheckTick` is properly scoped per player index (multiplayer isolation, even though the trait is `DisabledInMultiplayer`).
- Minimum next tests if needed:
  - Test: player with trait in vehicle → `onPlayerUpdate` called 60+ ticks apart → `getStress()` increases by 0.01.
  - Test: player with trait not in vehicle → `onPlayerUpdate` called → `getStress()` unchanged.
  - Test: player with trait in vehicle at stress 0.99 → after increment → `getStress() == 1.0` (cap holds, not 1.01).
  - Test: `onPlayerUpdate` called twice within 60 ticks → only one stress increment applied.

## Final Verdict
- Source origin: confirmed — trait originates from More Traits (`motionsickness`), cost -4. The name and cost are preserved exactly.
- UT implementation: partial and divergent port. The core concept (vehicle travel causes a negative stat to build up) is preserved, but the mechanic is substantially simplified and changed:
  - Source: nausea (`FakeInfectionLevel`) + health damage, speed-scaled, driver-only, with explicit recovery and Dynamic-mod removal path.
  - UT: stress only, flat rate, driver-or-passenger, no health damage, no speed scaling, no recovery logic, no removal mechanic.
  - The UT version is noticeably weaker in severity than source. The switch from `FakeInfectionLevel` to `stress` is a fundamental design departure that changes both the visual experience (nausea UI vs. stress UI) and the downstream effects.
- Description: thematically plausible but mechanically inaccurate — says "nauseous" but implements stress; says "short drives" but does not surface what stat is affected or at what rate. A player cannot determine the actual mechanical impact from the description.
- Balance: weak negative for its cost — -4 points for slow, flat stress buildup with no speed scaling and no health risk is generous to the trait-taker. Source's full implementation would justify -4 or more; the UT port as implemented sits closer to a -2 or -3 severity level.
- Regression proof: registration only — no behavior tests exist.
- Action needed: doc fix, test fix, behavior review
- Open gaps:
  1. Decision required: implement the nausea (`FakeInfectionLevel`) mechanic with speed scaling (faithful port), or keep stress but document the divergence intentionally and adjust description/cost accordingly.
  2. Driving-only check: change `player:getVehicle() ~= nil` to `player:isDriving() == true` (or an equivalent check) to match source intent that only the driver is affected. Alternatively, make it explicit that passengers are intended to be affected (and update description).
  3. Description rewrite needed regardless of mechanic chosen: replace "nauseous" with the actual stat affected; surface the rate and trigger condition.
  4. No `MutuallyExclusiveTraits` defined — evaluate whether `UT_vehophobic` should be mutually exclusive (thematic overlap, both negative vehicle traits).
  5. No behavior tests — add at minimum: stress-increments-in-vehicle, no-increment-out-of-vehicle, cap-at-1.0, 60-tick throttle.
  6. No recovery mechanic — source explicitly decrements sickness when not driving. UT relies on passive stress decay. Whether this is intentional should be documented.
