# UT_competitiveeater

## Accepted contract

- Trait: `UniversalTraits:UT_competitiveeater`
- Cost: 3
- Multiplayer: disabled; multiplayer support is a product non-goal
- Trigger: each completed or interrupted positive food-consumption event
- Effect: after native food effects, remove 10 boredom points and 0.05 hunger
- Bounds: both values stop at zero
- Exclusions: Anorexy and Gourmand, reciprocal in both directions

## Intent authority

The pre-campaign branch is the accepted product baseline. Git history supplies the missing numerical and migration context:

- `e87e49d` introduced one eating-event bonus of boredom `-0.1` and hunger `-0.05` through the nonexistent Build 42 `Events.OnEat` path.
- `16e1f1e` was explicitly an event-migration change. It replaced that path with `healthFromFoodTimer` polling but also changed the stat arguments to boredom `-10` and hunger `-5` without documenting a balance redesign.
- The pre-campaign runtime and header retain the accepted 10-point boredom reduction and describe both effects as slight. Current SVN 964 proves boredom uses a 0 to 100 domain while hunger uses a 0 to 1 domain. The `-5` hunger argument therefore emptied the entire meter and contradicted the accepted description. The corrected hunger effect is the original `-0.05`; the accepted pre-campaign 10-point boredom effect is preserved.
- `be6eed18` states that its food exclusion is `competitiveeater <-> gourmand` and that all exclusions in that commit are symmetric. The commit changed only Competitive Eater's side. Adding Competitive Eater to Gourmand repairs that declared contract.

This is an original UTMods trait. No installed source-mod implementation was found, so no unrelated external behavior is imported.

## Runtime trace

SVN 964 keeps completed and interrupted consumption separate:

1. A completed `ISEatFoodAction` calls `character:Eat(...)` and then returns through `complete()`.
2. An interrupted action calls `eat(food, percentage)`, which invokes the effective-fraction `character:Eat(...)` path.
3. `UT_ItemConsumptionHooks.lua` wraps both methods, runs the native method first, and then dispatches post-consumption trait effects only when the consumed fraction is positive.
4. Competitive Eater reads `CharacterStat.BOREDOM` and `CharacterStat.HUNGER`, then writes `max(0, current - 10)` and `max(0, current - 0.05)`.
5. Stable wrapper sentinels prevent repeated startup or same-process script load from stacking wrappers.
6. `UT_competitiveeater.lua` unregisters the obsolete tick handler and owns no loop or persistent state.

The old `healthFromFoodTimer` path was invalid because the engine does not raise that timer for every ordinary meal and the trait polled it on every player update.

## Player-facing contract

- Display name: `Competitive Eater`
- English description: `You eat with purpose and efficiency. Each time you eat, boredom decreases by 10 points and hunger decreases by 0.05 (5 percent of the hunger meter).`
- The description now states the trigger, both magnitudes, and the hunger-meter interpretation.
- Only English UI localization exists in the closed-world UniversalTraits inventory. Non-English localization remains a coverage gap.

## Regression proof

The standard-Lua suite covers:

- exact completed-consumption ordering and deltas;
- exact interrupted partial-consumption behavior;
- zero bounds for both stats;
- zero-consumption and missing-trait no-ops;
- absence of player-update polling, stale mod data, and a registered tick handler;
- no effect from `perform()` before actual consumption;
- coexistence in the shared wrapper with Anorexy without double application;
- reciprocal Competitive Eater and Gourmand exclusions;
- exact English copy;
- source and 42.0 release byte parity for runtime, shared hook, definition, and English UI.

## Remaining runtime proof

Static behavior is corrected and regression-covered. The following observations remain runtime-unproven:

- current-build Kahlua execution after a full Exit to Desktop relaunch;
- completed and interrupted eating in game;
- repeated world entry and current-version save/load;
- rendered English text;
- gameplay balance telemetry and profiler capture.

Backward save migration, multiplayer, and deployment are explicit non-goals.

## Verdict

The confirmed detection, scale, cadence, description, exclusion, and coverage defects are statically corrected. The trait remains `runtime-unproven` only for the listed in-game observations.
