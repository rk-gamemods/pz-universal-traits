# UT_noxpmaintenance

## Trait Summary
- UT trait id: UT_noxpmaintenance
- Source mod: MoreTraits (ToadTraits)
- Source trait id: noxpmaintenance (TraitFactory, no namespace prefix; B42 registry key `ToadTraits:noxpmaintenance`)
- Current cost: 3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (trait registration, line 229; mutual exclusions, lines 326, 330, 333, 335, 336)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (B42 registry, line 86)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (runtime implementation, lines 628–630)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (source EN strings, lines 202–203)
  - Identical content confirmed across 42, 42.13, and 42.15 subfolder versions.
- Source registration:
  - `TraitFactory.addTrait("noxpmaintenance", getText("UI_trait_noxpmaintenance"), 3, getText("UI_trait_noxpmaintenancedesc"), false, false)`
  - `TraitFactory.setMutualExclusive("noxpsneaky",    "noxpmaintenance")`
  - `TraitFactory.setMutualExclusive("noxptechnician","noxpmaintenance")`
  - `TraitFactory.setMutualExclusive("noxpshooter",   "noxpmaintenance")`
  - `TraitFactory.setMutualExclusive("noxpaxe",       "noxpmaintenance")`
  - `TraitFactory.setMutualExclusive("noxpfirstaid",  "noxpmaintenance")`
  - B42 registry: `ToadTraitsRegistries.noxpmaintenance = CharacterTrait.register("ToadTraits:noxpmaintenance")`
- Source display name: "Student: Maintenance"
- Source description: "You took maintenance lessons to make your tools last longer.<br>+2 Maintenance<br>You do not gain XP multiplier by this trait.<br>The bonus Maintenance level does not show in character creation menu."
- Source trigger path: The runtime function containing the noxpmaintenance block is called at character creation (new-game hook). It calls `player:hasTrait(ToadTraitsRegistries.noxpmaintenance)` and, if true, calls `levelPerkByAmount(player, Perks.Maintenance, 2)`.
- Source behavior:
  - `levelPerkByAmount(player, perk, amount)` computes `currentLevel = player:getPerkLevel(perk)`, `targetLevel = math.min(10, currentLevel + amount)`, then loops `for i = currentLevel+1, targetLevel do player:LevelPerk(perk); player:getXp():setXPToLevel(perk, i) end`.
  - Net effect: grants +2 Maintenance skill levels at character creation by directly calling `LevelPerk` and setting XP to match, bypassing the XP gain system entirely.
  - The "no XP multiplier" clause in the description refers to the fact that the levels are hardcoded level-ups, not XP awards subject to multipliers.
  - The trait does **not** disable ongoing Maintenance XP gain. It is purely a spawn-time skill bonus.
  - The "does not show in character creation menu" note refers to the fact that `TraitFactory.addTrait` grants the bonus outside the character sheet's XP preview; the levels appear after game start, not in the creation UI.
  - Source multiplayer flag: `false` (the fifth argument to `addTrait`); the trait was allowed in multiplayer in the source.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_noxpmaintenance = CharacterTrait.register("UniversalTraits:UT_noxpmaintenance")` at `media/registries.lua` line 211, within the No-XP Series block (phase 2).
- Defined in UT_character_traits.txt: yes — `media/scripts/UT_character_traits.txt` lines 1484–1492:
  ```
  character_trait_definition UniversalTraits:UT_noxpmaintenance
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_noxpmaintenance,
      Cost = 3,
      UIName = UI_UT_noxpmaintenance,
      UIDescription = UI_UT_noxpmaintenanceDesc,
  }
  ```
  No `MutuallyExclusiveTraits` field is present in the script block.
- Translation strings present: yes — `media/lua/shared/Translate/EN/UI_EN.txt` lines 455–456:
  - `UI_UT_noxpmaintenance    = "No XP: Maintenance"`
  - `UI_UT_noxpmaintenanceDesc = "Tool upkeep is routine. Maintenance grants no XP."`
- Exclusions/grants correct: no exclusions defined in `UT_character_traits.txt`. The source used `TraitFactory.setMutualExclusive` to make all five noxp-sibling traits mutually exclusive with each other. UT defines no mutual exclusions for this trait in the script file. (See balance notes.)
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_noxpmaintenance.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_noxpmaintenance.lua` (full, 11 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` (lines 45–48: `UTCore.disableXP`)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua` (full, 62 lines: `onAddXP` handler)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16: `UTCore.hasTrait`)
  - `media/scripts/UT_character_traits.txt` (lines 1484–1492)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 455–456)
  - `test/run_tests.lua` (line 263: trait in expected_ids list; line 461: dofile of trait at test load time)

