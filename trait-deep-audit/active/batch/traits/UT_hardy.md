# UT_hardy

## Trait Summary

- UT trait id: UT_hardy
- Source mod: More Traits
- Source trait id: hardy (namespaced `ToadTraits:hardy`)
- Current cost: 8
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/scripts/ToadTraits.txt` (trait definition, lines 372–380)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` (runtime, `hardytrait` function at line 1646; dispatcher call at line 4674)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` (lines 90–93, 239–240)
  - `research/installed-mods/EvolvingTraitsWorld/mods/Evolving Traits World - Mark Dynamic Traits/42/media/lua/shared/NPCs/ETWSubmodCreationMethods.lua` (altNames reference only — `altNames.hardy = true`)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/lua/shared/MoreTraits - Dynamic.lua` (dynamic unlock: grants `hardy` when `Fitness >= HardyDynamicSkill`)
- Source trait definition (`ToadTraits:hardy`, lines 372–380):
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = false`
  - `CharacterTrait = ToadTraits:hardy`
  - `Cost = 6`
  - `UIName = UI_trait_hardy` → "Hardy"
  - `UIDescription = UI_trait_hardydesc` → "Whether by force of will or physical fitness, you're not one to tire after long hours working.<br>Your maximum endurance is increased by 25%"
  - No mutual exclusions declared in the source script block
- Source runtime behavior (`hardytrait` function, lines 1646–1692):
  - Guard: checks `player:hasTrait(ToadTraitsRegistries.hardy)`; returns early if not present
  - Rate limiter: uses `getTimestampMs()` to throttle to at most once per 1000 ms real time (`lastHardyUpdate`)
  - State: `playerdata.iHardyEndurance` (starts at 5, max 5; configured via `iHardyMaxEndurance = 5`)
  - `regenAmount` default: 0.05; overridden by `SandboxVars.MoreTraits.HardyEndurance / 500` if set
  - **Discharge path** (endurance < 0.85 AND `iHardyEndurance >= 1`): adds `regenAmount` to current endurance (capped at 1.0), decrements `iHardyEndurance` by 1. Optionally displays halo text "Hardy Endurance Left : N" (red, if `HardyNotifier` option enabled).
  - **Recharge path** (endurance >= 1.0 AND `iHardyEndurance < iHardyMaxEndurance`): subtracts `regenAmount` from endurance, increments `iHardyEndurance` by 1. Optionally displays halo text (green).
  - Net effect: the trait acts as a hidden endurance buffer of 5 charges. Each charge pushes endurance up by 0.05 (default) when below 85%, drawing from the buffer. When endurance is full (>= 1.0), the buffer recharges by converting excess endurance back into charges (reducing displayed endurance by 0.05 per recharge step). This creates an effective endurance extension of up to 5 × 0.05 = 0.25 above the base maximum — consistent with the "25% endurance increase" stated in the source description.
  - Called from main dispatcher at line 4674: `hardytrait(player, playerdata)` — runs on every tick that the dispatcher fires.
  - Source is compatible with multiplayer (`DisabledInMultiplayer = false` in script; dispatcher sends `sendClientCommand` when `isClient()`)
- Source description (EN): "Whether by force of will or physical fitness, you're not one to tire after long hours working. Your maximum endurance is increased by 25%"
- Source cost: 6 (from `ToadTraits:hardy` script block)
- Source multiplayer flag: `DisabledInMultiplayer = false` (source supports MP; UT sets `DisabledInMultiplayer = true`)

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_hardy = CharacterTrait.register("UniversalTraits:UT_hardy")` at line 302, under the `-- PHASE 3d -- COMPLEX STATE TRAITS` section, immediately after `UT_indefatigable` and before `UT_secondwind`
- Defined in UT_character_traits.txt: yes — lines 2154–2163
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_hardy`
  - `Cost = 8`
  - `UIName = UI_UT_hardy`
  - `UIDescription = UI_UT_hardyDesc`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_indefatigable;UniversalTraits:UT_secondwind`
