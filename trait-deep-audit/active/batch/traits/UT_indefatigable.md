# UT_indefatigable

## Trait Summary

- UT trait id: UT_indefatigable
- Source mod: More Traits
- Source trait id: indefatigable
- Current cost: 10
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42/media/lua/client/MoreTraits .lua` (runtime, lines 1389–1515)
  - `research/installed-mods/EvolvingTraitsWorld/mods/Evolving Traits World - Mark Dynamic Traits/42/media/lua/shared/NPCs/ETWSubmodCreationMethods.lua` (altNames reference only — `altNames.indefatigable = true`)
- Source trigger path: called from a per-tick OnTick dispatcher (`indefatigable(_player, _playerdata)` called at line 4472; `indefatigablecounter()` called at line 4534)
- Source behavior (`indefatigable` function, lines 1389–1491):
  - Checks `player:HasTrait("indefatigable")`
  - Triggers when `player:getBodyDamage():getHealth() < 15` OR `player:isDeathDragDown()`, AND `playerdata.bindefatigable == false`
  - On activation (one-use or reusable depending on sandbox var `IndefatigableOneUse`):
    - Optionally plays a sound effect (`MTAddonIndefatigableLol` addon)
    - Restores all non-previously-injured body parts to full health (`RestoreToFullHealth`); adds 100 health to pre-injured parts
    - Sets overall body health to 100
    - If infected: clears infection entirely (`setInfected(false)`, zero mortality duration, zero infection level) — tracked by `indefatigablecuredinfection`; only cures infection once per cycle
    - If enemies within 2.5 units and count > 2: knockbacks/staggers nearby zombies
    - Sets `bindefatigable = true` and `indefatigablecooldown = 0`
    - Displays halo text `UI_trait_indefatigable`
    - In `OneUse` mode: also sets `indefatigabledisabled = true` and skips on subsequent calls
  - If `player:isDeathDragDown()`: additionally cancels death-drag animation, restores upright state
- Source behavior (`indefatigablecounter` function, lines 1493–1515):
  - Fires every minute (registered separately in dispatcher at line 4534)
  - Default recharge: 7 in-game days (7 × 24 = 168 hours); configurable via `SandboxVars.MoreTraits.IndefatigableRecharge`
  - Recharge doubles if `indefatigablecuredinfection == true`; doubles again if `IndefatigableHasBeenDraggedDown == true`
  - When cooldown expires: resets all state flags and player speaks `UI_trait_indefatigablecooldown`
- Source description (EN): `UI_trait_indefatigable` (text not captured; tooltip referenced via `getText` call in source Lua)
- Source cost: not captured (source script block not indexed; cost inferred from UT script only)
- Source multiplayer flag: not confirmed from source; no source script block found

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_indefatigable = CharacterTrait.register("UniversalTraits:UT_indefatigable")` at line 301, under the `-- PHASE 3d -- COMPLEX STATE TRAITS` section
- Defined in UT_character_traits.txt: yes — lines 2143–2152
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_indefatigable`
  - `Cost = 10`
  - `UIName = UI_UT_indefatigable`
  - `UIDescription = UI_UT_indefatigableDesc`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_hardy;UniversalTraits:UT_secondwind`
- Translation strings present: yes — in both `media/lua/shared/Translate/EN/UI_EN.txt` and `media/lua/shared/Translate/EN/UI.json`:
  - `UI_UT_indefatigable = "Indefatigable"`
  - `UI_UT_indefatigableDesc = "You do not know the meaning of worn out. While running, endurance slowly regenerates (+0.005 per 30 ticks). When endurance bottoms out, a 3-minute recovery timer starts and restores endurance to 50% on completion."`
- Exclusions/grants correct: mutual exclusion with `UT_hardy` and `UT_secondwind` — all three are in the same Phase 3d complex-state cluster; cross-exclusions are symmetric (confirmed: `UT_hardy` and `UT_secondwind` both list `UT_indefatigable` in their own exclusion fields at lines 2162 and 2173)
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_indefatigable.lua`

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_indefatigable.lua` (54 lines)
  - `media/scripts/UT_character_traits.txt` (lines 2143–2152)
  - `media/lua/shared/Translate/EN/UI_EN.txt`
  - `test/run_tests.lua` (lines 116–117, 302)
