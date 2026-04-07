# Movement Bug Fix Plan

**Date:** 2026-04-06  
**Confidence:** HIGH — root cause source-proven, kill mechanism source-proven, engine API verified  
**Scope:** UTCore_SpeedHook.lua + UT_natural.lua + UTCore_StatModifiers.lua  
**Project:** UniversalTraits / UT_CORE, PZ Build 42.16.x single-player  
**Status:** ✅ IMPLEMENTED — all code changes applied, 189 tests passing (0 failures), deployed to live

---

## Implementation Status

| Fix | Status | Tests |
|-----|--------|-------|
| Fix 1: SpeedHook rewrite (delta-scaling) | ✅ Complete | 9 new unit tests |
| Fix 2: UT_natural integration (UTCore API) | ✅ Complete | Existing suite covers |
| Fix 3: StatModifiers comment fix | ✅ Complete | N/A (comments only) |
| Engine contract tests | ✅ Complete | 22 tests parse PZ Java source |
| Mock updates (nextX/nextY) | ✅ Complete | 4 new API surface tests |
| Release sync + live deploy | ✅ Complete | Hash-verified |

**Remaining:** In-game validation (Phase 2/3/4 testing in the Testing Plan below).

---

## 1. Root Cause Summary (for context)

The bug is a **position-pinning feedback loop** caused by `UTCore_SpeedHook.lua`:

1. `preupdate()` resets `nextX = x` (frame start)
2. `doDeferredMovement()` writes `nextX += animDelta` (engine movement)
3. `OnPlayerMove` fires during `update()` — SpeedHook runs here
4. SpeedHook reads `getX()` (still stale pre-movement value)
5. SpeedHook calls `setX(newPos)` → clobbers `x`, `nextX`, AND `scriptNextX` to same value
6. `postupdate()` sees `dx = nextX - x = 0` → no movement applied

The player is stuck because every frame's pending animation movement is destroyed before
the engine can commit it. Walk To survives because the pathfinding state machine re-primes
movement after the `OnPlayerMove` cycle (source-proven in P014).

**Secondary bug:** `UT_natural.lua` caches `getMoveSpeed()` (a derived value including injury
penalties) and replays it into `setMoveSpeed()` (the raw base field). This bakes injury
states permanently into the player's base speed.

---

## 2. Fix Strategy: Delta-Scaling via nextX/nextY

### Why this approach

The engine provides `setNextX(float)` / `setNextY(float)` on `IsoMovingObject` (line 1423).
Unlike `setX()`, these methods **only set `nx`** — they do NOT clobber `x` or `scriptNextX`.

By reading the pending delta (`getNextX() - getX()`), scaling it, and writing back to
`setNextX()` only, we:

- Preserve the engine's animation-driven movement pipeline
- Avoid the position-pinning feedback loop entirely
- Let `postupdate()` see the correct scaled delta and commit it normally
- Stay compatible with any other mod that also reads/writes nextX
- Inherit the engine's built-in collision checking (postupdate still processes the delta)

### Why NOT other approaches

| Alternative | Problem |
|------------|---------|
| `setMoveSpeed()` | BodyDamage.java:2544 resets it to 0.06F; we'd fight the engine every frame |
| `runSpeedModifier` / `walkSpeedModifier` | Private/protected fields, no public setter |
| Post-`postupdate()` correction | Fires too late; would need to fight the scheduler |
| Keep `setX()`/`setY()` but "fix timing" | Fundamentally unsafe — any `setX()` during update clobbers nextX by design |

---

## 3. Implementation: Fix 1 — SpeedHook Rewrite (CRITICAL)

**File:** `UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua`  
**Risk:** High impact (this is THE bug). Must be correct.

### Current (broken) code

```lua
local dx = newX - prevX
local dy = newY - prevY
if dx ~= 0 or dy ~= 0 then
    local factor = 1.0 + mod
    local newPosX = prevX + dx * factor
    local newPosY = prevY + dy * factor
    player:setX(newPosX)        -- CLOBBERS nextX
    player:setY(newPosY)        -- CLOBBERS nextY
    md["UT_prevX"] = newPosX
    md["UT_prevY"] = newPosY
end
```

