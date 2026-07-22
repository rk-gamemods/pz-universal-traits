# UniversalTraits:UT_cleaver refreshed resolution

## Decision

- Preserve the pre-campaign `master` contract: cost 3, +1 Long Blade, and exactly +10 displayed critical-chance points for Long Blade weapons, capped at 100.
- Preserve the existing 30-player-update dispatch cadence and intentional compatibility with other critical-chance modifiers.
- Fix only the confirmed ownership defect. A weapon must not retain Cleaver's bonus after unequip, transfer, trait deactivation, invalid-player teardown, or module reload.
- Do not change the trait's cost, skill grant, magnitude, weapon category, or multiplayer restriction.

## Baseline authority

The pre-campaign `master` branch is internally consistent for Cleaver:

- `UT_character_traits.txt:863-872` declares cost 3, `LongBlade=1`, and `DisabledInMultiplayer = true`.
- `UI_UT_cleaverDesc` promises +1 Long Blade and +10 critical hit chance with Long Blade attacks.
- The pre-campaign runtime applies a +10 critical-chance item mutation to equipped Long Blade weapons.

This resolution does not reinterpret or replace that intended outcome. It changes only how the temporary bonus is owned and removed.

## Complete runtime trace

1. `UTCore_TickDispatch.lua` installs the single `OnPlayerUpdate` producer.
2. `UT_cleaver.lua` registers one trait handler under `UniversalTraits:UT_cleaver` with throttle 30.
3. UTCore includes the handler only for a player who owns Cleaver. The handler remains vehicle-aware so equipped-item ownership is reconciled even when ordinary combat is unavailable.
4. The handler examines only the current primary and secondary hand items. A qualifying object must be a `HandWeapon` whose subcategory is exactly `Long Blade`.
5. `HandWeapon.getCriticalChance()` returns displayed critical chance. For sharp weapons, SVN 964 multiplies the raw field by current sharpness.
6. `HandWeapon.setCriticalChance(float)` writes the raw field. The runtime therefore divides the displayed target by sharpness before calling the setter.
7. The displayed target is `min(100, current non-Cleaver displayed value + 10)`.
8. The runtime records only Cleaver's applied raw-field delta per weapon identity. It never writes an item modData baseline.
9. A later tick subtracts only that recorded delta when a weapon is no longer a currently equipped qualifying object.
10. UTCore calls the same restoration path when the handler is deactivated, unregistered, reloaded, or torn down for an invalid player.

## Engine and save/load evidence

- `PZCodebase/Java/source/zombie/inventory/types/HandWeapon.java:1495-1500` proves the setter/raw and getter/displayed domains.
- `HandWeapon.java:1612-1725` serializes mutable weapon fields but does not serialize `criticalChance`.
- `HandWeapon.java:1728-1845` restores the serialized fields and does not load `criticalChance`.
- `PZCodebase/Java/source/zombie/scripting/objects/Item.java:2149` initializes a new HandWeapon's raw critical chance from the script item.
- Item modData does have a separate save/load path. The corrected runtime therefore does not store a permanent Cleaver baseline there.

Static evidence strongly supports a clean current-version reload model: the Java item field is reconstructed from its script definition and Cleaver reapplies only after the current owner and equipped weapon qualify. A full in-game save/load observation remains required before that runtime dimension can be called proven.

## Resolved defects

### B03-UT_cleaver-01

The former implementation cached a baseline in item modData and permanently mutated the shared weapon object. It had no restoration path for unequip, transfer, trait loss, or reload. A non-Cleaver character could therefore receive a weapon that still carried Cleaver's bonus.

The corrected runtime tracks weapon identities in transient Lua state and removes only Cleaver's own applied delta at every lifecycle exit.

### IR0104-CLEAVER-SHARPNESS-RAW-MISMATCH

The former implementation read a sharpness-adjusted displayed value and passed it back to a raw-field setter. Any sharpness other than 1 changed the wrong numerical domain during application and restoration.

The corrected runtime converts displayed critical chance to raw space, computes the +10 and 100 cap in displayed space, and sends the converted raw target to the setter.

## Composition and edge behavior

- The primary and secondary slots are deduplicated by weapon identity.
- A weapon swap restores the former item before independently applying the new item.
- The 100 cap records the actual smaller applied delta, so restoration is exact.
- Later raw-field changes by another system are preserved because restoration subtracts Cleaver's delta instead of writing an old cached baseline.
- Concurrent Action Hero and Cleaver bonuses compose additively and either owner can remove its own delta without erasing the other.
- A nonpositive sharpness value is a safe no-op because the raw field cannot be reconstructed from a displayed getter multiplied by zero.
- No backward-save migration is provided or required.

## Focused proof

The standard-Lua suite covers:

- exact +10 displayed critical chance with no compounding;
- the 100 cap and exact capped-delta restoration;
- sharpness-adjusted getter versus raw setter conversion;
- non-Long-Blade rejection and zero-sharpness no-op;
- weapon swap and unequip restoration;
- primary/secondary same-object deduplication;
- preservation of a later external raw-field change;
- Action Hero overlap and independent restoration;
- duplicate module load, teardown restoration, and one remaining registration;
- exact cost, +1 Long Blade, English contract, and source/release parity.

The engine-faithful `MockWeapon` exposes sharpness-adjusted `getCriticalChance()`, raw `setCriticalChance()`, and `getRawCriticalChance()` for assertions.

## Remaining runtime proof

- Full Exit to Desktop and current-build Kahlua execution.
- Equip, swap, drop, transfer, trait-removal, death, repeated-world-entry, and current-version save/load observation.
- Concurrent Action Hero and Cleaver observation on a sharp Long Blade in the live Java bridge.
- Rendered English confirmation.
- Representative profiler capture and gameplay balance observation.

Multiplayer, backward save migration, deployment, and the separately tracked source poster issue are explicit non-goals.
