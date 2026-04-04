# UT_backpacker

## Trait Summary

- UT trait id: UT_backpacker
- Source mod: FillerTraits (UpgradeTraits.lua / UpgradeMainCreationMethods.lua)
- Source trait id: `Backpacker` (unnamespaced, registered via `TraitFactory.addTrait`)
- Current cost: 8
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua` (trait registration, mutual exclusion)
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/client/UpgradeTraits.lua` (runtime implementation, `IndomTimecheck()`)
- Source trigger path: `IndomTimecheck()` is called on some player-update or game-tick event (exact event binding not exposed in the reviewed file; the function is defined at module scope and called externally). Checks `player:HasTrait("Backpacker")`.
- Source behavior:
  - Registration: `TraitFactory.addTrait("Backpacker", getText("Backpacker"), 8, getText("Able to carry more weight."), false, false)` — cost 8, positive trait, no profession lock.
  - Mutual exclusion: `TraitFactory.setMutualExclusive("Backpacker", "Topheavy")` — cannot be taken with `Topheavy`.
  - Runtime effect: `player:setMaxWeightBase(5 + strength - 1)` where `strength = player:getPerkLevel(Perks.Strength)`. The formula sets carry weight to `4 + Strength` (i.e., base 5 offset by -1 bonus, net +0 over the strength-only floor of `5 + strength`). At default Strength 5 the effective max weight base = 9.
  - No XP boosts, no free recipes, no stat modifiers beyond carry weight.

**Source formula note:** The source uses `5 + strength - 1`, which is strictly weaker than the plain vanilla carry weight formula (vanilla B42 default base is typically around 8–15 depending on Strength). The `-1` means Backpacker in FillerTraits actually gives +0 above a hypothetical no-trait baseline of `5 + strength`, making it effectively a neutral or very weak carry trait that merely locks in `strength - 1` offset rather than a true boost. This is likely a design error or intentional minimalism in the source.

## Current UT Evidence

### Structure
- Registered in registries.lua: **yes** — line 136: `UTTraitsRegistries.UT_backpacker = CharacterTrait.register("UniversalTraits:UT_backpacker")`
- Defined in UT_character_traits.txt: **yes** — lines 1064–1073
- Translation strings present: **yes** — `UI_UT_backpacker` and `UI_UT_backpackerDesc` both present in `UI_EN.txt` (lines 311–312)
- Exclusions/grants correct: **yes** — `MutuallyExclusiveTraits = UniversalTraits:UT_packmouse;UniversalTraits:UT_topheavy` (UT expands exclusions vs. source; see Balance Review)
- Runtime Lua file exists: **yes**

### Script Definition (UT_character_traits.txt lines 1064–1073)

```
character_trait_definition UniversalTraits:UT_backpacker
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_backpacker,
    Cost = 8,
    UIName = UI_UT_backpacker,
    UIDescription = UI_UT_backpackerDesc,
    MutuallyExclusiveTraits = UniversalTraits:UT_packmouse;UniversalTraits:UT_topheavy,
}
```

No `XPBoosts` line — correct, source has none.

### Translation Strings (UI_EN.txt lines 311–312)

```
UI_UT_backpacker     = "Backpacker",
UI_UT_backpackerDesc = "Efficient packing and load distribution let you carry more comfortably. Carry weight is increased.",
```

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_backpacker.lua` (full file, 12 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1064–1073)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 311–312)
  - `media/registries.lua` (line 136)
  - `test/run_tests.lua` (line 237)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` (registerPeriodicHandler implementation)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` (applyStrengthCarryWeight implementation)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (hasTrait implementation)
- Event registrations:
  - `UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", handler)` — fires every player-update tick (every frame the player exists)
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe presence check via `player:getTraits():contains(traitId)`
  - `UTCore.applyStrengthCarryWeight(player, 4)` — sets `player:setMaxWeightBase(5 + Strength + 4)`
