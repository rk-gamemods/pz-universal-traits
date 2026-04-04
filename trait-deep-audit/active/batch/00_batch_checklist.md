# UT Trait Deep Audit — Batch Checklist

- Batch folder: trait-deep-audit/active/batch/
- Coordinator: Claude Opus (orchestrator)
- Status: in progress (107/~170 traits audited)

---

## Session Fix Log — P0 Corrections Applied

The following P0 and P1 issues were implemented and are no longer outstanding as of this session. The critical findings tables are preserved below for reference but individual items are marked FIXED where appropriate.

### New Files Created

- `UniversalTraits/media/lua/shared/UniversalTraits/UT_ItemConsumptionHooks.lua` — Shared hook file overriding `ISEatFoodAction.perform` and `ISDrinkFluidAction.perform`. Handles UT_allergic (food sickness spike), UT_antivaxxer (medication stress spike), UT_addictedtocaffeine (UT_hadCaffeine flag set on caffeine items).

### Lua Files Modified

| File | Change |
|------|--------|
| `UT_fearofthedark.lua` | FIXED: `getNight()` → `getTimeOfDay() < 0.25 or > 0.75` |
| `UT_mundane.lua` | FIXED: Perk key `"Electrical"` → `"Electricity"` |
| `UT_butterfingers.lua` | FIXED: Drop consumer implemented in `onPlayerUpdate`; player removes item from hand/inv and places on ground square |
| `UTCore_XPHook.lua` | FIXED: Skill cap enforcement added; reads `UT_skillCapReduction`, blocks XP at `level >= 10 - capReduction` |
| `UT_allergic.lua` | FIXED: Dead flag replaced; mechanic moved to `UT_ItemConsumptionHooks.lua` (30% food sickness +20 on eat) |
| `UT_antivaxxer.lua` | FIXED: Broken `setIsHidden()` API replaced; mechanic moved to `UT_ItemConsumptionHooks.lua` (+0.20 stress on medication, excluding beta blockers) |
| `UT_humanhamster.lua` | FIXED: Now a negative trait with hoarding compulsion stress system. Escalating stress when inventory < 80% full OR no backpack worn. Keeps +2 carry as tradeoff. |
| `UT_physicallyactive.lua` | FIXED: Dead flag replaced; ISFitnessAction override installed — stress -0.015 and boredom -5 per exercise loop; Fitness 10 = endurance immunity during gym exercises |
| `UT_gunspecialist_III.lua` | FIXED: Dead speed flags replaced; applies `weapon:setReloadTime()` and `weapon:setAimingTime()` at 0.9× multiplier with base-value caching in weapon modData |
| `UT_scardycat.lua` | FIXED: `ShouldBeShouting()` replaced with `addSound()` world noise (radius 15); panic cascade tracker added in `EveryOneMinute` (+0.15 when panic rises ≥ 0.05) |
| `UT_addictedtocaffeine.lua` | FIXED: `UT_hadCaffeine` is now set by `UT_ItemConsumptionHooks.lua`; added doc comment to trait file |

### Script Files Modified

| File | Change |
|------|--------|
| `UT_character_traits.txt` | Added `XPBoosts = Fitness=1;Sprinting=1` to `UT_physicallyactive` script block |

### Translation File Modified

| File | Changes |
|------|---------|
| `Translate/EN/UI_EN.txt` | Updated descriptions for: UT_allergic, UT_antivaxxer, UT_physicallyactive, UT_humanhamster, UT_scardycat, UT_butterfingers, UT_incomprehensive, UT_gunspecialist_III, UT_addictedtocaffeine — all descriptions now accurately reflect implemented mechanics with specific values |

### P0 False Positives (Confirmed Functional — No Code Change Needed)

| Trait | Finding | Resolution |
|-------|---------|------------|
| UT_gimp | "SpeedHook consumer unconfirmed" | FALSE POSITIVE — UTCore_SpeedHook.lua reads `UT_speedMod`. Trait fully functional. |
| UT_albino | `UT_albinoDamage` listed as dead | FALSE POSITIVE — It's an internal state tracker set/cleared each tick. Not an external consumer flag. |
| UT_sedentary | `UT_sedentaryPenalty = true` listed as dead | FALSE POSITIVE — Dead marker, but direct `stats:setEndurance(-0.01)` works correctly. |
| UT_immunocompromised | `UT_immunocompromised = true` listed as dead | FALSE POSITIVE — Dead marker. Infection escalation logic works directly. |
| UT_hardy | `UT_hardyExhaustedAt` listed as dead | FALSE POSITIVE — Set/cleared by internal logic as a state variable. |

### UT_actionhero (iZombie guard)

