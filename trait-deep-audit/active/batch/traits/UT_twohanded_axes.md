# Two-Handed Axe deep audit

## Scope and authority

This record is the post-repair evidence milestone for
`UniversalTraits:UT_twohanded_axes`. The accepted immutable implementation
chain is:

1. `bb866066` introduced exact-object critical-chance ownership and restoration.
2. `fbec784` contained Java-Lua bridge and critical-state failures.
3. `c3746c1` preserved ownership when a tracked refresh failed.
4. `6a2d55787650297d0b385e1138389f0e97f8ed10` completed tolerance and
   idempotence proof.

The final independent review verdict is `ACCEPT`: all 16 focused cases passed
and no blocking finding remained. Earlier review iterations identified
bridge-error containment, failed-refresh ownership, and tolerance proof gaps.
Those intermediate findings drove later commits and are repaired history, not
defects in the accepted final snapshot.

## Accepted contract

- Cost `4`, `Axe = 2`, no grants, and `DisabledInMultiplayer = true`.
- Existing WeaponTree exclusions, UI identity, English description, and
  single-player scope are unchanged.
- An eligible owner with an eligible two-handed Axe receives exactly `+10`
  displayed critical-chance points, capped at `100`.
- Nonowners, ineligible weapons, and unrelated or external critical-chance
  writers remain unmodified.
- The runtime tracks exact weapon objects in transient Lua state. It does not
  create persistent modData.
- The stale `UT_th_axesBaseCrit` key is retired only from encountered weapons;
  unrelated modData remains unchanged.

## Exact formula and lifecycle

For a weapon without sharpness, displayed and raw critical chance are the same.
For a sharpness-bearing weapon with finite positive sharpness `S`, the runtime
derives `baseRaw` from displayed chance divided by `S`, after removing only its
own previously applied raw bonus.

The target is:

`targetDisplayed = min(100, baseRaw * S + 10)`

`targetRaw = targetDisplayed / S`

The tracked contribution is `targetRaw - baseRaw`. Restoration subtracts that
exact tracked contribution from the weapon's current raw value, preserving
external writes and sharpness changes that occurred while the trait owned the
weapon.

Each owned tick-dispatch refresh:

1. resolves primary and secondary exact objects;
2. accepts only `HandWeapon`, Axe-category, two-handed weapons;
3. retires the stale legacy key without writing new persistent state;
4. restores tracked objects no longer in the eligible hand set;
5. applies or refreshes the bounded contribution on eligible exact objects;
6. contains getter, setter, category, handedness, modData, and sharpness
   failures without mutating unrelated objects.

Trait loss, player death, inactive-handler teardown, reload replacement,
unequip, hand swap, and tracked-object transfer reach restoration in the
standard-Lua proof. A failed tracked refresh retains ownership so a later
teardown can still drain the contribution. A failed teardown setter drains the
transient tracking entry without retry loops or duplicate handlers.

## Finding disposition

`B12-TWOHANDED-AXES-001` is repaired and currently proven by the accepted chain.
The former no-restoration, stale persistent baseline, external-composition,
trait-loss, unequip, transfer, and cross-owner risks are covered by the final
runtime and focused cases.

`IR0104-AXES-CRIT-MUTATION` is related repaired-pattern history for this trait:
the accepted Two-Handed Axe implementation avoids the absolute cached-base
mutation described there. The independent finding still anchors the separate
`UniversalTraits:UT_axes` implementation, which this exclusive one-trait
milestone does not change or close.

## Focused proof

The 16 accepted standard-Lua cases cover:

1. exact `+10` displayed points and idempotence;
2. scale-relative rewrite tolerance;
3. Axe-category and two-handed boundaries;
4. zero sharpness and general API failures;
5. every critical-state getter and setter failure;
6. ownership across a failed tracked refresh;
7. every invalid sharpness domain;
8. cap `100` and sharpness-domain conversion;
9. hand deduplication, swaps, and transfers;
10. trait loss, death, and inactive teardown;
11. external raw writes and sharpness changes;
12. selective retirement of `UT_th_axesBaseCrit`;
13. duplicate-load restoration and one handler;
14. cross-owner teardown isolation and setter-failure drain;
15. setter-failure reload without retry or duplication;
16. cost, Axe boost, copy, and source-release parity.

No full Lua suite is rerun for this evidence milestone. The immutable accepted
focused result is 16 passing cases at
`6a2d55787650297d0b385e1138389f0e97f8ed10`.

## Retained runtime proof

Still unobserved:

- current-build Kahlua execution and live Java-Lua bridge behavior;
- full desktop relaunch and current-version save-load;
- live cross-owner weapon transfer;
- live tick cadence and profiler behavior.

Multiplayer, backward save migration, deployment, live-mod mutation, and
changes to cost, Axe boost, exclusions, UI, or copy are explicit non-goals.