- Runtime chain (plain language):
  1. The module-level call `UTCore.registerPeriodicHandler(...)` runs at file load time, registering a wrapped handler with `Events.OnPlayerUpdate`. The registration is idempotent (keyed by `TRAIT_ID .. "::" .. "OnPlayerUpdate"`).
  2. Every player-update tick (every frame), the wrapped function calls `getPlayer()` and invokes `handler(player)`.
  3. `handler` immediately calls `UTCore.hasTrait(player, TRAIT_ID)`. If the player does not have `"UniversalTraits:UT_backpacker"` the function returns with no effect.
  4. If the trait is present, `UTCore.applyStrengthCarryWeight(player, 4)` is called. This reads `player:getPerkLevel(Perks.Strength)` and calls `player:setMaxWeightBase(5 + strength + 4)`.
- Actual behavior (exact values):
  - Carry weight base = `9 + Strength` (i.e., 5 base + 4 bonus + current Strength level).
  - Applied every frame via `setMaxWeightBase`, so the value tracks dynamically if Strength changes (leveling up, XP boosts applied, etc.).
  - At default Strength 5: max weight base = 14.
  - At max Strength 10: max weight base = 19.
  - The effect is re-applied every tick; there is no one-shot init or moddata caching.

**Carry weight formula in context:**
| Strength | No trait (vanilla base = `5 + str`) | UT_backpacker (`9 + str`) | Net gain |
|----------|--------------------------------------|--------------------------|----------|
| 1        | 6                                    | 10                       | +4       |
| 5        | 10                                   | 14                       | +4       |
| 10       | 15                                   | 19                       | +4       |

The +4 bonus is flat and Strength-independent. It replaces the vanilla base entirely each tick rather than adding to it — this is safe only because `setMaxWeightBase` is the canonical setter in PZ B42 and vanilla uses the same formula internally.

**Comparison to source:**
- Source: `5 + strength - 1` → net +0 gain over the vanilla baseline of `5 + strength` — effectively a no-op or a -1 penalty masquerading as a trait.
- UT: `5 + strength + 4` → net +4 above vanilla baseline. This is a genuine reinterpretation; UT corrected what appears to be a source design error.

## Description Integrity

- Display name check: "Backpacker" — matches source and intent; accurate.
- Description check: `UI_UT_backpackerDesc` = "Efficient packing and load distribution let you carry more comfortably. Carry weight is increased." — this is thematically accurate but **vague on the exact value**. The description says "carry weight is increased" without stating the amount (+4 flat) or the scaling relationship with Strength.
- Missing or misleading details:
  - The description does not state the exact bonus (+4 carry weight). Users cannot determine value from the description alone.
  - The description does not note that the effect scales with Strength (i.e., higher Strength gives a higher absolute max weight, though the bonus itself is a flat +4).
  - No mention that the trait is disabled in multiplayer (`DisabledInMultiplayer = true`), which is consistent with all UT traits and not a per-trait description concern.
  - Peer `UT_topheavy` (the mutual exclusive) similarly does not specify its exact penalty in description — consistent pattern, but still a gap across the carry weight family.

## Balance Review

- Upside: +4 flat carry weight base, applied every tick, dynamically tracking Strength. Unconditional — no state condition, no cooldown, no cost to activate.
- Downside: none — pure positive trait.
- Uptime: 100% — fires every frame unconditionally while the player has the trait.
- Cost: 8 points — matches source cost exactly.
- Peer comparison:
  - `UT_packmule` (carry weight positive peer, cost unknown from this audit but registered immediately before) — not yet audited; relative cost unknown.
  - `UT_packmouse` (mutually exclusive; negative carry weight trait) — excluded correctly.
  - `UT_topheavy` (mutually exclusive; cost −4; uses `applyStrengthCarryWeight(player, 2)` → net `7 + Strength` base) — UT_backpacker gives +4 vs. UT_topheavy penalty of +2 below vanilla. Symmetry: backpacker costs 8, topheavy refunds 4. The magnitudes (+4 vs. -3 net from vanilla) are not symmetric in effect — the negative trait gives 4 points for a -3 carry delta, while the positive trait costs 8 for a +4 carry delta. The cost-to-effect ratio is roughly 2 pts/unit for the negative and 2 pts/unit for the positive — reasonably balanced.
  - `UT_squirrel` is in the mutual exclusion list for `UT_packmouse` and `UT_topheavy`, but **not** excluded from `UT_backpacker` directly. If `UT_squirrel` also affects carry weight or fatigue, stacking with `UT_backpacker` may be unintended.
