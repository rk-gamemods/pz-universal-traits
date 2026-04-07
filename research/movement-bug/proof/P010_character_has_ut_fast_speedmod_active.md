# P010: Character Has UT_fast — SpeedHook Is Active with speedMod = 0.3

**Proven on:** 2026-04-06  
**Proven by:** Save file binary analysis + user confirmation  
**Source:** `C:\Users\Admin\Zomboid\Saves\Sandbox\2026-04-05_23-38-44\players.db`  
**Confidence:** Absolute

## Character: Arron Lyles

### Active UT Traits (from save data)

| Trait ID | Purpose |
|----------|---------|
| UniversalTraits:UT_fast | +30% movement speed |
| UniversalTraits:UT_fasthands | transfer speed |
| UniversalTraits:UT_backpacker | carry weight |
| UniversalTraits:UT_cangrabmore | carry weight |
| UniversalTraits:UT_preparedpack | starting items |
| UniversalTraits:UT_quickworker | work speed |

### ModData Values (extracted from save binary)

| Key | Value | Meaning |
|-----|-------|---------|
| UT_speedMod | **0.3** | SpeedHook applies 1.3x position multiplier |
| UT_prevX | 8219.47 | SpeedHook's cached previous X position |
| UT_prevY | 11678.51 | SpeedHook's cached previous Y position |

### Trait Contributions to Speed Bucket

Only `UT_fast` calls `applySpeedModifier(player, 0.3, TRAIT_ID)`.
No other active trait contributes to the speed bucket.
Sum = 0.3, clamped to [-0.75, 1.0] = **0.3**.

## Implication

**The SpeedHook's setX/setY code path is ACTIVE on this character.**

Every frame during movement:
1. SpeedHook computes `factor = 1.0 + 0.3 = 1.3`
2. Reads player position delta from stored prevX/prevY
3. Calls `player:setX(prevX + dx * 1.3)` and `player:setY(prevY + dy * 1.3)`

This confirms that **H001 (SpeedHook setX/setY disrupts movement) is actively in play**
for this character. The SpeedHook is not a no-op — it is rewriting position every movement frame.

## Next Step

The critical remaining question is: why does Walk To survive this while arrow keys don't?
This requires either:
- Live instrumentation to observe the exact behavior during both movement types
- Deeper engine analysis of how keyboard vs pathfinding movement handles position overrides