- Translation strings present: yes — in `media/lua/shared/Translate/EN/UI_EN.txt` lines 665–666:
  - `UI_UT_hardy = "Hardy"`
  - `UI_UT_hardyDesc = "You endure. When fatigue exceeds 0.8 an exhaustion phase begins, raising stress by +0.02 per minute. After 10 consecutive minutes of rest (fatigue below 0.3), exhaustion clears and a 5-minute bonus phase begins that slowly restores endurance (+0.002 per minute)."`
- Exclusions/grants correct: mutual exclusion with `UT_indefatigable` and `UT_secondwind`. Cross-exclusions are fully symmetric:
  - `UT_indefatigable` line 2151: `MutuallyExclusiveTraits = UniversalTraits:UT_hardy;UniversalTraits:UT_secondwind` — includes `UT_hardy`
  - `UT_secondwind` line 2173: `MutuallyExclusiveTraits = UniversalTraits:UT_indefatigable;UniversalTraits:UT_hardy` — includes `UT_hardy`
  - All three form a fully symmetric mutual-exclusion triangle; no gaps
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_hardy.lua` (50 lines)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_hardy.lua` (50 lines, complete)
  - `media/scripts/UT_character_traits.txt` (lines 2154–2163)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 665–666)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16, `UTCore.hasTrait`)
  - `test/run_tests.lua` (lines 302, 467, 1055–1070)
- Event registrations:
  - `Events.EveryOneMinute.Add(onEveryMinute)` — fires every in-game minute; the sole event hook; no `OnPlayerUpdate` registration
- Module-level state: none — all state is stored per-player in `player:getModData()`
- UTCore hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe guard at line 9; implementation: `player:getTraits():contains(traitId)` after nil-checking both player and traits collection
- Runtime chain — `onEveryMinute` (lines 6–47), called every in-game minute:
  1. `getPlayer()` — if nil, returns immediately (SP-safe guard)
  2. `UTCore.hasTrait(player, "UniversalTraits:UT_hardy")` — if false, returns immediately
  3. Reads `player:getStats()`, `player:getModData()`, `stats:getFatigue()`, `getGameTime():getWorldAgeHours()`

  **Branch A — Bonus phase cleanup** (lines 17–24), runs if `moddata["UT_hardyBonus"]` is set:
  - Computes `bonusAge = now - moddata["UT_hardyBonus"]` (elapsed in-game hours since bonus started)
  - If `bonusAge < (5 / 60.0)` (i.e., less than 5 in-game minutes have elapsed):
    - `stats:setEndurance(math.min(stats:getMaxEndurance(), stats:getEndurance() + 0.002))` — adds +0.002 endurance, capped at max
  - Else (5 minutes have elapsed):
    - `moddata["UT_hardyBonus"] = nil` — bonus phase ends; key is cleared

  **Branch B — Sub-exhaustion tracking** (lines 27–46), runs unconditionally after Branch A:

  - **Sub-branch B1** — not currently exhausted (`moddata["UT_hardyExhausted"]` is nil/false), lines 27–32:
    - If `fatigue > 0.8`:
      - Sets `moddata["UT_hardyExhausted"] = true`
      - Sets `moddata["UT_hardyExhaustedAt"] = now` (timestamp of exhaustion entry)
      - Sets `moddata["UT_hardyRestingMins"] = 0` (rest counter reset)
    - Else (fatigue <= 0.8): no action

  - **Sub-branch B2** — currently exhausted (`moddata["UT_hardyExhausted"]` is truthy), lines 33–45:
    - Always applies: `stats:setStress(math.min(1, stats:getStress() + 0.02))` — adds +0.02 stress, capped at 1.0, every in-game minute while exhausted
    - Rest accumulator:
      - If `fatigue < 0.3`: increments `moddata["UT_hardyRestingMins"]` by 1
      - Else: resets `moddata["UT_hardyRestingMins"]` to 0 (rest counter resets if fatigue rises back to >= 0.3)
    - Recovery trigger — if `moddata["UT_hardyRestingMins"] >= 10` (10 consecutive in-game minutes with fatigue < 0.3):
      - Clears `moddata["UT_hardyExhausted"]` (nil)
      - Clears `moddata["UT_hardyExhaustedAt"]` (nil)
      - Clears `moddata["UT_hardyRestingMins"]` (nil)
      - Sets `moddata["UT_hardyBonus"] = now` — triggers Branch A for the next 5 in-game minutes

