# UT_vehophobic
## Trait Summary
- UT trait id: UT_vehophobic
- Source mod: SomewhatTraits (SWTraits:SWVehophobic by somewhatfrog)
- Source trait id: SWTraits:SWVehophobic
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/scripts/SWTraits_character_traits.txt` (trait definition)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCoreOverrides.lua` (behavior implementation, latest)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (B42.12 registration and METs)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/SWTraits_MET.lua` (B42.15 MET wiring)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/registries.lua` (trait registry list)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` (EN strings)
- Source trigger path: `Events.EveryOneMinute.Add(SWCheckOverrideTraits)` polls once per in-game minute and sets a module-level boolean `vehoPhobic`. The actual block is in a method override: `ISEnterVehicle.isValid` is wrapped so that if `vehoPhobic == true`, the function returns `false`, preventing the player from entering any vehicle entirely.
- Source behavior:
  - Player cannot enter vehicles at all — `ISEnterVehicle:isValid()` returns `false` whenever the trait is active.
  - No panic or stress effects. No continuous per-tick loop. Effect is a hard UI/action block at the isValid layer.
  - The trait boolean is updated once per in-game minute via `character:HasTrait("SWVehophobic")`.
- Source trait definition (`SWTraits_character_traits.txt`): Cost = -6, `DisabledInMultiplayer = false`, no `MutuallyExclusiveTraits` field in the script definition block itself (METs added programmatically).
- Source METs (programmatic): `SpeedDemon` ↔ `SWVehophobic`, `SundayDriver` ↔ `SWVehophobic`, `MotionSensitive` ↔ `SWVehophobic` (B42.15 MET wiring).
- Source EN strings: `UI_trait_SWVehophobic = "Vehophobic"` / `UI_trait_SWVehophobic_Desc = "Can't enter vehicles."`

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `"UniversalTraits:UT_vehophobic"` appears in the run_tests.lua Phase 3c — Event-Driven registration list at line 302; consistent with registration in `media/registries.lua`.
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_vehophobic`, `Cost = -4`, `IsProfessionTrait = false`, `DisabledInMultiplayer = true`, `MutuallyExclusiveTraits = UniversalTraits:UT_expertdriver`.
- Translation strings present: yes — `UI_UT_vehophobic = "Vehophobic"` and `UI_UT_vehophobicDesc = "Getting behind the wheel or into a vehicle fills you with dread. The fear is irrational but it is very real."` in `media/lua/shared/Translate/EN/UI_EN.txt`.
- Exclusions/grants correct: partially — `UT_vehophobic` excludes `UT_expertdriver` (declared in UT_vehophobic's own block). `UT_expertdriver` in its own block lists `UT_vehophobic` in `MutuallyExclusiveTraits`, confirming the reciprocal is present. Source (B42.15) also excluded `SpeedDemon`, `SundayDriver`, and `MotionSensitive` vanilla traits; UT does not replicate those cross-mod exclusions. Source cost was -6; UT cost is -4 — a deliberate UT rebalance (see Balance Review).
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_vehophobic.lua`

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_vehophobic.lua`
  - `UniversalTraits/media/scripts/UT_character_traits.txt`
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `UniversalTraits/test/run_tests.lua`
- Event registrations: `Events.OnPlayerUpdate.Add(onPlayerUpdate)` registered at module load time (line 28 of the Lua file). Fires every game tick for each human player.
- Runtime chain (plain language):
  1. Each tick, `onPlayerUpdate(player)` fires.
  2. If the player does not have `"UniversalTraits:UT_vehophobic"`, returns immediately.
  3. If the player is not currently driving (`player:isDriving()` is false), returns immediately.
  4. Reads `md["UT_vehophobic_cooldown"]` from player moddata; initialises to 0 if nil.
  5. If cooldown > 0, decrements it by 1 and returns — no stat change this tick.
  6. If cooldown is 0 (or has just expired), applies stat changes inside a `pcall`:
     - `stats:setPanic(math.min(1, stats:getPanic() + 0.01))` — panic raised by 0.01 (capped at 1.0).
     - `stats:setStress(math.min(1, stats:getStress() + 0.005))` — stress raised by 0.005 (capped at 1.0).
  7. Resets cooldown to 30 ticks.
- Effective rate: one stat update per 30 ticks. At standard 30 ticks/second that is once per second; exact tick rate is server-configurable.
- Actual behavior: continuous panic and stress accumulation while driving, not a hard vehicle-entry block. This is a fundamental design divergence from source.

## Description Integrity
- Display name check: `"Vehophobic"` — identical to source name; accurate.
- Description check: `"Getting behind the wheel or into a vehicle fills you with dread. The fear is irrational but it is very real."` — flavour text only; states no mechanical effect whatsoever. The description implies the trait might prevent vehicle entry ("Getting behind the wheel... fills you with dread") but the actual implementation causes panic and stress accumulation while driving, not a block. A player reading this description would have no idea the trait causes continuous stat drain during driving, and would not know about the panic/stress rate, the cooldown cycle, or the cap-at-1.0 ceiling.
- Source description was `"Can't enter vehicles."` — a single-sentence hard mechanical statement. UT rewrote the source description entirely as narrative flavour, losing all mechanical information in exchange for zero new clarity about what actually happens.
- Missing details: The description must convey that the trait raises panic and stress continuously while driving. It currently conveys nothing mechanical.

## Balance Review
- Upside (to the character): none. Pure negative trait.
- Downside (the penalty): panic raised by +0.01 per 30 ticks and stress raised by +0.005 per 30 ticks while driving; both capped at 1.0. At maximum accumulation rate (continuous driving with no moderation), panic reaches maximum in approximately 100 seconds and stress in approximately 200 seconds of uninterrupted driving. These accumulation times assume starting from 0; actual times are faster if the character starts with elevated values.
- Uptime: penalty is active only while `player:isDriving()` is true. No effect on foot or as a passenger (if passengering sets `isDriving()` false, which is standard PZ behaviour).
- Peer comparison within vehicle cluster:
  - Source `SWVehophobic` (-6): completely blocked from entering vehicles — a hard capability loss.
  - `UT_vehophobic` (-4): allowed to drive, but accrues panic and stress over time. A fundamentally weaker penalty: the character can still use vehicles with management (beta blockers, stress management, accepting periodic panic state).
  - The 2-point cost reduction from source (-6 to -4) partially compensates for the weaker penalty, but whether -4 is the right price depends on how punishing the panic/stress accumulation actually is in play. High panic increases zombie aggro noise and affects combat accuracy; high stress causes unhappiness and long-term mood debuffs. Neither penalty is immediately disabling.
  - `UT_motionsickness` (also -4, neighbour in the script file): addresses vehicle-induced nausea; different axis of vehicle penalty. The two traits are not mutually exclusive and can be stacked, which would compound vehicle-related hardship.
- Cross-mod MET gap: source excluded `SpeedDemon`, `SundayDriver`, and `MotionSensitive` vanilla traits at the B42.15 level. UT only excludes `UT_expertdriver`. A player could take `UT_vehophobic` alongside vanilla `SpeedDemon` or `SundayDriver` in UT without conflict — the exclusion gap is not a bug per se but is a design divergence from source intent.
- `DisabledInMultiplayer = true` in UT versus `DisabledInMultiplayer = false` in source — UT restricts the trait to singleplayer.
- Cost verdict: -4 is plausible given the implementation is weaker than source's hard block, but the trait's actual bite depends heavily on whether the player manages panic/stress. Could justify -3 if panic/stress management is considered easy in the UT mod context, or -5 if panic penalties compound harshly with other active traits.

## Regression Proof
- Existing tests (run_tests.lua):
  - `UT_vehophobic` appears in the all-198-trait-IDs registration check at line 302. This test confirms the trait ID is registered with `CharacterTrait` at startup, nothing more.
  - No dedicated behavioral test exists for `UT_vehophobic`. The panic accumulation, stress accumulation, cooldown timer, `isDriving()` guard, `pcall` wrapping, and per-player moddata isolation are all untested.
- What the existing test proves: the trait ID string `"UniversalTraits:UT_vehophobic"` is present in the registration list passed to the 198-trait check. It does not prove the Lua file loads, the event fires, stats change, or the cooldown resets correctly.
- Missing proof (comprehensive list):
  1. No test confirms that a player with the trait and `isDriving() == true` receives a panic increment of +0.01 and stress increment of +0.005 on tick 0.
  2. No test confirms that panic and stress do not update on ticks 1–29 (cooldown active).
  3. No test confirms that panic and stress update again on tick 30 (cooldown expiry).
  4. No test confirms that a player without the trait is unaffected even when `isDriving()` is true.
  5. No test confirms that a player with the trait but `isDriving() == false` is unaffected.
  6. No test confirms that panic is capped at 1.0 (the `math.min(1, ...)` guard).
  7. No test confirms that stress is capped at 1.0.
  8. No test confirms that the cooldown moddata key is isolated per-player (two-player setup does not bleed between players).
  9. No test confirms the `pcall` swallows errors silently — if `getStats()` ever returns nil, the error is hidden and no assertion would catch it.
- Minimum next tests if needed:
  - Mock a player with `UT_vehophobic` and `isDriving() == true`; fire `onPlayerUpdate` once from tick 0; assert panic delta = +0.01, stress delta = +0.005, cooldown = 30.
  - Fire again 29 more times (ticks 1–29); assert no further stat change.
  - Fire once more (tick 30); assert panic delta = +0.01 again, cooldown resets to 30.
  - Mock a player without the trait; assert no stat change after any number of ticks while driving.
  - Mock a player with the trait but `isDriving() == false`; assert no stat change.
  - Set panic to 0.995; fire one update; assert panic == 1.0 (cap test).

## Final Verdict
- Source origin: proven — trait originates from SomewhatTraits (SWTraits:SWVehophobic by somewhatfrog), cost -6, with hard vehicle-entry block via `ISEnterVehicle:isValid()` override. Name is preserved exactly.
- UT implementation: redesigned port, not a faithful port. Source hard-blocks vehicle entry entirely. UT allows driving but applies continuous panic (+0.01) and stress (+0.005) accumulation per 30-tick cooldown cycle via `OnPlayerUpdate`. This is a deliberate reinterpretation — the effect axis changes from capability removal to stat drain. The cost reduction from -6 to -4 partially accounts for the weaker penalty.
- Description: inadequate — entirely flavour text with zero mechanical information. Does not mention panic accumulation, stress accumulation, driving trigger, rate, cooldown, or cap. Source description was a precise one-liner; UT replaced it with narrative that describes the phobia thematically but leaves the player with no mechanical understanding of the penalty. Needs a rewrite.
- Balance: plausible but soft — -4 is defensible for a continuous-drain penalty that a skilled player can manage, but the lack of any hard capability block makes this significantly weaker than the source intent. The missing cross-mod METs (SpeedDemon, SundayDriver) are a low-priority gap. Stacking with `UT_motionsickness` is possible and compounds vehicle hardship without designer intent being documented.
- Regression proof: minimal — the only test is the trait-ID registration check. All behavioral logic (stat accumulation, cooldown, guards, caps) is entirely uncovered. This is the largest gap.
- Action needed: description rewrite (mandatory), behavioral tests (mandatory), optional review of cost and cross-mod MET gaps.
- Open gaps:
  - Description provides no mechanical information; must state that driving raises panic and stress continuously, at what rate, with what cooldown, and with what ceiling.
  - All behavioral logic is untested; the trait could be silently broken with no test failure. At minimum: basic stat-delta test, cooldown cycle test, guard tests (no-trait, not-driving), and cap tests.
  - Source's hard vehicle-entry block (`ISEnterVehicle:isValid()`) is not ported; whether this is intentional design divergence or an oversight should be documented in a code comment.
  - Cross-mod METs (SpeedDemon, SundayDriver, MotionSensitive) from source B42.15 are absent in UT. Low priority but worth a design note.
  - `UT_vehophobic` and `UT_motionsickness` are not mutually exclusive and can be combined; whether this is intentional should be documented.
  - `DisabledInMultiplayer = true` in UT versus `false` in source — confirm this is a deliberate UT-wide policy decision, not an oversight.
