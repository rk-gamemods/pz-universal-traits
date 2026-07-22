# UT_albino

## Audit result

- Trait ID: `UniversalTraits:UT_albino`
- Source lineage: More Traits / `ToadTraits:albino`
- Accepted behavior authority: pre-campaign UTMods `master`
- Cost: -4
- Exclusion: reciprocal with `UniversalTraits:UT_badteeth`
- Multiplayer: disabled by definition and outside product scope
- Overall state: runtime-unproven
- Static verdict: the daylight-domain defect is fixed, exact behavior is tested and described, and no intended behavior was changed

## Authority and intended outcome

The upstream More Traits trait is lineage evidence. It used a more complex pain accumulator, an 08:00 to 17:00 exposure window, umbrella mitigation, head pain, and multiplayer commands. UTMods had already selected a simpler single-player outcome before this campaign: every in-game minute outdoors during its intended daylight window adds fixed stress and fatigue.

Pre-campaign `master` is the accepted behavior authority. Its runtime comment and effect establish:

1. Daylight exposure is the trigger.
2. The player must be outdoors and own Albino.
3. Each `EveryOneMinute` event adds 0.03 stress and 0.02 fatigue.
4. Both meters cap at 1.0.
5. `UT_albinoDamage` records whether the effect is currently active.
6. The intended 0.25 to 0.75 daylight bounds represented 06:00 to 18:00, but used the wrong domain for the current engine API.

Development commit `2f98749c3ecaa323b5eb037c30a2ad98b43dc834` corrected only the time-domain expression to `timeOfDay >= 6 and timeOfDay < 18`. It retained the intended 12-hour window and every other effect.

## Definition, registration, and text

- Registration: `UniversalTraits/media/registries.lua:257`
- Definition: `UniversalTraits/media/scripts/UT_character_traits.txt:1779-1788`
- The definition costs -4, has no XP boosts or grants, is disabled in multiplayer, and excludes Bad Teeth.
- Bad Teeth excludes Albino in the reverse direction. The same reciprocal relationship exists in the upstream More Traits definitions, so it is accepted lineage and pre-campaign intent rather than an unexplained campaign addition.
- Display key: `UI_UT_albino`
- Description key: `UI_UT_albinoDesc`

The former English copy promised unspecified physical harm. The runtime does not call health, body-damage, pain, or wound APIs. The corrected copy states the exact daylight window, cadence, stress increment, fatigue increment, and caps.

## Runtime map

1. The trait module registers one local handler with `Events.EveryOneMinute`.
2. `GameTime` emits `EveryOneMinute` from `PZCodebase/Java/source/zombie/GameTime.java:738`.
3. The handler resolves the current single-player character with `getPlayer()`.
4. Nil player and missing-trait paths return without work.
5. Indoor players set `UT_albinoDamage` false and receive no stat change.
6. Outdoor players read `getGameTime():getTimeOfDay()`.
7. Hours from 06:00 inclusive through 18:00 exclusive add exactly 0.03 stress and 0.02 fatigue, each capped at 1.0, then set the flag true.
8. All other hours set the flag false and leave both stats unchanged.

`GameTime.getTimeOfDay()` is a public float getter at `GameTime.java:1050`. Current engine consumers compare it with hour values such as 7.0, wrap it at 24.0, and derive minutes from its fractional hour. This proves the 0-to-24 domain.

## Findings and resolutions

### B01-ALB-TIME: wrong daylight time domain

- Severity: high
- Original reproduction: on `master`, noon was 12.0, but the handler accepted only values from 0.25 through 0.75. The effect therefore ran only shortly after midnight rather than during daylight.
- Correction: development commit `2f98749` changed the bounds to 6 inclusive and 18 exclusive in both source and release.
- Regression: the shared boundary table covers 00:00, 05:59, 06:00, 17:59, 18:00, and 23:59 on the 0-to-24 engine clock.
- Resolution: implemented and statically validated.

### IR0104-ALBINO-PHYSICAL-HARM: misleading English copy

- Severity: medium
- Reproduction: the former copy promised physical harm, while the complete runtime path only writes stress, fatigue, and the activity flag.
- Correction: source and release English now state the exact accepted effect and no longer promise damage or pain.
- Regression: the suite asserts the exact sentence and byte-identical source-release UI files.
- Resolution: implemented and statically validated.

### IR0104-ALBINO-CROSS-EXCLUSION: previously questioned exclusion

- Severity: medium
- Evidence: Albino and Bad Teeth exclude each other in both directions on pre-campaign `master`. The upstream `ToadTraits:albino` and `ToadTraits:badteeth` definitions also exclude each other.
- Resolution: proven intended. No definition change is indicated.

## Numerical, state, and interaction contract

- Day starts at 06:00 inclusive.
- Day ends at 18:00 exclusive.
- Active cadence is once per in-game minute.
- Stress delta is +0.03 per qualifying event, capped at 1.0.
- Fatigue delta is +0.02 per qualifying event, capped at 1.0.
- `UT_albinoDamage` is true only after a qualifying outdoor daylight event and is cleared by an indoor or non-daylight event.
- The flag has no consumer in the current closed-world UTMods source. It is retained because removing it is unnecessary and could break an external observer.
- Albino and Bad Teeth cannot be selected together.
- Other stress or fatigue traits compose additively through the engine Stats surface. No shared item or global mutable object is involved.
- No cooldown, accumulator, umbrella mitigation, health damage, pain, or passive recovery is part of the accepted UTMods implementation.

## Test and mock evidence

Focused tests prove:

- exact +0.03 stress and +0.02 fatigue at noon;
- exact caps at 1.0;
- the true activity flag during a qualifying event;
- indoor no-op and flag clearing;
- non-daylight no-op and flag clearing;
- 06:00 and 18:00 boundary opposition on the 0-to-24 clock;
- exact English copy and source-release equality;
- reciprocal Bad Teeth exclusion in both definition copies.

The GameTime mock exposes a controllable 0-to-24 `getTimeOfDay()` value. Stats are explicitly bounded by production code, so the tests do not rely on mock clamping for the cap result. Standard Lua and mocks prove the modeled contract, not current-build Kahlua execution.

## Lifecycle and performance

The handler is registered once when the shared trait module is loaded. It runs at `EveryOneMinute`, resolves one player, performs two early guards, and reads or writes a constant amount of state. There are no collection scans, loops, wrappers, or per-frame work.

The only persistent field is the boolean activity flag. The next indoor or non-daylight event reconciles it to false. Full desktop relaunch, repeated world entry, and current-version save/load remain unobserved in the game.

The static performance risk is low, but no current-build profiler capture exists, so performance remains runtime-unproven.

## Remaining proof and non-goals

Remaining open proof:

- current-build Kahlua execution after a full desktop relaunch;
- repeated world entry and current-version save/load observation;
- rendered English in character creation and the character screen;
- profiler and gameplay balance observation;
- non-English localization, because no non-English UniversalTraits locale exists;
- read-only package verification's separately tracked missing UniversalTraits source poster.

Explicit non-goals:

- multiplayer support;
- backward save migration;
- deployment or live-copy mutation;
- restoring upstream pain accumulation, umbrella mitigation, multiplayer commands, or its different daylight window;
- changing the accepted cost, exclusion, cadence, or stat magnitudes.

## Final verdict

Albino's accepted UTMods outcome is a fixed stress and fatigue penalty during outdoor daylight, not physical damage. The earlier development correction preserved that intent while converting the daylight bounds to the engine's actual 0-to-24 domain. The translation and focused regressions now match the implemented outcome. Current-build runtime, rendered UI, performance, balance, and non-English localization remain explicitly open.