- Actual behavior (exact values and cadences):
  - **Exhaustion entry**: fatigue crosses above 0.8 → exhausted state begins
  - **Exhaustion penalty**: +0.02 stress per in-game minute while exhausted (stress is capped at 1.0)
  - **Rest requirement**: fatigue must stay continuously below 0.3 for 10 consecutive in-game minutes to clear exhaustion; any tick where fatigue >= 0.3 resets the rest counter to 0
  - **Recovery bonus**: upon clearing exhaustion, a 5-minute bonus window begins in which +0.002 endurance is added per in-game minute, capped at `getMaxEndurance()`; bonus expires after 5 in-game minutes (`bonusAge >= 5/60.0` hours)
  - **Bonus total**: up to 5 × 0.002 = +0.010 endurance over the full bonus window (assuming it is not interrupted by the bonus expiring mid-minute)
  - **Interaction note**: Branch A (bonus phase) and Branch B (exhaustion tracking) both run in the same `onEveryMinute` call. It is possible for both to execute in the same minute — specifically, on the minute that exhaustion clears: `UT_hardyBonus` is set at the end of Branch B2, but Branch A already ran at the top of the function and will have found `UT_hardyBonus` nil (it was not yet set). The bonus phase therefore starts being processed starting from the *next* minute's call, not the same one that cleared exhaustion. This is correct behavior with no off-by-one error.
  - **No effect outside exhaustion**: when the player is neither exhausted nor in the bonus phase, the function exits both branches silently; there is no passive benefit

## Description Integrity

- Display name check: "Hardy" — accurate; matches the source mod name and is appropriately concise
- Description check (full text): "You endure. When fatigue exceeds 0.8 an exhaustion phase begins, raising stress by +0.02 per minute. After 10 consecutive minutes of rest (fatigue below 0.3), exhaustion clears and a 5-minute bonus phase begins that slowly restores endurance (+0.002 per minute)."
- Accuracy of description:
  - "When fatigue exceeds 0.8 an exhaustion phase begins" — correct; the trigger is `fatigue > 0.8` at line 28
  - "raising stress by +0.02 per minute" — correct; `stats:setStress(math.min(1, stats:getStress() + 0.02))` runs every in-game minute while exhausted
  - "After 10 consecutive minutes of rest (fatigue below 0.3)" — correct; `moddata["UT_hardyRestingMins"] >= 10` at line 40, incremented only when `fatigue < 0.3` at line 35
  - "exhaustion clears" — correct; all three exhaustion moddata keys are set to nil at lines 41–43
  - "a 5-minute bonus phase begins" — correct; `bonusAge < (5 / 60.0)` at line 19 defines a 5-minute window
  - "+0.002 per minute" — correct; `stats:getEndurance() + 0.002` at line 20
  - "slowly restores endurance" — accurate characterization; +0.002/min for 5 minutes is +0.010 total
