# UT_staunch

## Trait Summary

- UT trait id: UT_staunch
- Source mod: FillerTraits
- Source trait id: Staunch
- Current cost: 10
- Scripted: yes
- Owner: parallel trait audit worker
- Status: audited

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua`
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/client/UpgradeTraits.lua`
  - `research/installed-mods/FillerTraits/mods/FillerTraits/common/lua/shared/NPCs/UpgradeMainCreationMethods.lua`
- Source trigger path:
  - Build 42 source registers `Staunch` at cost 10 with `+1 Fitness` and `+1 Strength` XP boosts, then calls `Staunch(player)` from a shared `PlayerUpdate` function wired to `Events.OnPlayerUpdate`.
- Source behavior:
  - Proven. In the B42 source, if the player has `Staunch`, each `OnPlayerUpdate` tick checks all body parts. For every body part that is actively bleeding and not stemmed, it adds `0.002` health directly; Neck gets double (`0.004`).
  - Source text says: `Loses health at a slightly slower pace than normal. +1 Strength +1 Fitness`.
  - Source mutual exclusion in the B42 file is only `Frail`. Older/common source variants excluded a larger vanilla weakness/fitness set, so the source family is not perfectly consistent across versions.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_staunch = CharacterTrait.register("UniversalTraits:UT_staunch")`
- Defined in UT_character_traits.txt: yes — cost `10`, `XPBoosts = FirstAid=1`
- Translation strings present: yes — `UI_UT_staunch` and `UI_UT_staunchDesc`
- Exclusions/grants correct: no — current UT definition has no `MutuallyExclusiveTraits`; source B42 had at least `Frail`
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_staunch.lua`

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_staunch.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_BleedDecayHook.lua`
- Event registrations:
  - `Events.OnCreatePlayer.Add(onCreatePlayer)` in `UT_staunch.lua`
  - shared consumer: `Events.OnPlayerUpdate.Add(onPlayerUpdate)` in `UTCore_BleedDecayHook.lua`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)`
  - `UTCore.applyBleedDecayMult(player, 3.0, true)`
  - `UTCore_BleedDecayHook` reads `UT_bleedDecayMult` and `UT_bleedDecayBandagedOnly`
- Runtime chain (plain language):
  1. On player creation/load, the trait checks whether the player has `UniversalTraits:UT_staunch`.
  2. If yes, it stores `UT_bleedDecayMult = 3.0` and `UT_bleedDecayBandagedOnly = true` in modData.
  3. On every player update, `UTCore_BleedDecayHook` scans body parts with `bleedingTime > 0`.
  4. If a part is bandaged, it applies extra decay so bleedingTime shrinks at 3x the native bandaged rate.
  5. Unbandaged wounds are ignored. Active bleed death rate is unchanged. Pain is unchanged. Injury stat penalties are unchanged.
- Actual behavior (exact values):
  - Bandaged body parts: bleedingTime decays at `3.0x` native bandaged speed.
  - Unbandaged body parts: no bonus.
  - Native rates documented in UT_CORE: bandaged `0.0002 * gameMultiplier` per tick, unbandaged `0.00002 * gameMultiplier` per tick.
  - UT_staunch adds the extra `2.0x` decay needed to reach `3.0x` total on already-bandaged parts only.
  - No direct health gain, no pain reduction, no endurance/strength/fitness effect, no bleed-drain reduction.

## Description Integrity

- Display name check: acceptable — `Staunch` still implies toughness/recovery.
- Description check: misleading. Current text says `You have an unusually high pain tolerance and recover from injuries well. Pain effects and injury penalties are reduced.` The implementation does none of that.
- Missing or misleading details:
  - No pain tolerance mechanic exists.
  - No generic injury-penalty reduction exists.
  - The real effect is specifically: bandaged wounds close faster.
  - The current description also hides the bandaged-only condition.
  - Source intent drift is major: source gave Strength/Fitness XP and active-bleed health mitigation; UT gives First Aid XP and bandaged bleedingTime acceleration.

## Balance Review

- Upside:
  - `+1 First Aid` XP boost.
  - Faster closure of already-bandaged wounds via `3x` bandaged bleedingTime decay.
- Downside:
  - None intrinsic; this is a positive trait.
- Uptime:
  - First Aid XP is always on.
  - The wound-healing benefit only matters when the player is bleeding, has already bandaged the wound, and the wound still has positive bleedingTime.
- Peer comparison:
  - `UT_thickblood` costs 4 and provides broader bleed benefits: `UT_bleedDecayMult = 1.5` on all wounds plus `UT_bleedDrainMult = 0.5`.
  - `UT_staunch` costs 10 but is much narrower: bandaged-only clot acceleration plus a small XP boost.
  - Relative to the source, UT removed the valuable Strength/Fitness package but kept the top-end price.
- Stack or exclusion notes:
  - `UT_thickblood.lua` explicitly documents stacking with `UT_staunch`; bandaged wounds would get `4.5x` total decay if both are active.
  - No current script exclusion prevents that stack.
  - Source B42 at least excluded `Frail`; UT does not carry forward any exclusion here.
- Cost verdict: wrong. The implemented effect is far weaker and narrower than both the source package and several cheaper UT peers.

## Regression Proof

- Existing test:
  - Registration only: `UniversalTraits/test/run_tests.lua` verifies `UT_staunch` is registered.
- What it proves:
  - Only that the registry entry exists.
- Missing proof:
  - No automated test proves `OnCreatePlayer` writes `UT_bleedDecayMult = 3.0`.
  - No automated test proves `UT_bleedDecayBandagedOnly = true`.
  - No automated test proves the runtime path is bandaged-only rather than all-wounds.
- Minimum next test if needed:
  1. Fire `OnCreatePlayer` for a mock player with `UniversalTraits:UT_staunch`.
  2. Assert modData contains `UT_bleedDecayMult == 3.0` and `UT_bleedDecayBandagedOnly == true`.
  3. Add a UT_CORE hook test for `UTCore_BleedDecayHook` with one bandaged and one unbandaged bleeding body part, then assert only the bandaged part gets accelerated decay.

## Final Verdict

- Source origin: proven
- UT implementation: drifted
- Description: misleading
- Balance: wrong
- Regression proof: missing
- Action needed: doc fix | test fix | code fix
- Open gaps:
  - Source family inconsistency across FillerTraits variants: older/common files describe a stat-package trait, while B42 also includes an active bleeding-health hook. UT follows neither source version closely.
  - Current UT text should be rewritten to describe bandaged wound closure specifically if the implementation remains as-is.
  - Current UT cost likely needs redesign if the implementation remains bandaged-only.
  - Missing mutual exclusion carry-forward from source (`Frail` at minimum in B42 source).
