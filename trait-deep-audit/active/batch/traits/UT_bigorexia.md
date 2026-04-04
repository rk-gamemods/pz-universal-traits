# UT_bigorexia

## Trait Summary
- UT trait id: UT_bigorexia
- Source mod: DynamicTraitsExpandedMoodles (Dynamic-Traits-main) — single source analogue identified; `Bigorexia` was commented out in both the B41 and B42 registration files
- Source trait id: `Bigorexia` (DynamicTraitsExpandedMoodles — never actually registered; appears only as a commented-out `TraitFactory.addTrait` call)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/NPCs/DTEMMainCreationMethods.lua` (B42 registration file — line 475)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/shared/NPCs/DTMainCreationMethods.lua` (B41 registration file — line 203)

- Source registration: **none confirmed active.** In both files the `TraitFactory.addTrait("Bigorexia", ...)` call is commented out with `--`. The trait was present in the DT design but was never shipped as a live registration in either the B41 or B42 version of the installed mod. No other source mod in the `installed-mods` corpus references `Bigorexia` or `bigorexia` in any form.

- Source trigger path: unknown — no runtime Lua for the source `Bigorexia` trait exists in the corpus. The creation-method comment establishes intent (the trait existed conceptually) but no implementation file was found.

- Source behavior: not recoverable from the installed-mods corpus. The comment lines reveal:
  - Intended cost: `-8` (`TraitFactory.addTrait("Bigorexia", ..., -8, ..., false)`)
  - UI keys referenced: `UI_trait_Bigorexia`, `UI_trait_BigorexiaDesc`
  - No translation strings for those keys were found in any DT translation file in the corpus — the trait was incomplete in the source mod.

- Source display name: not found (no DT EN translation file contains `UI_trait_Bigorexia =`).
- Source description: not found (no DT EN translation file contains `UI_trait_BigorexiaDesc =`).
- Source cost: `-8` (from the commented-out `TraitFactory.addTrait` call — intended, never shipped).
- Source exclusions: not found (no script definition for `Bigorexia` exists in the corpus).

## Current UT Evidence

### Structure
- Registered in registries.lua: **yes**
  - `UTTraitsRegistries.UT_bigorexia = CharacterTrait.register("UniversalTraits:UT_bigorexia")` — `media/registries.lua` line 259
  - Matches the release copy at `release/UniversalTraits/42/media/registries.lua` line 259
- Defined in UT_character_traits.txt: **yes** — lines 1783–1791
  ```
  character_trait_definition UniversalTraits:UT_bigorexia
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_bigorexia,
      Cost = -4,
      UIName = UI_UT_bigorexia,
      UIDescription = UI_UT_bigorexiaDesc,
  }
  ```
  - No `MutuallyExclusiveTraits` block — the trait has no enforced mutual exclusions at the script level.
  - No `GrantedTraits` block.
- Translation strings present: **yes** — `media/lua/shared/Translate/EN/UI_EN.txt` lines 554–555
  - `UI_UT_bigorexia = "Bigorexia"`
  - `UI_UT_bigorexiaDesc = "You are never big enough, never strong enough, never enough. Your mood suffers whenever your body does not match the image in your head."`
- Runtime Lua file exists: **yes** — `media/lua/shared/UniversalTraits/traits/UT_bigorexia.lua` (18 lines)
- Release copy present: **yes** — `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_bigorexia.lua` (identical content confirmed by search)

### Runtime Trace

**Files reviewed:**
- `media/lua/shared/UniversalTraits/traits/UT_bigorexia.lua` (full file, 18 lines)
- `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (`UTCore.hasTrait` — lines 11–16)
- `UT_CORE/media/lua/shared/UTCore/UTCore_TraitChecks.lua` (supporting helpers — not called by this trait)
- `media/scripts/UT_character_traits.txt` (lines 1783–1791)
- `media/lua/shared/Translate/EN/UI_EN.txt` (lines 554–555)

**Full Lua source (verbatim):**
```lua
-- UT_bigorexia.lua
-- Bigorexia: body image anxiety causes constant stress, worse when physically weak

local TRAIT_ID = "UniversalTraits:UT_bigorexia"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setStress(math.min(1, stats:getStress() + 0.04))
    if player:getPerkLevel(Perks.Strength) < 5 then
        stats:setStress(math.min(1, stats:getStress() + 0.02))
    end
end

