# P007: Complete UT Event Registration Inventory

**Proven on:** 2026-04-06  
**Proven by:** Source code grep  
**Confidence:** Complete for UT_CORE and UniversalTraits media/lua directories

## UT_CORE Event Registrations

| File | Event | Notes |
|------|-------|-------|
| UTCore_SpeedHook.lua:66 | OnPlayerMove | Rewrites position via setX/setY when speedMod != 0 |
| UTCore_StatModifiers.lua:451 | OnCreatePlayer | reconcileAggregatedModifiers |
| UTCore_StatModifiers.lua:455 | OnPlayerUpdate | reconcileAggregatedModifiers (every tick) |
| UTCore_StatModifiers.lua:475 | OnVehicleEnter | syncVehicleTrait |
| UTCore_StatModifiers.lua:479 | OnVehicleExit | restoreVehicleMod |
| UTCore_StatModifiers.lua:483 | OnCreatePlayer | syncVehicleTrait |
| UTCore_ZombieCollisionHook.lua:80 | OnPlayerUpdate | bump detection |
| UTCore_ZombieCollisionHook.lua:97 | OnCreatePlayer | auto-register collision handlers |
| UTCore_ZombieCollisionHook.lua:122 | EveryOneMinute | integrity check |
| UTCore_BleedHook.lua:93 | OnPlayerUpdate | bleed rate |
| UTCore_BleedDecayHook.lua:56 | OnPlayerUpdate | bleed decay |
| UTCore_BleedDrainHook.lua:75 | OnPlayerUpdate | bleed drain |
| UTCore_DamageMultHook.lua:49 | OnPlayerUpdate | damage mult |
| UTCore_DamageMultHook.lua:53 | OnWeaponHitCharacter | damage mult |
| UTCore_FractureHook.lua:71 | OnWeaponHitCharacter | fracture |
| UTCore_MeleeDelayHook.lua:138 | OnPlayerUpdate | melee delay |
| UTCore_MeleeDelayHook.lua:142 | OnWeaponHitCharacter | reset flag |
| UTCore_PainHook.lua:26 | OnPlayerUpdate | pain |
| UTCore_NoiseHook.lua:44 | EveryOneMinute | noise |
| UTCore_SleepQualityHook.lua:45 | EveryOneMinute | sleep quality |
| UTCore_ThermalRegulationHook.lua:61 | EveryOneMinute | thermal |
| UTCore_XPHook.lua:17 | EveryOneMinute | XP tracking reset |
| UTCore_XPHook.lua:76 | AddXP | XP multiplier |
| UTCore_WorkSpeedHook.lua:61 | OnGameBoot | patches getDuration on all TimedActions |
| UTCore_ReadingHook.lua:146 | OnGameBoot | patches read action |
| UTCore_CharacterCreationMETDebug.lua:89 | OnMainMenuEnter | audit (client only) |

## Key Observations

- **OnPlayerUpdate handlers that fire every tick:** StatModifiers (reconcileAggregatedModifiers),
  ZombieCollisionHook (bump detection), BleedHook, BleedDecayHook, BleedDrainHook,
  DamageMultHook, MeleeDelayHook, PainHook
- **OnPlayerMove handlers:** Only SpeedHook
- **OnGameBoot monkeypatches:** WorkSpeedHook (wraps getDuration on all global tables with getDuration),
  ReadingHook (patches read action)
- **No UT code touches:** keyboard input, blockMovement, ignoreInputsForDirection, state machine
  transitions, animation variables, or movement direction

## Fact

UT does not directly intercept or consume keyboard input. The bug mechanism must be indirect.