- Event registrations:
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)` — fires every player update tick
  - `Events.EveryOneMinute.Add(onEveryMinute)` — fires every in-game minute
- Module-level state: `local tickCounter = 0` — shared across all calls; `local COOLDOWN_MINUTES = 3`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` — standard guard in both handlers
- Runtime chain — `onPlayerUpdate` (lines 9–28):
  1. Guards: exits if player does not have `UniversalTraits:UT_indefatigable`.
  2. Increments module-level `tickCounter`; exits unless `tickCounter % 30 == 0` (throttles to every 30 ticks).
  3. Gets `player:getStats()` and `player:getModData()`.
  4. If `moddata["UT_indefRecovering"]` is set: exits immediately (recovery mode suppresses the active effect).
  5. Gets current `endurance = stats:getEndurance()`.
  6. If endurance < 0.05: sets `moddata["UT_indefCooldown"] = getGameTime():getWorldAgeHours()`, sets `moddata["UT_indefRecovering"] = true`, returns. (Exhaustion trip.)
  7. If `player:isSprinting() or player:isRunning()` AND `endurance > 0.1`: calls `stats:setEndurance(math.min(stats:getMaxEndurance(), endurance + 0.005))`.
- Runtime chain — `onEveryMinute` (lines 31–51):
  1. Gets `getPlayer()`; exits if nil.
  2. Guards: exits if player does not have the trait.
  3. Gets `moddata`; exits if `moddata["UT_indefRecovering"]` is not set.
  4. Gets `cooldownStart = moddata["UT_indefCooldown"]`; if nil: clears `UT_indefRecovering` and returns.
  5. Computes `elapsed = getGameTime():getWorldAgeHours() - cooldownStart`.
  6. If `elapsed >= (COOLDOWN_MINUTES / 60.0)` (i.e., >= 0.05 in-game hours = 3 in-game minutes): sets endurance to 0.5 via `stats:setEndurance(0.5)`, clears both moddata keys.
- Actual behavior (exact values):
  - Active (not recovering): every 30 ticks while sprinting or running with endurance > 0.1, adds +0.005 endurance, capped at `getMaxEndurance()`
  - Exhaustion trigger: when endurance drops below 0.05, starts a 3-minute in-game recovery timer; the active regeneration effect is entirely suppressed during recovery
  - Recovery resolution: after 3 in-game minutes, restores endurance to exactly 0.5 (50% of default max of 1.0), clears recovery state

## Description Integrity

- Display name check: "Indefatigable" — accurate and evocative; appropriate
- Description check (full text): "You do not know the meaning of worn out. While running, endurance slowly regenerates (+0.005 per 30 ticks). When endurance bottoms out, a 3-minute recovery timer starts and restores endurance to 50% on completion."
- Accuracy of description:
  - "+0.005 per 30 ticks" — correct; matches `endurance + 0.005` applied at `tickCounter % 30 == 0`
  - "While running" — partially correct; the code checks `player:isSprinting() or player:isRunning()`; "running" in the description covers sprinting implicitly, but the distinction is absent
  - "endurance bottoms out" — the exhaustion trigger is `endurance < 0.05`, not 0.0; "bottoms out" implies zero but the trip fires at 5% endurance
  - "3-minute recovery timer" — correct; `COOLDOWN_MINUTES = 3` and the comparison `elapsed >= (COOLDOWN_MINUTES / 60.0)`
  - "restores endurance to 50%" — correct; `stats:setEndurance(0.5)`
  - The description does not mention that the active regeneration is suppressed during the recovery phase — a player may expect the +0.005 regen to continue helping them recover, but it is entirely disabled while `UT_indefRecovering` is set
  - The description does not mention the additional sprint guard: regeneration only applies when `endurance > 0.1`; if the player is running with endurance between 0.05 and 0.10, neither the exhaustion trip nor the regen fires — a silent dead zone