- Stack or exclusion notes:
  - Excluded from: `UT_packmouse`, `UT_topheavy` — correct.
  - `UT_packmouse` also excludes `UT_packmule` and `UT_squirrel` (line 916 of script file). `UT_backpacker` does NOT exclude `UT_packmule` or `UT_squirrel`. If `UT_packmule` provides a carry weight bonus, `UT_backpacker + UT_packmule` could stack. This should be verified against `UT_packmule`'s definition.
  - `DisabledInMultiplayer = true` is set — consistent with other dynamic stat traits.
- Cost verdict: reasonable at 8 — the flat +4 carry weight bonus with full-Strength scaling is a clear, consistent buff. The source cost was also 8. The UT implementation is strictly stronger than the source (source net was effectively 0 or -1; UT net is +4), so the cost is arguably underpriced relative to the improved implementation, but the absolute value of +4 carry weight is modest.

## Regression Proof

- Existing test: `"UniversalTraits:UT_backpacker"` appears in the exhaustive trait-ID list in `test/run_tests.lua` at line 237. This is inside the `allTraitIds` table that feeds a registration smoke-test asserting every trait ID is registered in `UTTraitsRegistries`.
- What it proves: The trait is present in `UTTraitsRegistries` (i.e., `CharacterTrait.register(...)` was called with the correct ID). It does not exercise any runtime behavior.
- Missing proof:
  - No test verifies that `handler` fires on `OnPlayerUpdate` and calls `applyStrengthCarryWeight` with the correct bonus.
  - No test verifies the exact carry weight formula: `setMaxWeightBase(5 + strength + 4)`.
  - No test verifies that the handler is a no-op when the player does not have the trait (the early-return guard).
  - No test verifies dynamic re-application when Strength changes mid-game.
- Minimum next tests needed:
  1. Mock a player with Strength N and the trait active; fire `OnPlayerUpdate` once; assert `player.maxWeightBase == 9 + N`.
  2. Mock a player without the trait; fire `OnPlayerUpdate`; assert `setMaxWeightBase` was never called (early-return guard).
  3. (Optional) Change Strength from 5 to 6, fire again, assert max weight base updated to 15.

## Final Verdict

- Source origin: proven — `Backpacker` trait from FillerTraits confirmed; cost (8), description flavor, and mutual exclusion with `Topheavy` all traced. UT correctly reinterprets the source formula from the functionally-broken `5 + strength - 1` to a genuine `5 + strength + 4` bonus.
- UT implementation: correct reinterpretation — the source carry weight formula was effectively a no-op (net +0 vs. vanilla). UT applies a flat +4 bonus, which is the expected design intent of a trait called "Backpacker" at 8 points. The `applyStrengthCarryWeight` helper is clean and well-documented in UTCore.
- Description: vague — the effect ("carry weight is increased") is accurate but omits the exact value (+4) and the dynamic Strength scaling. Peers at this cost tier should state exact numbers.
- Balance: reasonable but has a stacking gap — cost matches source; the effect is modest and well-proportioned against `UT_topheavy`. However, the absence of a mutual exclusion with `UT_packmule` is a potential stacking issue that needs verification.
- Regression proof: minimal — only the registration smoke-test covers this trait. The runtime carry-weight formula is entirely untested.
- Action needed: **description fix | test fix | exclusion audit**
  - Update `UI_UT_backpackerDesc` to state the exact bonus, e.g. "+4 carry weight. Scales with Strength."
  - Add `OnPlayerUpdate` handler tests (trait present → correct max weight; trait absent → no-op).
  - Verify whether `UT_packmule` should be added to `UT_backpacker`'s `MutuallyExclusiveTraits` list (and vice versa) to prevent carry weight stacking.
- Open gaps:
  - Description omits exact +4 value.
  - No unit test for the runtime carry weight path.
  - `UT_packmule` exclusion not set — stacking risk unresolved.
  - Source formula (`5 + strength - 1`) was likely a source bug; UT silently corrected it, but this correction is undocumented in the trait file's header comment. The header says "carry weight = 5 + Strength + 4" which is correct — this is the only documentation of the correction.
