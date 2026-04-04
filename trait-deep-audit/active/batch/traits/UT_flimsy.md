# UT_flimsy

## Trait Summary

- UT trait id: UT_flimsy
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWTraits:SWFlimsy (trait key: "SWFlimsy")
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/scripts/SWTraits_character_traits.txt` (lines 202–210) — B42.13 script definition
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt` (lines 202–210) — B42.15 script definition (identical)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.13/media/lua/server/SWTraitsCore_server.lua` (lines 294–313) — B42.13 server implementation
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` (lines 294–313) — B42.15 server implementation (identical)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (lines 32, 102) — B42.12 trait registration
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/registries.lua` (line 35) — B42.13 registry entry
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/registries.lua` (line 35) — B42.15 registry entry
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` (lines 49–50) — B42.13 EN strings
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (lines 49–50) — B42.15 EN strings (identical)
- Source cost: -4 (all reviewed versions: B42.12, B42.13, B42.15 — cost is consistent and matches UT).
- Source description (EN, B42.13 and B42.15): "Wearing heavy bags on the back causes upper arms pain which can drastically slow down the attack speed."
- Source `DisabledInMultiplayer`: `false` (B42.13 and B42.15 script definitions).
- Source mutual exclusions: none declared in reviewed files. No `TraitFactory.setMutualExclusive` call references "SWFlimsy" in the B42.12 NPC creation file.
- Source trigger path: `Events.OnTick.Add(SWFlimsy)` — fires every game tick.
- Source behavior (B42.13 and B42.15 server, identical code):
  1. Guard: exits if `player` is nil or player does not have the "SWFlimsy" trait.
  2. Guard: exits if player has no backpack (`getClothingItem_Back()` returns nil).
  3. Reads `backpack:getContentsWeight()`.
  4. If `contentsWeight > 20`:
     - Gets `BodyPartType.UpperArm_L` and `BodyPartType.UpperArm_R`.
     - Reads current pain for each arm: `bodyPartL:getPain()`, `bodyPartR:getPain()`.
     - Computes `extraPain = contentsWeight * 0.1`.
     - **Conditionally** sets additional pain: only if current pain `< 20`, sets `setAdditionalPain(extraPain)`.
     - Neither arm gets pain applied if its current pain is already >= 20.
  5. If `contentsWeight <= 20`: no action (pain is neither cleared nor set to zero).
- Source pain formula: `extraPain = contentsWeight * 0.1`. At the threshold of 21 weight: 2.1. At 30 weight: 3.0. At 100 weight: 10.0. No explicit cap on `extraPain` in the source formula — the only bound is the `painL < 20` / `painR < 20` guard on application.
- Source pain zero-reset: absent. If backpack weight drops to <= 20, pain set by this trait on a previous tick is not actively cleared. Pain decays through the normal PZ body damage system.
- Source XPBoosts: none in the script definition.

## Current UT Evidence

### Structure

- Registered in test harness: yes (`test/run_tests.lua` line 228, grouped in "Stat Modifiers (20)")
- Defined in UT_character_traits.txt: yes (lines 1000–1008)
  - `Cost = -4`
  - `DisabledInMultiplayer = true`
  - `IsProfessionTrait = false`
  - No `XPBoost` entries
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes (`media/lua/shared/Translate/EN/UI_EN.txt`, lines 293–294)
  - `UI_UT_flimsy = "Flimsy"`
  - `UI_UT_flimsyDesc = "You are not built for physical exertion. Strength and endurance are reduced."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_flimsy.lua`)
- Registered in `media/registries.lua`: yes (`UTTraitsRegistries.UT_flimsy = CharacterTrait.register("UniversalTraits:UT_flimsy")`, line 130)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_flimsy.lua` (full file, 31 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1000–1008)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 293–294)
  - `media/registries.lua` (line 130)
  - `test/run_tests.lua` (line 228)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16) — `UTCore.hasTrait`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` (lines 16–42) — `UTCore.registerPeriodicHandler`
- Event registrations:
  - `UTCore.registerPeriodicHandler("UniversalTraits:UT_flimsy", "EveryOneMinute", handler)`
  - This wraps the handler in a closure: `function() handlerFn(getPlayer()) end`, then calls `Events.EveryOneMinute.Add(wrappedFn)`.
  - Effective PZ event: `Events.EveryOneMinute` — fires once per in-game minute.
- UTCore hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe guard: checks `player ~= nil`, `player:getTraits() ~= nil`, then `traits:contains(traitId)`.
  - `UTCore.registerPeriodicHandler` — idempotent: skips re-registration if the key `"UniversalTraits:UT_flimsy::EveryOneMinute"` already exists in `UTCore._periodicHandlers`.
- Runtime chain (plain language):
  1. At module load time: `UTCore.registerPeriodicHandler` is called, registering the handler against `Events.EveryOneMinute`.
  2. Once per in-game minute: the wrapped closure fires `handler(getPlayer())`.
  3. `handler(player)` immediately calls `UTCore.hasTrait(player, "UniversalTraits:UT_flimsy")`. If the player is nil or the trait is absent, exits.
  4. Reads `player:getClothingItem_Back()` — the item in the back clothing slot (the backpack).
  5. Reads `player:getBodyDamage()`. If nil, exits.
  6. Gets `BodyPartType.UpperArm_L` and `BodyPartType.UpperArm_R` from `bodyDamage`. If either is nil, exits.
  7. **If a backpack is present:**
     - Reads `pack:getContentsWeight()`.
     - If `weight > 20`: computes `pain = math.min(weight * 0.1, 20)`, then calls `armL:setAdditionalPain(pain)` and `armR:setAdditionalPain(pain)` unconditionally.
     - If `weight <= 20`: calls `armL:setAdditionalPain(0)` and `armR:setAdditionalPain(0)` — actively zeroes pain.
  8. **If no backpack is present:** calls `armL:setAdditionalPain(0)` and `armR:setAdditionalPain(0)` — actively zeroes pain.
- Actual behavior (exact values):
  - Trigger condition: player has the trait AND has a backpack AND `getBodyDamage()` and both arm parts are non-nil.
  - Weight threshold: `> 20` (strictly greater; weight == 20 does not trigger).
  - Pain formula: `math.min(weight * 0.1, 20)`.
    - At weight 21: `math.min(2.1, 20)` = 2.1.
    - At weight 30: `math.min(3.0, 20)` = 3.0.
    - At weight 100: `math.min(10.0, 20)` = 10.0.
    - At weight 200: `math.min(20.0, 20)` = 20.0 — pain is capped at 20.
    - Cap point: `weight * 0.1 >= 20` → `weight >= 200`. The cap is only reached at extreme weights (200+ units of contents weight) unreachable in normal gameplay.
  - Pain application: `setAdditionalPain` is called unconditionally regardless of current arm pain — no `getPain() < 20` guard.
  - Active zero-reset: when weight drops to <= 20 or backpack is removed, the handler sets pain to 0 on the same minute tick. This is a behavioral addition absent from the source.
  - Frequency: `EveryOneMinute` (once per in-game minute) vs source `OnTick` (every game frame). The per-minute rate means pain is re-evaluated and re-applied once per minute rather than each frame.

## Description Integrity

- Display name check: "Flimsy" — matches source trait name exactly.
- Description check: `UI_UT_flimsyDesc` reads: "You are not built for physical exertion. Strength and endurance are reduced."
- Issues found:
  1. **Description does not match the implemented mechanic.** The code applies upper arm pain when carrying a heavy backpack (>20 weight). The description states that "Strength and endurance are reduced." There is no Strength or Endurance stat modification in the runtime file — no `XPBoost`, no stat multiplier, no perk-level change. The description describes effects that do not exist in the code.
  2. **The actual mechanic (arm pain from heavy backpack) is not mentioned.** A player reading the description has no indication that carrying a backpack over 20 weight causes upper arm pain. The source description ("Wearing heavy bags on the back causes upper arms pain which can drastically slow down the attack speed") accurately described the mechanic; the UT description replaces it with a fabricated one.
  3. **"Strength and endurance are reduced" implies static stat penalties.** Static reductions would typically appear as `XPBoost` or `StatModifier` entries in the script definition. No such entries exist. The description is not only wrong about the stat names but wrong about the nature of the penalty (it is dynamic and conditional on backpack weight, not a permanent static reduction).
  4. **Attack speed consequence is omitted.** The source description identified the downstream consequence — "drastically slow down the attack speed" — because arm pain in PZ directly impairs attack speed. The UT description makes no reference to this consequence, leaving players unaware that carrying weight impairs combat.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside: `setAdditionalPain` on both upper arms, scaled by `weight * 0.1`, capped at 20, applied once per in-game minute when backpack contents exceed 20 weight.
- Pain consequence in PZ: upper arm pain increases weapon swing time (attack speed penalty). The penalty is proportional to pain level. At pain = 20 (cap), the attack speed reduction is significant; at pain = 2–3 (typical mid-weight backpack), the effect is mild.
- Uptime: active only when a backpack is worn with >20 contents weight. Many early-game players carry under 20 units; the trait may have no effect early. In looting-heavy mid/late game where backpacks routinely exceed 20 weight, the pain accumulates to moderate levels.
- Active reset behavior (UT-specific, absent in source): when weight drops to or below 20, or the backpack is removed, arm pain is zeroed within one in-game minute. This makes the effect highly reversible: dropping or lightening the pack restores full attack speed promptly.
- Source cost comparison: source cost was -4 across all reviewed versions (B42.12 registration, B42.13 and B42.15 script definitions). UT cost is also -4. The cost is consistent with the source.
- Divergence impact on balance: the UT version adds a hard pain cap at 20 (via `math.min`) not present in the source formula, and adds active zero-reset when weight drops. These changes make the UT version strictly milder than the source: the source had no cap on `extraPain` from the formula (only the `getPain() < 20` guard), and the source never actively cleared pain on weight reduction. At -4 points this is potentially underpriced relative to the UT implementation's milder behavior.
- Event cadence impact: source fired every tick; UT fires once per minute. This means pain is re-evaluated at a much lower rate. In the source, a one-tick backpack pickup would begin applying pain immediately. In UT, there is up to one in-game minute of lag before pain is first applied and up to one minute before pain is cleared after the backpack is removed or lightened.
- Stack or exclusion notes: no `MutuallyExclusiveTraits` declared. No natural UT conflicts excluded. The `DynamicTraitsExpandedMoodles` mod (present in installed-mods) also references "Flimsy" as a separate trait key (plain "Flimsy", not "SWTraits:SWFlimsy" or "UniversalTraits:UT_flimsy"). These are distinct trait IDs and do not conflict with UT_flimsy.
- Cost verdict: -4 matches the source cost and is reasonable given the conditional, weight-gated, reversible nature of the penalty. However, the milder UT implementation (capped pain, active reset, once-per-minute cadence) compared to source arguably warrants -3 if strict parity with source power level were the goal.

## Regression Proof

- Existing test: `"UniversalTraits:UT_flimsy"` is listed in the Phase registration sweep (`run_tests.lua` line 228, "Stat Modifiers (20)" group), which confirms the trait ID is registered with `CharacterTrait`.
- What it proves: the trait ID `"UniversalTraits:UT_flimsy"` exists in the CharacterTrait registry. It does not test runtime behavior.
- Missing proof:
  1. No test that `EveryOneMinute` fires `handler` and sets `setAdditionalPain` on both arms when `weight > 20`.
  2. No test of the exact pain formula `math.min(weight * 0.1, 20)` — that the computed pain value matches expected values at boundary weights (21, 30, 200).
  3. No test that `setAdditionalPain(0)` is called when `weight <= 20`.
  4. No test that `setAdditionalPain(0)` is called when no backpack is equipped.
  5. No test that the handler exits when `player:getBodyDamage()` returns nil.
  6. No test that the handler exits when either arm body part is nil.
  7. No test that the handler exits when the player does not have the trait.
  8. No test of the `UTCore.registerPeriodicHandler` idempotency guarantee for this trait specifically.
- Minimum next test if needed: "flimsy: arm pain set to `weight * 0.1` when backpack weight > 20" — mock player with the trait, mock backpack returning `getContentsWeight() = 30`, mock both arm body parts, fire `EveryOneMinute`, assert both arms received `setAdditionalPain(3.0)`.

## Final Verdict

- Source origin: proven — SomewhatTraits `SWFlimsy` is the confirmed source across B42.12, B42.13, and B42.15. Source cost (-4) matches UT cost (-4) exactly across all reviewed versions.
- UT implementation: drifted from source with three structural differences:
  1. **Pain cap added**: UT applies `math.min(weight * 0.1, 20)` — pain is hard-capped at 20. The source applied `extraPain = contentsWeight * 0.1` with only a conditional guard (`getPain() < 20` — skip if arm pain already >= 20). The UT cap limits the formula output; the source guard was a skip-if-already-high check, not a formula cap. In practice both limit pain to 20 units, but the mechanism differs: the source would allow `extraPain` to exceed 20 and still skip, while UT always delivers exactly `math.min(weight * 0.1, 20)`.
  2. **Active zero-reset added**: When backpack weight drops to <= 20, or the backpack is absent, UT immediately calls `setAdditionalPain(0)` on both arms. The source never cleared pain — it only stopped applying new pain, leaving decay to the normal PZ system. The UT reset is a material behavioral addition that makes the effect more reversible.
  3. **Event frequency changed**: source fired every game tick (`OnTick`); UT fires once per in-game minute (`EveryOneMinute`). Pain is reapplied — and reset — at a much coarser interval.
- Description: **false** — the description says "Strength and endurance are reduced," which does not correspond to anything in the runtime code. The actual effect (upper arm pain proportional to backpack weight) is not mentioned at all. The source description accurately described the mechanic; the UT description replaced it with fabricated static stat penalties. This is the most serious finding in this audit.
- Balance: conditionally acceptable at -4 (matches source cost); the UT implementation is milder than the source due to the active reset and coarser cadence, which slightly undermines the -4 valuation. The core mechanic (arm pain from heavy packs, attack speed reduction) is real and meaningful in mid/late game play.
- Regression proof: registration confirmed; zero behavioral tests exist for this trait.
- Action needed:
  1. **Fix description immediately** — replace `UI_UT_flimsyDesc`. The current text is factually incorrect. Suggested replacement (matching actual mechanic): "Carrying a heavy backpack strains your upper arms, causing pain that slows your attack speed. The heavier the load, the worse the strain." This reflects the weight threshold (>20), the arm pain effect, and the attack speed consequence without overstating anything.
  2. **Decide on the active zero-reset** — the `setAdditionalPain(0)` call on weight <= 20 or pack removal is a UT design addition not present in the source. Decide deliberately whether this is intentional (forgiving, reversible design) or an oversight. If intentional, it is fine and arguably good UX. Document the decision.
  3. **Verify `setAdditionalPain` semantics** — confirm that `setAdditionalPain` in B42 PZ sets the "additional" pain component independently of base pain, so calling it once per minute overwrites the previous additional pain value (rather than accumulating). If it accumulates, the once-per-minute cadence would cause unbounded pain growth. This is a correctness risk requiring verification against the PZ Java source.
  4. **Add behavioral tests** for: arm pain set at weight 21 and 30, pain capped at weight 200, zero-reset at weight <= 20, zero-reset with no backpack, and handler guard conditions (nil bodyDamage, nil arm parts, trait absent).
- Open gaps:
  - `setAdditionalPain` accumulation vs overwrite behavior is not confirmed from reviewed files; this is a potential correctness risk if the value accumulates across ticks.
  - No mutual exclusions in UT or source; consider whether pairing with `UT_packmule` or `UT_backpacker` (which encourage carrying more weight) creates a thematic conflict worth excluding.
