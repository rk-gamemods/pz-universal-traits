# UT_anorexy

## Trait Summary
- UT trait id: UT_anorexy
- Source mod: DynamicTraitsExpandedMoodles (Dynamic Traits — DTEM)
- Source trait id: `"Anorexy"` (unnamespaced, vanilla-style key)
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/NPCs/DTEMMainCreationMethods.lua`
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMByOtherConditions.lua`
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMMainFile.lua`
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/Translate/EN/UI_EN.txt`
  - All 654 indexed files in `local/installed-mods-b571c288` searched for "anorex" — only DTEM matched
- Source registration: `TraitFactory.addTrait("Anorexy", getText("UI_trait_Anorexy"), -6, getText("UI_trait_AnorexyDesc"), false)` — `DTEMMainCreationMethods.lua` line 474
- Source trigger path:
  - `DTEMMainFile.lua` — on every player update tick, calls `DTEManorexyTrait(player)` unconditionally (line 119), then `DTEManorexyTraitHungerSymptoms(player)` (line 80) and `DTEManorexyTraitPassiveSymptoms(player)` (line 121) only if the player `HasTrait("Anorexy")`
- Source behavior (summarized from `DTEMByOtherConditions.lua`):
  - `DTEManorexyTrait(player)` is a **counter-based dynamic trait acquisition function**. It reads and updates `player:getModData().DTEManorexyTrait` (an integer counter, clamped between -1080 and +1080) every tick.
  - Counter decreases (trait approaches) when player has "Emaciated" or "Very Underweight" body type, scaled by Unhappy and Stress moodle levels (-1 to -5 each per tick, per moodle), plus occasional lucky/unlucky modifier (ZombRand(10) == 0 gate).
  - Counter increases (trait recedes) when player is "Underweight" (+1 or +2 per tick), or has any other body type (+2 or +3 per tick), also with lucky/unlucky modifier.
  - Threshold: counter reaching -720 adds "Anorexy"; counter reaching +720 removes it.
  - `DTEManorexyTraitHungerSymptoms(player)` applies ongoing penalties whenever the trait is active and the player is eating (based on FoodEaten moodle level 1–4): increasing unhappiness, stress, and food sickness at each FoodEaten level.
  - `DTEManorexyTraitPassiveSymptoms(player)` applies passive ongoing negative effects while the trait is held (not read in detail but confirmed present).