- Missing or misleading details:
  - "bottoms out" implies 0% endurance; actual trip threshold is < 5% (< 0.05)
  - The 0.10 lower guard on the regen path creates a band (0.05–0.10) where neither effect applies; this is not documented
  - The regen suppression during recovery is not mentioned; the description implies continuous operation
  - No mention of the `isSprinting()` branch — the description says "while running" which technically excludes sprinting in PZ's action vocabulary

## Balance Review

- Upside 1 (active regen): +0.005 endurance per 30 ticks while sprinting or running with endurance > 0.1. At a typical 30 ticks/second rate this adds 0.005 per second of active movement — meaningful mitigation of endurance drain during sustained exertion.
- Upside 2 (recovery burst): after exhaustion (< 0.05 endurance), endurance is restored to 0.5 (50%) after 3 in-game minutes. This is a strong emergency recovery: a player who has fully depleted endurance regains half their bar passively without rest.
- Downside: the 3-minute recovery period fully disables the active regen effect; during this window the player has no endurance benefit from the trait and must rely on natural recovery or the pending burst.
- Dead zone: endurance between 0.05 and 0.10 while running receives neither regen nor recovery trip — no trait benefit in this band.
- Uptime: active regen is continuous during sustained movement above 0.10 endurance; recovery mode is episodic and self-clearing.
- Magnitude assessment:
  - Active regen of +0.005 per 30 ticks is modest but consistent; it meaningfully extends sprinting duration compared to vanilla.
  - The recovery burst to 50% is strong: vanilla endurance recovery from near-zero to 50% requires complete rest for an extended period; this trait delivers the same result in 3 in-game minutes regardless of activity.
  - The source trait (More Traits `indefatigable`) was a dramatic one-shot full heal + infection clear + knockback effect, usable once per ~7 in-game days. The UT implementation is a fundamentally different design: continuous passive regen + periodic recovery burst. The UT version is far less dramatic but always-on.
- Cost assessment: Cost = 10 is the highest-cost positive trait in the Phase 3d cluster (UT_hardy = 8, UT_secondwind = 6). The combination of continuous movement regen and an emergency endurance recovery burst justifies a premium cost; however, whether 10 is calibrated correctly relative to other 10-point traits in the broader UT pool would require cross-trait comparison.
- Peer comparison: mutually exclusive with `UT_hardy` and `UT_secondwind`. `UT_secondwind` (Cost = 6) presumably also addresses endurance recovery — the exclusion is appropriate and prevents stacking endurance-recovery traits. The exclusion is symmetric and correctly defined in all three trait blocks.
- Stack or exclusion notes: no exclusion with `UT_physicallyactive` or `UT_humanhamster`; if those traits also affect endurance or movement, stacking may be possible — would require separate audit of those traits.
- Module-level `tickCounter` note: `tickCounter` is a module-level local, not per-player. In single-player this is immaterial (`DisabledInMultiplayer = true`). The `DisabledInMultiplayer = true` flag is consistent with the use of `getPlayer()` (single-player API) in `onEveryMinute` and the `player` parameter from `OnPlayerUpdate` in `onPlayerUpdate`.

## Regression Proof

- Existing tests:
  - `run_tests.lua` line 116–117: `test("UT_indefatigable registered", ...)` — asserts `UTTraitsRegistries.UT_indefatigable == "UniversalTraits:UT_indefatigable"`. Registration check only.
  - `run_tests.lua` line 302: `"UniversalTraits:UT_indefatigable"` listed in the Phase 3d expected-IDs array, covered by the "all 198 trait IDs registered with CharacterTrait" test.
  - No `dofile` entry for `UT_indefatigable.lua` found in any test harness — the runtime file is not loaded by the test suite.
- What it proves: the trait ID is correctly registered via `CharacterTrait.register`. Nothing about runtime behavior is verified.
- Missing proof:
  - No test loads `UT_indefatigable.lua` at all; parse errors in the file would not be caught.
  - No test covers `onPlayerUpdate` — regen path (+0.005 per 30 ticks while running), exhaustion trip (< 0.05 endurance sets recovery state), or the dead zone (0.05–0.10 endurance with no effect).
  - No test covers `onEveryMinute` — recovery completion (elapsed >= 0.05 hours → endurance = 0.5, clear state), or the nil-cooldown guard path.
  - No test verifies that regen is suppressed during the recovery window.
  - No test verifies the sprint guard (`isSprinting() or isRunning()` condition).
  - No test verifies the `endurance > 0.1` lower bound on regen.
