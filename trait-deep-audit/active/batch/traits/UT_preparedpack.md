# UT_preparedpack

## Trait Summary

- UT trait id: UT_preparedpack
- Source mod: MoreTraits (ToadTraits)
- Source trait id: ToadTraits:preparedpack
- Current cost: 1
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (trait definition, lines 708–717)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (translation strings, lines 14–15)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (runtime implementation, lines 369–373)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (registration, line 15)
- Source trigger path: `Events.OnCreatePlayer` → `MoreTraitsMainCreationMethods` fires once at character creation; checks `player:hasTrait(ToadTraitsRegistries.preparedpack)`.
- Source behavior: On character creation, if the trait is held, a `Base.Bag_NormalHikingBag` item is added to the player's inventory. If the player's back-slot is empty, the bag is also equipped to the back. No stat modifiers are applied — the trait is purely a spawn-inventory grant. Cost in source: 1 point. Mutually exclusive with `ToadTraits:deprived` and all other `ToadTraits:prepared*` sibling traits (preparedammo, preparedcamp, preparedcar, preparedcoordination, preparedfood, preparedmedical, preparedrepair, preparedweapon). Source `DisabledInMultiplayer = false`. Source description: "You were prepared for the inevitable looting that would occur following the apocalypse. You begin the game with a Regular Hiking Bag."

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — present in the Phase 2 Spawn/Inventory section of the all-traits list at line 240 of `test/run_tests.lua`
- Defined in UT_character_traits.txt: yes — `UniversalTraits:UT_preparedpack` block at lines 1108–1116
- Translation strings present: yes — `UI_UT_preparedpack` and `UI_UT_preparedpackDesc` at lines 326–327 of `UI_EN.txt`
- Exclusions/grants correct: no exclusions defined in UT definition — the source had mutual exclusions with all other `prepared*` siblings and `deprived`; UT drops all of them
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_preparedpack.lua`
- `DisabledInMultiplayer`: yes — UT sets `DisabledInMultiplayer = true`; source set `false`

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_preparedpack.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1108–1116)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 326–327)
  - `test/run_tests.lua` (lines 240, 336, 452, 513–516)
- Event registrations:
  - `Events.OnCreatePlayer.Add(onCreatePlayer)` — fires once when a player is created (new game and load)
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — presence check in `onCreatePlayer`
  - `UTCore.applyCarryWeight(player, 3)` — applies +3 to base carry weight
- Runtime chain (plain language):
  1. When a player is created (new game or loaded), if the player holds the trait, `UTCore.applyCarryWeight(player, 3)` is called, permanently increasing the player's base carry weight by 3 (from the default 8 to 11).
- Actual behavior (exact values):
  - Carry weight: +3 to base carry weight, applied at `OnCreatePlayer`.
  - No item is spawned. No skill bonuses. No other effects.

## Description Integrity

- Display name check: "Prepared: Pack" — matches the source name exactly; accurate.
- Description check: `UI_UT_preparedpackDesc` = "You packed your bag with obsessive care before everything fell apart. Increases your base carry weight by +3." — this accurately describes the single runtime effect with the exact value (+3 carry weight).
- Source description divergence: the source description promised a spawned Regular Hiking Bag; UT replaces the item-spawn mechanic with a carry-weight stat bonus. The UT description correctly reflects the UT implementation and does not carry forward the misleading item-spawn promise.
- Missing or misleading details: none — the description matches the code exactly.

## Balance Review

- Upside: +3 base carry weight (permanent, unconditional, applies on every load via `OnCreatePlayer`).
- Downside: none — pure positive trait.
- Uptime: 100% permanent.
- Peer comparison: `UT_packmule` costs 3 points and grants +6 carry weight. `UT_preparedpack` costs 1 point and grants +3 carry weight. Both are purely additive permanent carry bonuses with no downsides. The ratio of effect/cost is identical (2 weight per point), meaning these two traits sit on the same value curve. `UT_backpacker` and `UT_topheavy` are also carry-adjacent traits whose costs should be checked for consistency; however, those are separate audits.
- Stack or exclusion notes: UT defines no mutual exclusions. `UT_preparedpack` and `UT_packmule` can be combined freely, yielding +9 carry weight for 4 points total. This is likely intentional (they represent different magnitudes on the same axis) but is an open design question not yet documented. The source trait blocked all sibling `prepared*` variants; UT carries none of those exclusions forward, which is consistent with UT's general pattern of not porting sibling exclusions.
- Cost verdict: reasonable — at 1 point for +3 carry weight the cost/value ratio mirrors `UT_packmule` at 3 points for +6. No balance concern at the individual trait level; the combined-stacking case is a lower-priority open question.

## Regression Proof

- Existing tests:
  1. Registration presence check (line 240) — `"UniversalTraits:UT_preparedpack"` appears in the all-traits list; the surrounding test asserts correct registration count and ID strings.
  2. Cost assertion (line 336) — `assert_eq(costs["UniversalTraits:UT_preparedpack"], 1, "preparedpack cost")` — confirms the script definition cost is exactly 1.
  3. Runtime carry-weight test (lines 513–516) — `"UT_preparedpack keeps the +3 carry weight bonus"` fires `OnCreatePlayer` with the trait active and asserts `p:getMaxWeightBase() == 11` (default 8 + 3).
  4. Lua file loaded in test harness (line 452) — `dofile` for `UT_preparedpack.lua` confirms the file is exercised.
- What it proves: The trait is registered correctly, the script cost is correct, and the `onCreatePlayer` handler fires and applies exactly +3 carry weight.
- Missing proof: No negative-path test verifies that a player without the trait does not receive the carry bonus (guard check on `UTCore.hasTrait` correctness). Given the simplicity of the implementation this is low-risk, but the gap exists.
- Minimum next test if needed: A test that fires `OnCreatePlayer` with no trait and asserts `p:getMaxWeightBase() == 8` (unchanged default).

## Final Verdict

- Source origin: proven — `ToadTraits:preparedpack` from MoreTraits confirmed; definition, translation, runtime, and registration all traced.
- UT implementation: redesigned — the source granted a spawned Regular Hiking Bag item; UT replaces this with a permanent +3 carry-weight stat bonus. This is a deliberate mechanical redesign, not a port. The carry-weight approach is cleaner (no inventory-slot dependency, no equip-slot side effect) and consistent with UT's stat-modifier pattern.
- Description: accurate — the UT description correctly documents the +3 carry-weight bonus and does not carry forward the item-spawn language from the source.
- Balance: reasonable — cost/value ratio matches `UT_packmule`; no individual concern. Free stacking with `UT_packmule` (no exclusions) is an open design question but not a balance defect at current costs.
- Regression proof: well-protected — registration, cost, and runtime carry-weight effect are all tested; only the no-trait guard path is untested.
- Action needed: none required — implementation is clean and tested. Optional: add a negative-path test for the no-trait guard; document the intentional packmule-stacking design decision.
- Open gaps:
  - No negative-path test for the `UTCore.hasTrait` guard (low risk given code simplicity).
  - No explicit design note recording that the item-spawn mechanic was intentionally replaced with a carry-weight bonus.
  - Stacking behavior with `UT_packmule` (combined +9 carry for 4 points) is undocumented; confirm whether this is intended or whether a mutual exclusion should be added.
  - `DisabledInMultiplayer = true` in UT vs. `false` in source — the restriction is intentional but undocumented; a brief note in a design log would clarify the decision for future maintainers.