- Event registrations: `Events.OnNewGame.Add(onNewGame)` — one registration, no other events.

- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper; calls `player:getTraits():contains(traitId)` and returns false if player or traits is nil.
  - `UTCore.disableXP(player, "Maintenance")` — writes `player:getModData()["UT_xpDisable_Maintenance"] = true`.

- Runtime chain (plain language):
  1. On new game start, `Events.OnNewGame` fires and calls `onNewGame(player)`.
  2. `UTCore.hasTrait(player, "UniversalTraits:UT_noxpmaintenance")` is called. If false, the function returns immediately with no side effects.
  3. If true, `UTCore.disableXP(player, "Maintenance")` is called, writing `player:getModData()["UT_xpDisable_Maintenance"] = true` into the player's persistent mod data.
  4. On every subsequent XP gain event (`Events.AddXP`), `UTCore_XPHook.lua`'s `onAddXP(player, perk, amount)` fires.
  5. At step 1 of `onAddXP`: if `md["UT_xpDisable_" .. perk]` is truthy, the handler calls `player:getXp():AddXP(perk, -amount, false, false, false)` to cancel the XP gain, then returns. No multiplier or penalty logic runs after this.
  6. The cancellation is a same-tick negative XP award equal to `-amount`, not a prevention of the initial add; the net effect on the XP counter is zero for any Maintenance XP event.

- Actual behavior (exact values):
  - One-shot write at new-game start: `UT_xpDisable_Maintenance = true` in mod data.
  - Every `AddXP` event for `Maintenance` perk is cancelled by a `-amount` counter-award.
  - No starting skill bonus is granted. Starting Maintenance level is unchanged.
  - The XP disable persists across save/reload because it is stored in mod data (which PZ serialises to the save file).
  - The `EveryOneMinute` XP-tracking reset (`UTCore._xpPerksThisMinute`) does not affect XP disabling; disabling is unconditional and does not interact with the per-minute tracking table.
  - Guard: `onAddXP` skips processing if `amount <= 0`, so the `-amount` counter-award itself does not trigger a recursive disable loop.

## Description Integrity
- Display name check: Source = "Student: Maintenance"; UT = "No XP: Maintenance". The name pivot is intentional and consistent with the naming convention of the entire No-XP Series in UT. No issue with the UT name on its own terms, but it is a rename, not a carry-over.
- Description check: Source = "+2 Maintenance, no XP multiplier from trait, bonus not shown at creation." UT = "Tool upkeep is routine. Maintenance grants no XP."
- Accuracy: The UT description accurately describes the UT implementation. The phrase "Maintenance grants no XP" correctly reflects the `UT_xpDisable_Maintenance = true` flag and the `onAddXP` cancellation.
- Missing or misleading details:
  - The UT description does not disclose that no starting Maintenance bonus is granted. The source granted +2 Maintenance skill levels at spawn; UT grants zero. A player familiar with the source mod would expect a skill bonus — the UT version delivers only XP suppression with no skill head-start.
  - The description does not explain that XP is cancelled post-award (not pre-empted), which is a mechanical detail that could affect frame-level XP displays momentarily.
  - The description does not warn that this flag is written once at new-game start. Characters loaded from saves after a mod reload will retain the flag in mod data without re-triggering `OnNewGame`, which is actually the correct behavior (flag persists) but is worth noting.