- Source display name: `"Anorexia"` (via `UI_trait_Anorexy`)
- Source description: `"Eating disorder. Intense fear of gaining weight."` (via `UI_trait_AnorexyDesc`)
- Source cost: **-6** (negative trait)
- Source exclusions (set via `TraitFactory.setMutualExclusive`): Overweight, Obese, Strong, Athletic

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_anorexy = CharacterTrait.register("UniversalTraits:UT_anorexy")` at line 279 of `media/registries.lua`, in the Phase 3c — Event-Driven block (below UT_maniac)
- Defined in UT_character_traits.txt: yes — lines 1948–1957
  - `Cost = -6`
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_anorexy`
  - `UIName = UI_UT_anorexy`
  - `UIDescription = UI_UT_anorexyDesc`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_gourmand;UniversalTraits:UT_competitiveeater;UniversalTraits:UT_mundane`
- Translation strings present: yes — `media/lua/shared/Translate/EN/UI_EN.txt` lines 605–606
  - `UI_UT_anorexy = "Anorexia"`
  - `UI_UT_anorexyDesc = "Your relationship with food is deeply complicated. Eating feels wrong, and your body pays the price for every meal."`
- Exclusions verified (all cross-checked against counterpart script blocks):
  - `UT_anorexy` → `UT_gourmand`: `UT_gourmand` (line 1590) also lists `UT_anorexy` in its own exclusion set — **bidirectional confirmed**
  - `UT_anorexy` → `UT_competitiveeater`: `UT_competitiveeater` (line 1997) also lists `UT_anorexy` — **bidirectional confirmed**
  - `UT_anorexy` → `UT_mundane`: `UT_mundane` (line 1377) also lists `UT_anorexy` — **bidirectional confirmed**
  - All three mutual exclusion pairs are symmetrical in the script file.
  - `UT_ascetic` (line 1601) lists `UT_gourmand` and `UT_mundane` but does **not** list `UT_anorexy` — `UT_ascetic` and `UT_anorexy` are not mutually exclusive and can be taken simultaneously.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_anorexy.lua` (25 lines)

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_anorexy.lua` (full file, 25 lines — complete text verified)
  - `media/registries.lua` lines 276–290 (registration context)
  - `media/scripts/UT_character_traits.txt` lines 1948–1957 (script definition)
  - `media/lua/shared/Translate/EN/UI_EN.txt` lines 605–606 (translation strings)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (full file — `UTCore.hasTrait` definition)
- Event registrations: `Events.OnPlayerUpdate.Add(onPlayerUpdate)` — line 24 of the trait Lua file
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
  - Defined in `UTCore_API.lua`: nil-safe check — returns `false` if `player` is nil or `player:getTraits()` is nil; otherwise returns `player:getTraits():contains(traitId)`
  - No other UTCore hooks used (no periodic hook, no spawn effect, no stat modifier hook, no custom event hook)
- ModData key used: `md["UT_anorexy_prevTimer"]` — raw moddata key (not using the `UTCore.setModData`/`UTCore.getModData` helpers, which would prefix with `"UT_"`)
- Runtime chain (plain language):
  1. `onPlayerUpdate` fires on **every player update tick** (no throttle).
  2. `UTCore.hasTrait(player, TRAIT_ID)` is checked first; if the player does not have `"UniversalTraits:UT_anorexy"`, the function returns immediately with no work done.
  3. `player:getModData()` is retrieved into `md`. `player:getBodyDamage():getHealthFromFoodTimer()` is read into `healTimer`. `md["UT_anorexy_prevTimer"]` is read into `prev`.
  4. **Rising-edge detection**: if `prev` is not nil AND `healTimer > prev + 50`, a `pcall` block fires:
     - `player:getStats():add(CharacterStat.STRESS, 10)` — stress is increased by exactly **10**
     - Any error inside the `pcall` is silently swallowed
  5. `md["UT_anorexy_prevTimer"]` is unconditionally written to the current `healTimer` value at the end of every tick (line 21), storing state for the next tick's comparison.
- Actual behavior (exact values):
  - **Trigger condition**: `getHealthFromFoodTimer()` must jump by more than 50 between two consecutive ticks. This detects the moment food is consumed (the health-from-food timer is set to a high value when food is eaten, then drains over time).
  - **Effect on trigger**: stress increased by exactly +10, wrapped in `pcall`.
  - **Cadence**: fires once per eating event. After the jump tick, subsequent ticks see a declining or stable timer and do not re-trigger until the next eating event.
  - **First-tick guard**: `prev ~= nil` ensures no spurious trigger on the very first tick after load (when `prev` has never been set). The very first call stores `healTimer` in moddata and exits without applying stress.
  - **No health, hunger, boredom, or nausea effects** — the trait is strictly a stress spike on eating, nothing else.
  - **No recovery mechanic** — there is no mechanism to reduce the stress applied; the trait accumulates stress every time the player eats but provides no relief or offsetting benefit.

## Description Integrity
- Display name check: `"Anorexia"` — accurate and unambiguous. No issue.
- Description check: `"Your relationship with food is deeply complicated. Eating feels wrong, and your body pays the price for every meal."`
- Accuracy issues found:
  1. **No mechanical disclosure** — the description is entirely flavour text. It mentions "your body pays the price" but does not state what the price is (stress +10), how it is triggered (eating), or that the effect fires per meal. A player cannot determine the mechanics from the description alone.
  2. **"pays the price for every meal"** — directionally accurate (fires once per eating event), but the phrase "every meal" overstates the precision. The trigger is a rising edge on `getHealthFromFoodTimer()` jumping by more than 50, which corresponds to eating; the description is not technically wrong but gives no actionable number.
  3. **Omission of exclusions** — the description does not hint at the food-positive trait exclusions (UT_gourmand, UT_competitiveeater, UT_mundane), though exclusion disclosure is not required in any other audited trait's description.

## Balance Review
- Upside: none — this is a pure negative trait (-6 points cost, no positive effect)
- Downside: stress increased by +10 each time the player eats (once per eating event, rising-edge detection)
- Uptime: once per eating event; stress accumulates with eating frequency; no recovery mechanism within the trait
- Cost: -6 points (negative trait — player earns 6 points by taking it)
- Source cost: -6 (exact match with DTEM source)
- Peer comparison:
  - `UT_sensitivestomach` (-4 points) uses the same `getHealthFromFoodTimer` rising-edge pattern to apply pain and nausea (food sickness). Stress +10 per meal (anorexy) is a different stat axis but same mechanical pattern. Anorexy costs 2 more points, which is plausible if stress accumulation is considered a harder-to-manage penalty than the pain/nausea of sensitivestomach — though both are per-meal, single-stat spikes.
  - `UT_competitiveeater` (+3 points) is the positive mirror via the same detection pattern, applying boredom -10 and hunger -5 per meal. The asymmetry of +3 (positive) vs -6 (negative) reflects that stress accumulation has no natural cap and compounds over long play sessions, making it a more persistent burden than a one-time comfort boost.
  - `UT_gourmand` (+4 points) gives ongoing hunger multiplier; its mutual exclusion with UT_anorexy prevents the food-positive boost from masking the food-negative penalty.
  - `UT_mundane` (-9 points) is mutually exclusive; its own downside is broader and more severe, so the exclusion makes thematic sense — both constrain food-related play but in incompatible ways.
  - DTEM source had a much richer behavior (counter-based acquisition, unhappiness/stress escalation, food sickness on eating, passive symptoms) — the UT implementation is a significant **simplification**. The -6 cost is preserved from source but the penalty mechanism is reduced to a single stress spike on eating.
- Stack or exclusion notes:
  - Mutual exclusions are fully bidirectional (confirmed above): UT_gourmand, UT_competitiveeater, UT_mundane are all blocked.
  - `UT_ascetic` is NOT excluded — a player can have both UT_anorexy and UT_ascetic simultaneously. UT_ascetic reduces food-related needs (if it applies reduced hunger consumption); pairing it with UT_anorexy means the player eats less often, which indirectly reduces how often UT_anorexy's stress spike fires. This interaction is not documented or declared.
  - `DisabledInMultiplayer = true` — the per-player rising-edge moddata key is per-player stateless; the multiplayer restriction appears conservative. Not a bug, but worth noting.
- Cost verdict: plausible — -6 for stress +10 per meal is consistent with the source cost. However, the UT implementation is substantially milder than the source (DTEM's version included counter-based dynamic acquisition, food sickness symptoms, and passive ongoing penalties). The cost accuracy relative to UT's actual behavior (stress spike only) may be slightly generous to the player — i.e., the trait might be worth more than -6 given how narrow the penalty is.

## Regression Proof
- Existing tests:
  - `test/run_tests.lua` line 298: `"UniversalTraits:UT_anorexy"` appears in the `expected_ids` table (Phase 3c — Event-Driven group). Proves the trait is enumerable in the full registration count test.
  - No dedicated named test block for `UT_anorexy` found in `run_tests.lua`.
- What the tests prove: the trait ID is registered and appears in the enumeration list. Nothing more.
- Missing proof:
  - No test verifies the rising-edge detection (`healTimer > prev + 50` fires exactly once per eating event).
  - No test verifies the exact stat delta (`CharacterStat.STRESS +10`).
  - No test verifies the nil-guard on `prev` (no spurious stress spike on the very first tick).
  - No test verifies that `md["UT_anorexy_prevTimer"]` is persisted correctly between ticks.
  - No test verifies that the `pcall` wrapper silently swallows errors from `stats:add`.
  - No test verifies that the guard returns immediately when `UTCore.hasTrait` is false.
  - No test verifies mutual exclusion enforcement with UT_gourmand, UT_competitiveeater, or UT_mundane.
- Minimum next test if needed: Mock a player carrying `"UniversalTraits:UT_anorexy"`. Tick 1: `getHealthFromFoodTimer()` returns 0 — assert no stress applied, `md["UT_anorexy_prevTimer"]` == 0. Tick 2: timer returns 200 (200 > 0+50 → trigger) — assert `CharacterStat.STRESS` was incremented by exactly 10. Tick 3: timer returns 190 (declining — no trigger) — assert no additional stress applied.

## Final Verdict
- Source origin: DynamicTraitsExpandedMoodles — `"Anorexy"` trait, cost -6, registered via `TraitFactory.addTrait`. Source is a complex dynamic-acquisition trait with counter mechanics, escalating moodle-based symptoms, food sickness on eating, and passive ongoing effects. UT retains the display name ("Anorexia"), cost (-6), and the core concept (food causes distress) but implements only a single simplified mechanic.
- UT implementation: correct and self-consistent — rising-edge detection on `getHealthFromFoodTimer()` fires once per eating event and applies stress +10 via `pcall`; prev-timer nil-guard prevents spurious first-tick trigger; early-exit guard via `UTCore.hasTrait` is efficient. The implementation is a significant simplification of the source behavior.
- Description: pure flavour text — directionally accurate but discloses no mechanical information (no stat named, no value, no trigger condition). A player cannot determine from the description that eating causes stress, by how much, or when.
- Balance: plausible — cost preserved from source; stress +10 per meal is a real but narrow penalty. The cost may be slightly generous given how much simpler the UT version is versus the multi-axis DTEM original. The UT_ascetic stacking interaction (eating less often = fewer stress spikes) is undeclared.
- Regression proof: minimal — registration enumeration only; no behavioral coverage.
- Action needed: description fix (primary); optional cost re-review (secondary); optional test additions.
- Open gaps:
  1. **Description must be corrected**: it must disclose that eating triggers a stress increase of +10 per meal; remove or replace "pays the price" with the actual mechanic.
  2. **UT_ascetic coexistence**: confirm whether the absence of mutual exclusion between UT_anorexy and UT_ascetic is intentional. A player who eats less (ascetic) will trigger the stress spike less often — this may be a meaningful interaction or an oversight.
  3. **Cost re-review against UT behavior**: source cost -6 was calibrated against DTEM's full multi-axis behavior (counter, symptoms, food sickness, passive effects). UT's version is stress +10 per meal only. Consider whether -6 is still appropriate or whether the trait should be repriced relative to its simpler UT behavior (e.g., -4 to align with UT_sensitivestomach's narrower-scope per-meal penalty).
  4. **ModData key uses raw string key** (`md["UT_anorexy_prevTimer"]`) rather than `UTCore.setModData`/`UTCore.getModData` helpers — inconsistent with the helper convention; will not conflict but breaks the convention used elsewhere.
  5. **`DisabledInMultiplayer = true`**: the rising-edge detection is per-player and moddata-isolated; confirm whether this restriction is intentional or a blanket setting.
  6. **No test coverage** for rising-edge detection, stat application, or nil-guard behavior; add behavioral unit tests before this trait is considered regression-safe.
