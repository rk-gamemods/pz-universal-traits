# P006: UT_natural Caches Derived Speed, Not Raw Base

**Proven on:** 2026-04-06  
**Proven by:** Source code inspection  
**Source:** `UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_natural.lua:22-24`

## Code

```lua
-- UT_natural.lua:22-24
if not md["UT_naturalBaseSpeed"] then
    local ok, baseSpeed = pcall(function() return player:getMoveSpeed() end)
    md["UT_naturalBaseSpeed"] = (ok and baseSpeed) or 1.0
end
```

And later (line 27-31):
```lua
if md["UT_naturalLastBonus"] ~= bonus then
    md["UT_naturalLastBonus"] = bonus
    pcall(function()
        player:setMoveSpeed(md["UT_naturalBaseSpeed"] * (1.0 + bonus))
    end)
end
```

## Fact

`getMoveSpeed()` is a computed method (`IsoPlayer.java:1715-1756`) that returns
`this.moveSpeed * minDelta` where `minDelta` is derived from leg/foot fracture state.
It is NOT the same as reading the raw `moveSpeed` field (0.06F).

UT_natural snapshots the result of this computed method and stores it as if it were a stable base.
Later, it feeds this snapshot back into `setMoveSpeed()`, which directly sets the raw field.

## Real Bug (Confirmed)

If the player has a fracture when UT_natural first runs, the cached "base" is already
degraded. When the fracture heals, UT_natural continues using the degraded base instead of
the real 0.06F. This is a **stale-derived-speed bug**.

## What Is NOT Proven

- **Permanent corruption:** Vanilla resets moveSpeed back to 0.06F inside `BodyDamage.java:2529`,
  called in the regular body-damage update flow. So the corruption may be transient, not permanent.
- **Zero-speed scenario:** No code path was found in UT or vanilla that would write exactly 0 into
  moveSpeed. The getMoveSpeed() penalties are all positive multipliers (0.3, 0.4, etc.). The
  fallback `or 1.0` in the pcall prevents nil-to-zero. So "moveSpeed permanently pinned at zero"
  is not supported by evidence.
- **Symptom split explanation:** `setMoveSpeed()` affects BOTH keyboard and pathfinding movement
  equally (path speed is derived from moveSpeed via `getPathSpeed()` at `IsoPlayer.java:1012`).
  So even if UT_natural corrupts moveSpeed, it cannot by itself explain why Walk To works but
  arrow keys don't.

## Verdict

Real bug. Useful to fix regardless. But **not the primary suspect** for the arrow-key-only symptom.
