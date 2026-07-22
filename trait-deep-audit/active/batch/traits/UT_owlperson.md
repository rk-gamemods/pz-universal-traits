# UT_owlperson

## Audit result

- Trait ID: `UniversalTraits:UT_owlperson`
- Display name: Night Owl
- Accepted behavior authority: pre-campaign UTMods `master`, especially balance commit `df41a151c99cb2901577aff3c0a8a16013adf004`
- Cost: -1
- Exclusion: reciprocal with `UniversalTraits:UT_larkperson`
- Multiplayer: disabled by definition and outside product scope
- Overall state: runtime-unproven
- Static verdict: the critical time-domain defect is already corrected; exact behavior and remaining runtime proof are now separated

## Authority and intended outcome

MoreSimpleTraits and SomewhatTraits are lineage evidence only. Their Owl/Night Owl concepts modify fatigue or panic on different windows and cadences. UTMods deliberately redesigned the trait around stress.

Pre-campaign commit `df41a15` is explicit authority for the accepted UTMods balance contract. It changed the daytime penalty from +0.01 to +0.02 so the two 12-hour windows have equal and opposite nominal rates. The accepted outcome is:

1. From 18:00 inclusive through 06:00 exclusive, reduce stress by 0.02 per in-game minute, floored at 0.
2. From 06:00 inclusive through 18:00 exclusive, increase stress by 0.02 per in-game minute, capped at 1.
3. Apply regardless of sleep or location.
4. Run only for the current player with Night Owl.

The old English statement that the net effect over a full day is zero overstates the rate-balancing decision. Clamps and starting phase mean an observed 24-hour endpoint is not guaranteed to equal its starting value. The corrected copy states equal and opposite rates without promising a guaranteed net result.

## Definition, registration, and text

- Registration: `UniversalTraits/media/registries.lua:217`
- Definition: `UniversalTraits/media/scripts/UT_character_traits.txt`
- The definition costs -1, grants no XP or traits, disables multiplayer selection, and excludes Early Bird.
- Early Bird reciprocally excludes Night Owl.
- Display key: `UI_UT_owlperson`
- Description key: `UI_UT_owlpersonDesc`

## Runtime map

1. The shared module registers one local handler with `Events.EveryOneMinute`.
2. SVN 964 `GameTime` emits `EveryOneMinute` from `GameTime.java:738`.
3. The handler resolves `getPlayer()` and returns for nil or a player without Night Owl.
4. It reads `getGameTime():getTimeOfDay()` and current stress through the current `CharacterStat.STRESS` API.
5. Hours below 6 or at least 18 subtract 0.02 with a zero floor.
6. Hours from 6 inclusive through 18 exclusive add 0.02 with a one cap.

`GameTime.getTimeOfDay()` is a public float getter at `GameTime.java:1050`. Current engine consumers compare it with hour values, wrap at 24, and derive minutes from the fractional hour. This proves the 0-to-24 domain.

## Findings and resolutions

### B07-UT_owlperson-timeofday-domain: normalized fractions used against an hour clock

- Severity: critical
- Original reproduction: pre-campaign `master` accepted only values below 0.25 or above 0.75 as night even though the engine supplies hours. Most actual night hours therefore entered the daytime branch.
- Correction: development commit `2f98749c3ecaa323b5eb037c30a2ad98b43dc834` changed source and release to `< 6 or >= 18` without changing the accepted window.
- Regression: the shared boundary table covers 00:00, 05:59, 06:00, 17:59, 18:00, and 23:59 on the engine clock.
- Resolution: implemented and statically validated.

### B07-UT_owlperson-runtime-proof: no matching current-build observation

- Severity: medium
- Static evidence now proves the source path, engine time domain, numbers, guards, clamps, exclusion, tests, and package parity.
- Missing proof: full-relaunch current-build Kahlua execution, repeated world entry, current-version save/load, rendered English, balance, and profiler observation.
- Resolution: runtime-unproven. This is an exact validation requirement, not a confirmed functional defect.

### B07-UT_owlperson-net-zero-copy: guaranteed daily net-zero claim ignored clamps and phase

- Severity: medium
- Reproduction: equal nominal rates do not guarantee equal starting and ending stress after either branch reaches 0 or 1, or when the observation starts in a different phase.
- Correction: source and release English now state the exact windows, deltas, clamps, and unconditional scope, and describe the rates as equal and opposite without promising a net endpoint.
- Regression: the suite asserts the exact sentence and source-release equality.
- Resolution: implemented and statically validated.

## Numerical, state, and interaction contract

- Night starts at 18:00 inclusive and ends at 06:00 exclusive.
- Day starts at 06:00 inclusive and ends at 18:00 exclusive.
- Night delta is -0.02 per in-game minute with a zero floor.
- Day delta is +0.02 per in-game minute with a one cap.
- Both windows last 12 nominal hours and use equal absolute rates.
- There is no cooldown, modData, accumulator, location guard, or sleep guard.
- Night Owl and Early Bird cannot be selected together.
- Other stress effects compose through the shared Stats value and engine clamps.

## Test and mock evidence

Focused tests prove:

- exact -0.02 at night and +0.02 during day;
- lower and upper stress clamps;
- missing-trait rejection;
- 06:00 and 18:00 boundary opposition on the 0-to-24 clock;
- reciprocal Early Bird exclusion;
- exact English copy and source-release equality.

The GameTime mock exposes a controllable 0-to-24 hour value. Player, Stats, trait, event, and translation fixtures cover the full modeled path. Standard Lua proves the model, not current-build Kahlua execution.

## Lifecycle and performance

The handler is registered once during the normal shared-module load. It runs once per in-game minute, resolves one player, performs constant-time guards, and performs one bounded Stats write for an owner. There are no scans, item mutations, or per-frame hooks.

The trait owns no persistent state. Current-build repeated world entry, same-process manual reload, and save/load behavior remain unobserved. Static performance risk is low, but no profiler capture exists.

## Remaining proof and non-goals

Remaining open proof:

- current-build Kahlua execution after a full desktop relaunch;
- real 06:00 and 18:00 transitions, clamps, sleep, and location observation;
- repeated world entry and current-version save/load;
- rendered English in character creation and the character screen;
- profiler and gameplay balance observation;
- non-English localization, because no non-English UniversalTraits locale exists;
- read-only package verification's separately tracked missing source poster.

Explicit non-goals:

- multiplayer support;
- backward save migration;
- deployment or live-copy mutation;
- restoring upstream fatigue or panic mechanics, source windows, or cadences;
- changing the accepted cost, exclusion, stress deltas, or windows.

## Final verdict

Night Owl's accepted UTMods outcome is an unconditional circadian stress tradeoff with equal nominal rates in two 12-hour windows. The preserved development correction expresses those windows in the engine's actual hour domain. Exact tests and copy now match that outcome, while current-build execution and observational gaps remain explicitly runtime-unproven.
