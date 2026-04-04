# UT_noxpfirstaid

## Trait Summary

- UT trait id: UT_noxpfirstaid
- Source mod: More Traits (ToadTraits)
- Source trait id: ToadTraits:noxpfirstaid
- Current cost: +3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (trait registration, line 228; mutual exclusions, lines 325, 329, 332, 334, 336)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (CharacterTrait registry line 85)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (runtime implementation, line 619)
  - `research/installed-mods/MoreTraits/mods/More Traits/42/media/lua/client/MoreTraits .lua` (B42 client implementation, line 592)
- Source trait registration (MoreTraitsMainCreationMethods.lua, line 228):
  - `TraitFactory.addTrait("noxpfirstaid", getText("UI_trait_noxpfirstaid"), 3, getText("UI_trait_noxpfirstaiddesc"), false, false)`
  - Cost: `3` (positive trait — player pays points)
  - `negative = false`, `profession = false`
- Source registry (registries.lua, line 85):
  - `ToadTraitsRegistries.noxpfirstaid = CharacterTrait.register("ToadTraits:noxpfirstaid")`
- Source mutual exclusions (MoreTraitsMainCreationMethods.lua, lines 325–336):
  - `noxpsneaky` ↔ `noxpfirstaid`
  - `noxptechnician` ↔ `noxpfirstaid`
  - `noxpshooter` ↔ `noxpfirstaid`
  - `noxpaxe` ↔ `noxpfirstaid`
  - `noxpfirstaid` ↔ `noxpmaintenance`
  - (All noxp traits are mutually exclusive with each other in source — player can only hold one.)
- Source runtime (MoreTraits .lua, 42.15, line 619):
  - `if player:hasTrait(ToadTraitsRegistries.noxpfirstaid) then levelPerkByAmount(player, Perks.Doctor, 3) end`
  - On character creation/load, the player's Doctor perk is levelled up by 3 using `levelPerkByAmount`.
  - This is a **starting level boost**, not an XP multiplier or XP disable. The trait grants +3 to Doctor skill at character creation.
- Source B42 client (MoreTraits .lua, 42, line 592):
  - `if player:HasTrait("noxpfirstaid") then` followed by `player:LevelPerk(Perks.Doctor)` / `setXPToLevel` for up to 3 levels — same +3 Doctor levels on character creation.
- Source behavior summary: `noxpfirstaid` in the original More Traits mod grants **+3 levels in Doctor at character creation**. The name "noxpfirstaid" implies the intent is a trade-off: you start with high First Aid skill but can earn no more XP in it. However, the source implementation only does the level boost via `levelPerkByAmount`; the XP-disable half of the trade-off is not separately visible in the files reviewed. The trait costs +3 points (positive trait).

## Current UT Evidence

### Structure

- Registered in registries.lua: **yes** (line 210)
  - `UTTraitsRegistries.UT_noxpfirstaid = CharacterTrait.register("UniversalTraits:UT_noxpfirstaid")`
  - Located in the `-- PHASE 2 -- LUA-DRIVEN: NO-XP SERIES` block alongside `UT_noxpshooter`, `UT_noxptechnician`, `UT_noxpaxe`, `UT_noxpmaintenance`, `UT_noxpsneaky`.
