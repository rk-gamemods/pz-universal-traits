# UT_cangrabmore

## Trait Summary

- UT trait id: UT_cangrabmore
- Source mod: MoreSimpleTraits
- Source trait id: CanGrabMore
- Current cost: 2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` (trait registration, cost, mutual exclusions)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTWeightTraits.lua` (runtime implementation)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt` (lines 80–81, source display name and description)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/client/MSTWeightTraits.lua` (identical vanilla variant confirmed)
- Source trigger path: `Events.OnCreatePlayer.Add(cangrabmorecalc)` — fires once at character creation. The handler calls `getPlayer()`, checks `player:HasTrait("CanGrabMore")`, and if true calls `player:setMaxWeightBase(9)`.
- Source behavior: Hard-sets the player's base carry weight to 9 (the PZ default is 8). This is an absolute assignment, not a delta — if something else already raised MaxWeightBase above 9 the trait would silently lower it. Cost in source: 2 points. Mutually exclusive with `CanGrabLess`. Additionally mutually exclusive with `Weak` (vanilla trait). The companion `CanGrabLess` hard-sets base carry weight to 7 and is mutually exclusive with `Strong` (vanilla trait).
- Source display name: "Strong Back"
- Source description: "Can carry more weight.\n(bonus: plus 1-2 max weight depending on Strength, more Strength, more bonus)." — note this description references a strength-scaling bonus; the actual source code applies a flat hard-set to 9 with no strength scaling.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_cangrabmore = CharacterTrait.register("UniversalTraits:UT_cangrabmore")` at line 134, positioned in the Phase 1 Stat Modifiers block alongside `UT_cangrabless`, `UT_backpacker`, `UT_topheavy`, `UT_lesssweaty`, `UT_highsweaty`.
- Defined in UT_character_traits.txt: yes — lines 1042–1051:
  ```
  character_trait_definition UniversalTraits:UT_cangrabmore
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_cangrabmore,
      Cost = 2,
      UIName = UI_UT_cangrabmore,
      UIDescription = UI_UT_cangrabmoreDesc,
      MutuallyExclusiveTraits = UniversalTraits:UT_cangrabless,
  }
  ```
- Translation strings present: yes — `UI_EN.txt` lines 305–306:
  - `UI_UT_cangrabmore = "Strong Grip"`
  - `UI_UT_cangrabmoreDesc = "Your powerful hands let you grab and restrain zombies more effectively. Grab success rate is increased."`
- Exclusions/grants correct: partially — mutually exclusive with `UT_cangrabless` only. The source also excluded `Weak` (vanilla). The source vanilla variant additionally excluded `Strong`. Neither vanilla exclusion is carried over. Whether this is intentional or an oversight is not documented.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_cangrabmore.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_cangrabmore.lua` (full file, 13 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1042–1051)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 305–306)
  - `test/run_tests.lua` (line 236 — trait appears in registration smoke-test list only)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16 — `UTCore.hasTrait` implementation)
- Event registrations:
  - `Events.OnCreatePlayer.Add(onCreatePlayer)` — fires once at character creation
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — guard check; resolves to `player:getTraits():contains("UniversalTraits:UT_cangrabmore")` with nil-safety on both player and the traits collection
- Runtime chain (plain language):
  1. At character creation, `onCreatePlayer(playerIndex, player)` fires.
  2. `UTCore.hasTrait` checks `player:getTraits():contains("UniversalTraits:UT_cangrabmore")`. If false, returns immediately.
  3. If the trait is present, `player:setMaxWeightBase(9)` is called — hard-setting the base carry weight to 9.
- Actual behavior (exact values):
  - Base carry weight set to 9 (PZ default is 8; net effect is +1 base carry weight unit).
  - The assignment is unconditional and absolute — if `MaxWeightBase` was already above 9 due to another trait or effect, this call would overwrite it downward.
  - No strength scaling, no delta, no persistence via mod data, no subsequent ticks.

## Description Integrity

**CRITICAL MISMATCH — description does not describe actual behavior.**

- Display name check: `"Strong Grip"` — the name implies zombie grab/grapple mechanics. The Lua implementation has nothing to do with grabbing or gripping; it sets carry weight. The source name was "Strong Back" (carry weight framing). The UT name is wrong for the actual effect.
- Description check: `"Your powerful hands let you grab and restrain zombies more effectively. Grab success rate is increased."` — this description is entirely fabricated relative to the code. The Lua does one thing: `player:setMaxWeightBase(9)`. There is no grab mechanic, no success rate, no zombie restraint logic anywhere in the file or in any UTCore hook called by this trait. The description was written for a zombie-grapple trait; the code was written for a carry weight trait.
- Source description for comparison: "Can carry more weight. (bonus: plus 1-2 max weight depending on Strength, more Strength, more bonus)." — the source correctly framed this as a carry weight trait. The UT description abandoned this framing entirely and replaced it with unimplemented combat flavor.
- Missing or misleading details: The description is not merely imprecise — it describes a completely different, non-existent mechanic. The actual effect (+1 base carry weight via hard-set to 9) is not mentioned at all.

