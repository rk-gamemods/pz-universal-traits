# UT_topheavy

## Trait Summary

- UT trait id: UT_topheavy
- Source mod: FillerTraits (`UpgradeTraits.lua` / `UpgradeMainCreationMethods.lua`)
- Source trait id: `Topheavy` (unnamespaced, registered via `TraitFactory.addTrait`)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua`
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/client/UpgradeTraits.lua`
- Source trigger path: `IndomTimecheck()` handles the runtime effect. The exact event hook that calls `IndomTimecheck()` was not located in the reviewed source slice, so cadence is only partially proven from installed-mod evidence.
- Source behavior:
  - Registration: `TraitFactory.addTrait("Topheavy", getText("Topheavy"), -4, getText("Can't carry as much weight."), false, false)`
  - Mutual exclusion: `TraitFactory.setMutualExclusive("Backpacker", "Topheavy")`
  - Runtime effect in `IndomTimecheck()`: if the player has `Topheavy`, source calls `player:setMaxWeightBase(5 + strength - 3)`.
  - Relative to the UT baseline helper formula `5 + Strength`, source `Topheavy` is a flat **-3 carry weight** penalty.

## Current UT Evidence

### Structure

- Registered in `media/registries.lua`: **yes** — `UTTraitsRegistries.UT_topheavy = CharacterTrait.register("UniversalTraits:UT_topheavy")`
- Defined in `media/scripts/UT_character_traits.txt`: **yes**
- Translation strings present: **yes** — `UI_UT_topheavy` and `UI_UT_topheavyDesc`
- Runtime Lua file exists: **yes** — `media/lua/shared/UniversalTraits/traits/UT_topheavy.lua`
- Exclusions/grants correct: **yes** — `UT_squirrel`, `UT_backpacker`, and `UT_packmule` are real, correctly namespaced UT traits, and reciprocal `...;UniversalTraits:UT_topheavy` exclusions exist on the peer carry-family traits; this is structurally valid even though source only proves the `Backpacker` pairing

### Script Definition

```txt
character_trait_definition UniversalTraits:UT_topheavy
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_topheavy,
    Cost = -4,
    UIName = UI_UT_topheavy,
    UIDescription = UI_UT_topheavyDesc,
    MutuallyExclusiveTraits = UniversalTraits:UT_squirrel;UniversalTraits:UT_backpacker;UniversalTraits:UT_packmule,
}
```

### Translation Strings

```txt
UI_UT_topheavy     = "Top Heavy",
UI_UT_topheavyDesc = "Your upper-body bulk makes nimble movement harder. Nimbleness XP gain and base agility are reduced.",
```

### Runtime Trace

- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_topheavy.lua`
  - `UniversalTraits/media/scripts/UT_character_traits.txt`
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `UniversalTraits/media/registries.lua`
  - `UniversalTraits/test/run_tests.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua`
- Event registration used:
  - `UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", handler)`
- UT_CORE helpers traced:
  - `UTCore.hasTrait(player, traitId)` → nil-safe `player:getTraits():contains(traitId)` check
  - `UTCore.applyStrengthCarryWeight(player, bonus)` → `player:setMaxWeightBase(5 + strength + bonus)`
- Runtime chain:
  1. `UT_topheavy.lua` registers a periodic `OnPlayerUpdate` handler at file load.
  2. Every player update tick, UT_CORE resolves `getPlayer()` and calls `handler(player)`.
  3. `handler` early-returns unless the player has `"UniversalTraits:UT_topheavy"`.
  4. If present, it calls `UTCore.applyStrengthCarryWeight(player, 2)`.
  5. UT_CORE then sets `player:setMaxWeightBase(5 + Strength + 2)`.
- Real current behavior:
  - Max carry base becomes **`7 + Strength`**.
  - Versus the UT baseline helper formula `5 + Strength`, this is a **+2 carry weight bonus**, not a penalty.
  - At Strength 5: carry base = 12.
  - At Strength 10: carry base = 17.
  - Uptime is effectively 100% while the trait is active because the value is re-applied every `OnPlayerUpdate` tick.
  - No moddata is written; no save-state setup is required beyond the module being loaded.

### Source vs Current UT

| Version | Formula | Net vs `5 + Strength` baseline | Meaning |
|---|---|---:|---|
| Source FillerTraits | `5 + Strength - 3` | -3 | real downside |
| Current UT | `5 + Strength + 2` | +2 | positive buff |

Current UT is not a faithful port. It reverses the sign of the source effect.

## Description Integrity

- Display name check: `Top Heavy` matches the source trait theme.
- Description check: **misleading**.
- Missing or misleading details:
  - The current description claims `Nimbleness XP gain and base agility are reduced`, but the script block has no `XPBoosts`, and the runtime Lua has no Nimbleness or agility logic.
  - The real current runtime effect is carry weight, not nimbleness.
  - The source description was about carry capacity (`"Can't carry as much weight."`), so both the source and current runtime disagree with the current player-facing text.
  - The actual current +2 carry-weight buff is completely undisclosed to the player.

## Balance Review

- Upside: current implementation gives a flat **+2 carry weight** over the `5 + Strength` baseline.
- Downside: none found in current UT runtime or script definition.
- Uptime: 100% while traited; applied every `OnPlayerUpdate` tick.
- Peer comparison:
  - Source `Topheavy` was the negative counterpart to source `Backpacker`; source imposed a -3 carry penalty.
  - Current `UT_backpacker` already gives a positive carry bonus in UT.
  - Current `UT_topheavy` also gives a positive carry bonus while refunding 4 points.
- Stack or exclusion notes:
  - UT expanded exclusions beyond source by adding `UT_squirrel` and `UT_packmule` alongside `UT_backpacker`.
  - That expansion may be intentional carry-family design, but it does not fix the core problem: the trait is still a negative-cost positive-effect exploit.
- Cost verdict: **wrong**.

At its current implementation, `UT_topheavy` is effectively a free-point trait that also improves carry capacity. That is a high-severity balance and correctness defect.

## Regression Proof

- Existing test: `"UniversalTraits:UT_topheavy"` appears in the registration smoke-test trait list in `UniversalTraits/test/run_tests.lua`.
- What it proves: only that the trait id is expected to be registered.
- Missing proof:
  - No test exercises the `OnPlayerUpdate` path.
  - No test verifies the actual carry-weight formula applied by `UT_topheavy`.
  - No test would catch the current sign inversion bug.
  - No test checks that the player-facing description matches the implemented behavior family.
- Minimum next test if needed:
  1. Mock a player with `UT_topheavy` and Strength `N`; fire the registered `OnPlayerUpdate` handler; assert the intended carry base is `2 + N` if UT should remain faithful to source (`5 + Strength - 3`).
  2. Mock a player without the trait; fire the same path; assert `setMaxWeightBase` is not called.
  3. Add a trait-audit consistency test or fixture check that flags carry traits whose description mentions unrelated systems like Nimbleness XP without matching script/runtime evidence.

## Final Verdict

- Source origin: proven
- UT implementation: drifted
- Description: misleading
- Balance: wrong
- Regression proof: missing
- Action needed: code fix
- Open gaps:
  - The runtime formula is inverted from source intent and currently grants `+2` carry weight instead of applying a downside.
  - The description still claims Nimbleness/agility penalties that do not exist anywhere in script or runtime behavior.
  - No automated test currently protects the `OnPlayerUpdate` carry-weight path or catches the sign inversion.
