# UT_competitiveeater

## Trait Summary
- UT trait id: UT_competitiveeater
- Source mod: none — no matching trait found in any installed-mod source file; original design
- Source trait id: n/a
- Current cost: 3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/` — searched recursively for "competitiveeater", "CompetitiveEater", and "competitive" across all 654 indexed files in `local/installed-mods-b571c288`; zero results returned
- Source registration: none found
- Source trigger path: n/a — no source trait located
- Source behavior: n/a
- Source display name: n/a
- Source description: n/a
- Source cost: n/a
- Source exclusions: n/a

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_competitiveeater = CharacterTrait.register("UniversalTraits:UT_competitiveeater")` at line 283 of `media/registries.lua`, in the Phase 3c — Event-Driven block
- Defined in UT_character_traits.txt: yes — lines 1989–1998
  - `Cost = 3`
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_anorexy`
- Translation strings present: yes
  - `UI_UT_competitiveeater = "Competitive Eater"`
  - `UI_UT_competitiveeaterDesc = "You eat with purpose and efficiency. Every meal is an event you approach with genuine enthusiasm and unusual results."`
- Exclusions verified:
  - `UT_competitiveeater` lists `UT_anorexy` in its exclusion set (line 1997)
  - `UT_anorexy` lists `UT_competitiveeater` in its exclusion set (line 1956) — bidirectional confirmed
  - `UT_gourmand` is NOT listed in `UT_competitiveeater`'s exclusion set; however, `UT_anorexy` lists both `UT_gourmand` and `UT_competitiveeater` in its exclusion set. This means UT_competitiveeater and UT_gourmand are not mutually exclusive with each other and can be taken simultaneously.
- Runtime Lua file exists: yes — `UT_competitiveeater.lua` (27 lines)

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_competitiveeater.lua` (full file, 27 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1989–1998)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 617–618)
- Event registrations: `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
- Runtime chain (plain language):
  1. `onPlayerUpdate` fires on every player update tick.
  2. `UTCore.hasTrait` is checked; if the player does not have the trait, the function returns immediately.
  3. `player:getModData()` is retrieved to access the per-player persisted state key `"UT_competitiveeater_prevTimer"`.
  4. `player:getBodyDamage():getHealthFromFoodTimer()` is read into `healTimer`.
  5. If `prev` is not nil AND `healTimer > prev + 50`, a `pcall` block fires:
     - `stats:add(CharacterStat.BOREDOM, -10)` — reduces boredom by 10
     - `stats:add(CharacterStat.HUNGER, -5)` — reduces hunger by 5
  6. `md["UT_competitiveeater_prevTimer"]` is updated to `healTimer` unconditionally at the end of every tick.
- Actual behavior (exact values):
  - Trigger condition: `getHealthFromFoodTimer()` must rise by more than 50 between consecutive ticks — this is the rising-edge detection used to identify the moment food is consumed.
  - On the first tick after eating: boredom reduced by exactly 10, hunger reduced by exactly 5, wrapped in `pcall` (errors silenced).
  - The effect fires once per eating event (rising-edge detection fires only on the tick where the timer jumps; subsequent ticks see a declining or stable timer and do not re-trigger).
  - The guard `prev ~= nil` means the very first tick after load does not trigger spuriously (no prior value to compare against).
  - No tick throttle — the detection runs every single player update tick, though the effect only fires on the single rising-edge tick per eating event.

## Description Integrity
- Display name check: "Competitive Eater" — appropriate and accurate. No issue.
- Description check: `"You eat with purpose and efficiency. Every meal is an event you approach with genuine enthusiasm and unusual results."`
- Accuracy issues found:
  1. **No mechanical disclosure** — the description is entirely flavour text. It states no specific numbers, no stats affected, and no trigger condition. A player reading this has no information about what the trait actually does in gameplay terms (boredom -10, hunger -5 on each eating event).
  2. **"unusual results"** — the phrasing is vague and could imply negative side effects; the trait has no downsides. This is potentially misleading.
  3. The description does not mention that the effect fires once per meal (not ongoing), nor what stats are affected.

## Balance Review
- Upside: each eating event reduces boredom by 10 and hunger by 5 instantly
- Downside: none (purely positive trait)
- Uptime: once per eating event; no ongoing tick-based drain or cost
- Cost: 3 points
- Source cost: n/a (original trait, no source)
- Peer comparison:
  - `UT_gourmand` (4 points) applies a 1.5× hunger multiplier to all food items in inventory every 30 ticks — a broader, persistent, more mechanically complex effect at 1 point more. Competitive eater's single-event flat reduction is narrower in scope.
  - `UT_anorexy` (-6 points) is the mutual exclusion counterpart on the negative side.
  - `UT_sensitivestomach` (-4 points) uses the same `getHealthFromFoodTimer` detection pattern to impose pain/nausea on digestion; competitive eater is its positive mirror at 3 points. The asymmetry (-4 vs +3) is plausible given the positive effect is strictly narrower.
  - Boredom -10 and hunger -5 per meal are modest flat reductions. Their value depends on eating frequency; a player who eats rarely gains relatively little.
- Stack or exclusion notes:
  - Mutually exclusive with `UT_anorexy` (bidirectional). Not mutually exclusive with `UT_gourmand` — both can be taken simultaneously. When stacked with `UT_gourmand`, the player gets UT_competitiveeater's per-meal flat reduction plus UT_gourmand's ongoing 1.5× hunger multiplier; there is no declared interaction between them and no conflict.
  - The `UT_anorexy` exclusion set also lists `UT_gourmand` and `UT_mundane`, but neither of those lists `UT_competitiveeater` in their own exclusion sets — this asymmetry is intentional in the script file but means that UT_competitiveeater can coexist with UT_gourmand and UT_mundane.
- Cost verdict: plausible — 3 points for a small per-meal boredom and hunger reduction with no downside is within range. The trait is narrower and cheaper than `UT_gourmand` (4 points), which is an appropriate hierarchy.

## Regression Proof
- Existing tests:
  - `run_tests.lua` line 300: `"UniversalTraits:UT_competitiveeater"` appears in the `expected_ids` table (Phase 3c — Event-Driven group). Proves the trait is enumerable in the full registration count test.
  - No dedicated named test for `UT_competitiveeater` found in `run_tests.lua`.
- What the tests prove: The trait is registered and appears in the enumeration list. Nothing more.
- Missing proof:
  - No test verifies the rising-edge detection logic (that `healTimer > prev + 50` correctly triggers exactly once per eating event).
  - No test verifies the exact stat deltas applied (`BOREDOM -10`, `HUNGER -5`).
  - No test verifies the nil-guard on `prev` (no spurious trigger on first tick).
  - No test verifies that the prevTimer is stored correctly in mod data across ticks.
  - No test verifies that the `pcall` wrapper silently swallows errors (negative: errors in stat application are invisible).
  - No test verifies mutual exclusion enforcement with `UT_anorexy`.
- Minimum next test if needed: Mock a player with a `getBodyDamage()` stub where `getHealthFromFoodTimer()` returns 0 on tick 1 (stores prev=0), then returns 200 on tick 2 (200 > 0+50). Assert that `CharacterStat.BOREDOM` was decremented by 10 and `CharacterStat.HUNGER` by 5. Then advance a tick with timer returning 190 (declining) and assert no additional stat change.

## Final Verdict
- Source origin: none — no source trait found in any installed-mod; this is an original trait
- UT implementation: straightforward and correct — rising-edge detection on `getHealthFromFoodTimer()` fires once per eating event; applies flat boredom -10 and hunger -5; wrapped in `pcall`; prev-timer guard prevents spurious first-tick triggers
- Description: pure flavour text with no mechanical disclosure — players cannot determine from the description what stats are affected, by how much, or when; "unusual results" could be misread as implying negative effects
- Balance: plausible — 3-point positive-only trait with modest per-meal benefits; stacks legally with `UT_gourmand` (no cross-exclusion declared); peer cost hierarchy relative to gourmand is appropriate
- Regression proof: minimal — registration enumeration only; no behavioral coverage
- Action needed: description fix (primary — add stat values and trigger condition); optional test additions
- Open gaps:
  - Description must be corrected: it must state that eating reduces boredom by 10 and hunger by 5 per meal; remove or clarify "unusual results" to avoid implying a downside
  - Confirm whether the absence of mutual exclusion between `UT_competitiveeater` and `UT_gourmand` is intentional; both are positive food traits and can be stacked
  - Confirm whether `DisabledInMultiplayer = true` is an intentional restriction for this trait; the per-meal rising-edge detection is stateless per-player and appears multiplayer-safe
  - The `pcall` wrapping silently swallows any errors from `stats:add` calls — consider whether silent failure is acceptable or whether errors should be logged
  - No test coverage for the rising-edge detection or stat application; add behavioral unit tests before this trait is considered regression-safe
