# UT_noxptechnician

## Trait Summary

- UT trait id: UT_noxptechnician
- Source mod: MoreTraits (hypnotoadtrance/MoreTraits)
- Source trait id: ToadTraits:noxptechnician
- Current cost: 3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (trait registration, cost, mutual exclusions)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` (runtime — new game level grants)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/registries.lua` (CharacterTrait.register)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (cross-version verification — identical)
  - `research/installed-mods/MoreTraits/mods/More Traits/42/media/lua/client/MoreTraits .lua` (B42 client — same pattern, `player:HasTrait("noxptechnician")`)
- Source trigger path:
  - `TraitFactory.addTrait("noxptechnician", ..., 3, ..., false, false)` — registered as cost +3 (positive = disadvantage points returned to pool), not a profession trait, not free.
  - On new game the source checks `player:hasTrait(ToadTraitsRegistries.noxptechnician)` and then calls `levelPerkByAmount(player, Perks.Mechanics, 1)` and `levelPerkByAmount(player, Perks.Electricity, 2)`.
  - No XP multiplier is written; the source **grants free starting levels** (Mechanics +1, Electricity +2) as the trade-off mechanic for taking the trait.
  - Mutual exclusions in source (42.13): noxptechnician ↔ noxpsneaky, noxpshooter, noxpaxe, noxpfirstaid, noxpmaintenance (all cross-noxp exclusions; only one may be taken).
- Source behavior: Taking the trait gives +1 to Mechanics and +2 to Electricity at character creation in exchange for some cost. The description implies the character cannot gain further XP in those skills; however, the source runtime only grants starting levels — it does not hook XP gain to block it. The XP block is a design intent carried in the name and description, not implemented in the source code reviewed.
- Source EN description: not verified from source txt — taken from MoreTraits UI_EN (not indexed); inferred from trait name and behavior pattern common to the noxp series.

## Current UT Evidence

### Structure

- Registered in registries.lua: **yes** — line 208, under `-- PHASE 2 -- LUA-DRIVEN: NO-XP SERIES`
  ```
  UTTraitsRegistries.UT_noxptechnician = CharacterTrait.register("UniversalTraits:UT_noxptechnician")
  ```
- Defined in UT_character_traits.txt: **yes** (lines 1454–1462)
  ```
  character_trait_definition UniversalTraits:UT_noxptechnician
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_noxptechnician,
      Cost = 3,
      UIName = UI_UT_noxptechnician,
      UIDescription = UI_UT_noxptechnicianDesc,
  }
  ```
- Translation strings present: **yes**
  - `UI_UT_noxptechnician = "No XP: Tech"`
  - `UI_UT_noxptechnicianDesc = "Electrical work holds no more lessons for you. Electrical and Mechanics grant no XP."`
- Exclusions/grants in UT_character_traits.txt: **none defined** — no `MutualExclusive` or `FreePoint` lines in the UT script block. The source had cross-noxp mutual exclusions; UT does not replicate them at the script level.
- Runtime Lua file exists: **yes** — `media/lua/shared/UniversalTraits/traits/UT_noxptechnician.lua`
- DisabledInMultiplayer: **true** — consistent with the rest of the No-XP series in UT.

### Runtime Trace

- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_noxptechnician.lua` (full, 13 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (UTCore.hasTrait)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` (UTCore.disableXP)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua` (Events.AddXP handler)
  - `UniversalTraits/media/scripts/UT_character_traits.txt` (lines 1454–1462)
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` (lines 446–447)
  - `UniversalTraits/test/run_tests.lua` (lines 267, 458, 961–966)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` — fires once at new game start
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe presence check via `player:getTraits():contains(traitId)`
  - `UTCore.disableXP(player, "Electricity")` — writes `player:getModData()["UT_xpDisable_Electricity"] = true`
  - `UTCore.disableXP(player, "Mechanics")` — writes `player:getModData()["UT_xpDisable_Mechanics"] = true`
- Runtime chain (plain language):
  1. `Events.OnNewGame` fires once when a new game begins.
  2. `onNewGame(player)` checks `UTCore.hasTrait(player, "UniversalTraits:UT_noxptechnician")`. If the player does not have the trait, the function returns immediately with no side effects.
  3. If the trait is present, `UTCore.disableXP(player, "Electricity")` is called, writing `UT_xpDisable_Electricity = true` into the player's mod data.
  4. Immediately after, `UTCore.disableXP(player, "Mechanics")` is called, writing `UT_xpDisable_Mechanics = true` into the player's mod data.
  5. At runtime, whenever `Events.AddXP` fires for this player, the `onAddXP` handler in `UTCore_XPHook.lua` checks `md["UT_xpDisable_" .. perk]`. If the flag is `true` for the awarded perk, the hook calls `player:getXp():AddXP(perk, -amount, false, false, false)` to negate the full XP gain and returns immediately. No multiplier or multi-skill penalty logic is reached.
- Actual behavior (exact values):
  - Electricity XP: 100% cancelled on every `Events.AddXP` call for perk `"Electricity"` — effective gain = 0.
  - Mechanics XP: 100% cancelled on every `Events.AddXP` call for perk `"Mechanics"` — effective gain = 0.
  - Cancellation is permanent for the life of the save (mod data persists); it is set once on new game and never unset by this trait.
  - No starting level grants are given (contrast with source MoreTraits which granted Mechanics +1 and Electricity +2 as compensation).
  - No XP multipliers are applied; the disable flag takes priority over multipliers in the hook (Step 1 in `onAddXP`, which returns before multiplier logic at Step 2).
  - No interaction with `UT_multiSkillPenalty` (Step 3 in hook) — cancellation exits the hook before that block is reached.

## Description Integrity

- Display name check: `"No XP: Tech"` — concise, accurate, consistent with the No-XP series naming convention.
- Description check: `"Electrical work holds no more lessons for you. Electrical and Mechanics grant no XP."` — correctly identifies both blocked skills (Electricity and Mechanics). Framing is flavour-first then mechanical. Accurate.
- Missing or misleading details:
  - The description says "Electrical and Mechanics grant no XP" — both skill names are used but the perk string used in the XP hook is `"Electricity"` (not "Electrical"). This is not a description bug (the display name "Electrical" is the player-facing label for the Electricity perk); it is consistent with PZ's naming pattern.
  - The description does not mention that there are no compensating starting level grants (unlike the source MoreTraits version which granted free levels). This omission is not misleading — UT does not grant levels, so mentioning it would be correct, but not stating it does not create a false impression.
  - No mention of `DisabledInMultiplayer = true`. This is normal for UT traits — not a description gap.
  - No mention of cost in the description. Cost is communicated by the trait selection screen, not the description text. Normal.

## Balance Review

- Upside: none — pure negative trait. Returns 3 points to the character creation pool.
- Downside: Electricity and Mechanics XP are permanently disabled. The character cannot level either skill through gameplay at all.
- Uptime: permanent — set once at new game start via mod data; persists for the entire save.
- No-XP series peer comparison (all confirmed from UT_character_traits.txt and Lua files):

  | Trait              | Cost | Skills blocked                    | Skills count |
  |--------------------|------|-----------------------------------|--------------|
  | UT_noxpshooter     | 4    | Aiming, Reloading                 | 2            |
  | UT_noxptechnician  | 3    | Electricity, Mechanics            | 2            |
  | UT_noxpsneaky      | 3    | Sneaking, Lightfoot               | 2            |
  | UT_noxpaxe         | 2    | Axe                               | 1            |
  | UT_noxpfirstaid    | 2    | Doctor (First Aid)                | 1            |
  | UT_noxpmaintenance | 2    | Maintenance                       | 1            |

- Relative value assessment:
  - Electricity and Mechanics are both moderately valuable skills. Electricity governs generator use, electrical repair, and late-game crafting. Mechanics governs vehicle maintenance and repair — highly relevant in long runs. Blocking both permanently for +3 points is a meaningful penalty.
  - Compared to `UT_noxpshooter` (two combat skills, +4): combat skills (Aiming, Reloading) are also critical in the long run, arguably higher-stakes than Mechanics/Electricity in the early game. The +1 cost premium for blocking combat skills seems reasonable.
  - Compared to `UT_noxpsneaky` (Sneaking + Lightfoot, also +3): Sneaking and Lightfoot together are arguably less universally relied upon than Mechanics + Electricity for a broad set of playstyles. `UT_noxptechnician` at the same cost appears more punishing for non-stealth-focused builds.
  - Source MoreTraits gave Mechanics +1 and Electricity +2 as compensating grants with the trait. UT removes that compensation entirely and gives only 3 raw points. This is a meaningful design departure: the character gets no headstart and permanently cannot improve those skills.
- Cost verdict: plausible — +3 for two permanently disabled crafting/maintenance skills is defensible. Slightly arguable that +3 is light compared to noxpshooter's +4, since Mechanics and Electricity together cover vehicle upkeep and generator use, which become critical in mid-to-late survival. No urgent change needed, but reviewers should note that UT removed MoreTraits' compensating level grants while keeping the source cost.

## Regression Proof

- Test file: `UniversalTraits/test/run_tests.lua`
- Trait appears in all-traits registry list (line 267): **yes** — included in the Phase 2 No-XP Series block.
- Lua file loaded in test harness (line 458): **yes** — `dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxptechnician.lua")` is called after `UTCore_XPHook.lua` is loaded, correct ordering.
- Dedicated test (lines 961–966):
  ```lua
  test("noxptechnician blocks Electricity and Mechanics XP through the XP hook", function()
      local player = fireNewGame("UniversalTraits:UT_noxptechnician")
      Events.AddXP:fire(player, "Electricity", 10)
      Events.AddXP:fire(player, "Mechanics", 10)
      assert_true(xpWasCancelled(player, "Electricity", 10), "expected Electricity XP to be cancelled")
      assert_true(xpWasCancelled(player, "Mechanics", 10), "expected Mechanics XP to be cancelled")
  end)
  ```
