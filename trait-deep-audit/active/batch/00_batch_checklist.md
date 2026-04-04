# UT Trait Deep Audit — Batch Checklist

- Batch folder: trait-deep-audit/active/batch/
- Coordinator: Claude Opus (orchestrator)
- Status: in progress (35/~170 traits audited)

## Trait Queue

| UT Trait ID | Source Mod | Scripted? | Owner | Status | Blockers |
|-------------|-----------|-----------|-------|--------|----------|
| UT_fast | MoreTraits | yes | agent | done | |
| UT_noodlelegs | MoreTraits | yes | agent | done | |
| UT_pacer | SomewhatTraits | yes | agent | done | |
| UT_lurcher | SomewhatTraits | yes | agent | done | |
| UT_sorelegs | MoreSimpleTraits | yes | agent | done | |
| UT_quickworker | MoreTraits | yes | agent | done | |
| UT_slowworker | MoreTraits | yes | agent | done | |
| UT_slack | MoreSimpleTraits | yes | agent | done | |
| UT_batteringram | MoreTraits | yes | agent | done | |
| UT_fitted | MoreTraits | yes | agent | done | |
| UT_glassbody | MoreTraits | yes | agent | done | |
| UT_brittle | unknown | yes | agent | done | |
| UT_thickblood | MoreTraits | yes | agent | done | |
| UT_heavilybleedingwounds | MoreSimpleTraits | yes | agent | done | |
| UT_weaklybleedingwounds | MoreSimpleTraits | yes | agent | done | |
| UT_restfulsleeper | MoreTraits | yes | agent | done | |
| UT_quickrest | MoreTraits | yes | agent | done | |
| UT_snorer | MoreSimpleTraits | yes | agent | done | |
| UT_antigun | MoreTraits | yes | agent | done | |
| UT_flatearther | SomewhatTraits | yes | agent | done | |
| UT_luddite | SomewhatTraits | yes | agent | done | |
| UT_onetrickpony | SomewhatTraits | yes | agent | done | |
| UT_flailer | SomewhatTraits | yes | agent | done | |
| UT_fasthands | FillerTraits | yes | agent | done | |
| UT_analgesia | FillerTraits | yes | agent | done | |
| UT_preparedpack | MoreTraits | yes | agent | done | |
| UT_owlperson | MoreSimpleTraits | yes | agent | done | |
| UT_larkperson | MoreSimpleTraits | yes | agent | done | |
| UT_leadfoot | MoreTraits | yes | agent | done | |
| UT_expertdriver | MoreTraits | yes | agent | done | |
| UT_poordriver | MoreTraits | yes | agent | done | |
| UT_ironliver | SomewhatTraits | yes | agent | done | |
| UT_durability | MoreSimpleTraits | yes | agent | done | |
| UT_gourmand | MoreTraits | yes | agent | done | |
| UT_ascetic | MoreTraits | yes | agent | done | |

## Shared Blockers

- `UT_speedMod` modData key: multiple traits write this (UT_fast, UT_noodlelegs, UT_sorelegs, UT_lurcher). Last-write-wins risk if multiple active.
- `UT_sleepQualMod` modData key: UT_quickrest and UT_restfulsleeper both write this. Last-write-wins, no mutual exclusion defined.
- `UT_bleedDrainMult` modData key: UT_weaklybleedingwounds and UT_thickblood both write this. No mutual exclusion defined between them.
- `UT_damageMult` / `UT_fractureMult` / `UT_painImmune` / `UT_noiseMult` / `UT_transferSpeedMult` / `UT_combatAccuracyMod` / `UT_multiSkillPenalty`: modData keys written but no confirmed consumer exists. Potentially inert.

## Automation Candidates Found

- All `onPlayerUpdate` endurance drain/regen loops follow same pattern (30-tick counter). Could be tested with a shared harness.
- All vehicle traits use `UTCore.registerVehicleTrait` with enter/exit hooks — good candidate for shared test template.

## Critical Findings — Priority Tiers

### P0: INERT TRAITS (free points, no gameplay effect)
1. **UT_brittle** — writes `UT_fractureMult=1.5`, no consumer. -6 free points.
2. **UT_snorer** — writes `UT_noiseMult=2.0`, no consumer. -2 free points.
3. **UT_onetrickpony** — writes `UT_multiSkillPenalty=true`, no consumer. -4 free points.
4. **UT_analgesia** — writes `UT_painImmune=true`, no consumer. 12 wasted points (positive trait).
5. **UT_fasthands** — writes `UT_transferSpeedMult=0.6`, no consumer. 12 wasted points (positive trait).
6. **UT_restfulsleeper** — writes `UT_sleepQualMod=0.5`, no consumer. 6 wasted points (positive trait).
7. **UT_quickrest** — writes `UT_sleepQualMod=0.3`, no consumer. 3 wasted points (positive trait).
8. **UT_glassbody** — writes `UT_damageMult=1.5`, consumer unconfirmed. -10 possibly free points.

### P1: WRONG DESCRIPTIONS (code does not match what player reads)
1. **UT_batteringram** — says "+50% push force", code does collision knockdowns.
2. **UT_leadfoot** — says "+20% vehicle top speed", code does stomp-power buff.
3. **UT_lurcher** — says "-15% movement speed", code never applies speed penalty.
4. **UT_gourmand** — says "+30% hunger", code does +50%. Says "-0.05 boredom", no such code exists.
5. **UT_thickblood** — says "wounds stop bleeding twice as quickly", clot multiplier is 1.5x not 2x.

### P2: BALANCE ISSUES
1. **UT_slack vs UT_slowworker** — slack gives -6 for -20% penalty; slowworker gives -5 for -50%. Inverted.
2. **UT_ascetic** — -4 cost but 5-min eating window (~12 real seconds) rarely triggers. Effectively free points.
3. **UT_owlperson / UT_larkperson** — net stress sinks over 24h (2:1 ratio). No sleep guard.
4. **UT_noodlelegs** — permanent dual penalty (speed + drain) for -6 is much harsher than source's conditional trip.

### P3: MISSING MUTUAL EXCLUSIONS
1. **UT_weaklybleedingwounds + UT_thickblood** — share `UT_bleedDrainMult` key, no exclusion.
2. **UT_quickrest + UT_restfulsleeper** — share `UT_sleepQualMod` key, no exclusion.
3. **UT_flailer + UT_lurcher** — source excluded these; UT allows double-stack stumbles.
4. **UT_ironliver** — source excluded SWDrunkard; UT has no drinking trait exclusion.

### P4: TEST GAPS (nearly universal)
- Only 4 of 35 traits have behavioral tests beyond registration: UT_preparedpack, UT_expertdriver, UT_poordriver (strong), UT_noodlelegs/UT_fast/UT_quickworker (partial — sign checks only).
- 31 of 35 traits have no behavioral regression test.
