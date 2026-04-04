# UT_slowworker

## Trait Summary

- UT trait id: UT_slowworker
- Source mod: More Traits (ToadTraits / MoreTraits by Toad)
- Source trait id: ToadTraits:slowworker
- Current cost: -5
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (trait definition, cost -9)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/TimedActions/isQuickSlowWorker.lua` (runtime implementation)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (legacy commented-out OnPlayerUpdate implementation)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (English strings)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (ToadTraitsRegistries.slowworker registration)
- Source trigger path: `Events.OnGameBoot.Add(isWorker)` wraps `getDuration()` on all global TimedAction tables; `Events.OnGameBoot.Add(injectShared)` and `Events.OnMainMenuEnter.Add(injectClient)` additionally wrap specific per-action `getDuration()` methods. At each action construction the patched `getDuration` calls `MT_QuickSlowTraitCheck(self, baseTime)`, which checks `self.character:hasTrait(ToadTraitsRegistries.slowworker)` at that moment.
- Source behavior: The scaler is sandbox-configurable (`SandboxVars.MoreTraits.SlowWorkerScaler`, default 50 in the 42.15 TimedActions file, default 15 in the older sandbox-options.txt). With default scaler of 50: `modifier = 50 * 0.01 = 0.5`; `baseTime = baseTime + (baseTime * 0.5)`, i.e. +50% duration on all timed actions. A 10% chance each action checks Lucky/Dextrous (bonus +0.25 each) and Unlucky/AllThumbs (penalty -0.25 each) to reduce the penalty slightly. Source cost was -9. Source mutual exclusion: only `ToadTraits:quickworker` (no slack equivalent in source).

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: yes — `MutuallyExclusiveTraits = UniversalTraits:UT_quickworker;UniversalTraits:UT_slack` (UT adds UT_slack exclusion, which is correct given the family design)
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_slowworker.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua`
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`, `UTCore.applyWorkSpeed(player, 0.5)`
- Runtime chain (plain language):
  1. On new game start, `onNewGame` fires.
  2. If the player has `UniversalTraits:UT_slowworker`, `UTCore.applyWorkSpeed(player, 0.5)` is called.
  3. That writes `player:getModData()["UT_workSpeedMod"] = 0.5`.
  4. At runtime, `UTCore_WorkSpeedHook` (registered via `Events.OnGameBoot`) wraps `getDuration()` on all global TimedAction tables.
  5. Each wrapped `getDuration` call reads `md["UT_workSpeedMod"]` (default 0) and computes `math.max(1, math.floor(base * (1.0 + 0.5)))`, returning `floor(base * 1.5)`.
- Actual behavior (exact values): Every timed action duration is multiplied by 1.5 (i.e. +50% duration, -33% effective speed). Minimum duration is clamped to 1. The effect is permanent for the session once set at OnNewGame; no per-tick or probabilistic component in UT's implementation.

## Description Integrity

- Display name check: `UI_UT_slowworker = "Slow Worker"` — matches intent exactly.
- Description check: `UI_UT_slowworkerDesc = "You take your sweet time with everything. -50% work speed on all crafting and building actions (+50% work duration)."` — the parenthetical `(+50% work duration)` is correct and matches `applyWorkSpeed(player, 0.5)`. The leading `-50% work speed` is a player-friendly rephrasing of the same fact (50% longer = effectively ~33% fewer actions per unit time, but the description interprets "work speed" as speed relative to normal, which is a conventional framing, not a literal multiplier). The description is accurate for practical player understanding.
- Missing or misleading details: The phrase "-50% work speed" could be read as "you work at 50% of normal speed" (i.e., actions take 2x as long), but the implementation is +50% duration (actions take 1.5x as long). These are different magnitudes. The parenthetical clarifies the actual mechanic, but the leading claim is misleading — "-50% work speed" implies 2x duration, not 1.5x. This is a minor description inaccuracy. The source mod used a sandbox scaler defaulting to 50% in 42.15 (matching UT), so the magnitude is faithful to source.

## Balance Review

- Upside: -5 points refunded to the player at character creation.
- Downside: All timed actions (crafting, building, farming, vehicle work, medical actions, etc.) take 50% longer for the entire game with no uptime condition or skill mitigation.
- Uptime: 100% — the moddata value is set at game start and never cleared; it applies to every single timed action.
- Peer comparison:
  - `UT_slack` (-6 cost): +40% duration on all timed actions. Slower debuff for one more point refund.
  - `UT_quickworker` (+9 cost): -30% duration on all timed actions (floor(base * 0.7)). The positive-cost counterpart.
  - Source `ToadTraits:slowworker` was -9 points for the same effect (configurable, default 50%). UT charges -5 for an identical unconditional debuff that is permanent.
  - `-5` for a permanent 50% time penalty on every timed action in the game is potentially underpriced relative to the source (-9) and relative to `UT_slack` which gives -6 for a slightly milder 40% penalty.
- Stack or exclusion notes: Mutually exclusive with `UT_quickworker` and `UT_slack`. Cannot stack with either. `UT_workSpeedMod` is written as a flat value (not additive with other mods writing the same key) — if another trait also writes `UT_workSpeedMod`, the last writer wins; no stacking guard is present.
- Cost verdict: questionable — -5 for a permanent 50% timed-action penalty is milder than the source's -9 and milder than `UT_slack`'s pricing (-6 for -40%). The cost is internally consistent with `UT_slack` only if the cost difference reflects the extra 10% duration, which at -1 point per 10% is plausible, but the source evidence suggests -9 was the community-calibrated value for this magnitude.

## Regression Proof

- Existing test: The file is loaded via `dofile` in `run_tests.lua` (line 450) and the trait is listed in the registration coverage test and the cost assertion test (`assert_eq(costs["UniversalTraits:UT_slowworker"], -5, "slowworker cost")`). There is a test for `UT_quickworker` verifying `UT_workSpeedMod < 0`, but no equivalent test for `UT_slowworker` verifying `UT_workSpeedMod > 0`.
- What it proves: Cost is -5 and the trait is registered and present in the script definitions. The Lua file loads without error (implicit from dofile success).
- Missing proof: No test verifies that `UT_slowworker` actually writes `UT_workSpeedMod = 0.5` (positive) into player moddata on `OnNewGame`. A regression that changed the delta sign or value would go undetected.
- Minimum next test if needed: `test("UT_slowworker sets UT_workSpeedMod = 0.5", function() local p = fireNewGame("UniversalTraits:UT_slowworker") assert_eq(p:getModData()["UT_workSpeedMod"], 0.5, "expected UT_workSpeedMod 0.5") end)` — mirrors the existing `UT_quickworker` test pattern.

## Final Verdict

- Source origin: proven — `ToadTraits:slowworker` from More Traits; magnitude (50% duration) and scope (all timed actions) confirmed against 42.15 source.
- UT implementation: faithful — mechanism is simplified (no sandbox scaler, no Lucky/Dextrous interaction) but the core effect (50% duration penalty via UTCore work speed hook) faithfully reproduces the source default behavior.
- Description: incomplete — "-50% work speed" is ambiguous and technically inconsistent with the actual +50% duration (which is not the same as halving speed); the parenthetical `(+50% work duration)` rescues accuracy but the leading claim could mislead players into expecting a 2x slowdown.
- Balance: questionable — -5 cost for a permanent 50% all-action duration penalty is below the source-calibrated -9 and inconsistent with `UT_slack` (-6 for -40%), though internally consistent if priced at -1 per 10% duration.
- Regression proof: partially protected — cost and registration are tested; the moddata write value is not tested.
- Action needed: doc fix, test fix
- Open gaps:
  1. Description leading claim ("-50% work speed") does not match the mechanic (+50% duration / 1.5x); recommend rewriting to "-33% work speed (actions take 50% longer)" or simply "+50% work duration on all timed actions."
  2. No assertion test for the `UT_workSpeedMod = 0.5` write; add a parallel test to the existing `UT_quickworker` test.
  3. Cost relative to source (-9) and to `UT_slack` (-6 for weaker effect) is potentially underpriced; worth a balance pass against those reference points.