- Defined in UT_character_traits.txt: **yes** (lines 1474–1482)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_noxpfirstaid`
  - `Cost = 3`
  - No `MutuallyExclusiveTraits` field present in the script block — mutual exclusions are not declared at the script level.
- Translation strings present: **yes** (UI_EN.txt lines 452–453)
  - `UI_UT_noxpfirstaid = "No XP: First Aid"`
  - `UI_UT_noxpfirstaidDesc = "You know medicine as well as you ever will. First Aid actions grant no XP."`
- Exclusions/grants: no `MutuallyExclusiveTraits` in the script definition. Source declared mutual exclusion with all five other noxp traits; UT declares none at the script layer. No XPBoosts or stat grants are declared in the script block.
- Runtime Lua file exists: **yes** (`media/lua/shared/UniversalTraits/traits/UT_noxpfirstaid.lua`)
- Release copy present: **yes** (`release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_noxpfirstaid.lua` — identical content)

### Runtime Trace

- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_noxpfirstaid.lua` (full file, 11 lines)
  - `UniversalTraits/media/scripts/UT_character_traits.txt` (lines 1474–1482)
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` (lines 452–453)
  - `UniversalTraits/media/registries.lua` (lines 204–212)
  - `UniversalTraits/test/run_tests.lua` (lines 266–268 — recognised-trait list; line 460 — dofile; lines 969–976 — test block)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` (lines 44–48 — `disableXP` implementation)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16 — `hasTrait` implementation)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua` (lines 19–62 — XP intercept hook)
  - `UniversalTraits/test/UTTestMocks.lua` (line 209 — mock `disableXP`)

- Full trait Lua source (`UT_noxpfirstaid.lua`):
  ```lua
  -- UT_noxpfirstaid.lua
  -- Disables XP gain for Doctor skill

  local TRAIT_ID = "UniversalTraits:UT_noxpfirstaid"

  local function onNewGame(player)
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      UTCore.disableXP(player, "Doctor")
  end

  Events.OnNewGame.Add(onNewGame)
  ```

- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` — fires once at new game start only (not on save load).

- UTCore helpers used:

  1. **`UTCore.hasTrait(player, traitId)`** — defined in `UTCore_API.lua` lines 11–16:
     - Returns `false` if `player` is nil.
     - Calls `player:getTraits()` and returns `traits:contains(traitId)`.
     - Nil-safe; returns `false` if traits list is nil.

  2. **`UTCore.disableXP(player, perkName)`** — defined in `UTCore_StatModifiers.lua` lines 44–48:
     - Writes `player:getModData()["UT_xpDisable_Doctor"] = true`.
     - Single key-value write to persistent mod data. No immediate XP change; the flag is read by the XP hook on every subsequent XP gain event.

  3. **`UTCore_XPHook.lua` — `onAddXP(player, perk, amount)`** — intercepts `Events.AddXP`:
     - Guard: if `player`, `perk`, or `amount` is nil, or `amount <= 0`, returns immediately.
     - Step 1 — XP disable check (lines 24–27): reads `md["UT_xpDisable_" .. perk]`. If truthy, calls `player:getXp():AddXP(perk, -amount, false, false, false)` to cancel the full XP gain, then `return`s. No further processing.
     - Step 2 — XP multiplier (lines 30–44): only reached if the disable check did not fire. Reads `UT_xpMult_All` and `UT_xpMult_<perk>`, compounds them, applies a bonus delta. Not relevant for this trait.
     - Step 3 — Multi-skill penalty (lines 47–57): only reached if the disable check did not fire. Not relevant for this trait.

- Runtime chain (plain language):
  1. At new game start, `OnNewGame` fires and calls `onNewGame(player)`.
  2. `UTCore.hasTrait` checks that the player's trait list contains `"UniversalTraits:UT_noxpfirstaid"`. If not, the function returns immediately with no side effects.
  3. If the trait is present, `UTCore.disableXP(player, "Doctor")` writes `modData["UT_xpDisable_Doctor"] = true` into the player's persistent mod data.
  4. From that point on, every time any source (books, actions, events) would grant the player Doctor XP, `Events.AddXP` fires with `perk = "Doctor"`.
  5. `onAddXP` in `UTCore_XPHook.lua` reads `md["UT_xpDisable_Doctor"]`, finds it `true`, and immediately calls `player:getXp():AddXP("Doctor", -amount, false, false, false)` — subtracting the full XP amount that was just added. Net Doctor XP gain: zero.
  6. The hook returns after the cancel; no multiplier or multi-skill logic runs.

- Actual behavior (exact values):
  - Doctor XP: **100% cancelled** permanently from new game start. Every Doctor XP grant is immediately negated by an equal subtraction.
  - No other skills affected.
  - No stat changes, no mood effects, no starting level boosts.
  - The mod data flag `UT_xpDisable_Doctor = true` persists for the entire save (mod data survives save/load).
  - The `OnNewGame` hook does **not** re-run on save load — but the flag is already in mod data from the initial new game, so the cancel remains active on reloads.