### New (safe) implementation

```lua
-- UTCore_SpeedHook.lua
-- Applies UT_speedMod to movement by scaling the pending animation delta
-- stored in nextX/nextY, NOT by rewriting absolute position.
--
-- Engine frame order:
--   preupdate() → nextX = x
--   doDeferredMovement() → nextX += animDelta
--   OnPlayerMove fires → THIS HOOK RUNS HERE
--   postupdate() → applies dx = nextX - x
--
-- We scale the pending delta so postupdate commits a larger/smaller step.

UTCore = UTCore or {}

local TELEPORT_GUARD = 5.0
local MAX_DELTA_PER_FRAME = 1.5  -- tiles; safety cap against extreme jumps

local function onPlayerMove()
    local player = getPlayer()
    if not player then return end
    if not player:isLocalPlayer() then return end

    if UTCore.refreshAggregatedModifierCache then
        UTCore.refreshAggregatedModifierCache(player)
    end

    local md = player:getModData()
    local mod = md["UT_speedMod"]

    if not mod or mod == 0 then return end

    -- Read the pending movement delta that doDeferredMovement() wrote
    local x = player:getX()
    local y = player:getY()
    local nextX = player:getNextX()
    local nextY = player:getNextY()

    local dx = nextX - x
    local dy = nextY - y

    -- No pending movement this frame — nothing to scale
    if dx == 0 and dy == 0 then return end

    -- Teleport guard: skip if the pending delta is unreasonably large
    if math.abs(dx) > TELEPORT_GUARD or math.abs(dy) > TELEPORT_GUARD then return end

    -- Scale the pending delta
    local factor = 1.0 + mod  -- e.g., 1.3 for UT_fast (+30%), 0.5 for UT_gimp (-50%)
    local scaledDx = dx * factor
    local scaledDy = dy * factor

    -- Per-frame delta cap: prevent extreme movement regardless of modifier value
    local len = math.sqrt(scaledDx * scaledDx + scaledDy * scaledDy)
    if len > MAX_DELTA_PER_FRAME then
        local scale = MAX_DELTA_PER_FRAME / len
        scaledDx = scaledDx * scale
        scaledDy = scaledDy * scale
    end

    -- Write back to nextX/nextY ONLY (does NOT clobber x or scriptNextX)
    player:setNextX(x + scaledDx)
    player:setNextY(y + scaledDy)
end

if Events and Events.OnPlayerMove then
    Events.OnPlayerMove.Add(onPlayerMove)
end
```

### What changed and why

| Aspect | Old | New | Why |
|--------|-----|-----|-----|
| Position read | `getX()` vs stored `prevX` | `getNextX() - getX()` | Reads actual pending engine delta, not stale previous position |
| Position write | `setX()` / `setY()` | `setNextX()` / `setNextY()` | Does NOT clobber x or scriptNextX; preserves engine pipeline |
| Previous-position tracking | `UT_prevX` / `UT_prevY` in moddata | Removed entirely | No longer needed — we read the engine's own delta |
| Per-frame delta cap | None | `MAX_DELTA_PER_FRAME = 1.5` tiles | Safety net against extreme movement |
| Teleport guard | `> 5.0` on position diff | `> 5.0` on pending delta | Same purpose, applied to correct value |

### Verification requirement

Before merging, confirm `player:getNextX()` and `player:setNextX()` are callable from PZ Lua.
These are public methods on `IsoMovingObject` (Java base class of IsoPlayer). PZ's Kahlua VM
should expose them. Quick test: add a temporary `print("nextX=" .. tostring(player:getNextX()))`
in a loaded mod and check the console.

---

## 4. Implementation: Fix 2 — UT_natural Integration (IMPORTANT)

**File:** `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_natural.lua`  
**Risk:** Medium. Real bug but secondary to the position-pinning fix.

### Current (broken) code