- P3/P4 note: `isZombie()` guard removed, bonus applies to ALL targets not just zombies. User confirmed this is **intentional design**. No code change.

---

## Trait Queue

| UT Trait ID | Source Mod | Scripted? | Status |
|-------------|-----------|-----------|--------|
| UT_fast | MoreTraits | yes | done |
| UT_noodlelegs | MoreTraits | yes | done |
| UT_pacer | SomewhatTraits | yes | done |
| UT_lurcher | SomewhatTraits | yes | done |
| UT_sorelegs | MoreSimpleTraits | yes | done |
| UT_quickworker | MoreTraits | yes | done |
| UT_slowworker | MoreTraits | yes | done |
| UT_slack | MoreSimpleTraits | yes | done |
| UT_batteringram | MoreTraits | yes | done |
| UT_fitted | MoreTraits | yes | done |
| UT_glassbody | MoreTraits | yes | done |
| UT_brittle | unknown | yes | done |
| UT_thickblood | MoreTraits | yes | done |
| UT_heavilybleedingwounds | MoreSimpleTraits | yes | done |
| UT_weaklybleedingwounds | MoreSimpleTraits | yes | done |
| UT_restfulsleeper | MoreTraits | yes | done |
| UT_quickrest | MoreTraits | yes | done |
| UT_snorer | MoreSimpleTraits | yes | done |
| UT_antigun | MoreTraits | yes | done |
| UT_flatearther | SomewhatTraits | yes | done |
| UT_luddite | SomewhatTraits | yes | done |
| UT_onetrickpony | SomewhatTraits | yes | done |
| UT_flailer | SomewhatTraits | yes | done |
| UT_fasthands | FillerTraits | yes | done |
| UT_analgesia | FillerTraits | yes | done |
| UT_preparedpack | MoreTraits | yes | done |
| UT_owlperson | MoreSimpleTraits | yes | done |
| UT_larkperson | MoreSimpleTraits | yes | done |
| UT_leadfoot | MoreTraits | yes | done |
| UT_expertdriver | MoreTraits | yes | done |
| UT_poordriver | MoreTraits | yes | done |
| UT_ironliver | SomewhatTraits | yes | done |
| UT_durability | MoreSimpleTraits | yes | done |
| UT_gourmand | MoreTraits | yes | done |
| UT_ascetic | MoreTraits | yes | done |
| UT_depressive | MoreSimpleTraits/MoreTraits | yes | done |
| UT_paranoia | MoreTraits | yes | done |
| UT_selfdestructive | MoreTraits | yes | done |
| UT_melancholic | DTEM | yes | done |
| UT_acrophobic | SomewhatTraits | yes | done |
| UT_vehophobic | SomewhatTraits | yes | done |
| UT_motionsickness | MoreTraits | yes | done |
| UT_injured_I | SomewhatTraits | yes | done |
| UT_broke | original | yes | done |
| UT_burned | original | yes | done |
| UT_immuneresponse | SomewhatTraits | yes | done |
| UT_ravenous | SomewhatTraits | yes | done |
| UT_fearful | MoreTraits | yes | done |
| UT_nervouswreck | DTEM | yes | done |
| UT_scardycat | SomewhatTraits | yes | done |
| UT_maniac | SomewhatTraits | yes | done |
| UT_allergic | MoreSimpleTraits | yes | done |
| UT_competitiveeater | original | yes | done |
| UT_butterfingers | MoreTraits | yes | done |
| UT_sensitivestomach | MoreSimpleTraits | yes | done |
| UT_physicallyactive | DTEM | yes | done |
| UT_humanhamster | SomewhatTraits | yes | done |
| UT_superimmune | MoreTraits | yes | done |
| UT_indefatigable | MoreTraits | yes | done |
| UT_addictedtocaffeine | DTEM | yes | done |
| UT_albino | MoreTraits | yes | done |
| UT_alcoholic_I | DTEM | yes | done |
| UT_fibromyalgia | FillerTraits | yes | done |
| UT_bigorexia | DTEM (commented-out) | yes | done |
| UT_weathersensitive | MoreSimpleTraits | yes | done |
| UT_panicattacks | original | yes | done |
| UT_fearofthedark | MoreSimpleTraits | yes | done |
| UT_coldsensitive | SomewhatTraits | yes | done |
| UT_heatsensitive | SomewhatTraits | yes | done |
| UT_sedentary | DTEM | yes | done |
| UT_immunocompromised | MoreTraits | yes | done |
| UT_alcoholic_II | DTEM | yes | done |
| UT_alcoholic_III | DTEM | yes | done |
| UT_accmetabolism | MoreSimpleTraits | yes | done |
| UT_adaptivemetabolism | SomewhatTraits | yes | done |
| UT_anemic | MoreTraits | yes | done |
| UT_anorexy | DTEM | yes | done |
| UT_antivaxxer | SomewhatTraits | yes | done |
| UT_backpacker | FillerTraits | yes | done |
| UT_badteeth | MoreTraits | yes | done |
| UT_bouncer_I | MoreTraits | yes | done |
| UT_cangrabless | MoreSimpleTraits | yes | done |
| UT_cangrabmore | MoreSimpleTraits | yes | done |
| UT_couchdweller | SomewhatTraits | yes | done |
| UT_deprived | MoreTraits | yes | done |
| UT_driver | original | yes | done |
| UT_flimsy | SomewhatTraits | yes | done |
| UT_gimp | MoreTraits | yes | done |
| UT_gunspecialist_III | MoreTraits | yes | done |
| UT_hardy | MoreTraits | yes | done |
| UT_highsweaty | MoreSimpleTraits | yes | done |
| UT_idealweight | MoreTraits | yes | done |
| UT_incomprehensive | MoreTraits | yes | done |
| UT_injured_II | SomewhatTraits | yes | done |
| UT_lesssweaty | MoreSimpleTraits | yes | done |
| UT_actionhero | MoreTraits | yes | done |
| UT_martial | MoreTraits | yes | done |
| UT_mstoptimist | MoreSimpleTraits | yes | done |
| UT_mundane | MoreTraits | yes | done |
| UT_noxpaxe | MoreTraits | yes | done |
| UT_noxpfirstaid | MoreTraits | yes | done |
| UT_noxpmaintenance | MoreTraits | yes | done |
| UT_noxpshooter | MoreTraits | yes | done |
| UT_noxpsneaky | MoreTraits | yes | done |
| UT_noxptechnician | MoreTraits | yes | done |
| UT_optimist | FillerTraits | yes | done |
| UT_packmouse | MoreTraits | yes | done |

