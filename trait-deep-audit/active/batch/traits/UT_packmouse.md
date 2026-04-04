# UT_packmouse

## Trait Summary
- UT trait id: `UniversalTraits:UT_packmouse`
- Source mod: MoreTraits
- Source trait id: `packmouse`
- Current cost: -7
- Scripted: yes (runtime Lua)
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` line 242 — `TraitFactory.addTrait("packmouse", getText("UI_trait_packmouse"), -7, getText("UI_trait_packmousedesc"), false, false)` — original cost **-7**, non-profession trait
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` line 385 — `TraitFactory.setMutualExclusive("packmule", "packmouse")` — exclusive with `packmule` only (one-directional declaration; engine makes it bidirectional)
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` line 2990–2991 — `elseif player:hasTrait(ToadTraitsRegistries.packmouse) then targetWeight = SandboxVars.MoreTraits.WeightPackMouse or 6` — sets the player's base carry weight to a sandbox-configurable value (default **6**) when the trait is active
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` line 803 — `if player:hasTrait(ToadTraitsRegistries.packmouse) then basechance = basechance + 1` — a secondary secondary side-effect: raises some chance value by 1 when the player has the trait (context: internal chance calculation, not a carry-weight mechanic)
  - `MoreTraits/mods/More Traits/42/media/lua/client/ETWTraitsLogic.lua` (ETW compatibility file) lines 60–61 — `player:HasTrait("packmouse")` used in ETW's carry weight override; sets `maxWeightBase = SandboxVars.MoreTraits.WeightPackMouse` when active
  - `MoreTraits/mods/More Traits - Dynamic/42/media/lua/client/MoreTraits - Dynamic.lua` lines 94–96 — Dynamic variant: if `PackMouseDynamic == true` and player has `packmouse` and `Strength >= PackMouseDynamicSkill`, removes the `packmouse` trait and shows a halo notification (`UI_trait_packmouse`)
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` lines 133–134 — source EN strings: `UI_trait_packmouse = "Pack Mouse"` / `UI_trait_packmousedesc = "You always travel light.<br>Reduced maximum carrying capacity."`
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/Translate/EN/Sandbox_EN.txt` lines 21–22 — `Sandbox_MoreTraits_WeightPackMouse = "Weight: Pack Mouse"` / tooltip confirming default carry weight is sandbox-configurable
- Source trigger path:
  - The carry weight override runs inside MoreTraits' periodic weight recalculation function; it overrides `targetWeight` for the player to `SandboxVars.MoreTraits.WeightPackMouse or 6`. The default game carry weight base is 8. At sandbox default the trait reduces carry weight base from 8 → **6** (a delta of **-2**).
- Source behavior:
  - Reduces the player's base carry weight to the sandbox-configured `WeightPackMouse` value (default 6), which equates to a **-2 reduction** from the default base of 8.
  - Cost: **-7** (negative trait).
  - Mutual exclusion: `packmule` only (source).
  - Dynamic variant (MoreTraits-Dynamic): if the sandbox option is enabled, the trait auto-removes itself when the player's Strength reaches `PackMouseDynamicSkill` threshold (configurable), replacing it with `packmule`. UT does not replicate this dynamic removal mechanic.

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_packmouse = CharacterTrait.register("UniversalTraits:UT_packmouse")` at line 121, listed under the `-- PHASE 1 -- STAT MODIFIERS (SIMPLE, NO RUNTIME LUA)` comment block, directly after `UT_packmule`
  - Note: the registry comment labels this as a "simple, no runtime Lua" stat modifier, but the trait **does** have a runtime Lua file. This is a labelling inconsistency (the comment is describing the group header, not every trait in it; but UT_packmouse is the first trait after the header that actually has runtime Lua — see Runtime Trace below).
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_packmouse` at lines 908–917:
  ```
  character_trait_definition UniversalTraits:UT_packmouse
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_packmouse,
      Cost = -7,
      UIName = UI_UT_packmouse,
      UIDescription = UI_UT_packmouseDesc,
      MutuallyExclusiveTraits = UniversalTraits:UT_packmule;UniversalTraits:UT_squirrel;UniversalTraits:UT_backpacker,
  }
  ```
  No `XPBoosts`, no `GrantedTraits`.
- Translation strings present: yes — `UI_EN.txt` lines 266–267:
  - `UI_UT_packmouse = "Pack Mouse"`
  - `UI_UT_packmouseDesc = "You struggle to carry as much as most people. -2 base carry weight."`
