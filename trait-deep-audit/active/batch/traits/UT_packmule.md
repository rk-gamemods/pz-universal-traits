# UT_packmule

## Trait Summary

- UT trait id: `UniversalTraits:UT_packmule`
- Source mod: MoreTraits
- Source trait id: `packmule`
- Current cost: 3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` lines 203 and 385
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` lines 2984-3004
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/server/MoreTraits_UCWF.lua` lines 31-45
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/Translate/EN/UI_EN.txt` lines 129-130
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/Translate/EN/Sandbox_EN.txt` lines 19-24
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42/media/lua/client/MoreTraits - Dynamic.lua` lines 98-102
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42/media/sandbox-options.txt` lines 527-542
- Source trigger path:
  - MoreTraits registers `packmule` at cost 7, marks it mutually exclusive with `packmouse`, then its carry-weight framework resolves base carry from trait state.
  - In 42.13 shared runtime and 42.15 UCWF runtime, `packmule` sets carry base to `WeightPackMule or 10`, then adds `floor(Strength / 5)`.
  - With source defaults, vanilla base 8 becomes 10/11/12 at Strength 0-4 / 5-9 / 10, so the effective bonus is **+2 / +3 / +4**.
  - Optional More Traits Dynamic addon can auto-grant `packmule` at Strength >= 9 when its sandbox option is enabled.
- Source behavior:
  - Positive carry-capacity trait with source cost **7**.
  - Description explicitly says carry capacity is increased and Strength matters more.
  - Mutual exclusion proven only with `packmouse` in source.
  - Behavior is sandbox-configurable in source; UT does not preserve that configurability.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_packmule = CharacterTrait.register("UniversalTraits:UT_packmule")` at line 120.
- Defined in UT_character_traits.txt: yes — block at lines 897-906 with cost 3 and `MutuallyExclusiveTraits = UniversalTraits:UT_packmouse;UniversalTraits:UT_topheavy`.
- Translation strings present: yes — `UI_UT_packmule` / `UI_UT_packmuleDesc` at lines 263-264 of `UI_EN.txt`.
- Exclusions/grants correct: partially — all referenced IDs are real and namespaced, but current UT allows `UT_packmule` to stack with other positive carry traits such as `UT_backpacker` and `UT_preparedpack`; checklist already flags `UT_backpacker + UT_packmule` as a likely missing exclusion/design gap.
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_packmule.lua`.

### Runtime Trace

- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_packmule.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` lines 13-17
  - `UniversalTraits/test/run_tests.lua` lines 70-71, 335, 421-424, 451, 508-511
  - `UniversalTraits/test/UTTestMocks.lua` lines 171-172 and 229-231
- Event registrations:
  - `Events.OnCreatePlayer.Add(onCreatePlayer)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)`
  - `UTCore.applyCarryWeight(player, 6)`
- Runtime chain (plain language):
  1. On player creation/load, UT runs `onCreatePlayer`.
  2. If the player lacks `UniversalTraits:UT_packmule`, the function exits.
  3. If present, `UTCore.applyCarryWeight(player, 6)` reads current `MaxWeightBase` and writes back `base + 6`.
  4. No strength check, no sandbox lookup, no periodic recalculation, no dynamic unlock, and no other side effects occur.
- Actual behavior (exact values):
  - Flat **+6 base carry weight**.
  - On a default mock player, base carry rises from 8 to 14.
  - No scaling with Strength.
  - No source-style `WeightPackMule` sandbox value.
  - Save/load idempotence is not directly proven; current automated proof only covers the fresh `OnCreatePlayer` path on a new mock player.

## Description Integrity

- Display name check: accurate — `Pack Mule` matches source and current implementation.
- Description check: current UT text says `+6 base carry weight`, and that is exactly what the current Lua applies.
- Missing or misleading details:
  - Compared with source intent, the UT description no longer mentions Strength scaling because UT removed that mechanic entirely.
  - The description is accurate for UT-as-built, but it documents a **design drift**, not a faithful port.

## Balance Review

- Upside:
  - Permanent flat **+6** base carry weight.
  - 100% uptime once applied.
- Downside:
  - None.
- Uptime:
  - Constant after `OnCreatePlayer` applies it.
- Peer comparison:
  - Source MoreTraits version cost **7** and effectively gave **+2 to +4** depending on Strength.
  - UT version costs only **3** and gives a flat **+6**, making it materially stronger and cheaper than source.
  - `UT_preparedpack` gives +3 for cost 1; `UT_packmule` gives +6 for cost 3. Those two can currently stack for +9 total carry at cost 4.
  - `UT_backpacker` is another positive carry trait and is not excluded by `UT_packmule`, matching the shared checklist concern.
- Stack or exclusion notes:
  - Source only proved `packmouse` exclusion.
  - UT adds `UT_topheavy`, which is a sensible UT-specific exclusion.
  - UT does **not** exclude `UT_backpacker` or `UT_preparedpack`, so carry-bonus stacking remains possible.
- Cost verdict: **questionable** — current UT implementation is a substantial buff and cost reduction versus source. If this is intentional redesign, it needs explicit design justification; if the goal was faithful porting, cost/behavior drift is too large.

## Regression Proof

- Existing test:
  - Registration test at lines 70-71 confirms the trait ID is registered.
  - Script-cost test at line 335 locks `UniversalTraits:UT_packmule` cost to 3.
  - Runtime test at lines 508-511 asserts `fireCreatePlayer("UniversalTraits:UT_packmule")` yields `getMaxWeightBase() == 14`.
- What it proves:
  - Current UT implementation really is the flat +6 carry-weight version.
  - Registration and script cost are protected.
- Missing proof:
  - No test for the no-trait guard path.
  - No idempotence/save-load test to prove `OnCreatePlayer` does not stack unexpectedly across repeated calls.
  - No test captures the source-intent loss of Strength scaling, so the suite cannot detect further drift from source because it already codifies the redesigned behavior.
- Minimum next test if needed:
  - Add a no-trait `OnCreatePlayer` test asserting carry stays at 8.
  - Add a repeated-`OnCreatePlayer` test or explicit save/load contract test documenting whether carry should remain 14 rather than stacking.
  - If faithful-port behavior is desired, add a Strength-based test matrix instead of the current flat +6 assertion.

## Final Verdict

- Source origin: proven
- UT implementation: drifted
- Description: accurate
- Balance: questionable
- Regression proof: partially protected
- Action needed: code fix
- Open gaps:
  - Current UT behavior is not a faithful port: source was Strength-scaled and sandbox-based; UT is flat +6.
  - Current UT cost (3) is far below source cost (7) despite stronger default output.
  - Carry-stack design remains underconstrained: `UT_packmule` still stacks with other positive carry traits, especially `UT_backpacker`.
  - Save/load/idempotence behavior is not explicitly proven by tests.