## Shared Blockers

- `UT_speedMod`: multiple traits write (UT_fast, UT_noodlelegs, UT_sorelegs, UT_lurcher). Last-write-wins.
- `UT_sleepQualMod`: UT_quickrest + UT_restfulsleeper both write. No mutual exclusion.
- `UT_bleedDrainMult`: UT_weaklybleedingwounds + UT_thickblood both write. No mutual exclusion.
- Infection drain stacking: UT_superimmune + UT_immuneresponse both drain infection, no exclusion.

## Critical Findings — Priority Tiers

### P0: INERT/BROKEN TRAITS (free points or wasted points)

**Negative traits giving free points (no downside implemented):**

| Trait | Dead Flag | Cost | Points Exploitable |
|-------|-----------|------|--------------------|
| UT_allergic | UT_generalAllergyFlag | -4 | 4 free |
| UT_butterfingers | UT_dropNext | -4 | 4 free |
| UT_scardycat | cosmetic only, no world sound | -3 | ~3 free |
| UT_humanhamster | grants +2 carry (BENEFIT) | -3 | 5 free (3+2) |

**Negative traits with broken mechanics (penalty always fires, no counterplay):**

| Trait | Bug | Cost | Impact |
|-------|-----|------|----|
| UT_addictedtocaffeine | UT_hadCaffeine never set — suppression branch dead | -3 | unconditional stress, description promises caffeine relief |
| UT_fearofthedark | `getNight()` returns float (0.0 truthy in Lua) — day recovery unreachable | -4 | permanent max panic 24/7 |
| UT_antivaxxer | `setIsHidden()` doesn't exist on Recipe class + `getName()` locale-dependent | -3 | 3 free points, zero penalty |
| UT_incomprehensive | UT_skillCapReduction written but no consumer exists | -10 | 10 free points, zero penalty |
| UT_gimp | UT_speedMod=-0.5 written but SpeedHook consumer unconfirmed | -8 | potentially 8 free |
| UT_gunspecialist_III | UT_reloadSpeedBonus + UT_aimSpeedBonus written but no consumer | 10 | speed bonuses non-functional |

**Dead modData flags (written but never consumed):**

| Trait | Dead Flag |
|-------|-----------|
| UT_albino | UT_albinoDamage |
| UT_sedentary | UT_sedentaryPenalty |
| UT_immunocompromised | UT_immunocompromised |
| UT_hardy | UT_hardyExhaustedAt |
| UT_incomprehensive | UT_skillCapReduction |
| UT_gunspecialist_III | UT_reloadSpeedBonus, UT_aimSpeedBonus |

**Potential perk key mismatch (may silently break XP hooks):**

