# UT_immuneresponse

## Accepted Intent

- Authority: the pre-campaign `master` implementation, not the upstream SomewhatTraits mechanic.
- Trait id: `UniversalTraits:UT_immuneresponse`.
- Cost: 6.
- Cadence: every 10 in-game minutes.
- Effect: reduce `CharacterStat.ZOMBIE_INFECTION` by 3, floored at 0, and reduce fatigue by 0.02, floored at 0.
- Scope: single-player. Multiplayer support and old-save migration are non-goals.
- Exclusions: `UT_superimmune` and `UT_immunocompromised`, reciprocally defined.

The upstream SomewhatTraits trait instead improves fatigue and endurance while infected. That upstream behavior is historical origin evidence only. Restoring it would change the pre-campaign UTMods intent and is not authorized.

## Confirmed Defect

The pre-campaign runtime read `BodyDamage:getApparentInfectionLevel()` and wrote the result into `CharacterStat.ZOMBIE_INFECTION`. In the current SVN 964 baseline, `getApparentInfectionLevel()` returns the maximum of food sickness, zombie fever, and zombie infection. A character with ordinary food sickness or a higher zombie-fever value could therefore have that unrelated value copied into the zombie-infection channel.

Engine anchors:

- `PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:1664-1667`
- `PZCodebase/Java/source/zombie/characters/CharacterStat.java:35`

## Correction

The handler now reads and writes only `CharacterStat.ZOMBIE_INFECTION`. The reduction, floor, cadence, fatigue benefit, cost, exclusions, registration, and event remain unchanged. The English description now states the exact two effects and values.

No `isInfected()` gate was added. The direct stat channel is the smallest correction and preserves the accepted pre-campaign behavior without adding a new condition.

## Regression Proof

The standard-Lua suite covers:

1. direct zombie infection reduction from 50 to 47;
2. fatigue reduction from 0.40 to 0.38;
3. food sickness at 80 with zero zombie infection does not create infection;
4. zombie fever at 80 does not replace an underlying zombie infection of 10, which becomes 7;
5. food sickness and zombie fever remain unchanged;
6. infection reduction floors at zero;
7. source and release consistency through the existing package audit.

## Remaining Runtime Proof

- Full Kahlua execution after Exit to Desktop and relaunch.
- A current-version save/load cycle.
- Rendered English description observation.

These are exact runtime validation requirements. They do not weaken the stat-channel proof or justify restoring the upstream mechanic.

## Verdict

- Confirmed defect: corrected.
- Honest trait intent: preserved.
- Source/release runtime and English copy: synchronized.
- Static and mocked behavioral proof: complete for the defect and its counterexamples.
- In-game proof: still required before final whole-campaign closure.
