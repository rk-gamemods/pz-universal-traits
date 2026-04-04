# UT_cangrabless

## Trait Summary

- UT trait id: UT_cangrabless
- Source mod: MoreSimpleTraits ("CanGrabLess")
- Source trait id: CanGrabLess
- Current cost: -2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` (registration, line 135)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua` (registration, line 115)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTWeightTraits.lua` (runtime implementation, lines 8–16)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/client/MSTWeightTraits.lua` (runtime implementation, lines 8–16)
- Source registration:
  - `TraitFactory.addTrait("CanGrabLess", getText("UI_trait_cangrabless"), -2, getText("UI_trait_cangrablessdesc"), false)`
  - Cost: -2 (negative — the player is penalised at character creation).
  - Not a profession trait (`false`).
- Source trigger path: `Events.OnCreatePlayer.Add(cangrablesscalc)` — global function `cangrablesscalc()` fires once when the player character is first created.
- Source behavior: Calls `getPlayer()` to retrieve the local player, checks `player:HasTrait("CanGrabLess")`, and if true, calls `player:setMaxWeightBase(7)`. The default `MaxWeightBase` in the base game is 8 units, so this lowers maximum carry weight by 1 unit. No ongoing periodic handler exists in the source — the effect is a one-shot stat write on `OnCreatePlayer`.
- Source mutual exclusions: `CanGrabLess` is explicitly set mutually exclusive with `CanGrabMore` and `Strong` via `TraitFactory.setMutualExclusive` (MSTMainCreationMethods.lua lines 202–203).
- Source description text (from installed translation): `UI_trait_cangrabless`, `UI_trait_cangrablessdesc` — exact strings not present in the installed translation dump (only the key is referenced via `getText()`). Content is unknown from source; inferred as a reduced-carry-weight description.

## Current UT Evidence

### Structure
- Registered in registries.lua: **yes** — line 135: `UTTraitsRegistries.UT_cangrabless = CharacterTrait.register("UniversalTraits:UT_cangrabless")`
- Defined in UT_character_traits.txt: **yes** — lines 1053–1062:
  ```
  character_trait_definition UniversalTraits:UT_cangrabless
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_cangrabless,
      Cost = -2,
      UIName = UI_UT_cangrabless,
      UIDescription = UI_UT_cangrablessDesc,
      MutuallyExclusiveTraits = UniversalTraits:UT_cangrabmore,
  }
  ```
- Translation strings present: **yes** — UI_EN.txt lines 308–309:
  - `UI_UT_cangrabless = "Weak Grip"`
  - `UI_UT_cangrablessDesc = "Your weak hands make it harder to grab and hold onto things. Grab success rate is reduced."`
- Exclusions/grants correct: **partial — see Description Integrity below**
- Runtime Lua file exists: **yes** — `media/lua/shared/UniversalTraits/traits/UT_cangrabless.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_cangrabless.lua` (complete file, 10 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1053–1062)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 308–309)
  - `media/lua/shared/UniversalTraits/UT_MET.lua` (full file — no cangrabless/cangrabmore group present)
  - `test/run_tests.lua` (line 236 — trait appears in registration smoke-test list)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (UTCore.hasTrait implementation)
- Complete Lua file (all 10 lines):
  ```lua
  -- UT_cangrabless.lua
  -- Source: MoreSimpleTraits "CanGrabLess" — sets max carry weight base to 7 (default 8).

  local TRAIT_ID = "UniversalTraits:UT_cangrabless"

  local function onCreatePlayer(playerIndex, player)
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      player:setMaxWeightBase(7)
  end

  Events.OnCreatePlayer.Add(onCreatePlayer)
  ```
- Event registrations:
  - `Events.OnCreatePlayer.Add(onCreatePlayer)` — fires once when the player character is first created; receives `(playerIndex, player)`.
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe presence check; delegates to `player:getTraits():contains(traitId)` (UTCore_API.lua lines 11–16).
- Runtime chain (plain language):
  1. When a new character is created (`OnCreatePlayer` fires), `onCreatePlayer(playerIndex, player)` is called.
  2. `UTCore.hasTrait(player, TRAIT_ID)` checks whether the player's trait list contains `"UniversalTraits:UT_cangrabless"`. If not, the function returns immediately — no effect on other players.
  3. If the trait is present, `player:setMaxWeightBase(7)` is called, overwriting the base carry weight from the default (8) to 7.
  4. No moddata is written. No periodic handler is registered. No further runtime logic executes.
- Actual behavior (exact values):
  - Carry weight: sets `MaxWeightBase` to exactly 7 (down from the default 8), a net reduction of 1 unit.
  - Timing: one-shot on `OnCreatePlayer`; does not reapply dynamically.
  - No other stats are affected.

## Description Integrity

- Display name check: "Weak Grip" — the name implies a grip/grab mechanic. The source trait is named "CanGrabLess" and its source effect was a reduced carry weight via `setMaxWeightBase(7)`. "Weak Grip" is a plausible rebranding but introduces a conceptual shift: the source is purely a carry weight reduction, not a grip/grab mechanic.
- Description check: `UI_UT_cangrablessDesc` = "Your weak hands make it harder to grab and hold onto things. Grab success rate is reduced."
- **Description mismatch — CRITICAL**: The description claims "Grab success rate is reduced." The actual runtime implementation does nothing of the sort. The only effect is `player:setMaxWeightBase(7)` — a carry weight reduction. There is no code anywhere in UT_cangrabless.lua that modifies grab success rate, grab range, zombie grab resistance, or any combat mechanic. The description is factually incorrect as written.
- Missing or misleading details:
  - The description omits the actual effect entirely (carry weight reduced to 7 from 8, i.e., -1 unit).
  - The description invents an effect (grab success rate reduction) that has no implementation.
  - The display name "Weak Grip" reinforces the false grab-mechanic framing. A more accurate name would be "Weak Arms" or "Low Carry Capacity."
  - The source description was about carry weight; the UT description pivots to grab mechanics without any code to back it up.