- Exclusions/grants correct:
  - UT `MutuallyExclusiveTraits` = `UT_packmule`, `UT_squirrel`, `UT_backpacker`.
  - Source only declared `packmouse` ↔ `packmule`. The UT additions of `UT_squirrel` and `UT_backpacker` are UT-original design decisions (both are carry-weight-modifying traits, making the exclusions sensible).
  - Cross-check: `UT_packmule` script block (line 905) lists `MutuallyExclusiveTraits = UniversalTraits:UT_packmouse;UniversalTraits:UT_topheavy` — it does **not** list `UT_squirrel` or `UT_backpacker` as exclusions of packmule. Symmetry is partial: packmouse excludes packmule, squirrel, and backpacker; but packmule only excludes packmouse and topheavy. This asymmetry is intentional (packmouse's heavier penalty justifies broader exclusions) but worth documenting.
  - `UT_squirrel` script block (line 987) lists `MutuallyExclusiveTraits = UniversalTraits:UT_packmouse;UniversalTraits:UT_topheavy` — consistent with packmouse excluding squirrel.
  - `UT_backpacker` script block (line 1072) lists `MutuallyExclusiveTraits = UniversalTraits:UT_packmouse;UniversalTraits:UT_topheavy` — consistent with packmouse excluding backpacker.
  - `UT_topheavy` is not excluded from packmouse's own block, but packmouse appears in topheavy's and backpacker's exclusion lists. The engine makes exclusions bidirectional at runtime, so this is not a bug — if topheavy excludes packmouse, the player cannot have both regardless of which direction the `.txt` block declares it.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_packmouse.lua` (13 lines)
- UT_MET group membership: none — not present in any `UT_MET` group in `UT_MET.lua`.

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_packmouse.lua` (13 lines, complete)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait` definition (lines 11–16)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` — `UTCore.applyCarryWeight` definition (lines 14–17)
  - `test/UTTestMocks.lua` lines 210–212 — test stubs for `UTCore.applyCarryWeight` and `UTCore.hasTrait`
- Full Lua file (13 lines):
  ```lua
  -- UT_packmouse.lua
  -- Source: MoreTraits MoreTraits_UCWF.lua — packmouse carry weight penalty.
  -- OnNewGame: UTCore.applyCarryWeight(player, -2)

  local TRAIT_ID = "UniversalTraits:UT_packmouse"

  local function onCreatePlayer(_playerIndex, player)
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      UTCore.applyCarryWeight(player, -2)
  end

  Events.OnCreatePlayer.Add(onCreatePlayer)
  ```
- Event registrations:
  - `Events.OnCreatePlayer.Add(onCreatePlayer)` — fires once when a new player character is created (character creation / new game start). This is a one-shot application at game start, not a periodic or recurring hook.
- UT_CORE hooks used:
  1. `UTCore.hasTrait(player, TRAIT_ID)` — defined in `UTCore_API.lua` lines 11–16: nil-safe wrapper; checks `player:getTraits():contains(traitId)`; returns `false` if `player` or `traits` is nil.
  2. `UTCore.applyCarryWeight(player, delta)` — defined in `UTCore_StatModifiers.lua` lines 14–17:
     ```lua
     function UTCore.applyCarryWeight(player, delta)
         local base = player:getMaxWeightBase()
         player:setMaxWeightBase(base + delta)
     end
     ```
     Reads the current `MaxWeightBase`, adds `delta` (-2 in this case), and writes it back. This is a direct, immediate, permanent (for the session) modification to the player's base carry weight.
- Runtime chain (plain language):
  1. PZ fires `Events.OnCreatePlayer` when the player character is created at game start.
  2. `onCreatePlayer(_playerIndex, player)` runs. The `_playerIndex` argument is received but unused (prefixed `_` by convention).
  3. Guard: `UTCore.hasTrait(player, TRAIT_ID)` — if the player does not have `"UniversalTraits:UT_packmouse"`, exit immediately.
  4. `UTCore.applyCarryWeight(player, -2)` — calls `player:getMaxWeightBase()`, subtracts 2, calls `player:setMaxWeightBase(result)`.
  5. No moddata written. No further hooks, events, or side effects. The carry weight reduction is applied once and persists for the session via the game's own stat storage.
- Exact numbers:
  - Delta applied: **-2** to `MaxWeightBase`.
  - Default PZ `MaxWeightBase` is **8**. After this trait: **6**.
  - This matches the MoreTraits source exactly (source default `WeightPackMouse = 6`, implying a -2 reduction from the vanilla base of 8).
- `player` nil guard: present — `UTCore.hasTrait` returns `false` if `player` is nil, causing early return before `applyCarryWeight` is called. No risk of nil crash.
- Comment discrepancy: the file header comment says `-- OnNewGame: UTCore.applyCarryWeight(player, -2)` but the actual event registered is `Events.OnCreatePlayer`, not `Events.OnNewGame`. `OnCreatePlayer` fires on character creation (new save or joining a server), which in practice covers the same moment as "new game" for singleplayer. The comment is slightly misleading but functionally accurate for the singleplayer use case (`DisabledInMultiplayer = true`).

## Description Integrity
- Display name check: `"Pack Mouse"` — matches the source name exactly (`UI_trait_packmouse = "Pack Mouse"` in MoreTraits EN strings).
- Description check: `"You struggle to carry as much as most people. -2 base carry weight."`
  - "You struggle to carry as much as most people" — accurate flavour. The trait reduces carry weight.
  - "-2 base carry weight" — **accurate and precise**. The runtime applies exactly `-2` to `MaxWeightBase`. The description correctly communicates the exact mechanic and magnitude.
- Missing or misleading details:
  - None significant. The description is concise, accurate, and gives the exact number. This is one of the cleaner trait descriptions in the mod.
  - Minor: does not mention this is a one-time application at character creation (as opposed to a dynamic/recurring effect). Given that carry weight base is a permanent stat, this is unlikely to confuse players.

## Balance Review
- Upside: none — pure negative trait, returns **7 points**.
- Downside:
  - Base carry weight reduced by **2 units** (from 8 to 6), a **25% reduction** of the default base.
  - Carry weight in PZ determines how much the player can carry before becoming encumbered. A 2-unit reduction is meaningful: items commonly weighing 0.5–2.0 units means the player can carry roughly 1–4 fewer mid-weight items than baseline.
  - Strength skill increases carry weight beyond base (each Strength level typically adds to effective carry capacity). The trait reduces the **base** only, so the penalty is front-weighted at low Strength and proportionally smaller at high Strength levels. High-Strength builds mitigate this trait's impact significantly.
- Peer comparison:
  - `UT_packmule` (line 897): Cost +3, applies `+6` to carry weight base (base goes from 8 → 14). The magnitude ratio is 6:2 (packmule:packmouse), but the cost ratio is only 3:7 — **packmouse is priced considerably more harshly than packmule is rewarded**. Packmule gives 3x the magnitude for less than half the cost difference. This asymmetry is notable.
  - `UT_squirrel` (excluded by packmouse): a carry-weight modifier trait — exact values not traced here, but the mutual exclusion confirms it occupies the same design space.
  - `UT_backpacker` (excluded by packmouse): applies `UTCore.applyStrengthCarryWeight(player, 4)` dynamically (base = 5 + Strength + 4). At Strength 5: base = 14. At Strength 0: base = 9. Backpacker is strictly superior in carry weight at virtually all Strength levels. The mutual exclusion is correct.
  - `UT_topheavy` (excluded via engine bidirectionality from squirrel/backpacker blocks): carry-weight negative trait, not directly traced here.
  - `UT_sorelegs` (different file, same applyCarryWeight call): also applies `-2` carry weight plus a `-20% movement speed` penalty, at a presumably higher point return. If sorelegs gives more points for the same weight penalty plus a movement penalty, packmouse at -7 for only the weight penalty may be overpriced.
- Stack or exclusion notes: mutual exclusions (`UT_packmule`, `UT_squirrel`, `UT_backpacker`) prevent combining with all carry-weight-positive traits in the UT set. The player cannot take packmouse alongside any carry weight improvement trait, concentrating its downside without offset. This supports the higher point return.
- Cost verdict: **-7 is on the high end** for a single flat -2 to base carry weight. The source cost was also -7, so parity with source is maintained. However, compared within UT's own economy (packmule gives +6 for only +3 points), the asymmetry is large. The mutual exclusion set (blocking three positive carry-weight traits) adds implicit harshness beyond the raw stat change. **-5 or -6 might be more proportionate within UT's internal balance**, but -7 matches source precedent.

## Regression Proof
- Existing tests:
  - `"UniversalTraits:UT_packmouse"` appears in the Phase 1 smoke-test ID list at `test/run_tests.lua` line 229 (under `-- Stat Modifiers (20)`). This list is validated by:
    1. `"all N trait IDs registered with CharacterTrait"` — confirms `CharacterTrait.register("UniversalTraits:UT_packmouse")` has been called and the ID resolves.
    2. `"script trait definitions resolve cleanly and preserve UT_MET coverage"` — confirms the script block exists, `CharacterTrait` field matches the block ID, all `MutuallyExclusiveTraits` entries (`UT_packmule`, `UT_squirrel`, `UT_backpacker`) resolve to registered IDs.
    3. `"script costs match the current balance decisions"` — only a small set of named traits are explicitly cost-asserted; `UT_packmouse` is not among them, so the -7 cost is not regression-locked by a direct assertion.
  - `test/run_tests.lua` lines 508–511 contain a cost-validated test for `UT_packmule` (`assert_eq(p:getMaxWeightBase(), 14, ...)` after `fireCreatePlayer`). No equivalent test exists for `UT_packmouse`.
- What these tests prove: ID registration and script-block structural integrity (including MET reference resolution). Neither test exercises the Lua runtime handler.
- Missing proof: No moddata spot-check or carry weight delta test for `UT_packmouse`. The `onCreatePlayer` handler — the `hasTrait` guard, the `applyCarryWeight(-2)` call, and the resulting `MaxWeightBase` value — is entirely untested at the runtime level.
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_packmouse.lua")

  test("UT_packmouse reduces base carry weight by 2", function()
      local p = fireCreatePlayer("UniversalTraits:UT_packmouse")
      assert_eq(p:getMaxWeightBase(), 6, "expected base carry weight 6 after Pack Mouse (-2 from default 8)")
  end)

  test("UT_packmouse: no carry weight change when player does not have trait", function()
      local p = MockPlayer({})  -- no traits
      Events.OnCreatePlayer:fire(0, p)
      assert_eq(p:getMaxWeightBase(), 8, "expected carry weight to remain at 8 without trait")
  end)
  ```

## Final Verdict
- Source origin: confirmed — MoreTraits `packmouse` trait. Source behavior: sets `player:getMaxWeightBase()` to `SandboxVars.MoreTraits.WeightPackMouse or 6` (a sandbox-configurable weight cap, default 6, implying -2 from PZ vanilla base of 8). Source cost: **-7**. Source mutual exclusion: `packmouse` ↔ `packmule` only.
- UT implementation: **faithful and accurate**. The UT version applies exactly `-2` to `MaxWeightBase` via `UTCore.applyCarryWeight(player, -2)` on `Events.OnCreatePlayer`. This correctly reproduces the source's effective -2 delta from the vanilla base. The cost (-7) matches the source exactly.
- MET expansion: UT adds `UT_squirrel` and `UT_backpacker` as mutual exclusions beyond the source's `packmule`-only exclusion. Both additions are sensible (both are carry-weight-positive traits that would negate the penalty). The engine bidirectionality ensures `UT_topheavy` also cannot be combined with packmouse, via the reverse exclusion declarations in topheavy's and backpacker's blocks.
- Description: **accurate and precise**. `-2 base carry weight` is the exact number applied. No fabricated mechanics, no missing core effects. One of the cleaner descriptions in the trait set.
- Balance: **preserved from source but asymmetric within UT**. -7 for -2 carry weight base is defensible given the mutual exclusion set (no carry-weight-positive trait can be taken alongside it). However, the internal asymmetry with `UT_packmule` (+6 weight for only +3 points) is notable and may warrant review.
- Regression proof: **weak for runtime**. Registration and script-block structure are smoke-tested. The `onCreatePlayer` handler (hasTrait guard, applyCarryWeight delta, resulting weight value) has no runtime test coverage.
- Header comment error: the file says `-- OnNewGame: UTCore.applyCarryWeight(player, -2)` but registers `Events.OnCreatePlayer`, not `Events.OnNewGame`. Functionally equivalent for singleplayer, but the comment is inaccurate and should be corrected to `-- OnCreatePlayer: UTCore.applyCarryWeight(player, -2)`.
- Action needed:
  1. **Fix file header comment** — change `-- OnNewGame:` to `-- OnCreatePlayer:` on line 3 of `UT_packmouse.lua` to match the actual event registered.
  2. **Add runtime spot-check tests** per the minimum test block above — confirm the -2 delta and the hasTrait guard.
  3. **Optional balance review**: consider whether -7 is proportionate versus `UT_packmule` (+6 for +3). If the cost economy is being standardised, -5 or -6 may be more internally consistent. Current -7 matches source precedent, which is a valid reason to retain it.
  4. **Optional**: the registries.lua section header (`-- PHASE 1 -- STAT MODIFIERS (SIMPLE, NO RUNTIME LUA)`) is inaccurate for `UT_packmouse` since it does have a runtime Lua file. The comment describes the group intent (stat modifiers via script, not complex Lua), not a hard technical constraint. Consider either adding a sub-comment or moving UT_packmouse to a separate runtime-Lua stat modifier sub-group.
- Open gaps:
  - No `stats` or `player:getMaxWeightBase()` nil guard inside `UTCore.applyCarryWeight` — the function calls `player:getMaxWeightBase()` without checking the return. In practice PZ always provides a valid numeric base weight for a live player, so this is low risk. The outer `UTCore.hasTrait` guard already ensures `player` is non-nil before `applyCarryWeight` is called.
  - The MoreTraits Dynamic variant's auto-removal mechanic (trait is removed when Strength reaches a threshold, then `packmule` is added) is not replicated in UT. This is a known and intentional design difference — UT does not implement dynamic trait evolution. Worth documenting if players familiar with MoreTraits Dynamic expect this behavior.
