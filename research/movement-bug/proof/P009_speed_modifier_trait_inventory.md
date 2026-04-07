# P009: Complete List of Traits That Set UT_speedMod != 0

**Proven on:** 2026-04-06  
**Proven by:** Source grep for applySpeedModifier calls  
**Confidence:** Complete for UniversalTraits media/lua

## Traits That Call UTCore.applySpeedModifier

| Trait | File | Value | Effect |
|-------|------|-------|--------|
| UT_fast | UT_fast.lua:8 | +0.3 | 30% faster |
| UT_pacer | UT_pacer.lua:9 | +0.15 | 15% faster |
| UT_gimp | UT_gimp.lua:9 | -0.5 | 50% slower |
| UT_lurcher | UT_lurcher.lua:10 | -0.15 | 15% slower |
| UT_noodlelegs | UT_noodlelegs.lua:8 | -0.2 | 20% slower |
| UT_sorelegs | UT_sorelegs.lua:9 | -0.2 | 20% slower |

## Implication

If the user's character has ANY of these traits, `UT_speedMod` will be non-zero, and
the SpeedHook's `setX()`/`setY()` code path will execute every frame during movement.

If the character has NONE of these traits, `UT_speedMod == 0` and the SpeedHook is a no-op.

## Critical Test

Ask the user: does your test character have any of these traits?
- UT_fast, UT_pacer, UT_gimp, UT_lurcher, UT_noodlelegs, UT_sorelegs

If yes → SpeedHook is active and is the primary suspect.
If no → SpeedHook is inactive and we must look elsewhere.
