# UniversalTraits:UT_short_blades

## Accepted intent

- Display name: Short Blade
- Cost: 4
- Skill boost: `SmallBlade=2`
- Weapon eligibility: exact `WeaponCategory.SMALL_BLADE`
- Critical effect: +10 displayed critical-chance points, capped at 100
- Delay effect: primary-hand Small Blade attacks use the accepted `meleeDelay * 0.5` UTCore path
- Existing reciprocal weapon-tree exclusions remain unchanged

The pre-campaign master is the intent authority. The critical effect was missing at runtime, while the primary-hand melee-delay effect was already active. The former statement that XP was the only runtime path is superseded.

## Resolution

The trait now has two runtime paths:

1. `UTCore_MeleeDelayHook.lua` retains the existing primary-hand 50 percent melee-delay reduction.
2. `UT_short_blades.lua` uses the keyed UTCore tick lifecycle to reconcile both equipped hands, apply exactly +10 displayed critical-chance points in the correct raw/sharpness domain, cap at 100, and restore only its owned raw delta.

Transient ownership state is held only in UTCore memory. No baseline or delta is written to item modData. Focused tests cover exact category boundaries, positive and zero sharpness, non-sharp weapons, cap behavior, both hands, alias deduplication, swap and unequip, trait loss and re-add, external raw mutation, bridge failures, duplicate load, unregister, and teardown.

## Remaining runtime proof

Current-build Kahlua execution, rendered English, save/load observation, balance telemetry, and profiler evidence remain runtime-unproven. Multiplayer, backward save migration, deployment, and live-mod mutation are explicit non-goals for this milestone.
