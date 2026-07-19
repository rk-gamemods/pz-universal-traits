# UniversalTraits:UT_actionhero — refreshed resolution

## Decision

- Preserve the authoritative UniversalTraits behavior and balance: cost 8; +15 percentage points of displayed critical chance on equipped HandWeapons when at least three living spotted enemies are within 10 tiles; cap displayed critical chance at 100; evaluate on the existing 30-player-update dispatch cadence; Mundane disables the bonus.
- Do not restore the historical MoreTraits per-zombie damage formula, change cost/numbers/cadence, add multiplayer or backward migration, or touch the mod-global poster issue. Those are outside this one-trait resolution.
- Keep the definition unchanged. Its namespaced id, cost 8, no XP/grant/exclusion fields, and `DisabledInMultiplayer = true` still describe the selected semantics.

## Current direct-byte evidence

- Runtime source and release are equal: `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_actionhero.lua` and `UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_actionhero.lua`.
- English source and release are equal; `UI_UT_actionheroDesc` is at `UI.json:51` and now states the flat threshold, +15 percentage-point bonus, 100 cap, 30-update cadence, and Mundane suppression.
- Definition source and release are equal; the selected block begins at `UT_character_traits.txt:273`.
- Exact SVN 964 engine anchors used:
  - `HandWeapon.java:1495-1501`: `setCriticalChance(float)` writes raw `criticalChance`; `getCriticalChance()` returns raw critical chance multiplied by sharpness when sharpness exists.
  - `InventoryItem.java:1655-1659,1983-1991`: non-empty item modData has a save/load path. This does not prove that `HandWeapon.criticalChance` itself is serialized.
  - `IsoPlayer.java:2241`: current `OnPlayerUpdate` producer anchor retained from the selected trace.

## Resolved defects

1. Enemy enumeration is transactional inside the trait. It counts into a local scalar under `pcall` and publishes only a completed result; any error returns `nil`, makes the trait inactive, and restores tracked bonuses. A partially populated UTCore enemy list can no longer activate Action Hero.
2. Applied bonuses are tracked by weapon identity. Inactive state, Mundane, enumeration failure, unequip, and swap all restore every formerly boosted weapon before applying to current weapons.
3. Restoration removes only Action Hero's recorded raw-field delta instead of writing a stale cached baseline. This preserves later raw-field changes from other systems.
4. Sharp weapons are handled in the real engine domains: displayed getter value is converted to raw using current sharpness, the +15/cap calculation occurs in displayed space, and the setter receives raw space. Nonpositive sharpness is a safe no-op because the original raw value cannot be recovered from a zero-scaled getter.
5. Duplicate source loads reuse `UTCore._actionHeroState`; the selected tick registration remains keyed by the same namespaced trait id and does not abandon the prior tracked-weapon set.
6. English copy no longer claims distance bands, per-zombie stacking, or damage mutation.

## Focused proof status

The shared files were re-read after the Caffeine lease release and only the focused Action Hero block/methods were changed. Caffeine's current bytes were preserved. `UTTestMocks.MockWeapon` and the focused `MockWeaponSimple` now reproduce SVN 964's sharpness-adjusted getter/raw setter boundary. The focused block now covers:

- count 2 inactive / count 3 active;
- distance 10 included / greater than 10 excluded;
- exact +15 and 100 cap;
- drop-below-threshold restoration;
- Mundane acquired after activation restoration;
- primary/secondary same-object deduplication;
- weapon A to weapon B swap restores A and independently boosts/restores B;
- `getSpottedList`, `size`, `get`, `isDead`, and `DistTo` failures cannot leave a partial active count and restore any prior bonus;
- sharpness other than 1 proves displayed getter/raw setter behavior and exact raw restoration;
- repeated load keeps one logical state and does not compound or orphan a bonus;
- current-version reload fixture proves modData is not treated as serialization proof for the raw HandWeapon field.

Direct-byte post-edit hashes: `run_tests.lua` = `477a7b5b0227f2e5f4bf47ed763fe0229f7132fb4a9dbcea1501deb7980d2bda`; `UTTestMocks.lua` = `0b19459f2e4cf9abea4eb680245832799988ed47456fef3bcc1cbecf15f26ecf`. The selected Action Hero block is `run_tests.lua:727-949`; shared sharpness methods are `UTTestMocks.lua:1135,1178-1184`.

## Remaining runtime proof

- No commands or tests were executed by instruction.
- Full Exit to Desktop/relaunch is still needed to prove Kahlua parsing, Java bridge calls, one logical registration after reload, and current-version active/inactive/Mundane/swap/sharp-weapon save/reload behavior.
- Profiler/runtime cost remains unmeasured. Static work is one spotted-list pass every eligible 30-update dispatch plus work proportional to the small tracked-weapon set.
- Multiplayer, backward migration, deployment/live parity, other traits, and the poster are explicit non-goals.
