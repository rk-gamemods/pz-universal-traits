# Movement Bug Investigation Status

**Last updated:** 2026-04-06 (update 3)  
**Updated by:** Opus 4.6

## CLEAR PICTURE: Primary Cause Confirmed, Secondary Bug Confirmed, Compatibility Class Broadened

The evidence now supports a fix-ready model:

1. **Primary cause on the failing character:** `UTCore_SpeedHook.lua` rewrites position with
  `setX()` / `setY()` while `UT_fast` has `UT_speedMod = 0.3` active.
2. **Mechanism:** the hook runs during `update()` after deferred movement has been accumulated
  into `nextX`, but before `postupdate()` reconciles `nextX` into `x`. The hook therefore
  clobbers the current frame's pending movement.
3. **Secondary independent bug:** `UT_natural.lua` caches derived speed and replays it into the
  raw moveSpeed field. Real bug, but not the keyboard-only root cause.
4. **Broader compatibility boundary:** TchernoLib is still a structural conflict risk, but it is
  not the only relevant case. A broader installed-mod scan found the same general movement-rewrite
  pattern in other mods too (P013). The fix must target the pattern, not just the current loadout.

The only major unresolved behavior question is **why Walk To survives**. P014 now proves that
`Walk To` is a distinct persistent pathfinding mode, not synthetic keyboard input, and that the
local player re-primes path movement state after the current `OnPlayerMove` cycle. The final
live movement-survival mechanism is still not fully closed, but the model is now much tighter.

## BREAKTHROUGH: Kill Mechanism Identified — setX Destroys nextX Delta

**P011 + P012 prove the specific kill mechanism:**

1. `preupdate()` resets `nextX = x`
2. `doDeferredMovement()` writes `nextX += animDelta`
3. `OnPlayerMove` fires during `update()`, before `postupdate()`
4. SpeedHook reads `getX()` while the current frame's movement is still in `nextX`
5. SpeedHook calls `setX(...)` and `setY(...)` → forces `x = nextX = scriptNextX`
6. `postupdate()` then sees no pending current-frame movement left to apply

**This is a position-pinning feedback loop.** The player can never move because:
- The animation writes to `nextX` but SpeedHook reads from `x`
- `x` never updates because the nextX→x reconciliation can't happen before SpeedHook clobbers nextX
- Every frame: dx=0, setX(same position), nextX delta destroyed, repeat

Combined with P010 (speedMod=0.3 active), this explains why keyboard movement is broken.

**Walk To gap (partial):** WalkTowardState has position correction in doDeferredMovement
(IsoGameCharacter.java:1629-1641) and the pathfinding state machine may apply additional
corrections after the hook. Further investigation needed but the PRIMARY mechanism is now proven.

## Ranked Suspect List

| Rank | Suspect | Evidence | Gaps |
|------|---------|----------|------|
| **1** | **SpeedHook setX/setY (H001)** | **setX clobbers nextX (P003), fires when speedMod!=0 (P004), speedMod=0.3 confirmed in save (P010), kill mechanism proven with frame ordering (P011, P012)** | **Walk To gap (P005) partially explained** |
| 2 | Broader movement-library conflict class (H003) | TchernoLib plus other mods use the same family of per-frame position rewriting (P013) | Exact future stack unknown; must design by pattern |
| 3 | UT_natural stale speed (H002) | Real bug confirmed (P006) | Can't explain symptom split, may be transient |
| 4 | WorkSpeedHook collateral (H004) | Aggressive monkeypatch pattern | No specific victim identified, low probability |

## Hard Proof Summary

| ID | Title | Status |
|----|-------|--------|
| P001 | UT stack isolation test | Absolute — user-validated |
| P002 | Symptom split (arrows vs Walk To) | Absolute — user-validated |
| P003 | setX overwrites nextX/scriptNextX | Proven from Java source |
| P004 | SpeedHook calls setX when speedMod!=0 | Proven from Lua source |
| P005 | OnPlayerMove fires for pathfinding too | Proven from Java source — REFUTES naive Walk To explanation |
| P006 | UT_natural caches derived speed | Proven from Lua + Java source |
| P007 | Complete event registration inventory | Proven from source grep |
| P008 | No Lua errors in debug log | Proven from log grep |
| P009 | Speed modifier trait inventory | Proven from source grep |
| P010 | Character has UT_fast, speedMod=0.3 active | Absolute — save file binary extraction |
| P011 | setX destroys pending nextX delta — position-pinning loop | Proven from Java source (IsoMovingObject.java:585, :473) |
| P012 | Frame order proves OnPlayerMove sees pre-postupdate x | Proven from scheduler + preupdate/postupdate sources |
| P013 | Broader installed mod ecosystem shows same conflict class | Proven from local mod + Workshop source scan |
| P014 | Walk To uses persistent pathfinding mode, not synthetic keyboard input | Proven partial model from Lua + Java source |

