# UT_anorexy

## Accepted Contract

- Authority: pre-campaign UTMods `master` and its directly traceable Git history.
- Trait ID: `UniversalTraits:UT_anorexy`.
- Cost: -6.
- Exclusions: `UniversalTraits:UT_gourmand`, `UniversalTraits:UT_competitiveeater`, and `UniversalTraits:UT_mundane`, declared reciprocally.
- Intended outcome: each completed or interrupted positive food-consumption event adds exactly 0.10 stress after the food's own stat effects, capped at the stress maximum of 1.0.
- Scope: single-player. Multiplayer and backward save migration are explicit non-goals.

The initial UT implementation in commit `e87e49d` used the then-available `Events.OnEat` path and added 0.10 stress. The Build 42 migration in commit `16e1f1e` replaced that missing event with food-health-timer polling, but also changed the magnitude to `Stats:add(CharacterStat.STRESS, 10)`. That migration is the source of both confirmed defects. The accepted behavior is the pre-migration UT outcome, not the much larger upstream DTEM mechanic.

## Historical Source Boundary

Dynamic Traits Expanded Moodles is lineage evidence only. Its active Anorexy hunger symptoms apply varying stress, unhappiness, and food-sickness effects while an eating moodle is present. Pre-campaign UTMods deliberately reduced that design to one bounded stress effect per eating event. The upstream passive symptoms, dynamic trait acquisition, and varying magnitude were not restored.

## Corrected Runtime Trace

1. `UT_ItemConsumptionHooks.lua` installs one wrapper around `ISEatFoodAction.complete` and one around `ISEatFoodAction.eat` after the timed-action class is available.
2. A normal completed action reaches `ISEatFoodAction.complete`, which calls `character:Eat(item, percentage, useUtensil)` before the wrapper continues.
3. An interrupted action reaches `ISEatFoodAction.eat`, which converts action progress into the effective consumed fraction and calls the same Java `Eat` method before the wrapper continues.
4. The wrapper ignores nil, zero, or negative consumption and characters without Anorexy.
5. After native food effects are complete, it reads `CharacterStat.STRESS` and writes `min(1.0, stress + 0.10)`.
6. The completed and interrupted paths are separate in SVN 964, so one consumption event reaches one Anorexy wrapper.
7. Stable sentinel fields make repeated installer calls and same-process script reloads no-ops instead of adding wrapper layers.
8. `UT_anorexy.lua` removes any obsolete tick registration during a same-process reload. No persistent food timer or per-update state remains.

## Engine Contract

- SVN 964 `IsoGameCharacter.Eat` clamps the consumed percentage, applies the food's stress change, and then runs the remaining native food effects.
- SVN 964 `ISEatFoodAction.complete` calls `character:Eat` and returns true.
- SVN 964 `ISEatFoodAction.eat` multiplies interrupted progress by the action's selected percentage before calling `character:Eat`.
- The character action loop calls `perform` before `complete`. The older shared `perform` hook therefore cannot truthfully prove that food was consumed; the Anorexy effect is attached to the post-consumption methods instead.
- SVN 964 `CharacterStat.STRESS` has a 0.0 to 1.0 domain. `Stats.add` delegates to the clamped setter, so adding 10 would immediately saturate ordinary stress values.
- `BodyDamage.healthFromFoodTimer` changes only for particular food-healing conditions and can reset for dangerous uncooked food. It is not an eating-event contract.

## Corrected Defects

- Replaced `+10` stress with the accepted `+0.10`, capped at 1.0.
- Replaced the every-player-update food timer heuristic with the actual completed and interrupted food-consumption paths.
- Removed the obsolete tick handler and `UT_anorexy_prevTimer` state.
- Covered partial food, zero consumption, no-trait behavior, native-effect ordering, cap behavior, and same-process reload idempotence.
- Updated the English description to state the exact trigger and magnitude.

## Performance Contract

- Anorexy adds no global update handler, timer, polling loop, process, inventory scan, or persistent state.
- It reuses the existing shared item-consumption module.
- Inactive players pay one trait lookup only when food is actually consumed.
- An active Anorexy player adds one stress read, one bounded arithmetic operation, and one stress write per positive consumption event.
- Static work is event-bounded. A current-build profiler capture remains required for empirical runtime proof.

## Regression Proof

- UniversalTraits standard-Lua suite: 454 passed, 0 failed before campaign regeneration.
- Focused coverage proves exact +0.10 behavior after native food effects, the 1.0 cap, interrupted partial consumption, zero-consumption and no-trait no-ops, absence of update polling and stale mod data, and no effect from `perform` alone.
- Reload coverage proves the existing perform/drink wrappers and both new post-consumption wrappers remain single stable functions after script reload and repeated startup events.
- Exact English copy and source/release parity are regression-protected.
- Read-only package verification reports no release-content issues. Its only blocker is the missing source `poster.png`, which is separately tracked and predates this correction.

## Remaining Runtime Proof

- Execute under the current Kahlua runtime after a full Exit to Desktop and relaunch.
- Observe one completed meal and one interrupted partial meal. Confirm each adds exactly 0.10 after the food's own stress change and never exceeds 1.0.
- Re-enter a world in the same process and confirm one consumption still applies one increment.
- Save and reload a current-version Anorexy character, then repeat both consumption paths.
- Capture a representative profiler sample. Rendered English and balance telemetry remain unobserved.

## Verdict

The accepted one-event, +0.10 stress contract is statically reconciled and regression-protected without a polling loop. Current-build Kahlua execution, current-version save/load, rendering, balance, and empirical performance remain explicitly runtime-unproven. No deployment was performed.
