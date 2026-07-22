# UT_batteringram

## Audit result

- Trait ID: `UniversalTraits:UT_batteringram`
- Source lineage: More Traits / `ToadTraits:batteringram`
- Accepted behavior authority: pre-campaign UTMods `master`
- Cost: 7
- Multiplayer: disabled by definition and outside product scope
- Overall state: runtime-unproven
- Static verdict: the accepted knockdown-only behavior is now accurately described and protected against stale callback ownership

## Authority and intended outcome

The installed More Traits source is lineage evidence, not the current behavior authority. Its older implementation used sprint-only ghost mode, a leg-fracture gate, a spotted-zombie scan, fitness-scaled endurance loss, and optional Martial synergy.

UTMods deliberately evolved away from that implementation before this campaign. Commit `2b03dc140bfdc61322135b59f1e6cd80d6b3770a` is the controlling pre-campaign decision. Its subject is `fix!: remove setBumpedChr guard - root cause of permanent freezes`, and its body explicitly defines ZombieCollisionHook v4 as a breaking, knockdown-only defense. It removed all player bump-state manipulation after four documented freeze paths. Restoring promised trip or stagger immunity would reverse that accepted decision and reintroduce the unsafe design class.

The accepted net outcome is therefore:

1. While running or sprinting, a newly encountered live zombie within 0.7 tiles is knocked down once per encounter.
2. Running drains 0.05 endurance.
3. Sprinting drains 0.03 endurance and attempts 0.15 direct zombie health damage.
4. Martial Artist additionally delegates to its existing `applyBonusDamage` contract.
5. The trait does not manipulate `bumpedChr`, `bumpType`, `bumpFall`, `blockMovement`, or `bumpDone`, so normal engine trip or stagger remains possible.

## Definition, registration, and text

- Registration: `UniversalTraits/media/registries.lua:165`
- Definition: `UniversalTraits/media/scripts/UT_character_traits.txt:1217-1225`
- The definition is a non-profession trait, costs 7, has no XP boosts, grants, or mutual exclusions, and is disabled in multiplayer.
- Display key: `UI_UT_batteringram`
- Description key: `UI_UT_batteringramDesc`
- Source and 42.0 release text are required to be byte-identical.

The previous English description promised that collision knockdown happened instead of player stagger and claimed immunity to trip and stagger. The v4 source explicitly did not provide that outcome. The corrected text states the exact numbers, Martial Artist interaction, and lack of bump immunity.

## Runtime map

### Declaration and ownership

`UT_batteringram.lua:61` declares one handler through `UTCore.declareZombieCollisionHandler`. `UTCore_ZombieCollisionHook.lua:219-230` receives `OnCreatePlayer` and now reconciles the declared handler with the current player's trait set. `UTCore_ZombieCollisionHook.lua:238-260` repeats that reconciliation every ten `EveryOneMinute` events to repair callback-table drift or trait-set changes.

The callback also checks `UTCore.hasTrait(player, TRAIT_ID)` before applying any effect. This is a defense at the effect boundary if another caller retains the function after its registration is no longer valid.

### Per-update path

1. `IsoPlayer.update` emits `OnPlayerUpdate` at `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2241`.
2. UTCore dispatches `ZombieCollisionHook` at priority 0.
3. If no collision callbacks are active, the hook returns after one counter check.
4. If the player is not running or sprinting, the hook clears per-encounter dedup state and returns.
5. Otherwise, it examines the 3 by 3 square neighborhood around the current square.
6. It accepts only live `IsoZombie` objects on the same height within 0.7 tiles.
7. `player.modData.UT_handledZombies` deduplicates each zombie while it remains in range. Leaving range or stopping resets eligibility.
8. On first entry, the hook invokes every active callback through `pcall`.
9. Battering Ram verifies trait ownership and movement again, calls `zombie:knockDown(true)`, applies the running or sprinting numbers, and optionally invokes Martial Artist.

### Engine bump path

`IsoPlayer.update` calls `separate()` later at line 2646. `IsoMovingObject.separate()` still evaluates player movement and `getBumpedChr() != obj` at lines 1198 and 1216. `IsoZombie.knockDown(boolean)` exists at line 4916, but the state change does not establish that all later separation and bump conditions are suppressed during the same update.

Because v4 never writes the player's bump fields, the static call graph proves knockdown behavior but does not prove trip or stagger immunity. The description must not promise immunity.

## Confirmed defects and corrections

### B02-UT_batteringram-01: stale player-facing contract