Events.EveryTenMinutes.Add(handler)
```

**Event registration:** `Events.EveryTenMinutes.Add(handler)` — fires every 10 in-game minutes.

**UTCore hooks used:**
- `UTCore.hasTrait(player, TRAIT_ID)` — defined in `UTCore_API.lua` lines 11–16. Implementation: `if not player then return false end; local traits = player:getTraits(); if not traits then return false end; return traits:contains(traitId)`. Nil-safe. Returns `false` for nil player or nil traits collection, otherwise delegates to Java `ArrayList.contains`.

**Runtime chain (step by step):**
1. `handler` is registered to `Events.EveryTenMinutes` at module load time. It fires every 10 in-game minutes, unconditionally — including during sleep, combat, looting, and all other activities.
2. `getPlayer()` is called. If it returns nil (no local player exists, e.g. not yet spawned), the function returns early with no effect.
3. `UTCore.hasTrait(player, "UniversalTraits:UT_bigorexia")` is called. If the player does not hold the trait, the function returns early.
4. `player:getStats()` is called to obtain the `IsoGameCharacter.Stats` object. Result stored in `stats`.
5. **Base stress increment:** `stats:getStress()` is read (a float in [0, 1]). `setStress` is called with `math.min(1, currentStress + 0.04)` — stress increases by exactly **+0.04**, hard-capped at 1.0.
6. **Conditional bonus increment:** `player:getPerkLevel(Perks.Strength)` is called. If the result is less than 5 (i.e., Strength is 0–4 inclusive), `stats:getStress()` is read again (which now reflects the result of step 5), and `setStress` is called with `math.min(1, updatedStress + 0.02)` — an additional **+0.02** of stress is applied, again capped at 1.0.
7. **Total per-tick stress increment:**
   - Strength ≥ 5: **+0.04** per 10-minute tick
   - Strength < 5: **+0.06** per 10-minute tick (+0.04 base, then +0.02 applied to the already-incremented value)
8. No randomness. No unhappiness manipulation. No sleep check. No panic manipulation.

**Time-to-max-stress from floor of 0.0:**
- Strength ≥ 5: 1.0 ÷ 0.04 = **25 ticks = 250 in-game minutes ≈ 4 hours 10 minutes**
- Strength < 5: 1.0 ÷ 0.06 ≈ **16.7 ticks = 167 in-game minutes ≈ 2 hours 47 minutes**

**Strength threshold:** `Perks.Strength` level 5 is the crossover. A player at exactly level 5 is exempt from the bonus penalty; a player at level 4 or below takes the full +0.06. This directly ties trait severity to a character-building decision, creating a mechanical incentive to keep Strength above 5.

**Double-read detail (step 6):** The second `stats:getStress()` read occurs after `setStress` from step 5 has already been written. This means the cap in step 6 is applied to the post-step-5 value, not the original value. In practice this is correct — both increments stack additively up to 1.0 — but the implementation reads `getStress()` twice rather than storing the intermediate result in a local variable. This is a minor code style issue, not a behavioral bug.

**No UTCore.registerPeriodicHandler:** Unlike traits such as `UT_backpacker`, this trait directly calls `Events.EveryTenMinutes.Add(handler)` and uses the `getPlayer()` + inline nil guard pattern (same as `UT_accmetabolism`, `UT_albino`, etc.). This is the standard pattern for singleplayer periodic traits in this codebase.

## Description Integrity
- Display name: `"Bigorexia"` — matches the real psychological condition name and the source trait name. No issue.
- Description: `"You are never big enough, never strong enough, never enough. Your mood suffers whenever your body does not match the image in your head."`
- Accuracy issues found:
  1. **Stat not named.** The description says "your mood suffers" but does not say *stress*. The runtime applies `setStress`; stress is the operative stat. A player reading the description cannot know whether this affects unhappiness, stress, or panic. The stat should be named explicitly.
  2. **Strength threshold not disclosed.** The description says mood suffers "whenever your body does not match the image in your head." This is intended flavor for the Strength-level check (`< 5`), but the actual threshold (Strength below 5) is never stated. A player cannot make an informed character-build decision without knowing the mechanical trigger.
  3. **Tick values not disclosed.** The description does not state that stress rises every 10 minutes, nor the per-tick amounts (+0.04 base, +0.02 additional when Strength < 5). The description is accurate in flavor but silent on every mechanical number.
  4. **"Mood suffers" is ambiguous.** In PZ's stat vocabulary, "mood" most commonly suggests `UnhappynessLevel`. The actual affected stat is `Stress`, which is mechanically distinct. A player familiar with vanilla PZ terminology may assume this raises unhappiness; it does not.
- Overall description verdict: The flavor language accurately captures the concept but is mechanically opaque. It does not claim anything false, but it discloses nothing specific — no stat name, no threshold, no per-tick rate. Given that other UT descriptions (e.g., `UT_depressive`) explicitly name the stat and rate, this trait's description is inconsistent with the mod's usual transparency standard.

## Balance Review
- **Downside (Strength ≥ 5):** +0.04 stress every 10 minutes. Time to max stress from floor: 250 in-game minutes (~4 hours 10 min). Unconditional — no sleep exemption, no activity gating.
- **Downside (Strength < 5):** +0.06 stress every 10 minutes. Time to max stress from floor: ~167 in-game minutes (~2 hours 47 min). This condition is active for all early-game play and for any build that does not invest in Strength.
- **Upside:** none (purely negative trait).
- **Uptime:** 100% for the base increment. The conditional Strength-based increment is 100% for Strength 0–4, 0% for Strength 5–10.
- **Cost:** -4 points (UT).
- **Source intended cost:** -8 (from commented-out DT registration line). The UT implementation prices this at exactly half the source intent.
- **Peer comparison within UT:**
  - `UT_depressive` (-4 cost): +0.08 stress per 10 minutes, unconditional, no Strength interaction. From floor to max in ~125 min (2 hr 5 min). Same cost, roughly 2× the rate of UT_bigorexia at Strength ≥ 5, and faster than UT_bigorexia even at Strength < 5.
  - `UT_melancholic` (Phase 3b group, cost not verified in this audit): likely a comparable mood/unhappiness periodic trait.
  - `UT_paranoia` (Phase 3b group, cost not verified here): panic-based periodic trait for comparison.
- **Balance assessment:** At -4 points, the base rate of +0.04/10min is mild — `UT_depressive` delivers double the stress for the same cost. The Strength-conditional bonus narrows the gap only when Strength is below 5 (a common early-game state but one players can build out of). At Strength ≥ 5, UT_bigorexia is the weakest pure stress-per-minute trait in the -4 tier. This makes it possibly underpowered relative to peers at the same cost (i.e., good value for the player — low price for a mild debuff) unless the game's stress management systems make even +0.04/10min meaningful. The source intended -8, which is twice the UT price; the UT pricing decision to set it at -4 was a deliberate halving of the source cost, possibly to account for the source trait never having shipped and its behavior being entirely UT-designed rather than adapted from a real implementation.
- **Strength threshold balance note:** The incentive for a player to invest in Strength to reduce the penalty is interesting design — the trait punishes physical weakness and rewards physical investment, which is thematically aligned with bigorexia as a condition. The threshold at 5 (midpoint of the 0–10 scale) is a reasonable inflection point.

## Regression Proof
- **Existing tests:**
  - `test/run_tests.lua` line 288: `"UniversalTraits:UT_bigorexia"` appears in the `expected_ids` table (Phase 3b — Periodic-Check group, inside the "all 198 trait IDs registered with CharacterTrait" test). Confirms the trait ID is expected to be registered and that it is classified as a Periodic-Check trait in the harness.
  - `test/run_tests.lua` (the "all 198 trait IDs registered" test, line 312): if `CharacterTrait._registered["UniversalTraits:UT_bigorexia"]` is absent, this test fails. Proves registry presence.
  - `test/run_tests.lua` (the "total registration count is 198" test, line 341): any extra or missing registration breaks this count. Proves global registration integrity.
  - `test/run_tests.lua` (the "script trait definitions resolve cleanly" test, line 347): verifies that the `CharacterTrait` field in the script block matches the `block_id` (`UniversalTraits:UT_bigorexia` in both), and that the `CharacterTrait` value appears in the registry. Proves script-to-registry consistency for this trait.
  - `UTTestMocks.lua` line 106: `UTCore.hasTrait` is stubbed as `player:getTraits():contains(traitId)` — any test that exercises a handler calling `UTCore.hasTrait` will use this stub correctly.
- **What the tests prove:** The trait is registered, is counted in the full registry, has a consistent script definition, and its registry ID resolves cleanly. Nothing else.
- **Missing proof:**
  - No test verifies that `handler` increases stress by exactly +0.04 per call when Strength ≥ 5.
  - No test verifies that `handler` increases stress by exactly +0.06 per call when Strength < 5.
  - No test verifies the `math.min(1, ...)` cap — stress does not exceed 1.0 when already near maximum.
  - No test verifies that the second `getStress()` read in the Strength-conditional branch correctly reads the post-step-5 value (i.e., that the two increments stack and are each capped individually rather than combined before capping).
  - No test verifies the trait-check guard — that `handler` exits early when the player does not have the trait.
  - No test verifies the nil-guard — that `handler` exits early when `getPlayer()` returns nil.
  - No test verifies the Strength threshold boundary: that `getPerkLevel(Perks.Strength) == 5` produces only the base increment, and `== 4` produces the bonus increment.
  - No test verifies the event registration — that `Events.EveryTenMinutes.Add(handler)` is called at module load time.
- **Minimum next tests if needed:**
  1. Mock a player holding `UniversalTraits:UT_bigorexia` with `Strength >= 5` and `getStress() == 0.5`. Fire `handler`. Assert `setStress` was called with `0.54`.
  2. Same player, `getStress() == 0.98`. Assert `setStress` capped to `1.0`.
  3. Mock a player holding the trait with `Strength == 4` and `getStress() == 0.5`. Fire `handler`. Assert stress ends at `0.56` (0.5 + 0.04 = 0.54 after step 5, then 0.54 + 0.02 = 0.56 after step 6).
  4. Mock a player holding the trait with `Strength == 4` and `getStress() == 0.96`. Assert final stress is `1.0` (0.96 + 0.04 = 1.0 after step 5 cap, then step 6 reads 1.0 and min(1, 1.02) = 1.0 — cap holds).
  5. Mock a player without the trait. Fire `handler`. Assert `setStress` is never called.
  6. Fire `handler` with nil player. Assert no error is raised.

## Final Verdict
- **Source origin:** The `Bigorexia` trait was designed in DynamicTraitsExpandedMoodles but was never shipped as a live registration in either the B41 or B42 versions of the mod — both registration calls are commented out. No implementation Lua, no active translation strings, and no script definition exist in the source mod corpus. The UT implementation is therefore an **original UT design** that uses only the trait's name and the -8 cost signal from the commented DT line as reference; all mechanical choices (stress stat, per-tick rates, Strength threshold) are UT-authored.
- **UT implementation:** Sound and self-consistent. The two-phase increment (flat base + Strength-conditional bonus) is a clean design. The trait correctly uses `UTCore.hasTrait`, a nil-safe `getPlayer()` guard, and `math.min` capping on both increments. The double-read of `getStress()` across the two increment steps is not a bug but is a minor style point. The event registration (`EveryTenMinutes`) is appropriate for a slow ambient stress trait. No hooks beyond `UTCore.hasTrait` are used.
- **Description:** Accurate in flavor, opaque in mechanics. Does not name the stat (stress), does not state the per-tick rate (+0.04 base / +0.06 at Strength < 5), does not disclose the Strength threshold (< 5), and the phrase "your mood suffers" may be misread by players as an unhappiness effect. Inconsistent with the transparency standard of other UT trait descriptions. Recommend revision to name the stat and the Strength trigger explicitly.
- **Balance:** -4 cost is plausible but sits at the weak end relative to peers. `UT_depressive` delivers +0.08/10min for the same -4 cost; `UT_bigorexia` delivers +0.04 to +0.06. The Strength-conditional mechanic is thematically strong and adds build-interaction depth absent from most pure-penalty traits. Whether -4 is appropriate depends on how impactful the game's stress buildup is at the chosen tick rates. The source intended -8, making this a deliberate and significant downward repricing; this should be a confirmed intentional design call.
- **Regression proof:** Registration and script consistency are proven. All runtime behavior (stress increments, caps, Strength threshold, nil guards, event hook) is unproven.
- **Action needed:**
  1. (Medium urgency) Revise the description to name `Stress` explicitly and disclose the +0.04/+0.06 per-10-minute rates and the Strength < 5 threshold.
  2. (Low urgency) Confirm the -4 cost vs. the source's intended -8 is a deliberate decision and document it.
  3. (Low urgency) Add behavioral unit tests for the two-tier stress increment, the 1.0 cap in both branches, the Strength threshold boundary, and the nil and trait-missing guards.
- **Open gaps:**
  - No translation strings exist in the source mod — the UT description is entirely original and should be reviewed for accuracy against the trait's intended psychological concept (bigorexia / muscle dysmorphia: obsessive belief that one's body is not muscular enough).
  - `DisabledInMultiplayer = true` — the source trait was never live, so there is no source baseline for this decision; confirm it is intentional.
  - No `MutuallyExclusiveTraits` block — consider whether `UT_bigorexia` should be mutually exclusive with body-image or mental-health peers (e.g., `UT_depressive`, `UT_melancholic`) or whether stacking is intended design.
  - The trait's stress accumulation stacks additively with all other stress sources (e.g., `UT_depressive`, `UT_paranoia`, caffeine withdrawal). Verify that an all-stress-penalty build does not produce a degenerate experience by confirming that vanilla stress decay is sufficient to counteract the combined load at these tick rates.
