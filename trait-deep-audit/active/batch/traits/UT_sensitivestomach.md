# UT_sensitivestomach
## Trait Summary
- UT trait id: UT_sensitivestomach
- Source mod: More Simple Traits (MoreSimpleTraits by the MST author)
- Source trait id: SensitiveStomach (unnamespaced, B41)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` (B41 implementation, lines 629–651)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/client/MSTMainFile.lua` (Vanilla variant, lines 629–651 — identical implementation)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` (trait registration, line 117)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua` (trait registration, line 97)
- Source behavior (B41, `MSTMainFile.lua`):
  - A single function `sensitivestomach()` handles the trait, registered on `Events.OnPlayerUpdate` with no throttle — fires every game tick.
  - Calls `getPlayer()` (single-player only; uses `getPlayer()` not a player argument).
  - Reads `HealByFoodTimer = player:getBodyDamage():getHealthFromFoodTimer()`.
  - Checks `player:HasTrait("SensitiveStomach")` (unnamespaced string).
  - If `HealByFoodTimer > 1000`:
    - Initialises `playerdata.fPreviousHealthFromFoodTimer = 1000` if nil.
    - If `HealByFoodTimer > fPreviousHealthFromFoodTimer` (food timer is actively rising — digestion in progress):
      - Reads `Torso_Lower` body part via `BodyPartType.FromString("Torso_Lower")`. No nil-guard on the body part.
      - Computes `pain = (HealByFoodTimer - fPreviousHealthFromFoodTimer) * (0.003 * (ZombRand(2) + 3))`. The multiplier is `0.003 * {3 or 4}`, i.e., 0.009 or 0.012, applied to the per-tick delta in the food timer.
      - Calls `MSTincreasePoison(player, 0, (ZombRand(11)+5+pain) * 0.3)` — applies a poison/nausea increment. `ZombRand(11)+5` = 5–15 base, plus the pain delta, times 0.3.
      - Sets `Torso_Lower:setAdditionalPain(Torso_Lower:getAdditionalPain() + pain)`.
      - Clamps: `if Torso_Lower:getAdditionalPain() >= 100 then Torso_Lower:setAdditionalPain(100) end`.
    - Updates `playerdata.fPreviousHealthFromFoodTimer = HealByFoodTimer`.
- Source trigger path: `Events.OnPlayerUpdate` (polled every tick, no throttle) → `sensitivestomach()`.
- Source detection mechanism: `getHealthFromFoodTimer()` — a rising value while food is actively healing the player. The function only triggers when this value is both above 1000 and actively increasing tick-over-tick, isolating the active digestion window.
- Source effects: two concurrent effects per active-digestion tick —
  1. **Lower torso pain**: proportional to the per-tick rise in the food timer, randomised multiplier (0.009–0.012), clamped at 100.
  2. **Nausea/poison**: `MSTincreasePoison` call with a random base (5–15) plus the pain delta, scaled by 0.3. This fills the MST poison/nausea internal counter.
- Source trait registration: `TraitFactory.addTrait("SensitiveStomach", ..., -2, ...)` — cost **-2** in source, not -4.
- Source EN strings (from registration calls): `getText("UI_trait_sensitivestomach")` / `getText("UI_trait_sensitivestomachdesc")` — exact strings not present in the indexed source files; names inferred from key patterns.

## Current UT Evidence
### Structure
- Registered in run_tests.lua: yes — `"UniversalTraits:UT_sensitivestomach"` appears at line 294 in the Phase 3c — Event-Driven block, on the same line as `UT_competitiveeater`.
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_sensitivestomach`, `IsProfessionTrait = false`, `DisabledInMultiplayer = true`, `Cost = -4`. No `MutuallyExclusiveTraits` field present.
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_sensitivestomach = CharacterTrait.register("UniversalTraits:UT_sensitivestomach")` at line 284, in the Phase 3c block between `UT_competitiveeater` and `UT_butterfingers`.
- Translation strings present: yes —
  - `UI_UT_sensitivestomach = "Sensitive Stomach"` (line 620, UI_EN.txt)
  - `UI_UT_sensitivestomachDesc = "Your digestive system does not take kindly to stress or poor food. Meals that others handle fine can leave you miserable."` (line 621, UI_EN.txt)
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sensitivestomach.lua`

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sensitivestomach.lua` (full file, 32 lines)
  - `UniversalTraits/media/scripts/UT_character_traits.txt` (lines 2000–2008)
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` (lines 620–621)
  - `UniversalTraits/test/run_tests.lua` (line 294)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` (lines 629–651, source)