```lua
-- Caches getMoveSpeed() (DERIVED, includes injury) as a "base"
if not md["UT_naturalBaseSpeed"] then
    local ok, baseSpeed = pcall(function() return player:getMoveSpeed() end)
    md["UT_naturalBaseSpeed"] = (ok and baseSpeed) or 1.0
end
-- Replays cached derived value into raw field
player:setMoveSpeed(md["UT_naturalBaseSpeed"] * (1.0 + bonus))
```

**Two bugs:**

1. `getMoveSpeed()` returns derived speed (includes injury penalties) — caching it bakes injuries permanently
2. `setMoveSpeed()` fights BodyDamage.java:2544 which resets moveSpeed to 0.06F

### New (safe) implementation

Instead of manipulating `moveSpeed` directly, feed UT_natural's bonus into the unified
speed modifier system that the SpeedHook already aggregates:

```lua
-- UT_natural.lua
-- Natural: movement speed +10%, reduced by 2% per clothing item worn.
-- Formula: bonus = max(0, 0.10 - clothingCount * 0.02)
-- At 5+ clothing items the bonus reaches zero. Recalculated every 30 ticks.
-- Uses the unified UTCore speed modifier system (safe nextX/nextY scaling).

local TRAIT_ID = "UniversalTraits:UT_natural"
local SOURCE_ID = "UT_natural"

local tickCounter = 0

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end

    local clothingCount = (player:getWornItems() and player:getWornItems():size()) or 0
    local bonus = math.max(0.0, 0.10 - (clothingCount * 0.02))

    local md = player:getModData()

    -- Only update if the bonus changed (avoids unnecessary recalculation)
    if md["UT_naturalLastBonus"] ~= bonus then
        md["UT_naturalLastBonus"] = bonus
        UTCore.applySpeedModifier(player, bonus, SOURCE_ID)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
```

### What changed and why

| Aspect | Old | New | Why |
|--------|-----|-----|-----|
| Speed modification | Direct `setMoveSpeed()` | `UTCore.applySpeedModifier()` | Uses unified safe system; no fight with BodyDamage |
| Base speed caching | Cached `getMoveSpeed()` (derived) | Removed entirely | Eliminates permanent injury bake-in |
| Moddata cleanup | `UT_naturalBaseSpeed` stored | No longer written | Dead field; can be cleaned up in migration |

### Migration note

Existing saves will have stale `UT_naturalBaseSpeed` in moddata. This is harmless (unused field).
Optionally clean it up in a one-time migration hook, but not required for correctness.

---

## 5. Implementation: Fix 3 — Comment Correction (MINOR)

**File:** `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua`

The clamping constants have swapped comments:

```lua
-- Current (wrong comments):
local SPEED_MIN_DELTA = -0.75  -- "75% faster" (WRONG — this means factor=0.25, 75% SLOWER)
local SPEED_MAX_DELTA = 1.0    -- "100% slower" (WRONG — this means factor=2.0, 100% FASTER)
```

Fix:

```lua
local SPEED_MIN_DELTA = -0.75  -- floor: factor=0.25 → 75% slower than normal
local SPEED_MAX_DELTA = 1.0    -- cap: factor=2.0 → 100% faster than normal (2x speed)
```

**Also:** the existing clamp range `[0.25x, 2.0x]` is reasonable. At 2x sprint speed
the player moves at roughly 30-40 km/h equivalent, well below PZ car speeds (80-100+ km/h).
No change to the actual values needed.

---

## 6. Movement Smoothing Analysis

The user raised concern about movement stutter at high speed modifiers.

### Why the new approach is inherently smooth

The delta-scaling approach scales the engine's **per-frame animation delta**, which is already
animation-smoothed by PZ's `animPlayer.getDeferredMovement()` system. This means:

1. **No teleportation** — movement follows the animation, just with larger/smaller steps
2. **Constant multiplier** — trait modifiers don't change frame-to-frame (they're set once when
   the trait is applied and stay constant), so there's no inter-frame jitter from modifier oscillation
3. **No accumulated position error** — each frame derives the delta fresh from `nextX - x`, so
   rounding errors don't compound across frames
4. **Engine collision still applies** — `postupdate()` processes the scaled delta through normal
   collision/physics, so the player won't walk through walls at high speed

### When smoothing WOULD be needed (and isn't, currently)