## Description Integrity

- Display name: `"No XP: First Aid"` — accurate. "First Aid" is the player-facing name for the Doctor skill in PZ; this matches common usage.
- Description: `"You know medicine as well as you ever will. First Aid actions grant no XP."` — accurate. The phrasing "grant no XP" correctly describes the full cancel mechanism. The flavour ("you know medicine as well as you ever will") fits the UT redesign where there is no starting level boost.
- Source description (More Traits EN): not directly observed in the files reviewed; expected to describe the +3 Doctor level bonus from character creation.
- Missing or misleading details: none identified. The description does not promise a starting skill level (which UT does not grant), and correctly implies permanent XP lockout. The description is fully consistent with the implementation.

## Balance Review

- Type: positive trait (player pays points to take it).
- Cost: +3 points.
- Upside: none — this is a pure penalty trait. The player pays 3 points and receives only the permanent loss of all Doctor XP gain. The "positive" framing comes from the More Traits convention where noxp traits cost points (implying the player is specialised and does not need XP), but UT grants no compensating starting level.
- Downside: Doctor XP permanently zeroed. Doctor (First Aid) governs bandaging speed, splinting, and wound treatment efficiency — a significant mid-to-late survival skill.
- Uptime: permanent from new game start; no conditions, no expiry.
- Peer comparison within the No-XP series:

  | Trait              | Cost | Skills locked       | Skills count |
  |--------------------|------|---------------------|--------------|
  | UT_noxpshooter     | +3   | Aiming, Reloading   | 2            |
  | UT_noxptechnician  | +3   | Electricity, Mechanics | 2         |
  | UT_noxpaxe         | +2   | Axe                 | 1            |
  | UT_noxpfirstaid    | +3   | Doctor              | 1            |
  | UT_noxpmaintenance | +3   | Maintenance         | 1            |
  | UT_noxpsneaky      | +3   | Sneaking, Lightfoot | 2            |

  - `UT_noxpfirstaid` costs the same as `UT_noxpshooter`, `UT_noxptechnician`, and `UT_noxpsneaky`, but locks only one skill while those lock two. `UT_noxpaxe` locks only one skill (Axe) but costs +2. The Doctor skill is arguably more universally critical than Axe, but the +3 cost for a single-skill lockout is inconsistent with `UT_noxpaxe`'s +2 cost for the same structure.
- Source comparison: the source `noxpfirstaid` granted +3 Doctor levels at character creation as compensation for the XP lockout. UT removes the level grant and keeps only the XP disable. The trait is therefore strictly worse in UT than in source — the player pays the same +3 points but receives no compensating starting skill.
- Cost verdict: **potentially overpriced**. For a single-skill XP lockout with no compensating grant, +3 is harder to justify against `UT_noxpaxe` at +2. Either the cost should be reduced to +2 (matching `UT_noxpaxe`), or a starting Doctor level bonus should be added to justify the extra point. This is a design call, not a bug.

## Regression Proof

- Recognised-trait list: **present** — `"UniversalTraits:UT_noxpfirstaid"` appears at line 268 of `run_tests.lua` in the Phase 2 No-XP Series block.
- `dofile` present: **yes** — `run_tests.lua` line 460:
  - `dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpfirstaid.lua")`
  - The trait file is loaded into the test harness.