- Event registrations: `Events.OnPlayerUpdate.Add(onPlayerUpdate)` — registered once at module load time. No guard against multiple registrations.
- Runtime chain (plain language):
  1. Every game tick, `onPlayerUpdate(player)` fires.
  2. Checks `UTCore.hasTrait(player, "UniversalTraits:UT_sensitivestomach")`. If not present, returns immediately.
  3. Reads `md = player:getModData()` and `healTimer = player:getBodyDamage():getHealthFromFoodTimer()`.
  4. If `healTimer > 1000`:
     a. Initialises `md["UT_prevFoodTimer"] = 1000` if nil.
     b. If `healTimer > md["UT_prevFoodTimer"]` (food timer is actively rising):
        - Enters a `pcall` wrapper.
        - Reads `torsoLower = player:getBodyDamage():getBodyPart(BodyPartType.FromString("Torso_Lower"))`.
        - If `torsoLower` is non-nil:
          - Computes `pain = (healTimer - md["UT_prevFoodTimer"]) * (0.003 * (ZombRand(2) + 3))`.
          - Sets `torsoLower:setAdditionalPain(math.min(100, torsoLower:getAdditionalPain() + pain))`.
     c. Updates `md["UT_prevFoodTimer"] = healTimer`.
- Actual behavior (UT implementation, exact from source):
  - Fires every tick while the player has the trait (no throttle).
  - Only acts during active digestion: `healTimer` must exceed 1000 and be rising tick-over-tick.
  - Applies lower torso pain proportional to the per-tick increase in the food healing timer, with a randomised multiplier (0.009 or 0.012), clamped at 100 via `math.min`.
  - Body part access is wrapped in `pcall` — a nil `torsoLower` silently no-ops without erroring.
  - No poison/nausea mechanic — only lower torso pain.
  - No recovery logic — pain decays via native game mechanics on its own schedule.

## UT Divergences from Source
1. **Nausea removed**: Source calls `MSTincreasePoison(player, 0, ...)` on every active-digestion tick, filling an internal nausea/poison counter. UT has no equivalent call — the nausea/poison effect is entirely absent.
2. **pcall guard added**: Source accesses `Torso_Lower` without a nil-guard and without pcall — a missing body part would error. UT wraps the body-part block in `pcall` and nil-checks `torsoLower`. This is a safety improvement over source.
3. **Pain cap method**: Source uses a two-step if/then clamp (`if >= 100 then set(100)`). UT uses `math.min(100, current + pain)` in a single call. Functionally equivalent.
4. **ModData key renamed**: Source uses `playerdata.fPreviousHealthFromFoodTimer`. UT uses `md["UT_prevFoodTimer"]` — namespaced to avoid collision with other mods.
5. **Player argument vs. getPlayer()**: Source calls `getPlayer()` (B41 single-player pattern). UT receives `player` as a function argument from `Events.OnPlayerUpdate` (correct B42 multi-player pattern, though the trait is `DisabledInMultiplayer`).
6. **Trait check**: Source uses `player:HasTrait("SensitiveStomach")` (unnamespaced B41 string). UT uses `UTCore.hasTrait(player, "UniversalTraits:UT_sensitivestomach")` (namespaced B42 pattern via UTCore).
7. **Cost**: Source registers the trait at **-2** (`TraitFactory.addTrait(..., -2, ...)`). UT defines it at **-4** — doubled relative to source.
8. **Throttle**: Source polls every tick with no throttle. UT also polls every tick with no throttle. No divergence on this axis, but neither version throttles.
9. **Nausea absence is a significant departure**: The source's two-effect design (pain + nausea) is more severe and more thematically coherent with the description. UT delivers only pain. A player with a "sensitive stomach" who experiences only lower back/torso pain with no nausea would find the name and description misleading.

## Description Integrity
- Display name check: `"Sensitive Stomach"` — matches source concept; accurate.
- Description check: `"Your digestive system does not take kindly to stress or poor food. Meals that others handle fine can leave you miserable."` — thematically plausible but factually inconsistent with the implementation on two counts:
  1. "Does not take kindly to stress or poor food" — the trait does not inspect food quality or stress at all. It fires on any active digestion (`getHealthFromFoodTimer() > 1000`), regardless of what was eaten or the player's stress level.
  2. "Leave you miserable" — the only implemented effect is lower torso pain during digestion. There is no nausea, no sickness display, no mood penalty. "Miserable" implies a broader or more visible debuff than intermittent torso pain.
- Missing details: The description does not name the mechanical effect (lower torso pain), does not indicate that the trigger is active digestion detected via `getHealthFromFoodTimer`, and gives no indication of severity or rate. A player cannot determine the actual mechanical impact from the description.

## Balance Review
- Downside: lower torso additional pain proportional to the per-tick rise in `getHealthFromFoodTimer()`, with a random multiplier of 0.009–0.012, applied only while the food timer is actively rising and above 1000. In practice this means pain accumulates gradually over the digestion window rather than spiking. The pain is capped at 100.
- Upside: none. Pure negative trait.
- Severity assessment: mild to moderate. The pain mechanic is real — high enough accumulated torso pain creates a debuff and triggers pain animations — but it is entirely absent outside active digestion windows, which are finite. No nausea, no sickness bar, no mood effect, no health drain. Compare to source: source added nausea (`MSTincreasePoison`) on top of the same pain formula, making the trait considerably more punishing. UT's pain-only implementation is meaningfully weaker.
- Cost: -4 points. Source cost is **-2**. UT doubled the cost without adding the nausea component that would justify the increase. A pain-only trait with no nausea, no health drain, and no effect outside digestion windows does not warrant -4 by source precedent. Cost of -4 is generous to the mod designer (high refund for a low-impact trait) and generous to players (cheap to absorb in character builds).
- Peer comparison:
  - `UT_anorexy` (cost -4): food-related negative trait; full reviewed behavior not available in this session but sits at the same cost tier.
  - `UT_competitiveeater` (cost +3): positive food trait registered immediately before `UT_sensitivestomach` in both the script file and registries. No mutual exclusion defined between them — a player could take both a positive eating trait and a sensitive stomach negative trait simultaneously. Whether this is intended is unclear.