- Severity: high
- Reproduction: compare the former English immunity promise with v4 source and the engine ordering above.
- Root cause: the description was not updated when pre-campaign commit `2b03dc1` deliberately removed bump suppression.
- Correction: English source and release now state the exact knockdown-only contract and numerical effects.
- Regression: the UniversalTraits suite asserts the exact English value, source-release equality, no player bump-state mutation, and engine event ordering.
- Resolution: implemented and statically validated.

### B02-UT_batteringram-02: callback ownership leaked across players

- Severity: high
- Reproduction before correction: create a player with Battering Ram, fire `OnCreatePlayer`, then create a player without the trait and fire `OnCreatePlayer` again. The declaration logic only added callbacks, so the old callback remained active. The callback itself did not recheck ownership.
- Effect: a later player without Battering Ram could receive knockdown, damage, and endurance behavior from the previous player's registration.
- Correction: both `OnCreatePlayer` and periodic integrity handling now register eligible declarations and unregister ineligible declarations. The trait callback independently rejects a player without the trait.
- Regression: UT_CORE covers player switch and periodic trait loss. UniversalTraits retains the function, calls it with a non-owner, proves no zombie effect, then proves current-player reconciliation removes it and restores the count to zero.
- Resolution: implemented and statically validated.

## Numerical and interaction contract

- Collision range: strictly less than 0.7 tiles.
- Vertical tolerance: at most 0.3.
- Running endurance drain: 0.05, floored at zero.
- Sprinting endurance drain: 0.03, floored at zero.
- Sprint direct damage attempt: 0.15 health.
- A nil Stats receiver does not undo knockdown or sprint damage; the handler reports that the effect ran and skips endurance and Martial processing.
- Martial Artist receives the post-drain endurance value and owns its own bonus-damage formula.
- The hook deduplicates by the zombie object's `tostring` identity for the current encounter.
- No persistent cooldown exists. Dedup state is temporary player modData and is rebuilt from current proximity.

## Test and mock evidence

The focused UniversalTraits tests cover:

- absent-trait rejection and registration removal;
- sprint and run activation, walking no-op, range and height boundaries;
- live-zombie filtering and Java-list iteration;
- once-per-encounter dedup and reset after stopping or leaving range;
- exact 0.03 sprint drain, 0.05 run drain, and zero floor;
- sprint damage and Martial Artist delegation;
- nil Stats behavior and callback return values;
- no mutation of player bump state;
- exact English source/release copy;
- `OnPlayerUpdate` ordering before engine `separate()` and the current bump guard symbols.

The UT_CORE suite separately proves declaration idempotence, missing-handler repair, current-player removal, periodic trait-loss removal, callback count reconciliation, no-handler fast return, Java-list traversal, distance handling, dedup, dead-zombie filtering, and callback error containment.

These standard-Lua mocks preserve zero-based Java-list access for moving objects. They prove the modeled call contract, not current-build Kahlua execution.

## Performance and lifecycle assessment

The no-handler path is O(1). With Battering Ram active, the hook runs on each player update while moving and searches at most nine grid squares plus their moving-object lists. It invokes the trait only for a new live zombie inside the collision radius. The integrity path runs once per ten `EveryOneMinute` events and iterates the small declaration table.

This is structurally bounded by local square occupancy, but no current-build profiler capture exists. Performance therefore remains runtime-unproven.

Repeated player or world entry is statically reconciled, and the callback has a local ownership fence. Full desktop relaunch, current-version save/load, and repeated-world-entry execution remain unobserved in the game.

## Remaining proof and non-goals

Remaining open proof:

- current-build Kahlua execution after a full desktop relaunch;
- rendered English in character creation and the character screen;
- repeated world entry and current-version save/load observation;
- profiler capture under a dense local zombie population;
- gameplay balance observation for cost 7 and the fixed numerical effects;
- non-English localization, because no non-English UniversalTraits locale exists;
- read-only package verification reports no source-release drift, but both UniversalTraits and UT_CORE lack their separately tracked source poster.

Explicit non-goals:

- multiplayer support;
- backward save migration;
- deployment or live-copy mutation;
- restoring the upstream More Traits ghost-mode or fracture-gate implementation;
- restoring player bump-state suppression without separate user approval of a changed intended outcome.

## Final verdict

The accepted pre-campaign trait is a proactive, knockdown-only collision effect, not trip or stagger immunity. Its text now matches that intended outcome. The callback lifecycle no longer leaks the effect to a later player without the trait, and the effect boundary has an independent trait-ownership guard. Static source, engine trace, focused regressions, and source-release parity support the correction. Current-build runtime, rendered UI, performance, and balance proof remain explicitly open.