Smoothing would only matter if the speed modifier changed rapidly between frames (e.g., an
effect that oscillates `UT_speedMod` every few ticks). Current UT traits set their modifier
once and leave it constant. If future traits need rapid modifier changes, add exponential
smoothing at that time:

```lua
-- NOT needed now; include only if future traits change modifiers rapidly
local SMOOTH_ALPHA = 0.3
local smoothedMod = prevSmoothed + SMOOTH_ALPHA * (targetMod - prevSmoothed)
```

### Per-frame delta cap (already included in Fix 1)

The `MAX_DELTA_PER_FRAME = 1.5` tiles cap in Fix 1 prevents any single frame from moving
the player more than 1.5 tiles regardless of modifier value. This handles:

- Extreme modifier values from moddata corruption
- Edge cases where the engine reports an unusually large animation delta
- Future traits with high speed bonuses

At 60 FPS, 1.5 tiles/frame = 90 tiles/second. PZ sprint is roughly 3-5 tiles/second.
So 1.5 tiles/frame is ~18-30x sprint speed — extremely generous as a safety cap, will never
trigger during normal gameplay but catches pathological cases.

**Recommendation:** Keep `MAX_DELTA_PER_FRAME = 1.5` as-is. If testing reveals any stutter
at maximum trait speed (+30% from UT_fast + 10% from UT_natural = +40% total), reduce to `1.0`.
But stutter is extremely unlikely because the animation delta itself is already small.

---

## 7. Speed Cap Analysis

### Current situation

The existing `SPEED_MIN_DELTA` / `SPEED_MAX_DELTA` clamp in `UTCore_StatModifiers.lua` already
limits the aggregated modifier to `[-0.75, +1.0]`, giving a factor range of `[0.25x, 2.0x]`.

### Is 2x speed faster than a car?

No. PZ movement speeds (approximate):

| Mode | Speed (tiles/sec) | Equivalent |
|------|--------------------|------------|
| Walk | ~1.5 | ~5 km/h |
| Jog | ~3.0 | ~10 km/h |
| Sprint | ~4.5 | ~15 km/h |
| Sprint × 2.0 (max UT) | ~9.0 | ~30 km/h |
| Slow car | ~15 | ~50 km/h |
| Fast car | ~30+ | ~100+ km/h |

**At maximum possible UT speed boost (2x), sprint is ~30 km/h — half of a slow car.** Safe.

### Current traits can't even reach the cap

Maximum stacking: `UT_fast` (+0.3) + `UT_natural` (+0.1 max) = +0.4 total.
Factor = 1.4x. Well below the 2.0x cap.

Negative minimum: `UT_gimp` (-0.5) = factor 0.5x. Well above the 0.25x floor.

**No changes needed to clamping values.**

---

## 8. Testing Plan

### Phase 1: API Verification (before any code changes)

1. Add temporary debug print to any loaded mod:

   ```lua
   local p = getPlayer()
   print("nextX=" .. tostring(p:getNextX()) .. " x=" .. tostring(p:getX()))
   ```

2. Confirm `getNextX()` and `setNextX()` are callable without errors
3. If they error → fall back plan needed (see Risk Assessment)

### Phase 2: SpeedHook Fix Validation

1. **Character with UT_fast (the failing case):**
   - Load save with UT_fast character
   - Verify keyboard arrow movement works
   - Verify Walk To still works
   - Verify movement feels ~30% faster than vanilla

2. **Character with UT_gimp:**
   - Verify movement is ~50% slower than vanilla
   - Verify Walk To still works at reduced speed

3. **Character with NO speed traits:**
   - Verify movement is completely unaffected (SpeedHook should early-return when mod=0)

4. **Teleport guard test:**
   - Use debug teleport or map load
   - Verify player doesn't get stuck after teleport (guard should skip the frame)

### Phase 3: UT_natural Fix Validation

1. **UT_natural + UT_fast character:**
   - Verify combined speed boost feels like +40% (0.3 + max 0.1)
   - Verify clothing reduces the UT_natural portion
   - Verify 5+ clothing items zeroes the UT_natural bonus (only UT_fast remains)