- Missing or misleading details:
  - The description does not state that the +0.002 endurance bonus is capped at `getMaxEndurance()` — this is not a practical gap since the cap is expected behavior, but a pedantic omission
  - The description does not state that the rest counter resets to zero if fatigue rises back above 0.3 during the rest period. A player who drops fatigue to 0.25, waits 8 minutes, then has fatigue rise back to 0.5 for one minute, then rests again must restart the 10-minute counter from zero. The description implies that 10 total minutes of low fatigue is sufficient, but the code requires 10 *consecutive* minutes. The word "consecutive" is present in the description and is correct.
  - The description does not mention the stress-cap behavior (`math.min(1, ...)`); stress cannot be driven above 1.0 by this trait
  - There is no mention of what happens if the player removes the trait mid-exhaustion: the moddata keys remain set but Branch B2 will not fire (hasTrait guard fails), so stress accumulation stops but the keys persist in moddata until cleared by some other mechanism or a new game session. This is a persistence artifact, not a description gap, but worth noting for the balance review.

## Balance Review

- **Source trait behavior**: the More Traits `hardy` trait extended endurance via a hidden buffer of 5 charges (each worth +0.05 endurance, default), effectively adding ~25% endurance capacity. This was a straightforward passive benefit with no cost to the player.
- **UT implementation design**: the UT version completely replaces the mechanic. Rather than a passive endurance buffer, UT_hardy introduces a two-phase state machine: an exhaustion *penalty phase* (stress accumulation at +0.02/min) that resolves into an endurance *bonus phase* (+0.002/min for 5 minutes). The net benefit is modest (+0.010 endurance over 5 minutes), but the design imposes a genuine cost (stress buildup) before delivering the reward.
- **Upside**: when the player successfully rests through an exhaustion phase, they receive a brief endurance restoration boost and implicitly benefit from the game's stress-reduction mechanics resolving the accumulated stress. The trait rewards disciplined play patterns (push hard, then rest).
- **Downside**: during the exhaustion phase (fatigue > 0.8, then fatigue does not stay below 0.3 for 10 consecutive minutes), the trait *only* inflicts +0.02 stress per minute with no compensating benefit. A player who frequently hovers between 0.3 and 0.8 fatigue without completing a full rest cycle will experience net harm: stress accumulates, the rest counter resets repeatedly, and the bonus phase never arrives.
- **Magnitude assessment**:
  - Stress +0.02/min is a meaningful penalty; at maximum exhaustion duration before rest, a player who takes 20 minutes to rest would accumulate +0.40 stress — a significant psychological debuff that compounds other stress sources.
  - Endurance bonus of +0.010 total (+0.002 × 5 minutes) is small. It does not materially extend a combat sprint; it is more a symbolic recovery reward than a mechanical endurance benefit.
  - The source trait's 25% endurance extension (up to +0.25 effective max endurance) is dramatically more powerful than the UT version's +0.010 recovery burst. The UT design is not a translation of the source — it is a different concept sharing the name.
- **Cost assessment**: Cost = 8 sits between `UT_indefatigable` (Cost = 10) and `UT_secondwind` (Cost = 6). The UT_hardy mechanic is arguably the most punishing of the three Phase 3d traits to use in practice: it requires reaching fatigue > 0.8 (which the player may be trying to avoid), then committing to a 10-consecutive-minute low-fatigue rest (which may not always be possible in combat or active survival scenarios) before any benefit is received. A cost of 8 for a trait that primarily manifests as a stress penalty during high-exertion periods may be high relative to the practical value of the reward.
- **Peer comparison** (Phase 3d cluster):
  - `UT_indefatigable` (Cost = 10): continuous passive endurance regen while moving (+0.005/30 ticks) plus emergency 50% endurance recovery after 3 in-game minutes. Always-on benefit during movement; recovery is automatic.
  - `UT_secondwind` (Cost = 6): instant +0.3 endurance restore when sprinting at or below 0.1 endurance, once per 10-minute cooldown. High-impact, immediate, clearly timed.
  - `UT_hardy` (Cost = 8): state-machine requiring exhaustion entry → sustained rest → bonus window. Most complex to trigger; lowest peak reward; only trait in the cluster that imposes a *penalty* before a benefit. At Cost = 8 this may be overpriced relative to the other two options in the same exclusion cluster.
