# UT_martial

## Audit result

- Trait ID: `UniversalTraits:UT_martial`
- Display name: Martial Artist
- Accepted behavior authority: pre-campaign UTMods `master`, especially retune commit `d92ca9cacd70692479f101b4224a9c5bd4bba64d`
- Cost: 5
- XP boosts: Fitness +1 and Short Blunt +1
- Multiplayer: disabled by definition and outside product scope
- Overall state: runtime-unproven
- Static verdict: the critical event-signature defect was already corrected on `development`; the stale English formulas are corrected without changing behavior

## Authority and intended outcome

The initial port established a bare-hand damage trait. Pre-campaign commit `d92ca9c` deliberately retuned that implementation after the earlier damage was too small to be meaningful. Its commit message, runtime formulas, comments, and regression updates agree on the accepted outcome:

1. The normal bonus is `0.5 + 0.05 * ShortBlunt level`.
2. The critical bonus is `3.0 + 0.3 * ShortBlunt level`.
3. Critical chance is `5 + 8 * ShortBlunt level` percent.
4. Bonus damage is multiplied by `pre-drain endurance + 0.35`.
5. Each qualifying event drains 0.001 endurance after taking the damage-scaling snapshot.
6. Short Blunt XP equals twice the computed bonus damage.
7. Mundane suppresses the bonus damage, XP, and feedback, but not the event's 0.001 bare-hand endurance cost.

The old English sentence retained pre-retune values. Correcting that sentence to the accepted formulas is documentation repair, not a behavior or balance change.

## Definition, registration, and text

- Registration: `UniversalTraits/media/registries.lua:37`
- Definition: `UniversalTraits/media/scripts/UT_character_traits.txt`
- The definition costs 5, grants Fitness +1 and Small Blunt +1, has no grants or exclusions, and is disabled in multiplayer.
- Display key: `UI_UT_martial`
- Description key: `UI_UT_martialDesc`
- The corrected English text states the endurance cost, both formulas, critical chance, endurance multiplier, XP formula, and Mundane suppression.

## Direct bare-hand runtime map

1. The shared module registers `onWeaponHitCharacter` with `Events.OnWeaponHitCharacter`.
2. SVN 964 `IsoGameCharacter.Hit` rejects nil wielder or weapon before reaching the event.
3. `IsoGameCharacter.java:6768` emits `(wielder, target, weapon, damageSplit)` before native hit processing.
4. Development commit `2f98749c3ecaa323b5eb037c30a2ad98b43dc834` corrected the listener to that exact four-argument order.
5. The listener accepts only a weapon whose type is `BareHands` and a wielder with Martial Artist.
6. It snapshots current endurance, subtracts 0.001 with a zero floor, and calls `applyBonusDamage` with the pre-drain value.
7. `applyBonusDamage` rejects Mundane, obtains the Short Blunt level, rolls the exact critical chance, computes the exact normal or critical bonus, and applies the endurance multiplier.
8. It subtracts the computed bonus directly from target health, grants twice that amount as Short Blunt XP, plays punch feedback, adds critical blood feedback when applicable, and returns the computed damage and critical state.
9. The engine then continues its ordinary hit calculation, so this is bonus damage rather than replacement damage.

SVN 964 also proves that unarmed combat uses the character's real `bareHands` `HandWeapon`, and `HandWeapon.isBareHands()` accepts the `BareHands` type or tag.

## Battering Ram integration map

`UT_batteringram.lua` calls the same public `UT_martial.applyBonusDamage` function after Battering Ram drains its own collision endurance. That integration therefore uses post-collision endurance and the same accepted formulas, Mundane suppression, XP, and feedback. It does not incur Martial Artist's separate 0.001 bare-hand event cost because it does not enter through `onWeaponHitCharacter`.

## Findings and resolutions

### UT6-MARTIAL-EVENT: wrong event argument order