## Balance Review

- Upside: none — pure negative trait (costs -2, giving the player 2 character-creation points).
- Downside: MaxWeightBase reduced to 7 (from 8), a -1 unit carry weight reduction.
- Uptime: permanent and unconditional from character creation onward; the stat write is not reversible via any UT logic.
- Peer comparison:
  - `UT_cangrabmore` costs +2, sets `MaxWeightBase` to 9 (+1 unit). It is the direct counterpart: same magnitude, opposite direction, same cost (absolute value).
  - `UT_packmule` costs +4 with a scaling strength-based carry weight bonus well in excess of +1 unit.
  - `UT_packmouse` costs approximately -4 with a larger carry weight reduction than -1.
  - A flat -1 MaxWeightBase for -2 points is a very minor penalty. In practice, most carry-weight builds absorb -1 unit trivially, making this trait extremely cheap relative to the actual burden it imposes.
- Stack or exclusion notes:
  - `MutuallyExclusiveTraits = UniversalTraits:UT_cangrabmore` in the script definition — enforced by the game engine at character creation.
  - No exclusion from `UT_packmouse` (another negative carry-weight trait) — these could be stacked at character creation, compounding the carry weight reduction, though no UT logic prevents it.
  - No entry in `UT_MET.lua` for this pair — UT_MET only tracks pairs that require Lua-side enforcement. The cangrabless/cangrabmore mutex is engine-enforced via the .txt definition, which is correct.
- Cost verdict: reasonable in isolation for the actual effect (-1 MaxWeightBase for -2 points), but the source mutual exclusion with `Strong` has been dropped in UT (source excluded `CanGrabLess` from `Strong`; UT only excludes `UT_cangrabmore`). Dropping the `Strong` exclusion means a player could take `UT_cangrabless` and have high Strength, partially neutralising the carry weight penalty while banking the -2 points. This makes the trait slightly more exploitable than intended by the source.

## Regression Proof

- Existing test: `UT_cangrabless` appears in the bulk trait-ID list at `test/run_tests.lua` line 236, inside the "all registered trait IDs present in script file" smoke test. This test verifies:
  1. That `UTTraitsRegistries.UT_cangrabless` exists and equals `"UniversalTraits:UT_cangrabless"`.
  2. That `"UniversalTraits:UT_cangrabless"` appears as a `CharacterTrait` value in `UT_character_traits.txt`.
- What it proves: registration and script-definition presence are covered. The trait will not silently disappear from the registry or the script file without failing this test.
- Missing proof:
  - No test fires `OnCreatePlayer` with this trait active and asserts that `player:setMaxWeightBase(7)` was called (i.e., that `getMaxWeightBase()` returns 7 after the event fires).
  - No test verifies that the trait has no effect when the player does not have it (guard path through `UTCore.hasTrait`).
  - No test validates the MET exclusion (that `UT_cangrabmore` is excluded when `UT_cangrabless` is selected).
- Minimum next test if needed: Create a player with the trait, fire `OnCreatePlayer`, and assert `player:getMaxWeightBase() == 7`. Create a second player without the trait, fire `OnCreatePlayer`, and assert `getMaxWeightBase()` is not 7 (default or unset).

## Final Verdict

- Source origin: proven — `MoreSimpleTraits "CanGrabLess"` confirmed across both the standard and vanilla variant files. Cost (-2), event hook (`OnCreatePlayer`), and stat write (`setMaxWeightBase(7)`) all faithfully reproduced.
- UT implementation: faithful — the one-shot `OnCreatePlayer` + `setMaxWeightBase(7)` pattern is an exact port of the source `cangrablesscalc()`. No divergence from source behavior.
- Description: **WRONG** — the description claims "Grab success rate is reduced" but the only runtime effect is a carry weight reduction (`setMaxWeightBase(7)`). Grab success rate is not touched anywhere. The display name "Weak Grip" compounds this confusion. Both name and description need rewriting to reflect the actual effect.
- Balance: acceptable for the actual effect, but the dropped `Strong` exclusion (present in source, absent in UT) slightly over-rewards the player. The -1 MaxWeightBase is a minor penalty at -2 points.
- Regression proof: partially protected — registration and script presence are tested; the runtime carry-weight write is untested.
- Action needed: **description fix required** | test fix | balance note
- Open gaps:
  1. **CRITICAL**: `UI_UT_cangrablessDesc` claims "Grab success rate is reduced" — this is false. The description (and likely the display name "Weak Grip") must be rewritten to reflect the actual effect: carry weight reduced to 7 (−1 unit from default 8).
  2. No `OnCreatePlayer` test asserting `setMaxWeightBase(7)` was applied; add a targeted moddata/stat test.
  3. Source excluded `CanGrabLess` from `Strong`; UT only excludes `UT_cangrabmore`. Decide whether to add a `Strong` (or equivalent strength trait) exclusion and document the decision.
  4. No UT_MET.lua entry needed (engine enforces the cangrabless/cangrabmore mutex via .txt), but the absence should be confirmed as intentional — current state is correct.