- **Multiplayer flag**: `DisabledInMultiplayer = true`. The source trait was MP-capable (`DisabledInMultiplayer = false`). The UT implementation uses `getPlayer()` (SP API) — the MP restriction is technically correct and consistent with the implementation.
- **ModData persistence note**: the keys `UT_hardyExhausted`, `UT_hardyExhaustedAt`, `UT_hardyRestingMins`, and `UT_hardyBonus` are written to `player:getModData()` and will persist across save/load cycles. If the player saves mid-exhaustion, the exhaustion phase resumes correctly on load. If the player saves mid-bonus-phase, the bonus clock (`UT_hardyBonus` stores the world-age-hours timestamp) will correctly evaluate elapsed time on reload. Persistence is handled correctly.

## Regression Proof

- Existing tests:
  - `run_tests.lua` line 302: `"UniversalTraits:UT_hardy"` listed in the Phase 3d expected-IDs array, covered by the "all 198 trait IDs registered with CharacterTrait" test. Confirms `CharacterTrait.register` was called with the correct ID.
  - `run_tests.lua` line 467: `dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_hardy.lua")` — the runtime file IS loaded by the test harness. Parse errors would be caught.
  - `run_tests.lua` lines 1055–1070: `test("hardy enters exhaustion state then grants the recovery bonus", ...)` — behavioral test:
    - Creates `MockPlayer` with trait, `fatigue = 0.9`, `endurance = 0.4`
    - Sets game time to `1.0`, fires `EveryOneMinute` → player enters exhaustion (`UT_hardyExhausted = true`)
    - Sets `fatigue = 0.2`, sets `UT_hardyRestingMins = 9` (pre-seeds 9 minutes of rest), sets game time to `1.2`
    - Fires `EveryOneMinute` → rest counter reaches 10, exhaustion clears, `UT_hardyBonus = 1.2`
    - Sets game time to `1.21`, fires `EveryOneMinute` → bonus phase fires, endurance incremented
    - Asserts: `UT_hardyExhausted == nil`, `UT_hardyBonus ~= nil`, `endurance > 0.4`
- What the existing test proves:
  - The file parses without error (dofile succeeds)
  - The exhaustion entry path fires when `fatigue > 0.8`
  - The rest counter increments when `fatigue < 0.3`
  - The recovery trigger fires at `UT_hardyRestingMins >= 10`
  - The bonus phase sets `UT_hardyBonus` and begins incrementing endurance on subsequent `EveryOneMinute` firings
- Missing proof:
  - No test verifies the stress penalty path: while exhausted, `stats:getStress() + 0.02` should accumulate each minute; there is no assertion on stress values
  - No test verifies the rest counter *reset* path: if `fatigue >= 0.3` during the exhausted phase, `UT_hardyRestingMins` should reset to 0 (line 38); this path is uncovered
  - No test verifies the bonus phase *expiry* path: when `bonusAge >= (5 / 60.0)`, `UT_hardyBonus` should be set to nil; no test advances time past the 5-minute window and asserts the key is cleared
  - No test verifies the no-trait guard: a MockPlayer without `UT_hardy` should experience no moddata changes and no stat changes when `EveryOneMinute` fires
  - No test verifies the fatigue-above-threshold guard in sub-branch B1: a player whose fatigue is exactly at 0.8 (not > 0.8) should not enter exhaustion
  - No test verifies that `UT_hardyExhaustedAt` is set on exhaustion entry (the key is set at line 30 but never read in the current runtime — see open gaps)
  - The test pre-seeds `UT_hardyRestingMins = 9` rather than driving 9 real fire-cycles at low fatigue, which means the rest-counter increment path is exercised only for the 10th tick, not the first through ninth