## Ruled Out

| Theory | Evidence Against |
|--------|-----------------|
| Pure third-party cause | P001 — disabling UT removes bug while other mods remain |
| Authentic Z alone | User tested — bug persisted with Authentic Z disabled |
| Lua runtime crash | P008 — no errors in log |
| Direct keyboard input interception by UT | P007 — no UT code touches keyboard/input |
| UT touches blockMovement or ignoreInputsForDirection | Grep confirmed zero matches |
| UT manipulates state machine | Grep confirmed zero matches |

## Critical Next Steps (Priority Order)

### 1. ~~CHARACTER TRAIT TEST~~ ANSWERED (P010)
**Result:** Character has UT_fast. UT_speedMod = 0.3. SpeedHook setX/setY is active.
H001 is confirmed as active on the failing character.

**Still valuable follow-up test:** Create a NEW character with UT enabled but NO speed traits.
If bug disappears → SpeedHook is the sole cause.
If bug persists → there is an ADDITIONAL cause beyond the SpeedHook.

### 2. ~~KILL MECHANISM RESEARCH~~ ANSWERED (P011, P012)
**Result:** frame ordering and movement reconciliation are now source-proven. The hook runs
before postupdate applies the current frame's deferred movement, and its setX/setY calls clobber
that pending movement.

### 3. DESIGN FIX FOR SPEEDHOOK (Next priority)
The SpeedHook must stop using setX/setY. Options:
- **Option A:** Modify `nextX`/`nextY` directly (additive) instead of using setX
- **Option B:** Hook earlier and scale the animation delta before it's applied
- **Option C:** Use the engine's movement rate variables (currentSpeed, walkSpeed) instead of position rewriting
- Evaluate which approach is safest and most compatible with the engine pipeline.

**Compatibility requirement:** any replacement must avoid absolute position rewriting entirely.
That not only fixes the current bug, it also removes the shared failure mode that could conflict
with TchernoLib, Lifestyle-style movement helpers, or any future movement library using the same
setX/setY rewrite pattern.

**Scope rule:** the current active mod list is for reproduction only. It is NOT the compatibility
boundary. Compatibility design must account for the broader class of movement mods evidenced in P013.

### 4. WALK TO MECHANISM RESEARCH (Lower priority — partial explanation strengthened)
P014 proves the important structural distinction:

- `Walk To` is a pathfinding timed action, not manual input by another name.
- It sets `pathfinding=true`, survives normal stop-on-walk cancellation, and repeatedly calls
  `PathFindBehavior2.update()`.
- Local-player code later re-primes `justMoved` from `hasPath() && shouldBeMoving()` after the
  current `OnPlayerMove` cycle.
- The timed-action queue does NOT give it a separate post-world-update movement pass.

**What remains open:** the exact frame sequence that turns that persistent pathfinding mode into
net progress in live play despite the confirmed UT position-clobber. This is now a smaller,
better-isolated question and likely requires targeted instrumentation rather than more broad source search.

**Planned next step:** see `instrumentation/I001_walkto_vs_keyboard_frame_trace_plan.md`.

### 4. UT_NATURAL FIX (Independent — do regardless)
Fix the stale-derived-speed bug in UT_natural.lua even if it's not the primary cause.

## Files of Interest

### Our Code
- `UTMods/UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua` — primary suspect
- `UTMods/UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` — sets UT_speedMod
- `UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_natural.lua` — secondary bug
- `UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_fast.lua` — speed trait
- `UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_lurcher.lua` — speed trait

### Engine Code
- `PZCodebase/Java/source/zombie/iso/IsoMovingObject.java:473` — setX implementation
- `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2166` — OnPlayerMove trigger
- `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2370` — pathfinding justMoved
- `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2076` — doDeferredMovement
- `PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:1600` — doDeferredMovement impl

### Third Party
- `TchernoLib SpeedFramework.lua` — corroborates setX danger, potential conflict partner

## Agent Coordination Notes

- Any agent starting work on this bug: read this STATUS.md first.
- After completing work: update this file with findings and move proven items to proof/.
- Do NOT re-investigate ruled-out theories without new evidence.
- The handoff document at `planning/2026-04-06_universal_traits_movement_bug_handoff.md`
  provides earlier investigation context but some of its conclusions are superseded by
  this research folder.
