# UniversalTraits:UT_sharpshooter refreshed resolution

## Decision

- Preserve the pre-campaign `master` contract: cost 4, +2 Aiming, and 25 percent more hit chance and effective range for equipped firearms.
- Preserve the integer hit-chance rule `floor(base * 1.25)`, the 100 cap, and the raw maximum-range multiplier `base * 1.25`.
- Fix only ownership, lifecycle, save, and proof defects. Sharpshooter's bonuses must never remain on an unequipped, transferred, or no-longer-eligible weapon.
- Do not change the cost, skill grant, magnitude, ranged-weapon scope, or multiplayer restriction.

## Baseline authority

The pre-campaign `master` branch is internally consistent about the intended outcome:

- `UT_character_traits.txt:294-303` declares cost 4, `Aiming=2`, and `DisabledInMultiplayer = true`.
- `UI_UT_sharpshooterDesc` promises +2 Aiming and 25 percent more firearm accuracy and effective range.
- The runtime multiplies the hit-chance and maximum-range fields of equipped ranged HandWeapons by 1.25.

The corrected English uses "hit chance" and "equipped firearms" because those are the exact runtime field and scope. It does not change the effect.

## Complete runtime trace

1. `UTCore_TickDispatch.lua` owns the single `OnPlayerUpdate` producer.
2. `UT_sharpshooter.lua` registers one vehicle-aware trait handler with throttle 30.
3. UTCore dispatches the handler only while the current player owns Sharpshooter.
4. The handler considers only the primary and secondary equipped objects. Each object must be a ranged `HandWeapon`; the same object in both slots is processed once.
5. `HandWeapon.getHitChance()` and `setHitChance(int)` read and write the same integer field. The target is `min(100, floor(non-Sharpshooter value * 1.25))`.
6. `HandWeapon.getMaxRange()` and `setMaxRange(float)` read and write the raw maximum-range field. The target is `non-Sharpshooter value * 1.25`.
7. The runtime records only the two deltas it actually applied for each weapon identity. It stores no permanent baseline in item modData.
8. On every reconciliation, prior Sharpshooter deltas are removed before the target is recalculated. This prevents compounding while preserving later additive attachment or mod changes.
9. A weapon that leaves the eligible equipped set is restored immediately on the next 30-update reconciliation.
10. UTCore calls the same restoration function on trait deactivation, invalid-player teardown, unregister, and reload.
11. The reload path removes the old `OnSave` handler before adding the replacement, so repeated loading cannot stack callbacks.

## Engine and save evidence

- `PZCodebase/Java/source/zombie/inventory/types/HandWeapon.java:1543-1548` proves the integer hit-chance getter and setter.
- `HandWeapon.java:959-974` proves the raw maximum-range getter and setter.
- `HandWeapon.java:1612-1670` serializes both `maxRange` and `hitChance` when they differ from defaults.
- `HandWeapon.java:1730-1790` loads both fields back into the item.
- `HandWeapon.java:2068-2072,2105-2110` proves weapon parts modify both fields additively.
- `PZCodebase/Java/source/zombie/GameWindow.java:1020-1085` fires `OnSave` synchronously before `IsoWorld.instance.currentCell.save(...)` writes world and item state.

Because these fields are serialized, transient tracking alone is insufficient. The corrected `OnSave` callback restores all tracked fields before serialization. The next eligible tick reapplies the temporary owner-bound effect.

## Resolved defect

### B10-SHARPSHOOTER-001

The former implementation cached permanent baselines in item modData and overwrote the weapon's serialized fields. It never restored either field on unequip, transfer, trait loss, invalid-player teardown, or reload. The bonus could therefore travel with the weapon, erase later attachment changes, and compound after save/load.

The corrected runtime owns only its applied deltas, restores every tracked weapon at each lifecycle exit and before save, and recalculates from the current non-Sharpshooter field values.

## Composition and edge behavior

- Primary and secondary slots are deduplicated by object identity.
- A swap restores the old weapon before applying the replacement.
- The hit-chance cap records the actual smaller delta, so restoration remains exact.
- Additive weapon-part changes remain after restoration because only Sharpshooter's recorded deltas are subtracted.
- `OnSave` is event-based and performs no polling or background work.
- The regular runtime cost remains one light reconciliation every 30 player updates over at most two equipped objects and the small tracked set.
- No backward-save migration is provided or required.

## Focused proof

The standard-Lua suite covers:

- exact 25 percent relative hit chance and range without compounding;
- integer flooring, the 100 hit-chance cap, and exact capped-delta restoration;
- non-ranged rejection;
- primary/secondary identity deduplication;
- swap and unequip restoration;
- preservation of later additive hit-chance and range changes;
- pre-save restoration followed by next-dispatch reapplication;
- duplicate module load, teardown restoration, one tick registration, and one save registration;
- exact cost, +2 Aiming, English contract, and source/release parity.

## Remaining runtime proof

- Full Exit to Desktop and current-build Kahlua execution.
- Equip, swap, drop, transfer, trait-removal, death, repeated-world-entry, and current-version save/load observation.
- Weapon-part attachment and removal while the bonus is active in the live Java bridge.
- A save inspection confirming serialized base fields, followed by correct post-load reapplication.
- Rendered English confirmation, representative profiler capture, and gameplay balance observation.

Multiplayer, backward save migration, deployment, and the separately tracked source poster issue are explicit non-goals.