## Balance Review
- Upside (UT): none — the trait disables Maintenance XP gain with no compensating skill bonus. The player permanently cannot level Maintenance through normal play.
- Downside: permanent inability to level Maintenance, which governs weapon durability decay rate. Maintenance is a cross-cutting skill affecting all melee and some ranged weapons.
- Uptime: 100% (XP disable is persistent from new-game start and cannot be reversed mid-game).
- Cost: 3 points (positive) — the player gains 3 character creation points by taking this trait.
- Source comparison:
  - Source granted +2 Maintenance at spawn in exchange for no XP gain from the trait itself. The "no XP from this trait" clause in the source referred only to the spawn-bonus not granting XP in the traditional sense — it did **not** permanently suppress all future Maintenance XP. The player could still earn Maintenance XP through normal gameplay in the source.
  - UT is a complete behavioral inversion: no spawn bonus, and all future Maintenance XP is permanently cancelled. This transforms a "free skill points, trade-off is none" trait into a "permanent skill cap" trait.
- Peer comparison (No-XP Series cost structure):
  - `UT_noxpshooter` (Aiming + Reloading disabled): Cost not independently audited here, but the series costs 3 each based on the txt file block pattern.
  - `UT_noxpsneaky` (Sneaking + Lightfoot disabled): 5 points per `UT_character_traits.txt` (two skills).
  - `UT_noxpmaintenance` (Maintenance only): 3 points for one skill.
  - Maintenance is a high-value cross-cutting skill (affects all weapon durability). Disabling it entirely for +3 points is a significant permanent penalty. Comparably impactful skills in peer UT traits (e.g. Aiming) are also set at 3, so the cost is consistent within the series.
- Multiplayer: `DisabledInMultiplayer = true` in UT. Source had `false` (fifth argument to `addTrait`). This is a divergence — the source allowed the trait in multiplayer.
- Mutual exclusions: Source enforced all five No-XP siblings as mutually exclusive with each other. UT defines no exclusions in the script file for this trait. A player could theoretically take multiple No-XP traits simultaneously if UT relies solely on the script file for enforcement (since `TraitFactory.setMutualExclusive` is not called in UT). This needs verification — other UT No-XP traits should be checked to confirm whether the exclusions are absent across the entire series or only here.
- Stack or exclusion notes: No exclusion from any non-sibling trait. No stated interaction with Maintenance-boosting profession traits (e.g. Engineer). If a player has a profession that grants starting Maintenance levels, those levels remain; only future XP gain is blocked.
- Cost verdict: internally consistent with the No-XP Series pricing, but the behavioral divergence from the source (no spawn bonus, full XP cap instead of spawn-bonus-with-XP-still-allowed) means the cost logic is being applied to a fundamentally different mechanic than what the source defined.

## Regression Proof
- Existing tests:
  - `test/run_tests.lua` line 263: `"UniversalTraits:UT_noxpmaintenance"` appears in the `expected_ids` table used by the all-traits registration count test. Proves the trait ID is enumerable and registered.
  - `test/run_tests.lua` line 461: `dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpmaintenance.lua")` — the trait file is loaded at test startup, which registers its `Events.OnNewGame.Add(onNewGame)` handler into the mock event system.
  - `test/UTTestMocks.lua` line 209: `UTCore.disableXP = function(player, perk) player:getModData()["UT_xpDisable_" .. perk] = true end` — the mock correctly mirrors the real implementation.