| Trait | Key Used | Possibly Correct Key |
|-------|----------|---------------------|
| UT_mundane | "Electrical" | "Electricity" (used by UT_luddite) |

**Positive traits wasting points (no upside implemented):**

| Trait | Dead Flag | Cost | Points Wasted |
|-------|-----------|------|---------------|
| UT_physicallyactive | UT_physActiveBonus | 4 | 4 wasted |

*Note: 8 traits from batch 1-3 (UT_brittle, UT_snorer, etc.) were already fixed with real consumers.*

### P1: WRONG DESCRIPTIONS (code does not match what player reads)

**Total mismatch (description describes different mechanic):**

1. **UT_fearful** — says "+0.2 panic per event", code does noise/shout zombie attraction
2. **UT_nervouswreck** — says "+0.3 panic per event", code reduces panic recovery rate by 70%
3. **UT_acrophobic** — says "higher up = worse", code applies flat penalty at any z>0

**Wrong numbers:**
4. **UT_gourmand** — says "+30% hunger", code does +50%
5. **UT_thickblood** — says "twice as quickly", multiplier is 1.5x
6. **UT_burned** — says burns on "upper torso and hands", code burns ALL body parts

**Wrong stat:**
7. **UT_motionsickness** — says "nauseous", code raises stress not nausea
8. **UT_depressive** — flavor implies unhappiness, code raises stress
9. **UT_melancholic** — flavor implies sadness, code raises stress

**Stat mislabeled (description names wrong stat):**
10. **UT_fibromyalgia** — says "chronic pain" but never touches pain; raises stress+fatigue
11. **UT_albino** — says "real physical harm" but only raises stress+fatigue, no pain/damage
12. **UT_sedentary** — says "fitness fades faster" but drains endurance, not Fitness perk
13. **UT_immunocompromised** — says "infections take hold more easily" (initiation), code only escalates existing infections

**Description promises non-functional mechanic:**
14. **UT_addictedtocaffeine** — says caffeine relieves symptoms, but UT_hadCaffeine is never set
15. **UT_weathersensitive** — says "storms drag you down, clear days lift you up" but code has zero weather checks
16. **UT_fearofthedark** — day/night cycle described but day recovery is unreachable (getNight() bug)
17. **UT_antivaxxer** — says "medical items less effective" but code tries to hide injection recipes (and fails)
18. **UT_accmetabolism** — says "weight shifts with your diet" but no weight/calorie API called; drains hunger+thirst
19. **UT_cangrabless** — says "grab success rate reduced" but code only sets MaxWeightBase=7 (carry weight)
20. **UT_cangrabmore** — says "grab and restrain zombies more effectively" but code only sets MaxWeightBase=9

**Missing numbers / undisclosed mechanics:**
21. **UT_bigorexia** — doesn't name stress stat, doesn't disclose rates or Strength<5 threshold
22. **UT_panicattacks** — "the attacks pass" understates +0.4 panic spikes ~3x/hour
23. **UT_coldsensitive** — fatigue component not disclosed
24. **UT_heatsensitive** — fatigue component not disclosed
25. **UT_adaptivemetabolism** — "adjusts to changing conditions" names no stat, threshold, or magnitude
26. **UT_backpacker** — "carry weight is increased" with no +4 value
27. **UT_anorexy** — "pays the price for every meal" — no stat, value, or trigger disclosed
28. **UT_bouncer_I** — says "Start at Strength 6" but XPBoosts are bonuses not starting levels
29. **UT_accmetabolism** — thirst drain (+0.03/10min) not mentioned
30. **UT_couchdweller** — says "endurance is reduced" (wrong-trait paste); actually removes boredom+unhappiness
31. **UT_deprived** — says "multiple physical stats are reduced" but only strips spawn items
32. **UT_driver** — says "Gain ×2 XP in Driving" but no XP boost exists; actual vehicle multipliers not mentioned
33. **UT_flimsy** — says "Strength and endurance are reduced" but applies upper arm pain from backpack weight
34. **UT_idealweight** — says "+1 carry weight and 85% fatigue rate" but actual mechanic is calorie burn multiplier
35. **UT_highsweaty** — thirst drain, idle wetness, and combat trigger all undisclosed
36. **UT_gunspecialist_III** — XPBoosts described as "×3 XP" instead of "+2 bonus"

**Pure flavor, no mechanical info:**
21. **UT_selfdestructive** — 100% flavor, zero numbers
22. **UT_vehophobic** — 100% flavor, zero numbers
23. **UT_competitiveeater** — 100% flavor, zero numbers
24. **UT_sensitivestomach** — mentions "stress or poor food" that doesn't exist

