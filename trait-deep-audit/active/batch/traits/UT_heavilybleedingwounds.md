# Heavy Bleeding Wounds Deep Trace

## Contract

- Trait ID: `UniversalTraits:UT_heavilybleedingwounds`
- Display name: `Heavily Bleeding Wounds`
- Pre-campaign authority: UTMods `master`
- Cost: `-4`
- XP boosts: none
- Granted traits: none
- Multiplayer: disabled, with multiplayer support outside product scope
- Exclusions: `UT_thickblood` and `UT_weaklybleedingwounds`
- Intended result: active bleeding causes exactly twice the normal general-health loss. Bandaging stops active bleed damage normally, and the trait does not change wound-healing or clotting speed.

The historical MoreSimpleTraits port is provenance, not the campaign behavior authority. Current work preserves the exact behavior already present on pre-campaign `master`.

## Definition and Player-Facing Surfaces

The source and release definitions are byte-identical. They declare cost `-4`, `DisabledInMultiplayer = true`, and reciprocal exclusions with both other bleed-rate traits. Thick Blood and Weakly Bleeding Wounds each declare the reverse edge.

The exact English keys exist in source and release:

- `UI_UT_heavilybleedingwounds = Heavily Bleeding Wounds`
- `UI_UT_heavilybleedingwoundsDesc = Even minor cuts refuse to close. Bleed rate is increased to 200 percent of normal - wounds bleed twice as fast.`

The description matches the active-bleed result. It does not claim slower clotting or slower bandaged healing, so no product-intent or documentation change is required.

## Runtime Trace

1. Project Zomboid loads the shared trait module and registers `onNewGame` with `Events.OnNewGame`.
2. `onNewGame` checks the exact namespaced trait through `UTCore.hasTrait`.
3. A matching player receives `UT_bleedDrainMult = 2.0` in player modData through `UTCore.applyBleedDrainMult`.
4. Native `BodyPart.DamageUpdate` calculates active bleed damage for each unbandaged bleeding wound.
5. Native code applies that amount through `BodyDamage.ReduceGeneralHealth`.
6. Native code then fires `OnPlayerGetDamage(player, "BLEEDING", damage)` with that same requested damage amount.
7. `UTCore_BleedDrainHook` reads the stored factor. For `2.0`, it calculates `damage * abs(1 - 2.0)`, which equals one more copy of the native requested damage.
8. The hook invokes `BodyDamage.ReduceGeneralHealth` with that adjustment. Normal positive-health body parts therefore receive two identical native distributions in total.
9. At terminal body-part clamps, additional requested damage may have no further numerical health to remove, but the character is already at the relevant terminal boundary. The hook never heals or modifies wound duration on this path.

The current implementation is event-driven. It does not poll `OnPlayerUpdate`, estimate a thirty-tick damage window, or call actor-level `setHealth`. Those descriptions in the superseded audit were stale.

## Java and Kahlua Evidence

- `BodyPart.java:163-170` proves native active bleed ordering: calculate damage, call `ReduceGeneralHealth`, then fire `OnPlayerGetDamage` with type `BLEEDING` and the damage value.
- `BodyDamage.java:1060-1072` proves `ReduceGeneralHealth` distributes the requested amount across the body-part collection using the engine damage modifiers.
- `LuaEventManager.java:823` registers `OnPlayerGetDamage` for Lua.
- The shared UT_CORE tests reproduce the post-native event and prove the factor-greater-than-one path requests exactly one additional damage amount at factor `2.0`.

This gives high static confidence in the complete normal-play chain. Current-build Kahlua execution and a live wound remain unobserved.

## Mutual-Exclusion Finding

`B05-HEAVYBLEED-001` was valid but metadata-only. The authoritative script definitions already enforced every selection-time edge. `UT_MET.BleedRate` omitted Heavy Bleeding Wounds, so Lua-side audit or debug lookup could not return the group for this trait.

The correction adds Heavy Bleeding Wounds to the three-member `UT_MET.BleedRate` group. The standard-Lua consistency test now includes that group and proves every member lists every other member in its script definition. No production behavior or trait intent changed.

## Regression Coverage

Focused tests now prove:

- the trait stores exactly `UT_bleedDrainMult = 2.0`;
- `UT_MET.BleedRate` contains all three bleed-rate traits;
- each group member has both reciprocal script exclusions;
- the shared hook adds exactly one native-equivalent damage request for factor `2.0`;
- source and release copies remain byte-identical.

The deterministic campaign generator owns only this trait's batch and review row, its resolution record, and shared derived ledgers. It rejects duplicate target records, preserves non-target records, and reaches a byte-for-byte fixed point on the second run.

## Remaining Proof

- Full desktop relaunch with current-build Kahlua.
- New game, save-load, death, and repeated world-entry observation.
- One live wound and several simultaneous live wounds, including the terminal health boundary.
- Rendered English observation.
- Gameplay balance telemetry and a profiler capture.
- Non-English localization remains absent across UniversalTraits.
- The separately tracked missing source poster remains a packaging gap.

Multiplayer, backward save migration, deployment, and any change to cost, exclusions, magnitude, wound scope, or bandaged-wound behavior are explicit non-goals for this correction.