- What the tests prove: The trait file loads without error and its ID is present in the registry enumeration. Nothing more.
- Missing proof:
  - No test calls `fireNewGame("UniversalTraits:UT_noxpmaintenance")` and asserts `player:getModData()["UT_xpDisable_Maintenance"] == true`.
  - No test calls `fireNewGame` with a player lacking the trait and asserts `UT_xpDisable_Maintenance` is nil.
  - No test exercises `UTCore_XPHook.onAddXP` with a player carrying `UT_xpDisable_Maintenance = true` and verifies that a Maintenance XP event is cancelled (i.e., that `player:getXp():AddXP(Perks.Maintenance, -10, ...)` is logged).
  - No test verifies that a player without the trait receives Maintenance XP normally through the hook.
  - No test verifies that the mutual exclusions (source-defined) are absent or present in UT script.
  - `xpWasCancelled(player, perk, amount)` helper exists in `run_tests.lua` (line 435–442) and checks `player:getXp()._log` for a matching negative entry — this is exactly the helper needed for a cancellation test, but it is not wired to any `UT_noxpmaintenance` test case.
- Minimum next test if needed:
  ```lua
  test("UT_noxpmaintenance sets UT_xpDisable_Maintenance", function()
      local p = fireNewGame("UniversalTraits:UT_noxpmaintenance")
      assert_eq(p:getModData()["UT_xpDisable_Maintenance"], true, "expected xp disable flag")
  end)

  test("UT_noxpmaintenance cancels Maintenance XP via hook", function()
      local p = fireNewGame("UniversalTraits:UT_noxpmaintenance")
      Events.AddXP:fire(p, Perks.Maintenance, 10)
      assert_true(xpWasCancelled(p, Perks.Maintenance, 10), "expected Maintenance XP cancelled")
  end)
  ```

## Final Verdict
- Source origin: proven — MoreTraits "noxpmaintenance" confirmed via `TraitFactory.addTrait("noxpmaintenance", ...)` in `MoreTraitsMainCreationMethods.lua` (all three version subfolders), `ToadTraitsRegistries.noxpmaintenance = CharacterTrait.register("ToadTraits:noxpmaintenance")` in `registries.lua`, and the `levelPerkByAmount(player, Perks.Maintenance, 2)` runtime call in `MoreTraits .lua`
- UT implementation: substantially diverges from source — the source granted +2 Maintenance skill levels at spawn via `levelPerkByAmount` and did not suppress future XP gain; UT grants no spawn bonus and instead permanently disables all Maintenance XP gain via `UT_xpDisable_Maintenance = true` and `UTCore_XPHook.onAddXP` cancellation; this is a trade-off inversion (source: free skill, no cost; UT: permanent skill cap, +3 points)
- Description: accurate for the UT implementation — "Tool upkeep is routine. Maintenance grants no XP." correctly reflects the XP disable; however, it does not disclose the absence of a spawn bonus (which source players would expect) or the mechanism (post-award cancellation)
- Balance: internally consistent with No-XP Series pricing (3 points), but the mechanic being priced is not equivalent to the source — the source was a spawn-bonus trait with no ongoing XP effect; UT is a permanent XP cap; whether 3 points is appropriate for a permanent Maintenance cap (vs. a skill bonus) is a design question, not a defect
- Regression proof: minimal — registration proven; runtime XP disable behavior is unproven by any test; `xpWasCancelled` helper already exists and is unused for this trait
- Action needed: add behavioral tests; decide whether the mutual exclusion absence is intentional
- Open gaps:
  - No behavioral test for `onNewGame` setting `UT_xpDisable_Maintenance`
  - No XP-hook cancellation test (helper `xpWasCancelled` is already available in `run_tests.lua`)
  - Mutual exclusions absent from `UT_character_traits.txt` — source enforced all five No-XP siblings as mutually exclusive; UT has no exclusion block; confirm whether this is intentional (allowing stacking all No-XP traits) or an omission consistent across the full series
  - `DisabledInMultiplayer = true` in UT vs. `false` in source — confirm this is a deliberate UT policy decision
  - Source spawn bonus (+2 Maintenance) is silently dropped; if this is intentional, a design note recording the decision would prevent re-introduction confusion
  - Confirm whether `OnLoadedPlayer` needs to re-apply `UT_xpDisable_Maintenance` — current implementation relies on mod data persistence (correct for existing saves) but new characters added to an existing save mid-run would not fire `OnNewGame` and would lack the flag
