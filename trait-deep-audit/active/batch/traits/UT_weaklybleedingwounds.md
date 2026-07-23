# Weakly Bleeding Wounds Deep Trace

## Contract

- Trait ID: `UniversalTraits:UT_weaklybleedingwounds`
- Display name: `Weakly Bleeding Wounds`
- Pre-campaign authority: UTMods `master`
- Cost: `3`
- XP boosts: none
- Granted traits: none
- Multiplayer: disabled, with multiplayer support outside product scope
- Exclusions: `UT_heavilybleedingwounds` and `UT_thickblood`
- Intended result: active bleeding causes exactly 60 percent of normal general-health loss. The trait does not change wound duration, clotting, or bandaged healing.

The historical source mod is provenance, not the campaign behavior authority. Current work preserves the exact 0.6 behavior already present on pre-campaign `master`.

## Definition and Player-Facing Surfaces

The source and release definitions are byte-identical. They declare cost `3`, `DisabledInMultiplayer = true`, and reciprocal exclusions with both other bleed-rate traits. Heavy Bleeding Wounds and Thick Blood each declare the reverse edge.

The previous English sentence said wounds “seal up,” which implied faster clotting that the accepted runtime does not provide. The corrected English contract is:

`Active bleeding drains your health at 60 percent of the normal rate. Wound clotting speed is unchanged.`

The display name remains unchanged. Source and release English files are byte-identical.

## Runtime Trace

1. Project Zomboid loads the shared trait module and registers `onNewGame` with `Events.OnNewGame`.
2. `onNewGame` checks the exact namespaced trait through `UTCore.hasTrait`.
3. A matching player receives `UT_bleedDrainMult = 0.6` in player modData through `UTCore.applyBleedDrainMult`.
4. Native `BodyPart.DamageUpdate` calculates active bleed damage for each unbandaged bleeding wound.
5. Native code applies that amount through `BodyDamage.ReduceGeneralHealth`.
6. Native code then fires `OnPlayerGetDamage(player, "BLEEDING", damage)` with that same requested damage amount.
7. `UTCore_BleedDrainHook` reads factor `0.6` and calculates `damage * abs(1 - 0.6)`, which is exactly 40 percent of the native requested damage.
8. The hook retrieves the native 0-based body-part list and the exact `BodyPartType.getDamageModifyer(index)` value for every part.
9. Before changing anything, it validates the complete inverse plan. For every positive-health part, it calls `AddHealth(adjustment / partCount / modifier)`.
10. This reverses exactly 40 percent of each unclamped native `ReduceGeneralHealth` share, leaving 60 percent of normal active-bleed general-health loss.

A zero-health part may already have been clamped by the native damage or may contain unrelated prior damage. The hook does not heal zero-health parts because the event reports requested damage rather than the actual clamped loss. This is conservative at terminal boundaries and prevents unrelated wound restoration.

The current implementation is event-driven. It does not sample every thirty updates, estimate native bleed damage, or modify actor-level health. Those descriptions in the superseded audit and ledger were stale.

## Numerical Result

The damage rate is exactly `0.6x` in the normal unclamped domain. If bleeding is the only health-loss source and the wound state remains otherwise constant, time to bleed out scales by `1 / 0.6 = 1.6667`, or about 66.7 percent more time. The old runtime comment incorrectly called this 40 percent more time and has been corrected.

## Java and Kahlua Evidence

- `BodyPart.java:163-170` proves native active bleed ordering: calculate damage, call `ReduceGeneralHealth`, then fire `OnPlayerGetDamage` with type `BLEEDING` and the damage value.
- `BodyDamage.java:1060-1072` proves the native division by body-part count and damage modifier.
- `BodyPartType.java` provides the exact damage modifiers used by the native distribution.
- `LuaManager.java:1755` exposes `BodyPartType` to Lua.
- `BodyPart.AddHealth` is public and clamps body-part health to the valid range.
- Shared UT_CORE tests model unequal modifiers, 0-based access, zero-health parts, invalid bridge operations, and factor-below-one restoration.

This gives high static confidence in the complete normal-play chain. Current-build Kahlua execution and a live wound remain unobserved.

## Finding Resolution

`IR12-WEAKBLEED-POOL-002` and shared `IR11-BLEED-POOL-001` described the old actor-health compensation path. The current hook performs the correction in `BodyDamage` and exactly inverts native per-part shares in the unclamped domain. Those findings are resolved by the shared Thick Blood correction and its weighted regression tests.

`IR12-WEAKBLEED-DESC-001` remained valid. The English sentence implied faster sealing despite unchanged clotting. The new sentence states the exact active-bleed health-loss factor and explicitly says clotting speed is unchanged.

## Regression Coverage

Focused tests now prove:

- the trait stores exactly `UT_bleedDrainMult = 0.6`;
- the English sentence states the 60 percent general-health result and unchanged clotting;
- runtime and English source-release pairs are byte-identical;
- all three bleed-rate traits form one reciprocal exclusion group;
- unequal native damage modifiers are reversed exactly by 40 percent;
- zero-health parts are never healed;
- invalid or non-finite bridge data cannot cause a partial correction;
- the shared event handler is reload-safe.

The deterministic campaign generator owns only this trait's batch and review row, the shared bleed-pool finding, its resolution record, and shared derived ledgers. It rejects duplicate target records, preserves non-target records, and reaches a byte-for-byte fixed point on the second run.

## Remaining Proof

- Full desktop relaunch with current-build Kahlua.
- New game, save-load, death, and repeated world-entry observation.
- One live wound and several simultaneous live wounds, including terminal health boundaries.
- Rendered English observation.
- Gameplay balance telemetry and a profiler capture.
- Non-English localization remains absent across UniversalTraits.
- The separately tracked missing source poster remains a packaging gap.

Multiplayer, backward save migration, deployment, and any change to cost, exclusions, magnitude, wound scope, or clotting behavior are explicit non-goals for this correction.
