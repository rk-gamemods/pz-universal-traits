# UT_immunocompromised

## Accepted Intent

- Authority: the pre-campaign `master` implementation, not the upstream MoreTraits mechanic.
- Trait id: `UniversalTraits:UT_immunocompromised`.
- Cost: -6.
- Cadence: every in-game minute.
- Effect: if `CharacterStat.ZOMBIE_INFECTION` is above 0, increase it by 1, capped at 100.
- New-game state: preserve the `UT_immunocompromised = true` modData marker.
- Scope: single-player. Multiplayer support and old-save migration are non-goals.
- Exclusions: `UT_superimmune` and `UT_immuneresponse`, reciprocally defined.

The upstream MoreTraits trait modifies individual wound infections. That upstream behavior is historical origin evidence only. Restoring it would change the pre-campaign UTMods intent and is not authorized.

## Confirmed Defect

The pre-campaign runtime read `BodyDamage:getApparentInfectionLevel()` and wrote the result plus 1 into `CharacterStat.ZOMBIE_INFECTION`. In the current SVN 964 baseline, `getApparentInfectionLevel()` returns the maximum of food sickness, zombie fever, and zombie infection. Ordinary food sickness or a higher zombie-fever value could therefore create or sharply increase zombie infection.

Engine anchors:

- `PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:1664-1667`
- `PZCodebase/Java/source/zombie/characters/CharacterStat.java:35`

## Correction

The minute handler now reads and writes only `CharacterStat.ZOMBIE_INFECTION`. The increase, cap, cadence, cost, marker, exclusions, registration, and event remain unchanged. The English description states the exact channel, cadence, increase, and cap.

The minute callback also removes its prior same-process registration before adding the current function. This preserves the intended single 1-point increase if the module is loaded again during testing or development.

No new infection-state condition was introduced. Reading the direct stat is the smallest correction and preserves the accepted pre-campaign outcome.

## Regression Proof

The standard-Lua suite covers:

1. the new-game marker;
2. direct zombie infection increase from 50 to 51;
3. food sickness at 80 with zero zombie infection does not create infection;
4. zombie fever at 80 does not replace an underlying zombie infection of 10, which becomes 11;
5. food sickness and zombie fever remain unchanged;
6. zombie infection caps at 100;
7. a same-process module reload still produces exactly one 1-point increase;
8. source and release consistency through the existing package audit.

## Remaining Runtime Proof

- Full Kahlua execution after Exit to Desktop and relaunch.
- A current-version save/load cycle.
- Rendered English description observation.

These are exact runtime validation requirements. They do not weaken the stat-channel proof or authorize restoring the upstream wound mechanic.

## Verdict

- Confirmed defect: corrected.
- Honest trait intent: preserved.
- Source/release runtime and English copy: synchronized.
- Static and mocked behavioral proof: complete for the defect, boundaries, reload behavior, and counterexamples.
- In-game proof: still required before final whole-campaign closure.
