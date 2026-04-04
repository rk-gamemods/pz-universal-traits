# UT_humanhamster

## Trait Summary

- UT trait id: UT_humanhamster
- Source mod: SomewhatTraits (somewhatfrog)
- Source trait id: SWHumanHamster
- Current cost: -3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/registries.lua` (registration, line 15 — commented out)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/registries.lua` (registration, line 15 — commented out)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (registration call, line 82 — commented out)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (runtime implementation, lines 102, 245–255 — implementation fully commented out)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/Translate/EN/UI_EN.txt` (translation strings, lines 20–21)
- Source trigger path: `Events.AddXP` → `SWHumanHamster` handler (inside a block comment `--[[...]]` in the shipped source).
- Source behavior: In the source, `SWHumanHamster` was a positive trait costing 3 points. Its only implemented effect — when it was active — was to fire on `Events.AddXP`: if the XP event granted more than 1000 XP to the Strength or Fitness perk, the handler would add an additional 30% of that amount on top. The trait required two external mods (`modFC4WT` and `modSD`) to be present before it was registered at all; both the registration call and the `Events.AddXP` handler are commented out in all shipped versions of SomewhatTraits, meaning the trait was never active in any released build. The source EN description read: "Extra experience from treadmill." The source had no mutual exclusions and `DisabledInMultiplayer = false`.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — present in the Phase 3c Event-Driven section of the all-traits list at line 303 of `test/run_tests.lua`
- Defined in UT_character_traits.txt: yes — `UniversalTraits:UT_humanhamster` block at lines 2061–2069
- Translation strings present: yes — `UI_UT_humanhamster` and `UI_UT_humanhamsterDesc` at lines 638–639 of `UI_EN.txt`
- Exclusions/grants correct: no exclusions defined in UT definition; source had none either — consistent
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_humanhamster.lua`
- `DisabledInMultiplayer`: yes — UT sets `DisabledInMultiplayer = true`; source set `false` (and was never actually registered anyway)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_humanhamster.lua`
  - `media/scripts/UT_character_traits.txt` (lines 2061–2069)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 638–639)
  - `test/run_tests.lua` (line 303)
- Event registrations:
  - `Events.OnCreatePlayer.Add(onCreatePlayer)` — fires once when a player is created (new game and load)
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — presence check in `onCreatePlayer`
  - `UTCore.applyCarryWeight(player, 2)` — applies +2 to base carry weight
  - `player:getModData()["UT_hamsterMode"] = true` — sets a flag on the player's mod data
- Runtime chain (plain language):
  1. When a player is created (new game or loaded), if the player holds the trait, `UTCore.applyCarryWeight(player, 2)` is called, permanently increasing the player's base carry weight by 2 (from the default 8 to 10).
  2. The flag `UT_hamsterMode = true` is also written into the player's mod data.
- Actual behavior (exact values):
  - Carry weight: +2 to base carry weight, applied at `OnCreatePlayer`.
  - Mod data flag: `player:getModData()["UT_hamsterMode"] = true` — set unconditionally alongside the carry bonus.
  - No XP effects. No treadmill interaction. No other stat modifiers.

## Description Integrity

- Display name check: `UI_UT_humanhamster` = "Human Hamster" — matches the source name exactly; accurate.
- Description check: `UI_UT_humanhamsterDesc` = "You have an overwhelming compulsion to hoard. Every container you pass demands to be checked and filled." — this describes a compulsive-hoarding personality but does not mention carry weight at all, and does not mention any mechanical effect.
- Accuracy verdict: **misleading** — the description is pure flavor text evoking hoarding behavior, which implies the player compulsively picks up items. The actual runtime effect is a permanent +2 carry weight bonus applied at character creation. The description does not state the carry-weight benefit, does not state the exact value (+2), and does not indicate whether the trait is positive or negative. A player reading only the description cannot determine what the trait does mechanically.
- Additional concern: the UT cost is -3 (negative trait), meaning the player takes a disadvantage to gain points. A trait that grants +2 carry weight and is coded as a negative trait is internally inconsistent — carry weight is universally beneficial in PZ. Either the cost sign is wrong, or the trait is intended to have an additional downside that is not yet implemented. The `UT_hamsterMode` flag suggests a future downside mechanic is planned but not present in the current code.
- Source description divergence: the source description promised treadmill XP; UT replaces the mechanic entirely with a carry-weight bonus and a mod-data flag. The UT description does not reference the source mechanic, which is correct, but it also does not describe the actual UT mechanic.

## Balance Review

- Upside: +2 base carry weight (permanent, unconditional, applies on every load via `OnCreatePlayer`).
- Downside: none implemented — the `UT_hamsterMode` flag is set but no code in the audited Lua file reads or acts on it.
- Uptime: 100% permanent (carry weight bonus); the flag persists in mod data indefinitely.
- Peer comparison: `UT_packmule` costs +3 points (positive trait) and grants +6 carry weight. `UT_preparedpack` costs +1 point (positive trait) and grants +3 carry weight. `UT_humanhamster` costs -3 points (negative trait) and grants +2 carry weight — meaning the player receives 3 free character points AND a carry-weight bonus simultaneously. This is strictly dominant over taking no trait at all, and dominates `UT_preparedpack` on cost efficiency.
- Stack or exclusion notes: no mutual exclusions defined. Can be stacked freely with `UT_packmule`, `UT_preparedpack`, `UT_sorelegs`, and other carry-adjacent traits.
- Cost verdict: **broken** — as implemented, a -3 cost (negative trait) that grants +2 carry weight with no downside is a free benefit, not a drawback. The player is paid 3 points to take what is mechanically a positive bonus. Either the cost must be flipped to a positive value (making it a standard positive trait consistent with peers), or a meaningful downside must be implemented that consumes the `UT_hamsterMode` flag before release.

## Regression Proof

- Existing tests:
  1. Registration presence check (line 303) — `"UniversalTraits:UT_humanhamster"` appears in the Phase 3c all-traits list; the surrounding test asserts correct registration count and ID strings.
- What it proves: the trait ID is registered with the CharacterTrait system.
- Missing proof:
  - No cost assertion verifying that the script definition cost is -3.
  - No runtime test firing `OnCreatePlayer` with the trait active and asserting `p:getMaxWeightBase() == 10`.
  - No test verifying `UT_hamsterMode` is set in mod data.
  - No negative-path test confirming a player without the trait does not receive the carry bonus.
  - No test documenting or guarding the `UT_hamsterMode` flag against future consumers.
- Minimum next tests needed:
  1. Cost assertion: `assert_eq(costs["UniversalTraits:UT_humanhamster"], -3, "humanhamster cost")`.
  2. Runtime carry-weight test: fire `OnCreatePlayer` with trait active; assert `p:getMaxWeightBase() == 10`.
  3. Mod-data flag test: fire `OnCreatePlayer` with trait active; assert `p:getModData()["UT_hamsterMode"] == true`.
  4. Negative-path test: fire `OnCreatePlayer` without trait; assert `p:getMaxWeightBase() == 8` (unchanged).

## Final Verdict

- Source origin: proven — `SWHumanHamster` from SomewhatTraits confirmed; all source references located. Critically, the source trait was never active in any shipped build: both the registration call and the `Events.AddXP` handler are commented out in all observed versions of SomewhatTraits, meaning UT adapted a trait that existed only as dead code in the source.
- UT implementation: redesigned — the source (when active) applied a 30% XP bonus to Strength/Fitness perk events above a 1000 XP threshold, gated behind two external mod dependencies. UT replaces this entirely with a flat +2 carry weight on `OnCreatePlayer` and a `UT_hamsterMode` mod-data flag. The mechanism is completely different from the source.
- Description: **inaccurate** — the UT description is flavor text only; it does not state the carry-weight effect, the exact value (+2), or any downside. A player cannot determine the mechanical effect from the description alone. Must be rewritten to accurately reflect the +2 carry weight benefit and, once implemented, any downside that justifies the -3 negative cost.
- Balance: **broken** — the trait is coded as a negative trait (cost -3) but grants a universally positive effect (+2 carry weight) with no implemented downside. The `UT_hamsterMode` flag implies a downside is planned but it is not yet present. As shipped, this trait gives players 3 free points plus a carry bonus, which is a balance defect. Resolution requires either: (a) implementing the intended downside mechanic that reads `UT_hamsterMode`, or (b) changing the cost to a positive value and reclassifying the trait.
- Regression proof: **severely underprotected** — only the registration presence check exists. No cost test, no runtime effect test, no flag test, no negative-path test.
- Action needed: **do not ship as-is**. Three blocking issues must be resolved before release:
  1. Implement the missing downside that `UT_hamsterMode` implies, OR reclassify as a positive trait with a positive cost.
  2. Rewrite the description to accurately state the mechanical effect (carry weight value) and any downside.
  3. Add runtime tests covering cost, carry-weight effect, mod-data flag, and negative-path guard.
- Open gaps:
  - `UT_hamsterMode` flag is set but never read by any audited code — its intended consumer is unknown and undocumented.
  - Cost sign is inconsistent with the implemented effect; the trait functions as a positive trait priced as a negative trait.
  - Description is pure flavor with no mechanical information.
  - Source trait was commented-out dead code in all known SomewhatTraits releases; the design intent behind the original treadmill-XP mechanic and its replacement with carry weight is undocumented.
  - No cost assertion, runtime carry-weight test, mod-data flag test, or negative-path test exists.
  - `DisabledInMultiplayer = true` in UT — consistent with UT's general pattern but undocumented as a design decision.
