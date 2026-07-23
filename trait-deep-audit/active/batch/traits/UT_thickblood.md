# UT_thickblood

## Accepted contract

- Authority: pre-campaign `UTMods` `master`.
- Trait ID: `UniversalTraits:UT_thickblood`.
- Display name: `Thick Blooded`.
- Cost: 4.
- XP boosts and granted traits: none.
- Exclusions: Heavy Bleeding Wounds, Weak Bleeding Wounds, and Anemic.
- Multiplayer: disabled by definition; multiplayer support is not a product goal.
- Intended effect: bleeding time decays at 1.5 times normal on all wounds, and active bleeding causes 50 percent of normal general-health loss.
- Allowed Staunch interaction: 4.5 times decay while bandaged and 1.5 times while unbandaged.

## Full runtime trace

1. `Events.OnNewGame` calls the trait handler once for a new character.
2. The handler checks `UTCore.hasTrait(player, "UniversalTraits:UT_thickblood")`.
3. `UTCore.applyBleedDecayMult(player, 1.5, false)` stores the all-wound decay factor.
4. `UTCore.applyBleedDrainMult(player, 0.5)` stores the active-bleed damage factor.
5. `UTCore_BleedDecayHook` applies the extra decay at its bounded ten-update cadence. The all-wound 1.5 factor multiplies the named Staunch 3.0 bandaged-only factor, producing 4.5 while bandaged without overwriting either owner.
6. Native `BodyPart.DamageUpdate` calculates each unbandaged wound's exact bleed damage, calls `BodyDamage.ReduceGeneralHealth(damage)`, and then fires `OnPlayerGetDamage(player, "BLEEDING", damage)`.
7. `UTCore_BleedDrainHook` receives that exact post-damage amount. For a factor below 1.0, it inverts each unclamped `ReduceGeneralHealth` share with the same `BodyPartType.getDamageModifyer(index)` weight. A part already at zero is skipped because the event does not reveal whether that boundary loss belongs to this hit. For a factor above 1.0, the hook calls `ReduceGeneralHealth` with the additional amount.
8. For Thick Blood's factor of 0.5, ordinary positive-health body parts retain exactly half of the native weighted loss. Zero-health boundary cases fail conservatively and never heal unrelated destroyed parts.

## Engine evidence

- `PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPart.java:163-170` proves native bleed ordering and the exact event payload.
- `PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:1040-1072` proves the unequal `AddGeneralHealth` path and the weighted `ReduceGeneralHealth` distribution.
- `PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:2465-2479` proves overall health is recalculated from weighted body-part damage.
- `PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPart.java:509-519` proves the bounded body-part health mutation methods.
- `PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPartType.java:1-276` proves the body-part modifiers and public static modifier lookup on a Lua-exposed type.
- `PZCodebase/Java/source/zombie/Lua/LuaManager.java:1755,2677-2685` explicitly adds `BodyPartType.class` to the Kahlua exposure set.

## Defect resolution

- `B11-THICKBLOOD-BLEED-STACK-001`: resolved. Thick Blood and Staunch now own independent decay factors and compose deterministically across setup and teardown.
- `IR11-THICKBLOOD-001`: resolved. The original actor-health correction was already replaced with a `BodyDamage` correction before this focused pass. This pass found that `BodyDamage.AddGeneralHealth` was still not the mathematical inverse of native bleed damage. The hook now restores each unclamped native weighted share and skips ambiguous zero-health boundaries instead of healing unrelated wound damage.

## Regression proof

- UT_CORE tests verify exact weighted 0.5 restoration, zero-health non-healing, exact additional loss above 1.0, full-plan validation before any healing, invalid and non-finite inputs, and the required `BodyPartType.getDamageModifyer` bridge surface.
- UT_CORE tests verify exact Thick Blood and Staunch decay composition, Staunch removal while preserving Thick Blood, and the allowed Anemic composition with Staunch.
- UniversalTraits tests verify the exact 1.5 and 0.5 setup values, exclusions, definition, English text, and source-release parity.

## Remaining proof

- Current-build Kahlua execution after a full desktop relaunch is unobserved.
- Live unbandaged bleed damage, several simultaneous wounds, new game, save load, death, and repeated world entry are unobserved.
- The bounded per-bleed-event body-part correction has not received an in-game profiler capture.
- Rendered English and comparative balance remain unobserved.
- No non-English UniversalTraits locale exists.

The static contract is corrected and regression-protected. Remaining records are runtime observation or localization and balance coverage, not permission to change the accepted behavior.