### P2: BALANCE ISSUES

1. **UT_humanhamster** — costs -3 but grants +2 carry weight (net positive!)
2. **UT_scardycat** — cosmetic only, -3 free points
3. **UT_selfdestructive** — -6 for a 20% chance of minor stress/fatigue bump; overpriced
4. **UT_ravenous** — cost tripled from source (-2 → -6) without rationale
5. **UT_sensitivestomach** — cost doubled from source (-2 → -4) with reduced severity
6. **UT_superimmune** — stronger than source but cheaper (8 vs 10)
7. **UT_paranoia** — unconditional panic drain, may be underpriced at -4
8. **UT_injured_I / UT_injured_II / UT_broke / UT_burned** — temporary conditions become permanent point refunds
9. **UT_addictedtocaffeine** — -3 for unconditional +0.06 stress/10min (no counterplay); 3x faster than UT_alcoholic_I at -4
10. **UT_bigorexia** — source intended -8, UT halved to -4 without rationale
11. **UT_coldsensitive / UT_heatsensitive** — cost doubled from source (-2 → -4) for weaker flat-rate effect
12. **UT_actionhero** — source's 50% base-damage penalty removed but cost unchanged at 8; pure bonus now vs source's risk/reward
13. **UT_noxp series** — cost inconsistency: noxpaxe=2, noxpfirstaid/shooter/technician/maintenance=3, noxpsneaky=3; no documented rationale

### P3: MISSING MUTUAL EXCLUSIONS

1. **UT_superimmune + UT_immuneresponse** — double-stack infection drain
2. **UT_vehophobic + UT_motionsickness** — redundant vehicle penalties stack
3. **UT_depressive + UT_melancholic** — double-stack stress drain (+0.13/10min)
4. **UT_selfdestructive + UT_optimist** — thematically contradictory, no exclusion
5. **UT_maniac** — source excluded hemophobic; UT has none
6. **UT_fearful** — source excluded brave/desensitized; UT has none
7. **UT_scardycat** — source excluded flailer/desensitized; UT has none
8. **UT_competitiveeater + UT_gourmand** — stacking confirmed, intentionality unclear
9. **UT_coldsensitive + UT_heatsensitive** — no mutual exclusion (source had it); exploit: take both for -8 points, manage temperature
10. **UT_fibromyalgia + UT_analgesia** — source excluded them; UT does not
11. **UT_immunocompromised + base:resilient** — source excluded; UT allows partial negation
12. **UT_immunocompromised + UT_immuneresponse** — escalation (+0.01/min) dominates drain (-0.003/min); probably unintended
13. **UT_sedentary** — source had 5 exclusions (PhysicallyActive, Strong, Athletic, Fit); UT has zero
14. **UT_panicattacks** — no exclusions with UT_acrophobic, UT_fearofthedark, or other panic sources
15. **UT_anemic + UT_thickblood** — both write UT_bleedDecayMult; source excluded them; last-write-wins collision
16. **UT_backpacker + UT_packmule** — both positive carry weight; UT_packmouse excludes both but they don't exclude each other
17. **UT_cangrabless + base:Strong** — source excluded; UT allows partial negation of carry weight penalty
18. **UT_cangrabmore + base:Weak** — source excluded; UT does not carry over
19. **UT_badteeth + UT_albino** — source excluded; stacking gives head pain from both eating and sun
20. **UT_gimp + UT_fast** — both write UT_speedMod; source excluded; no MET in UT
21. **UT_idealweight** — source/release threshold mismatch (84/76 vs 85/75) needs sync
22. **UT_mstoptimist + UT_optimist** — both drain stress every 10min; stack freely for -0.14/tick at high stress
23. **UT_noxp series** — source had all 6 siblings mutually exclusive; UT has none; players can stack all for large point windfall
24. **UT_actionhero** — `isZombie()` guard removed; applies bonus damage to all targets not just zombies

### P4: TEST GAPS

- **55 of 59 traits** have no behavioral regression test (registration sweep only)
- Only UT_preparedpack, UT_expertdriver, UT_poordriver have strong pinned-value tests
- UT_indefatigable runtime file not even loaded by test harness

## Automation Candidates Found

- All `onPlayerUpdate` endurance drain/regen loops follow same 30-tick pattern → shared test harness
- All vehicle traits use `UTCore.registerVehicleTrait` → shared test template
- Rising-edge food detection pattern (UT_competitiveeater, UT_sensitivestomach, UT_ascetic) → shared test
- Periodic stress/panic traits (depressive, paranoia, melancholic, owlperson, larkperson) → shared EveryTenMinutes test pattern
