# UT_scardycat

## Accepted intent

- Authority: pre-campaign `master`, not the original SomewhatTraits implementation.
- Trait ID: `UniversalTraits:UT_scardycat`.
- Cost: `-3`.
- Exclusions: `UniversalTraits:UT_flailer` and `base:desensitized`.
- Panic effect: compare panic once per in-game minute. A fresh rise of at least 5 points adds 15 more points, capped at 100.
- Scream effect: while at least 9 living spotted zombies are present, each eligible player update rolls a 3 percent scream chance. A scream emits world sound at radius and volume 15, says `!`, and starts a 120-player-update cooldown.
- Multiplayer is disabled and is outside the product roadmap.

The SomewhatTraits source remains provenance evidence only. It used a different close-zombie API and probability curve. Those source differences do not override the accepted pre-campaign UT behavior.

## Pre-campaign and current surfaces

- Runtime source: `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_scardycat.lua`.
- Runtime release: `UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_scardycat.lua`.
- Definition source and release: `UT_character_traits.txt`.
- English source and release: `Translate/EN/UI.json`.
- Regression harness: `UniversalTraits/test/run_tests.lua`.
- Dispatcher contracts: `UTCore.registerPeriodicHandler`, `UTCore.unregisterTickHandler`, `UTCore.registerTickHandler`, and `UTCore.getLivingEnemies`.

Pre-campaign master and the campaign starting point agreed on the two effects, the numbers, the cost, and the exclusions. The campaign therefore has no authority to replace the panic window with a different trigger or to recalibrate the scream cadence without user approval.

## Confirmed defects

### B09-SCARDYCAT-001: the panic bonus retriggered itself

The old minute handler read the external panic value into `current`, added 15 when the rise was at least 5, but stored the pre-bonus `current` value as the next baseline. On the next minute, the trait's own 15-point write still looked like a new external increase. It could therefore add another 15 every minute until panic reached 100 even when nothing else raised panic.

Correction: after applying and clamping the bonus, the handler now stores the post-bonus value. Only a later external rise of at least 5 points can trigger another bonus.

### B09-SCARDYCAT-002: English described an event callback that did not exist

The old English text said that each panic event added `+0.15`. The runtime has always sampled net panic change once per minute, and the current Build 42 panic domain is 0 through 100. The runtime amount is 15 points, not a 0.15 write.

Correction: English now states the real minute-window threshold and 15-point addition. Runtime comments use the same domain. This is a documentation correction, not a behavior change.

### B09-SCARDYCAT-003: scream timing remains update-rate dependent

The scream chance is evaluated on player updates, and the cooldown is also counted in player updates. Its real-time frequency therefore varies with update frequency. Changing this to game-time or a fixed interval requires choosing a new calibrated frequency, which would materially change the accepted effect. This finding remains open for user direction.

## Runtime trace

### Panic path

1. `UTCore.registerPeriodicHandler` owns exactly one `EveryOneMinute` wrapper for the namespaced trait and replaces the previous closure on reload.
2. The wrapper resolves the current player at call time.
3. A different player object resets the transient comparison state.
4. Trait absence clears the previous panic baseline, so later reacquisition begins with a fresh sample.
5. The handler reads `CharacterStat.PANIC` in the current 0 through 100 domain.
6. A rise below 5 records the current value without adding panic.
7. A rise of at least 5 adds 15, clamps to 100, writes the result, and records that post-bonus value.

The transient baseline is not save data. A new Lua process or player object takes one baseline sample before it can apply a bonus. This prevents a stale pre-load comparison from manufacturing a panic event.

### Scream path

1. `UTCore.registerTickHandler` gates dispatch by trait ownership.
2. `UTCore.getLivingEnemies` traverses the Java spotted list with 0-based indexing, excludes dead entries, and provides the living count through the tick cache.
3. Counts from 0 through 8 do nothing.
4. At 9 or more living enemies, `ZombRand(100) < 3` succeeds for values 0, 1, or 2.
5. Success calls the verified six-argument `addSound` form with radius 15 and volume 15, then calls `player:Say("!")`.
6. The player modData cooldown is set to 120. Each subsequent active dispatch decrements it and returns until it reaches zero.

Reload first unregisters the old tick handler, while the periodic registry replaces its exact prior wrapper. Focused tests prove that one periodic entry and one tick handler remain.

## Definition, translation, and packaging

- The definition retains `Cost = -3`.
- The definition retains both exclusions.
- `DisabledInMultiplayer = true` is unchanged.
- English names the exact panic threshold, bonus, living-enemy threshold, chance domain, and cooldown unit.
- Runtime and English source/release pairs are byte-identical.
- The `42.0` release paths remain the only supported package paths.

No non-English UniversalTraits locale exists. That remains a product-wide localization coverage gap rather than a Scaredy Cat-specific translation regression.

## Regression proof

The standard Lua suite proves:

- the first fresh rise applies exactly one 15-point bonus;
- the trait cannot retrigger its own bonus on the next minute;
- a later external rise can trigger one new bonus;
- panic caps at 100 without repeating;
- a rise below 5 does nothing;
- trait loss clears the comparison baseline and reacquisition starts cleanly;
- duplicate module load applies one cascade and leaves one periodic plus one tick registration;
- dead zombies do not count toward the 9-living-enemy threshold;
- 7 living plus 3 dead zombies do not scream;
- 9 living zombies can scream on a successful roll;
- cost, exclusions, exact English, and source/release copies match.

## Remaining runtime proof

- Full game exit and relaunch on the current supported build.
- Observe minute-boundary panic changes and verify no self-retrigger.
- Observe trait removal/reacquisition and a current-version save/load cycle.
- Observe the audible world sound and living-zombie threshold in game.
- Measure update frequency and scream timing under representative load.
- Render the revised English in the trait UI.

## Verdict

The panic cascade and its English contract are corrected without changing the accepted outcome. Static source, dispatcher, API, state, reload, definition, translation, release, and regression evidence are strong. The trait remains `confirmed-defect` only because the pre-existing update-rate-dependent scream cadence requires a user-approved calibration decision. Multiplayer, backward save migration, deployment, and changes to cost, exclusions, panic magnitude, or scream frequency are outside this correction.
