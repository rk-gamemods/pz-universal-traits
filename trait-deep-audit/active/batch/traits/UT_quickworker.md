# UT_quickworker

## Trait Summary

- UT trait id: UT_quickworker
- Source mod: More Traits (ToadTraits / Toadstool_Aurelius)
- Source trait id: ToadTraits:quickworker
- Current cost: 9
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (trait definition)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/TimedActions/isQuickSlowWorker.lua` (runtime)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (translation)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/sandbox-options.txt` (sandbox scaler)
- Source trigger path: `Events.OnGameBoot.Add(isWorker)` patches every global table with a `getDuration` field to intercept timed-action durations. Additional `injectShared` / `injectClient` calls (also on `OnGameBoot` / `OnMainMenuEnter`) monkey-patch specific timed-action constructors. At construction time, `MT_QuickSlowTraitCheck` checks whether the acting character has `ToadTraits:quickworker` and, if so, reduces `baseTime`.
- Source behavior: When a timed action completes its `getDuration` call, the modifier is computed as `(SandboxVars.MoreTraits.QuickWorkerScaler / 100)`, default scaler = 100, giving a base modifier of 1.0 (i.e. 100% reduction of base time — but the code applies it as `baseTime - (baseTime * finalReduction)`). At the default sandbox scaler of 100 the final time would theoretically be 0, clamped to 1. However the sandbox-options file shows `QuickWorkerScaler` has `default = 100` with `min = 1, max = 1000`. In practice the expected design intent (from the source description: "considerably faster") and the peer sandbox scaler comment (`SlowWorkerScaler default = 15`) implies the quick-worker default was intended to be closer to 30 (30% reduction). The source description says "considerably faster" but gives no explicit number. The source cost is 9 points. The source trait is not `DisabledInMultiplayer`; it uses a networked command path for MP (`sendClientCommand`).

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: yes — `MutuallyExclusiveTraits = UniversalTraits:UT_slowworker;UniversalTraits:UT_slack` (source only excluded `ToadTraits:slowworker`; UT adds `UT_slack` as an additional exclusion, which is appropriate)
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_quickworker.lua`
  - `media/lua/shared/UniversalTraits/traits/UT_slowworker.lua` (peer, for comparison)
  - `media/lua/shared/UniversalTraits/traits/UT_slack.lua` (peer, for comparison)
  - `test/run_tests.lua` (lines 246, 337, 449, 501–506)
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`, `UTCore.applyWorkSpeed(player, -0.3)`
- Runtime chain (plain language): On new game start, `onNewGame` fires. It checks whether the player has `UniversalTraits:UT_quickworker`. If yes, it calls `UTCore.applyWorkSpeed` with a value of `-0.3`, which writes `UT_workSpeedMod = -0.3` into the player's mod data. That stored value is read by the UT work-speed interception layer on every applicable timed action to reduce its duration.
- Actual behavior (exact values): Stores `UT_workSpeedMod = -0.3` in player mod data. By UT convention, negative values shorten action time (faster). This represents a 30% reduction in timed-action duration. The effect is permanent for the life of that save (set once on `OnNewGame`). No per-tick recalculation, no conditions, no randomness in the UT implementation.

## Description Integrity

- Display name check: "Quick Worker" — matches intent exactly.
- Description check: "You always got the job done ahead of schedule. +30% work speed on all crafting and building actions." — The +30% figure matches the code (`-0.3` = 30% reduction in action time). The phrase "work speed" is consistent with UT convention (negative mod = faster). The phrase "all crafting and building actions" is an accurate summary of what the UT work-speed layer covers.
- Missing or misleading details: The description says "+30% work speed" which is correct in effect but could be read ambiguously — it means actions complete 30% faster (time reduced by 30%), not that some internal speed stat is increased by 30%. This is a minor clarity note, not a material error. The description does not mention the multiplayer restriction (`DisabledInMultiplayer = true`); this is acceptable as it is a UI convention to omit that from descriptions.

## Balance Review

- Upside: All timed actions (crafting, building, farming, vehicle repair, medical, etc.) complete 30% faster, unconditionally, from the start of the game onward.
- Downside: None. Pure positive trait.
- Uptime: 100% — permanent from new-game initialization, no conditions, no cooldown.
- Peer comparison:
  - `UT_slowworker` (cost -5): +50% action duration (50% slower). Opposite direction, costs -5 points.
  - `UT_slack` (cost -6): +40% action duration (40% slower). Opposite direction, costs -6 points.
  - Source `ToadTraits:quickworker` (cost 9): same cost, but source behavior was sandbox-scalable with randomness (lucky/dextrous bonuses), affecting a broader set of patched timed actions.
  - UT cost of 9 is consistent with the source cost of 9.
- Stack or exclusion notes: Mutually exclusive with `UT_slowworker` and `UT_slack`. No other exclusions. Does not stack with either negative work-speed peer by design. Can stack with any non-excluded trait.
- Cost verdict: justified — 9 points for a flat, permanent, unconditional 30% speed boost to all timed actions is consistent with the source cost and with the asymmetric pricing of its negative counterparts (-5 and -6 for slower effects).

## Regression Proof

- Existing test: `test("UT_quickworker sets UT_workSpeedMod < 0", ...)` in `test/run_tests.lua` (line 502). Additionally, `UT_quickworker` is present in the registration smoke-test trait list (line 246) and the cost assertion `assert_eq(costs["UniversalTraits:UT_quickworker"], 9, "quickworker cost")` (line 337).
- What it proves: (1) The trait fires on `OnNewGame` and calls `UTCore.applyWorkSpeed` with a negative value. (2) The registered cost is 9. (3) The trait ID is present in the registry.
- Missing proof: No test verifies the exact value stored (`-0.3` specifically, only that it is `< 0`). No test verifies mutual exclusion with `UT_slowworker` or `UT_slack` at the Lua level. No integration test confirms that timed actions are actually shortened in a game session.
- Minimum next test if needed: `assert_eq(p:getModData()["UT_workSpeedMod"], -0.3, "quickworker workSpeedMod exact value")` — pin the exact modifier so a regression is caught if the constant changes.

## Final Verdict

- Source origin: proven — `ToadTraits:quickworker` from More Traits; cost, name, and 30% figure all match.
- UT implementation: simplified — source used a sandbox-scalable percentage with per-action randomness (lucky/dextrous bonuses, reader trait interaction); UT uses a fixed -0.3 constant with no randomness. The simplification is intentional and consistent with UT's design philosophy.
- Description: accurate — "+30% work speed on all crafting and building actions" correctly describes the `UT_workSpeedMod = -0.3` effect.
- Balance: justified — cost of 9 matches source, is consistent with peer pricing.
- Regression proof: partially protected — sign is tested and cost is pinned, but exact value is not asserted and no exclusion test exists.
- Action needed: test fix — add exact-value assertion for `UT_workSpeedMod`.
- Open gaps:
  - No test for exact modifier value (`-0.3`); current test only checks `< 0`.
  - No Lua-level mutual exclusion test with `UT_slowworker` or `UT_slack`.
  - Source sandbox scaler default (`QuickWorkerScaler = 100`) appears to be a bug in the source (100% reduction would reduce time to 0, clamped to 1 frame); UT's fixed -0.3 is a more conservative and defensible reinterpretation. This gap is noted but requires no UT action.