- How `xpWasCancelled` works (lines 435–441): iterates the mock XP log for a call where `call.perk == perk and call.amount == -(amount)`. A cancel is confirmed by the presence of an `AddXP(..., -10, ...)` negation call in the log. This correctly mirrors the XP hook's cancellation mechanic (`AddXP(perk, -amount, ...)`).
- What the test proves:
  1. `onNewGame` executes for the player when the trait is present.
  2. `UTCore.disableXP` writes the mod data flags correctly.
  3. The `onAddXP` hook reads those flags and issues the negation call for both Electricity and Mechanics.
  4. The full chain from new game through XP hook to cancellation is verified end-to-end for both skills.
- Coverage completeness: **strong** — both skills are independently asserted. The test does not merely check that one of the two was cancelled.
- Missing proof:
  1. No test verifies that the mod data keys are written with the correct values (`UT_xpDisable_Electricity = true`, `UT_xpDisable_Mechanics = true`). If `disableXP` were changed to write a different key name, the hook would silently stop working but the existing test would also fail — so this gap is implicitly covered by the end-to-end test. No separate unit test is strictly necessary.
  2. No test verifies that XP for **other** perks (e.g., Aiming) is **not** cancelled when only `UT_noxptechnician` is active. This negative-space check would guard against a regression where the disable flag is written for all perks or the wrong perk name.
  3. No test verifies behavior when the trait is **absent** (the early-return guard in `onNewGame`). If the guard were removed, no test would catch the false positive.
- Minimum next tests if needed:
  1. Assert a third perk (e.g., `"Aiming"`) is **not** cancelled when only `UT_noxptechnician` is active — verifies the XP block is scoped to Electricity and Mechanics only.
  2. Assert that without the trait, `UT_xpDisable_Electricity` and `UT_xpDisable_Mechanics` are **not** set — verifies the early-return guard.

## Final Verdict

- Source origin: **proven** — `ToadTraits:noxptechnician` from MoreTraits (hypnotoadtrance) confirmed across 42, 42.13, and 42.15 versions. Source cost: +3. Source behavior: grants Mechanics +1 and Electricity +2 as starting level compensation; does not implement an XP block hook.
- UT implementation: **redesigned** — the source gave free starting levels as trade-off compensation. UT removes the starting-level grants entirely and instead permanently disables XP gain for both skills via mod data flags enforced by `UTCore_XPHook`. The trait name and blocked skills are preserved; the mechanical expression is different and more punishing (no compensation).
- Description: **accurate** — `"Electrical work holds no more lessons for you. Electrical and Mechanics grant no XP."` correctly describes the UT runtime effect. No values are stated incorrectly. No skills are omitted.
- Balance: **plausible** — +3 points for two permanently disabled crafting/utility skills is reasonable. The removal of the source's compensating level grants (Mechanics +1, Electricity +2) makes UT's version strictly worse than the source at the same cost, which is a deliberate design choice that should be documented.
- Regression proof: **strong** — the dedicated test covers both skills end-to-end through the full event chain. Minor gaps exist for negative-space and absent-trait coverage but the critical path is well-tested.
- Action needed: **none urgent** — implementation is correct, description is accurate, test coverage is solid.
- Open gaps:
  1. No negative-space test verifies that an unrelated perk (e.g., Aiming) is not accidentally cancelled when only `UT_noxptechnician` is active.
  2. No absent-trait guard test verifies that mod data flags are not written when the player lacks the trait.
  3. The UT version removes MoreTraits' compensating starting-level grants (Mechanics +1, Electricity +2) without documentation in any trait file. This design departure is internally consistent but undocumented.
  4. `DisabledInMultiplayer = true` is set; no test exercises the multiplayer-disabled path. This is consistent with the rest of the No-XP series and is not a unique gap.