- Severity: critical
- Original reproduction: pre-campaign `master` declared `(player, weapon, target)` while SVN 964 emits `(wielder, target, weapon, damageSplit)`. The listener therefore treated the target as a weapon and could not reach valid bare-hand logic.
- Correction: development commit `2f98749` changed source and release to `(player, target, weapon, damage)` and changed tests to fire the engine order.
- Regression: the focused suite invokes the exact four-argument engine order and proves exact target-health and endurance changes.
- Resolution: implemented and statically validated.

### IR0508-OM-011: English formulas contradicted accepted combat math

- Severity: high
- Original reproduction: English described 0.2 normal, 0.6 critical, a three-times relationship, and 5 percentage points per level. Accepted pre-campaign runtime uses 0.5/3.0 bases, level scaling, and 8 percentage points per level.
- Correction: source and release English now state the accepted formulas and the previously omitted endurance cost, XP formula, and Mundane boundary.
- Regression: the suite asserts the exact sentence and byte-identical source/release UI files.
- Resolution: implemented and statically validated.

## Numerical contract

At Short Blunt level `L` and pre-drain endurance `E`:

- critical chance percent: `5 + 8L`;
- normal bonus damage: `(0.5 + 0.05L) * (E + 0.35)`;
- critical bonus damage: `(3.0 + 0.3L) * (E + 0.35)`;
- Short Blunt XP: `2 * computed bonus damage`;
- direct bare-hand endurance after the event: `max(0, E - 0.001)`.

Focused opposition proves rolls 4/5 at level 0 and 84/85 at level 10. At level 5 and full endurance, a critical bonus is exactly 6.075. At level 10 and 0.5 endurance, a normal bonus is exactly 0.85.

## State, lifecycle, and interactions

- The trait owns no modData, accumulator, cooldown, item mutation, or saved baseline.
- Trait ownership and weapon type are checked on every event.
- Mundane suppresses `applyBonusDamage` for both direct hits and Battering Ram synergy.
- The public helper centralizes the formulas for both callers.
- The shared module is loaded once by the normal game Lua load lifecycle. Same-process manual reload behavior remains unobserved and is not claimed as proven.
- No multiplayer or backward-save behavior is required.

## Test and mock evidence

Focused tests prove:

- exact current four-argument event order;
- exact level-5 critical health delta and 0.001 endurance cost;
- exact level-10 normal damage at 0.5 endurance;
- level-0 and level-10 critical chance boundaries;
- non-bare-hand and missing-trait rejection;
- Mundane suppression for direct and synergy calls;
- Battering Ram delegation;
- exact English copy and source-release parity.

The mock provides controllable random rolls, perk levels, Stats, XP, target health, feedback methods, event dispatch, and bare-hand weapon type. Standard Lua proves the modeled contract, not current-build Kahlua execution.

## Performance and failure behavior

The listener runs only on weapon-hit events. Its rejected path is constant time. A qualifying hit performs a constant number of trait, Stats, perk, random, health, XP, sound, and optional blood operations. There are no scans or per-frame hooks.

Perk lookup, target-health mutation, XP, and feedback use protected calls. Feedback or bridge failure cannot block the engine's native hit path. No current-build profiler capture or Java-Lua failure injection exists, so runtime performance and bridge behavior remain unproven.

## Remaining proof and non-goals

Remaining open proof:

- current-build Kahlua execution after a full desktop relaunch;
- real bare-hand event, native-hit continuation, XP, sound, and blood observation;
- Battering Ram integration in game;
- repeated world entry and current-version save/load observation;
- rendered English in character creation and the character screen;
- profiler and gameplay balance observation;
- non-English localization, because no non-English UniversalTraits locale exists;
- read-only package verification's separately tracked missing source poster.

Explicit non-goals:

- multiplayer support;
- backward save migration;
- deployment or live-copy mutation;
- changing the accepted damage, chance, endurance, XP, cost, or XP-boost values.

## Final verdict

Martial Artist now has a statically proven engine-signature path and exact regressions for the accepted pre-campaign retune. The remaining campaign correction is documentation parity, which now states the actual formulas without altering gameplay. Current-build execution, rendered UI, balance, profiling, and absent locale coverage remain explicitly open.