- Minimum next tests if needed:
  1. MockPlayer with trait, exhausted state, `fatigue = 0.9`; fire `EveryOneMinute`; assert `stress` increased by 0.02.
  2. MockPlayer with trait, exhausted state, `UT_hardyRestingMins = 5`, then set `fatigue = 0.5` (not < 0.3); fire `EveryOneMinute`; assert `UT_hardyRestingMins == 0` (counter reset).
  3. MockPlayer with trait, bonus phase active, `UT_hardyBonus = now - (6/60.0)` (bonus expired); fire `EveryOneMinute`; assert `UT_hardyBonus == nil` and endurance unchanged.
  4. MockPlayer without trait, `fatigue = 0.9`; fire `EveryOneMinute`; assert all moddata keys are nil and stats unchanged.
  5. MockPlayer with trait, `fatigue = 0.8` exactly (not > 0.8); fire `EveryOneMinute`; assert `UT_hardyExhausted` is nil (exhaustion does not trigger at the boundary).

## Final Verdict

- Source origin: confirmed — More Traits `hardytrait` function (line 1646) and `ToadTraits:hardy` script definition (line 372) are both present in the research/installed-mods corpus. The EvolvingTraitsWorld altName reference (`altNames.hardy = true`) corroborates the trait name as established in the modding ecosystem.
- UT implementation: substantially redesigned — the source trait was a passive endurance buffer of 5 charges (+0.05/charge at default, max +0.25 effective endurance extension), delivering a clean ~25% endurance increase with no cost or state management. The UT implementation is a completely different design: a state machine that penalizes the player with +0.02 stress/minute during high-fatigue exhaustion phases, then rewards sustained rest with a modest +0.010 total endurance recovery over a 5-minute bonus window. No endurance extension, no buffering — the concept is reused but the mechanics are not derived from the source.
- Description: accurate and complete. All quantitative values match the code exactly: `> 0.8` entry threshold, `+0.02/min` stress, `< 0.3` rest threshold, `10 consecutive minutes`, `5-minute` bonus window, `+0.002/min` endurance. The only non-trivial gap is that the description does not explicitly state the rest counter resets if fatigue rises above 0.3 mid-rest — however, the word "consecutive" is present and correctly implies this behavior. No correction required unless player confusion is reported.
- Balance: potentially overpriced at Cost = 8 relative to its Phase 3d peers. The trait imposes a genuine stress penalty before delivering a small endurance reward, requiring a specific play pattern (push to exhaustion, then rest continuously for 10 minutes) to yield any benefit. A player who never exceeds fatigue 0.8 receives zero benefit. Compared to `UT_secondwind` (Cost = 6, immediate +0.3 endurance burst) and `UT_indefatigable` (Cost = 10, always-on regen + recovery burst), `UT_hardy` is the most situational and lowest-reward of the three — consider whether Cost = 6 or 7 is more appropriate.
- Regression proof: partially adequate — the file is loaded and a meaningful behavioral scenario is tested. Gaps exist in stress accumulation, counter-reset, bonus expiry, and boundary conditions.
- Action needed: balance review + test additions
- Open gaps:
  1. **`UT_hardyExhaustedAt` is set but never read** — `moddata["UT_hardyExhaustedAt"]` is written at line 30 and cleared at line 42 but is never consumed by any logic in the runtime file. It is dead state. Either add a feature that uses it (e.g., display time-in-exhaustion, or apply escalating penalties based on elapsed exhaustion time) or remove the key to eliminate confusing dead moddata.
  2. **Balance reconsideration**: evaluate whether Cost = 8 is correct for a trait that only benefits players who specifically reach fatigue > 0.8 and can then rest for 10 consecutive low-fatigue minutes; consider reducing to Cost = 6 or 7, or strengthening the reward (e.g., larger endurance bonus, or a stress-relief component on exhaustion recovery).
  3. **Test additions**: add tests for stress accumulation path, rest-counter reset, bonus expiry, no-trait guard, and boundary conditions as specified in the Regression Proof section above.
  4. **No MP consideration needed**: `DisabledInMultiplayer = true` is correct given the SP-only `getPlayer()` API; the source MP support is intentionally not carried forward.
