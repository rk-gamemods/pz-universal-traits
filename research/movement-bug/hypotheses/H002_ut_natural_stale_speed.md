# H002: UT_natural Stale-Derived-Speed Bug

**Status:** CONFIRMED as a real bug, but UNLIKELY to be the primary movement bug cause  
**Probability (as primary cause):** Low  
**Depends on:** P006

## Hypothesis

UT_natural.lua caches `getMoveSpeed()` (a derived value including injury penalties) and
later feeds it back via `setMoveSpeed()` (which sets the raw field). If the cached value
is injury-degraded, it will persist even after the injury heals.

## What Supports This

1. **P006:** Confirmed that getMoveSpeed is derived, not raw — proven from Java source.
2. The cache-and-replay pattern is a real bug regardless of the movement issue.

## What Does NOT Support This as the Primary Cause

1. **Symptom split:** `setMoveSpeed()` affects both keyboard and pathfinding equally
   (path speed derives from moveSpeed via getPathSpeed at IsoPlayer.java:1012).
   Cannot explain why Walk To works but arrow keys don't.
2. **Vanilla reset:** BodyDamage.java:2529 resets moveSpeed to 0.06F in regular updates,
   so the corruption may be transient.
3. **No zero-speed path:** All getMoveSpeed penalties are positive multipliers (0.3-0.4).
   The pcall fallback prevents nil. No path to exactly zero was found.

## Verdict

Fix this bug regardless — it's a real code defect. But it is NOT the primary explanation
for the keyboard-only movement failure.

## Fix Direction

Replace `getMoveSpeed()` cache with either:
- A hardcoded known baseline (0.06F is vanilla default)
- A delta-based approach that doesn't cache absolute values
- Read the raw `moveSpeed` field directly if possible via reflection/moddata