- Test block present: **yes** — the shared No-XP integration test at lines 969–976:
  ```lua
  test("single-skill noxp traits block their matching XP through the hook", function()
      local axePlayer = fireNewGame("UniversalTraits:UT_noxpaxe")
      Events.AddXP:fire(axePlayer, "Axe", 10)
      assert_true(xpWasCancelled(axePlayer, "Axe", 10), "expected Axe XP to be cancelled")

      local firstAidPlayer = fireNewGame("UniversalTraits:UT_noxpfirstaid")
      Events.AddXP:fire(firstAidPlayer, "Doctor", 10)
      assert_true(xpWasCancelled(firstAidPlayer, "Doctor", 10), "expected Doctor XP to be cancelled")
  ```
  - `fireNewGame("UniversalTraits:UT_noxpfirstaid")` creates a mock player with the trait, fires `OnNewGame`, and returns the player.
  - `Events.AddXP:fire(firstAidPlayer, "Doctor", 10)` triggers the XP hook.
  - `assert_true(xpWasCancelled(firstAidPlayer, "Doctor", 10), ...)` asserts the Doctor XP gain was fully cancelled.
  - Mock `UTCore.disableXP` (UTTestMocks.lua line 209): `function(player, perk) player:getModData()["UT_xpDisable_" .. perk] = true end` — matches the real implementation exactly.
- What is proven:
  1. The trait file loads without syntax error.
  2. `OnNewGame` fires and `UTCore.disableXP(player, "Doctor")` is called, writing `UT_xpDisable_Doctor = true` to mod data.
  3. The XP hook reads the flag and cancels a Doctor XP gain of 10 in full.
  4. `xpWasCancelled` assertion passes — the cancel mechanism is end-to-end verified.
- What is not proven:
  1. Behaviour on save load (the `OnNewGame` handler does not re-fire; the flag persists in mod data, but this is not explicitly tested).
  2. That non-Doctor XP (e.g., Axe) is unaffected when only `UT_noxpfirstaid` is held — no negative-case assertion is present.
  3. Interaction with other traits that may also write to `UT_xpDisable_Doctor` (none identified, but not tested).
- Overall regression proof status: **good**. This trait has the strongest test coverage in the No-XP series — the `dofile` is present and a named assertion in the integration test block verifies the full cancel path end-to-end.

## Final Verdict

- Source origin: **proven** — `ToadTraits:noxpfirstaid` from More Traits confirmed. Registration via `TraitFactory.addTrait` at cost 3, registry via `CharacterTrait.register("ToadTraits:noxpfirstaid")`, mutual exclusions with all five other noxp traits, and runtime implementation (levelPerkByAmount Doctor +3) all traced in More Traits 42.15.
- UT implementation: **redesign with omission** — the source trait granted +3 Doctor levels at character creation as compensation for the XP lockout. UT keeps only the XP disable (`UTCore.disableXP(player, "Doctor")` → `UT_xpDisable_Doctor = true` in mod data → full cancel via `UTCore_XPHook`). The starting level grant is absent. The mutual exclusions with peer noxp traits are not declared in the script definition (no `MutuallyExclusiveTraits` field).
- Description: **accurate** — `"You know medicine as well as you ever will. First Aid actions grant no XP."` correctly describes the UT implementation. No false claims; no missing effects.
- Balance: **potentially overpriced** — +3 cost for a single-skill XP lockout with no compensating level grant. Peer `UT_noxpaxe` costs +2 for the same structure. Either reduce cost to +2 or restore a Doctor level bonus. Design call, not a bug.
- Regression proof: **good** — `dofile` is present and the integration test at `run_tests.lua` lines 974–976 exercises the full `OnNewGame → disableXP → AddXP hook → cancel` chain with an explicit assertion. Best-covered trait in its series.
- Action needed: **design review only** — no code or description bugs. Open items are design questions.
- Open gaps:
  1. No starting Doctor level bonus in UT (source granted +3). Whether this is intentional is not documented. If intentional, a comment in the Lua file or a design note would prevent future confusion.
  2. No mutual exclusions declared in `UT_character_traits.txt`. Source excluded all five peer noxp traits from each other. UT has no such exclusion at the script layer. Whether the engine enforces any exclusion via another mechanism is not verified in this audit.
  3. Cost parity gap vs. `UT_noxpaxe` (+2 for one skill vs. +3 here for one skill). No documentation of why Doctor commands a higher price than Axe.
  4. No test for the save-load path (flag already in mod data; `OnNewGame` does not re-fire — this is correct behaviour but untested).
  5. No negative-case test asserting that non-Doctor XP is unaffected when only this trait is active.
