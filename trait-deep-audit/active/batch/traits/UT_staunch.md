# UniversalTraits:UT_staunch refreshed resolution

## Decision

Finding `B11-STAUNCH-BLEED-STACK-001` is confirmed and corrected without changing the pre-campaign trait contract.

The accepted contract is the UTMods `master` state that existed before this campaign:

- cost 10;
- `Doctor=1` (`+1 First Aid`);
- bandaged wounds close at 3 times the native rate;
- unbandaged wounds and active bleed health drain are unaffected by Staunch;
- Staunch is allowed with Thick Blood, and the master Thick Blood runtime explicitly requires 4.5 times bandaged wound closure when both traits are active.

The older FillerTraits implementation is historical evidence only. Its Strength, Fitness, and direct-health behavior does not override the accepted UTMods baseline.

## Confirmed defect

Before this correction, Staunch and Thick Blood both called `UTCore.applyBleedDecayMult`, which stored one shared `UT_bleedDecayMult` scalar and one shared bandaged-only flag. Project Zomboid fires `OnNewGame` before `OnCreatePlayer` for a new character. Thick Blood therefore wrote `1.5,false` first and Staunch then replaced it with `3.0,true`.

The result was 3 times bandaged decay and normal unbandaged decay. The required 4.5 times bandaged and 1.5 times unbandaged behavior could not occur. The same scalar design also made legal opposite effects overwrite rather than compose.

## Runtime trace

1. The complete trait definition registers `UniversalTraits:UT_staunch`, cost 10, `Doctor=1`, and no exclusions.
2. `UT_staunch.lua` applies a named factor of `3.0` in the bandaged-only multiplier bucket.
3. `UT_thickblood.lua` retains its existing all-wound scalar of `1.5` and active-bleed drain scalar of `0.5`.
4. `UTCore_BleedDecayHook` runs through the single UTCore player-update dispatcher and reconciles once per ten player updates.
5. For each body part with positive `bleedingTime`, it multiplies all-wound factors and, only when bandaged, bandaged-only factors.
6. The hook subtracts the extra accumulated decay before the engine performs that update's native `BodyPart.DamageUpdate` subtraction.
7. Embedded glass retains the engine's `bleedingTime=3.0` floor.
8. Staunch owns only its named factor. Trait deactivation, invalid-player teardown, player replacement, unregister, and same-process reload remove only that source.

## Exact composition

| Active effects | Bandaged multiplier | Unbandaged multiplier |
| --- | ---: | ---: |
| Staunch | `3.0` | `1.0` |
| Thick Blood | `1.5` | `1.5` |
| Staunch and Thick Blood | `3.0 * 1.5 = 4.5` | `1.5` |
| Anemic | `0.33` | `0.33` |
| Staunch and Anemic | `3.0 * 0.33 = 0.99` | `0.33` |

Thick Blood and Anemic are mutually exclusive. Staunch is legally selectable with either. Multiplication preserves each accepted independent factor and removes event-order dependence.

## Engine evidence

- `PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPart.java:215-233` applies native bandaged decay of `0.0002 * GameTime.multiplier`, unbandaged decay of `0.00002 * GameTime.multiplier`, the embedded-glass floor of `3.0`, and zero cleanup.
- `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2011-2035,2233-2242` proves `OnPlayerUpdate` runs inside `updateInternal2` before `super.update`, where normal body-damage processing occurs.
- `PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:9731-9743` calls `BodyDamage.Update` from the superclass update.
- `PZCodebase/Java/source/zombie/iso/IsoWorld.java:2160-2209` and `zombie/gameStates/GameLoadingState.java:400-431` prove new-game `OnNewGame` precedes `OnCreatePlayer`.
- `PZCodebase/Java/source/zombie/gameStates/GameLoadingState.java:400-431` proves save loading still fires `OnCreatePlayer`.

## Focused proof

UT_CORE tests now prove:

- the mock BodyPart exposes the exact bleeding-time, bandage, and embedded-glass methods used by production;
- Staunch's named factor does not overwrite the legacy all-wound scalar;
- Staunch alone changes only bandaged wound decay;
- Staunch and Thick Blood produce exact 4.5 and 1.5 factors by wound state;
- removing Staunch preserves Thick Blood;
- Staunch and Anemic deterministically produce 0.99 and 0.33 factors by wound state.

UniversalTraits tests now prove:

- OnCreatePlayer stores Staunch in the named bandaged-only bucket;
- an existing Thick Blood scalar survives Staunch setup;
- deactivation removes only Staunch's source;
- duplicate runtime loading replaces both handler registrations and clears stale state.

Source and 42.0 release copies remain byte-identical for every changed runtime file.

## Remaining runtime proof

Static source and deterministic tests establish the high-confidence runtime model. Final observational proof still requires a full current-build relaunch and live checks for new game, save load, bandaged and unbandaged wounds, Staunch with Thick Blood, Staunch with Anemic, trait removal, death, repeated world entry, embedded glass, rendered English, balance, and profiler behavior.

Multiplayer, backward save migration, and deployment are explicit non-goals.