- Minimum next tests if needed:
  1. Load `UT_indefatigable.lua` via `dofile` to confirm it parses without error.
  2. MockPlayer with trait, `endurance = 0.5`, sprinting/running; fire `OnPlayerUpdate` 30 times; assert endurance = 0.505.
  3. MockPlayer with trait, `endurance = 0.04` (below 0.05 trip), sprinting; fire `OnPlayerUpdate` 30 times; assert `moddata["UT_indefRecovering"] == true` and `moddata["UT_indefCooldown"]` is set; assert endurance unchanged (regen did not apply).
  4. MockPlayer with trait in recovery state, elapsed >= 0.05 hours; fire `EveryOneMinute`; assert endurance == 0.5, `UT_indefRecovering` is nil, `UT_indefCooldown` is nil.
  5. MockPlayer with trait in recovery state, elapsed < 0.05 hours; fire `EveryOneMinute`; assert endurance unchanged and recovery state still set.
  6. MockPlayer with trait, `endurance = 0.08` (in dead zone 0.05–0.10), running; fire `OnPlayerUpdate` 30 times; assert endurance unchanged and no recovery state set.
  7. MockPlayer without trait, `endurance = 0.5`, running; fire `OnPlayerUpdate` 30 times; assert endurance unchanged.

## Final Verdict

- Source origin: confirmed — More Traits `indefatigable` function and `indefatigablecounter` function are present in `research/installed-mods/MoreTraits/mods/More Traits/42/media/lua/client/MoreTraits .lua`. The EvolvingTraitsWorld altName reference (`altNames.indefatigable = true`) corroborates the trait name is well-known across the modding ecosystem.
- UT implementation: substantially redesigned — the source trait was a dramatic one-shot emergency activation (full heal, infection cure, zombie knockback, long recharge) triggered by near-death health or death-drag events. The UT implementation is a completely different design: continuous passive endurance regen while moving (+0.005 per 30 ticks) plus a periodic endurance recovery burst (50% after 3 in-game minutes following exhaustion). No health restoration, no infection curing, no knockback. The concept name "indefatigable" (tireless) is shared, but the mechanics are not derived from the source — they are a new design using the same theme.
- Description: mostly accurate with three specific gaps — (1) "bottoms out" implies 0% endurance but the actual trip threshold is 5%; (2) the description does not document the 0.05–0.10 endurance dead zone where neither regen nor the trip fires; (3) the description does not state that active regen is suppressed during the recovery window. The quantitative details (+0.005 per 30 ticks, 3 minutes, 50%) are all correct.
- Balance: reasonable at Cost = 10 — the combination of always-on movement regen and emergency recovery burst is a strong dual-purpose endurance package. The mutual exclusion cluster with `UT_hardy` and `UT_secondwind` is correctly implemented and prevents stacking with the closest peers.
- Regression proof: critically weak — the runtime file is not loaded by the test harness at all; no behavioral coverage exists for either event handler.
- Action needed: doc fix + test fix
- Open gaps:
  - Fix `UI_UT_indefatigableDesc` to state that the exhaustion trip fires at 5% endurance (not 0%), that regen is suppressed during the recovery phase, and that regen requires endurance above 10% to activate.
  - Add a `dofile` entry for `UT_indefatigable.lua` in the UniversalTraits test harness.
  - Add behavioral tests covering: regen path, exhaustion trip, recovery completion, recovery suppression of regen, dead zone, no-trait guard.
  - Decide whether the 0.05–0.10 dead zone is intentional design (hysteresis to prevent rapid trip-regen cycling) or an accidental gap; document the decision in a code comment if intentional.
  - Confirm whether module-level `tickCounter` shared state causes any issue if the event fires for multiple players in a future multiplayer-enabled scenario (currently moot due to `DisabledInMultiplayer = true`, but worth noting for forward compatibility).