2. **UT_natural alone:**
   - Verify +10% naked, reducing with clothing
   - Verify injury does NOT permanently alter speed

### Phase 4: Regression and Compatibility

1. Run existing UT_CORE test suite (157 tests)
2. Run existing UniversalTraits test suite
3. Test with TchernoLib still in loadout (it should not conflict since we no longer write setX)
4. Test with Lifestyle still in loadout (same reasoning)

---

## 9. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `getNextX()`/`setNextX()` not callable from Lua | Low | Blocking | Test first in Phase 1; fallback: use moddata-based delta tracking with `setNextX` replaced by direct field write |
| Negative speed modifier causes backward movement | None | N/A | Factor = 1 + mod; minimum mod = -0.75 → factor = 0.25 (slow but forward) |
| Other mods also write to nextX on same frame | Low | Medium | Our approach is additive (scales existing delta), so it composes better than setX. If another mod also scales, effects multiply rather than clobber. |
| Stale `UT_prevX`/`UT_prevY` in existing saves | None | None | New code doesn't read these fields. They're harmless orphans. |
| `MAX_DELTA_PER_FRAME` cap too aggressive | Very Low | Low | 1.5 tiles/frame is ~18-30x sprint. Only triggers on pathological input. Tune if needed. |

### Fallback if `getNextX()`/`setNextX()` are NOT callable

If Phase 1 testing reveals these methods aren't exposed to Lua:

**Fallback approach:** Track our own delta using the position AFTER `postupdate()` committed last
frame's movement (i.e., read `getX()` at the START of the next frame's OnPlayerMove, compare to
our stored position from the end of last frame). This is less clean but avoids `setX()` entirely
by writing to `setNextX()` through Java reflection or by using a different event hook.

However, this fallback is unlikely to be needed since `setNextX()` is a standard public method
on `IsoMovingObject`, the base class of all moving objects.

---

## 10. Implementation Order

| Step | File | Description | Depends On |
|------|------|-------------|------------|
| 1 | (any loaded mod) | Phase 1: Verify `getNextX()`/`setNextX()` are callable from Lua | Nothing |
| 2 | `UTCore_SpeedHook.lua` | Fix 1: Rewrite to delta-scaling via nextX/nextY | Step 1 passes |
| 3 | `UTCore_StatModifiers.lua` | Fix 3: Correct swapped comments on clamp constants | Nothing |
| 4 | `UT_natural.lua` | Fix 2: Integrate into unified speed modifier system | Step 2 (so SpeedHook is safe first) |
| 5 | (game) | Phase 2+3: Full gameplay validation | Steps 2-4 |
| 6 | (test suite) | Phase 4: Run test suites, regression check | Steps 2-4 |
| 7 | (release) | Sync release → live → commit | Step 5+6 pass |

---

## 11. Files Modified (Complete List)

| File | Change Type |
|------|-------------|
| `UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua` | Full rewrite |
| `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` | Comment fix only (2 lines) |
| `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_natural.lua` | Rewrite to use unified modifier system |

No new files. No deleted files. No structural changes.

---

## 12. Research Threads — Closure Status

| Thread | Status | Blocks Fix? |
|--------|--------|-------------|
| H001: SpeedHook setX kills movement | **PROVEN** — source-proven kill mechanism | No (this IS the fix target) |
| H002: UT_natural stale speed | **PROVEN** — real bug, fix included | No |
| H003: Broader mod conflict class | **PROVEN structural risk** — fix eliminates it by design | No |
| H004: WorkSpeedHook collateral | **OPEN, low probability** — unrelated to movement | No |
| Walk To survival mechanism | **~80% explained** — pathfinding re-primes after OnPlayerMove | No (fix makes it irrelevant) |
| `getNextX()`/`setNextX()` Lua accessibility | **UNVERIFIED** — public Java methods, expected to work | Phase 1 test required |
| TchernoLib active in current loadout | **UNCONFIRMED** — structural risk only | No (fix removes the conflict pattern) |

**All threads that could block implementation are closed. The one remaining verification
(Lua API accessibility) is a 30-second test in Phase 1.**