**Required fix:** Replace display name and description to accurately reflect the carry weight effect. Suggested:
- Name: `"Strong Back"` (matches source and actual effect)
- Description: `"Your build lets you carry more. Base carry weight is increased by 1 (from 8 to 9)."`

## Balance Review

- Upside: +1 base carry weight (MaxWeightBase 8 → 9). This is a modest, permanent gain.
- Downside: none — pure positive trait.
- Uptime: 100% permanent, applied once at character creation.
- Peer comparison: `UT_backpacker` costs 8 points and applies a strength-based carry weight bonus via `UTCore.applyStrengthCarryWeight(player, 4)` on `OnPlayerUpdate`. `UT_cangrabmore` at 2 points gives a flat +1. The cost ratio (2 vs. 8) is broadly proportionate given the difference in effect magnitude. `UT_packmule` likely provides a larger bonus for its cost — exact comparison pending `UT_packmule` audit — but at 2 points for +1 carry weight, this trait reads as fair.
- Stack or exclusion notes: Only excludes `UT_cangrabless`. Does not exclude `UT_backpacker`, `UT_packmule`, or any other carry weight traits, so stacking is possible. Whether stacking +1 (cangrabmore) on top of `UT_backpacker` is intended is not documented.
- Hard-set risk: the `setMaxWeightBase(9)` call is absolute. If applied after a trait that raised `MaxWeightBase` above 9 (e.g., `UT_backpacker` raises it higher during `OnPlayerUpdate`), load order determines whether this silently overwrites or is overwritten. The source had the same design flaw. This is a latent interaction bug when stacked with other carry weight traits that also use hard-sets.
- Cost verdict: reasonable for the actual +1 carry weight effect. The mismatch between name/description and effect makes the cost unverifiable from the player's perspective.

## Regression Proof

- Existing test: `UT_cangrabmore` appears in the registration smoke-test list at `test/run_tests.lua` line 236 (within the `-- Stat Modifiers (20)` block). This verifies the trait ID string is registered and passes the script-definition parse check. No dedicated functional test exists.
- What it proves: The trait is registered, has a script definition, and its trait ID appears in the all-traits list used by the smoke test. The smoke test confirms `CharacterTrait.register` returns the correct namespaced ID.
- Missing proof: No test verifies that `onCreatePlayer` fires and calls `setMaxWeightBase(9)`. Specifically:
  - (a) That a player with the trait exits `onCreatePlayer` with `MaxWeightBase == 9`.
  - (b) That a player without the trait exits `onCreatePlayer` with `MaxWeightBase` unchanged.
  - (c) That the hard-set to 9 does not silently overwrite a pre-existing value above 9.
- Minimum next test if needed: Use `fireCreatePlayer("UniversalTraits:UT_cangrabmore")` and assert `p:getMaxWeightBase() == 9`. Add a second case with a player that does not have the trait and assert `MaxWeightBase` remains at its default (8). The mock player's `getMaxWeightBase`/`setMaxWeightBase` methods are already present in `UTTestMocks.lua` (confirmed by existing tests at lines 510, 515 for `UT_packmule` and `UT_preparedpack`).

## Final Verdict

- Source origin: proven — `CanGrabMore` from MoreSimpleTraits confirmed; registration cost (2), mutual exclusion (`CanGrabLess`), and `OnCreatePlayer` + `setMaxWeightBase(9)` mechanism all faithfully reproduced.
- UT implementation: faithful — the UT Lua is a direct, clean re-implementation of the source runtime: same event hook, same API call, same value. The only structural difference is using `UTCore.hasTrait` (nil-safe) instead of the source's bare `player:HasTrait`. The source's additional mutual exclusions against vanilla `Weak`/`Strong` traits were not carried over.
- Description: **WRONG** — the display name ("Strong Grip") and description ("grab and restrain zombies… Grab success rate is increased") describe a zombie-grapple mechanic that does not exist in the code. The actual effect is +1 base carry weight. This is a critical description bug requiring immediate correction.
- Balance: reasonable — 2 points for a flat +1 carry weight is proportionate. The hard-set implementation is a latent interaction risk if stacked with other carry weight traits that also use absolute assignments.
- Regression proof: minimally protected — smoke-test registration only; no functional test for the `onCreatePlayer` carry weight assignment.
- Action needed: **doc fix (critical)** | test fix — fix display name and description immediately; add `fireCreatePlayer` carry weight assertion test.
- Open gaps:
  - Display name and description are entirely wrong — describe a non-existent zombie grab mechanic instead of the actual carry weight effect. Must be corrected before release.
  - No functional test for `onCreatePlayer` carry weight write.
  - Missing exclusion against vanilla `Weak` trait (present in source). Not documented as intentional.
  - Hard-set `setMaxWeightBase(9)` is order-dependent when stacked with other absolute carry weight setters; behavior when combined with `UT_backpacker` or `UT_packmule` is not tested or documented.
  - Source description claimed strength scaling ("1-2 max weight depending on Strength") but source code is flat (always 9). UT simplified correctly but this discrepancy in the source is worth noting for completeness.