- Uptime: present only during active digestion windows (food timer > 1000 and rising). Zero effect otherwise.
- Stack or exclusion notes: no `MutuallyExclusiveTraits` defined. Nothing prevents taking `UT_sensitivestomach` alongside `UT_competitiveeater` (competitive eater + sensitive stomach), which is thematically incongruent. No exclusion against `UT_anorexy` (anorexia + sensitive stomach could co-exist from a script standpoint).

## Regression Proof
- Existing tests (run_tests.lua): `"UniversalTraits:UT_sensitivestomach"` appears at line 294 in the Phase 3c — Event-Driven block. It is included in the batch registration test that confirms all trait IDs register with `CharacterTrait` without error. No dedicated behavior test exists for this trait.
- What the registration test proves: the trait ID is registered with `CharacterTrait.register` without error at load time. It does not test any runtime behavior.
- Missing proof:
  - No test verifies that lower torso pain increases during an active digestion window.
  - No test verifies that no pain is applied when the food timer is not rising or is below 1000.
  - No test verifies the pain cap at 100 (i.e., that `math.min` prevents exceeding the maximum).
  - No test verifies that `md["UT_prevFoodTimer"]` is initialised to 1000 on first call, not nil.
  - No test verifies that `pcall` silently absorbs a nil `torsoLower` without propagating an error.
  - No test verifies that the function is a no-op for players without the trait.
- Minimum next tests if needed:
  - Test: player with trait, `healTimer` rising from 1001 to 1010 over two ticks → `torsoLower:getAdditionalPain()` increases by approximately `9 * 0.009` to `9 * 0.012` (delta 9, multiplier range).
  - Test: player with trait, `healTimer` steady at 1050 (not rising) → `getAdditionalPain()` unchanged.
  - Test: player with trait, `healTimer` at 990 (below 1000) → `getAdditionalPain()` unchanged.
  - Test: player without trait → `onPlayerUpdate` returns immediately; `getAdditionalPain()` unchanged.
  - Test: `torsoLower` returns nil (mock) → `pcall` absorbs error; no uncaught exception propagated.
  - Test: cumulative pain at 98, one tick with pain delta of 5 → `getAdditionalPain()` is 100, not 103.

## Final Verdict
- Source origin: confirmed — trait originates from More Simple Traits (`SensitiveStomach`), source cost -2. The name is preserved; the cost is doubled in UT.
- UT implementation: partial port — the pain mechanic is faithfully ported with improvements (pcall guard, nil-check, namespaced modData key, correct B42 player argument). However, the nausea/poison component (`MSTincreasePoison`) present in source is entirely absent from UT.
- Description: thematically plausible but mechanically inaccurate — references "stress or poor food" (no food-quality or stress check in code) and implies general misery (only lower torso pain is implemented; no nausea). A player cannot determine what the trait actually does from the description.
- Balance: cost is inflated relative to implementation — UT charges -4 for an effect that source valued at -2 and that UT delivers at reduced severity (no nausea component). The trait provides a weak-to-moderate negative for a high refund.
- Regression proof: registration only — no behavior tests exist.
- Action needed: doc fix, behavior review, balance review
- Open gaps:
  1. **Nausea gap**: decide whether to implement a nausea equivalent (e.g., raise `FakeInfectionLevel` or a stress increment) to restore the second source effect and justify the -4 cost, or accept pain-only and reduce cost to -2 to match source value.
  2. **Cost mismatch**: source cost is -2; UT charges -4. If the nausea component is not restored, cost should be revisited downward.
  3. **Description rewrite needed**: remove the reference to "stress or poor food" (no such check exists); remove "miserable" or replace with a concrete description of the actual effect (lower torso pain during digestion). If nausea is added, the description becomes accurate as-is.
  4. **Mutual exclusion gap**: no `MutuallyExclusiveTraits` defined. Evaluate whether `UT_competitiveeater` (competitive eater) should be mutually exclusive — a character who eats competitively and enthusiastically coexisting with a sensitive stomach is thematically ambiguous.
  5. **No behavior tests**: add at minimum: pain-increases-during-digestion, no-effect-outside-digestion, pain-cap-at-100, no-op-without-trait, pcall-absorbs-nil-body-part.
  6. **Throttle consideration**: neither source nor UT throttle the `OnPlayerUpdate` handler. For a trait whose condition (food timer rising) is already inherently infrequent, this is acceptable but worth noting if performance becomes a concern across many traits.
