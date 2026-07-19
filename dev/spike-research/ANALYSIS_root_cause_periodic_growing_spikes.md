# Root Cause Analysis: Periodic Growing Frame-Budget Spikes

**Status:** ~~FINAL~~ **SUPERSEDED** — Key conclusion was wrong. See updated `CASE_frame_spikes.md`.
**Date:** 2026-04-19
**Fatal flaw:** This analysis concluded "the profiler does NOT cause the spikes" based on the assumption that engine-side periodic operations were the cause. User-reported symptom B1 (no stutter without profiler) falsifies ALL engine-blame hypotheses. The actual cause is the profiler's own dirty-frame refresh cost (refreshRows sorting), which is periodic, growing, and only exists when the profiler runs. See CASE file for corrected analysis.

---

## 1. Architecture: How Frame Time Is Measured and Displayed

### 1.1 The Frame Pipeline (code-proven)

PZ uses triple-buffered rendering with lock-step synchronization between the game thread and a dedicated render thread.

**Game thread** runs `frameStep()` ([GameWindow.java#L697–777]()):

```
frameStep() {
    startTime = nanoTime()
    logic()              ← OnTick fires here (inside IngameState.updateInternal:1590)
    renderInternal()     ← populates sprite commands; ISUIElement:prerender() runs here
    onRender()
    LightingThread.update()
    LuaEventManager.RunQueuedEvents()
    Core.EndFrameUI() → RenderThread.Ready() → pushFrameDown()   ← may BLOCK
    finally: updateTime = nanoTime() - startTime
}
```

**pushFrameDown()** ([SpriteRenderer.java#L706–718]()) acquires `synchronized(this.states)` and calls `waitForReadySlotToOpen()`. If the render thread hasn't consumed the previous "ready" frame, the game thread **blocks in `wait()`** until it does. The blocking duration is captured as `waitTime` → exposed as `SpriteRenderer.getWaitTime()` → profiler reads this as **cpu-wait**.

**Render thread** ([RenderThread.java#L230–255]()) calls `acquireStateForRendering()` which **blocks in `wait()`** until the game thread produces a new ready frame. This blocking duration is captured as `RenderThread.waitTime` → profiler reads it as **gpu-wait**.

**Key implication:** `updateTime` (= `getCPUTime()`) includes the pushFrameDown block time. If cpu-wait is high, frame time rises even though CPU work hasn't increased.

### 1.2 Current Measurements

| Metric | Value | Meaning |
|--------|-------|---------|
| **cpu-wait** | **0.0 ms** | Game thread NEVER blocks on render thread |
| **gpu-wait** | **10.5 ms** | Render thread waits 10.5ms/frame for game thread |
| **cpuMs (avg)** | **6.8 ms** | Average frameStep duration |
| **budgetMs** | **16.7 ms** | 60fps target |
| **headroom** | **~10 ms** | 59% of budget is unused |

**Conclusion:** CPU is the bottleneck. The render thread finishes its work in ~6.2ms (16.7 − 10.5) and then idles waiting for the next frame from the game thread. The game thread completes in 6.8ms average with no blocking. There is 10.5ms of render-side slack.

### 1.3 What getCPUTime() Returns

`LuaManager.getCPUTime()` ([LuaManager.java#L9872]()):

```java
return (int)(GameWindow.getUpdateTime() / 1000000L)
```

Returns the **PREVIOUS** frame's total `frameStep()` duration in milliseconds. Includes logic, render submission, UI prerender, and any pushFrameDown wait.

### 1.4 What the Budget Graph Shows

The stacked area chart ([drawStackedArea, line 326–374]()) renders pre-filled layer arrays built by `refreshBudgetLayers()` ([line 926–960]()). Each bar corresponds to one ring entry, and each ring entry is produced by `dumpIntervalReport()` once every 30 ticks (0.5 seconds).

**The values are 30-tick AVERAGES**, not peaks:

```lua
-- engineTick() samples every tick:
_cpuMsSum = _cpuMsSum + cpu    -- accumulates 30 samples
_cpuMsCount = _cpuMsCount + 1

-- dumpIntervalReport() divides:
cpuMs = _cpuMsSum / _cpuMsCount   -- AVERAGE of 30 per-tick CPU samples
modMs = grandMs / INTERVAL_TICKS   -- AVERAGE of 30 per-tick mod costs
engineMs = cpuMs - modMs           -- derived average
headroomMs = budgetMs - cpuMs      -- derived average
```

**Critical consequence: AVERAGING DILUTES SINGLE-FRAME SPIKES.** If one frame in an interval costs 30ms extra while the other 29 frames cost 6.8ms each, the interval average rises by only 1ms (30/30). For a spike to be visibly prominent in the graph (~2ms above baseline), it must represent SUSTAINED elevated cost affecting most frames in the interval, or a catastrophic single frame (60ms+).

`cpuMsPeak` IS captured separately and fed to a Memory-tab sparkline, but it is NOT what the stacked area graph shows.

---

## 2. The Profiler's Own Per-Frame Cost

### 2.1 Drawing Cost (constant after warmup)

On **TAB_MODS** (the default view), every frame executes:

| Component | Draw Calls | Notes |
|-----------|-----------|-------|
| drawHeader() | 7 | Status, CPU string, progress bar |
| drawTabBar() | 13 | 4 tabs with text + separator |
| drawColHeader() | 7 | Column headers |
| drawModRow() × 20 | 160 | 8 calls per row |
| Separator + gap display | 7 | Separators, gap stats |
| **drawStackedArea()** | **~950** | **300 samples × 3 layers + 45 budget dashes** |
| **TOTAL (TAB_MODS)** | **~1,157** | Every frame, unconditionally |

Each draw call is a Lua → Java bridge call (`ISUIElement.drawRect/drawText` → `UIElement.DrawTexture` → `SpriteRenderer.render()` → ring buffer append). The per-call cost is:

- Kahlua method dispatch (reflection-based): ~2–5 μs
- Java method body (queue append to ring buffer): ~0.5–1 μs
- **Per-call total: ~3–6 μs**

**Estimated total: 1,157 × 4.5μs ≈ 5.2 ms/frame** (3.5–6.9 ms range)

This is a CONSTANT overhead after the budget ring fills at ~2.5 minutes (300 entries × 0.5s each). Before that, drawStackedArea renders fewer bars.

### 2.2 Where This Cost Appears in the Graph

The profiler's prerender() runs inside `renderInternal()`, which is part of `frameStep()`. The time IS included in `getCPUTime()` → `cpuMs`. However, it is NOT instrumented as a "mod callback" — `prerender()` is called by PZ's built-in ISUIElement traversal, not through the profiler's Lua callback wrapper. Therefore:

> **The profiler's 5.2ms/frame drawing cost appears in the "Engine + unattributed" band of its own graph.**

The profiler is hiding inside its own unattributed metric. The 88–95% unattributed includes both real engine work AND the profiler's own drawing overhead.

### 2.3 Interval-Boundary Frame (periodic but diluted)

Every 30 ticks (0.5 seconds), ONE frame does extra work:

**In engineTick()** (runs during OnTick, BEFORE prerender):
- `dumpIntervalReport()`: iterates all callbacks, computes per-mod totals, pushes ring entries, calls `probeBatchSnapshot()` (1 JMX batch → ZBPerfBridge.snapshotAll), resets accumulators, sets `_snapshotDirty = true`

**In prerender()** (same frame, AFTER OnTick):
- Checks `_snapshotDirty`, calls: `refreshRows()` (sort mods, format 20 rows), `refreshBudgetLayers()` (iterate 300 ring entries × 3 layers), `refreshGapStats()`, `refreshMemoryTab()`, `refreshWorldTab()`, pre-format header strings, push to 6 sparkline rings

**Estimated extra cost:** ~2–5 ms (JMX batch ~0.5–1ms, refreshBudgetLayers ~0.5–1ms, refreshRows ~0.5–1ms, other refreshes ~0.5–1ms).

**However**, this cost hits ONE frame out of 30 in the interval. After averaging:

> Extra cost in averaged graph = (2–5 ms) / 30 ticks = **0.07–0.17 ms** per bar.

**This is invisible in the stacked area chart.** The interval-boundary frame's cost is completely diluted by the 30-tick averaging.

It WOULD be visible in the `cpuMsPeak` sparkline on the Memory tab (since cpuMsPeak captures the single worst frame).

---

## 3. Symptom-Fit Analysis

### 3.1 Observed Symptoms (from CASE file)

| # | Symptom | Source |
|---|---------|--------|
| S1 | Periodic spikes in budget graph (stacked area, AVERAGED) | Screenshots |
| S2 | Spike amplitude grows over time | Screenshots |
| S3 | Spikes appear before ZGC fires (0 completed collections) | Memory tab |
| S4 | +20–24 MB/int heap allocation rate unchanged after profiler fix | Memory tab |
| S5 | Unattributed = 88–95% of CPU | Budget breakdown |
| S6 | Profiled mods total = 0.4–0.7 ms (tiny) | Budget breakdown |
| S7 | cpu-wait = 0.0 ms (game thread never blocks) | Render sync |
| S8 | gpu-wait = 10.5 ms (render thread waits for game thread) | Render sync |
| S9 | Metaspace at 98% (85/87 MB) | Memory tab |
| S10 | CodeHeap growing (30/116 MB profiled nmethods) | Memory tab |
| S11 | Thread count growing (33 avg → 39 peak) | Memory tab |
| S12 | Predates ZBPerfBridge addition (spikes existed before Java bridge) | Historical |
| S13 | Frame average = 6.8 ms / 16.7 ms (41% budget used) | Budget display |

### 3.2 Hypothesis Evaluation

#### H-DRAW: Profiler Drawing Overhead (~1,157 calls/frame)

| Symptom | Fit | Explanation |
|---------|-----|-------------|
| S1 Periodic | **NO** | Drawing is CONSTANT every frame — raises baseline uniformly, doesn't create spikes |
| S2 Growing | **PARTIALLY** | Grows during warmup (0–2.5 min as rings fill), then stabilizes. Can't explain growth beyond 2.5 min |
| S3 Pre-ZGC | YES | Drawing doesn't involve GC |
| S4 Alloc rate | NEUTRAL | Drawing allocations are negligible vs. 20 MB/int |
| S5 Unattributed | **YES** | Drawing cost IS hidden in unattributed band (~5.2ms of the 6.4ms) |
| S6 Low mod cost | NEUTRAL | Drawing isn't a mod callback |
| S7 cpu-wait=0 | YES | Drawing doesn't cause render-thread blocking |
| S8 gpu-wait=10.5 | SLIGHTLY | Adds ~950 sprites/frame reducing render slack, but 10.5ms slack remains |
| S12 Pre-bridge | YES | Drawing existed before ZBPerfBridge |
| S13 6.8ms avg | **YES** | 5.2ms of the 6.8ms could be profiler drawing |

**Verdict:** H-DRAW explains the high unattributed baseline but does **NOT** explain periodic or growing spikes. The profiler's drawing is a constant tax, not a periodic cost.

#### H-INTERVAL: Profiler Interval-Boundary Frame

| Symptom | Fit | Explanation |
|---------|-----|-------------|
| S1 Periodic | WEAKLY | Periodic (every 0.5s) but DILUTED to invisibility by 30-tick averaging in the budget graph |
| S2 Growing | **NO** | Cost is bounded by fixed ring sizes and fixed callback count after warmup |
| S3 Pre-ZGC | YES | No GC involvement |

**Verdict:** H-INTERVAL CANNOT cause visible spikes in the stacked area chart because averaging dilutes the single heavy frame to ~0.1ms. Would only be visible in the cpuMsPeak sparkline.

#### H1: JIT Compilation + CodeCache Growth

| Symptom | Fit | Explanation |
|---------|-----|-------------|
| S1 Periodic | **MEDIUM** | JIT compiles in batches as methods reach invocation thresholds. C1→C2 tiered recompilation creates waves. CodeCache sweeper runs periodically |
| S2 Growing | **YES** | CodeHeap growing (30→? MB) = more methods compiled → more sweeps → longer sweeps |
| S3 Pre-ZGC | **YES** | JIT is independent of GC |
| S5 Unattributed | **YES** | JIT pauses are JVM-internal, invisible to Lua profiling |
| S10 CodeHeap | **YES** | Direct evidence of active JIT compilation |
| S11 Threads | **YES** | More threads → longer time-to-safepoint at method installation |
| S12 Pre-bridge | **YES** | JIT runs on all Java code |

**Verdict:** STRONG FIT for growing amplitude. Medium fit for periodicity (batchy, not perfectly regular). Testable: add `CompilationMXBean.getTotalCompilationTime()` delta and correlate with spike intervals.

#### H2: Safepoint Synchronization Overhead

| Symptom | Fit | Explanation |
|---------|-----|-------------|
| S1 Periodic | **MEDIUM** | Safepoints happen for JIT installation, biased lock revocation, ZGC phases, class unloading — semi-periodic |
| S2 Growing | **YES** | Time-to-safepoint grows with thread count (33→39) and compiled method count. More threads = more time for all to reach safepoint |
| S3 Pre-ZGC | **YES** | Safepoints occur for many reasons besides GC |
| S5 Unattributed | **YES** | Safepoint stalls are invisible to Lua profiling |
| S9 Metaspace 98% | **YES** | Near-full metaspace triggers class unloading → safepoints |
| S11 Threads | **YES** | Direct driver of TTSP growth |

**Verdict:** STRONG FIT. Safepoint overhead is the most likely amplification mechanism. Combined with H1, explains both the periodicity (JIT/sweep triggers) and the growth (more threads + methods). Testable: ZBPerfBridge already captures `safepointCount`, `safepointSyncMs`, `safepointTotalMs` — correlate these deltas with spike amplitude.

#### H3: ZGC Concurrent Phase CPU Contention

| Symptom | Fit | Explanation |
|---------|-----|-------------|
| S1 Periodic | **LOW** | ZGC concurrent phases are sustained, not periodic spikes. Would cause a plateau, not repeated spikes |
| S2 Growing | MEDIUM | Concurrent marking scales with live-set size |
| S3 Pre-ZGC | **CONTRADICTED** | If ZGC phases cause the spikes, they shouldn't exist before ZGC starts. But CASE says spikes exist pre-ZGC |
| S4 Alloc rate | NEUTRAL | ZGC concurrent work is triggered by allocation, not spikes |

**Verdict:** POOR FIT. ZGC concurrent phases cause sustained elevation, not periodic spikes. And spikes predate ZGC activity.

#### H-ENGINE: PZ Engine Periodic Operations

| Symptom | Fit | Explanation |
|---------|-----|-------------|
| S1 Periodic | **YES** | Multiple periodic operations at different frequencies create a composite periodic pattern |
| S2 Growing | **YES** | World complexity grows → periodic operations cost more |
| S3 Pre-ZGC | **YES** | Engine operations are independent of GC |
| S5 Unattributed | **YES** | All engine-internal, invisible to Lua profiling |
| S12 Pre-bridge | **YES** | Engine operations existed before profiler |

PZ engine periodic operations and their graph signatures:

| Operation | Frequency | Duration | Graph Signature (30-tick avg) |
|-----------|-----------|----------|-------------------------------|
| **Auto-save chunk queuing** | ~30 game sec | 1 frame (queue) + N frames (1 chunk/frame) + 1 frame (HotsaveAncilliary) | **SUSTAINED ELEVATION over multiple bars** — most visible |
| **Zombie pop update** | 5s real-time | 1 frame | Diluted in average (invisible in stacked area) |
| **Climate tick** | 1 game minute | 1 frame | Diluted (invisible) |
| **HotsaveAncilliarySystems** | When save queue empties | 1 frame (main thread!) | Diluted in average, but visible in cpuMsPeak |
| **Erosion (10 min)** | 10 game minutes | 1 frame | Diluted (invisible) |
| **Loot respawn (weekly)** | Configurable | 1 frame (iterates ALL chunks) | Rare but catastrophic single frame |

**Auto-save is the strongest candidate for visible periodic spikes in the averaged graph** because it's the only periodic operation that causes SUSTAINED elevation across multiple frames (not just one frame that gets averaged away).

**Verdict:** STRONG FIT. Auto-save chunk processing is the best explanation for visible periodic spikes in the averaged budget graph. Growth explained by world complexity (more dirty chunks over time).

### 3.3 Summary Matrix

| Hypothesis | S1 Periodic | S2 Growing | S3 Pre-ZGC | S5 Unattributed | S9 Meta98% | S10 CodeHeap | S11 Threads |
|-----------|:-----------:|:----------:|:----------:|:---------------:|:----------:|:------------:|:-----------:|
| H-DRAW (profiler drawing) | ✗ | ~2.5min | ✓ | ✓ | — | — | — |
| H-INTERVAL (dirty frame) | diluted | ✗ | ✓ | ✓ | — | — | — |
| H1 (JIT/CodeCache) | medium | **✓** | ✓ | ✓ | — | **✓** | **✓** |
| H2 (Safepoints) | medium | **✓** | ✓ | ✓ | **✓** | **✓** | **✓** |
| H3 (ZGC concurrent) | ✗ plateau | medium | **✗** | ✓ | — | — | — |
| H-ENGINE (PZ periodic) | **✓** | **✓** | ✓ | ✓ | — | — | — |

---

## 4. Conclusions

### 4.1 What Causes the Periodic Growing Spikes

**Primary cause (highest confidence): PZ engine periodic operations, principally auto-save chunk processing.**

Auto-save is the only identified periodic operation that creates SUSTAINED elevated CPU cost across multiple consecutive frames (because ChunkSaveWorker processes 1 chunk per frame from the queue, creating a multi-frame "hump" visible in the 30-tick averaged budget graph). The cost grows because more chunks become dirty as the world gains complexity (more zombies, items, vehicles, player actions).

**Contributing cause (high confidence): JIT compilation + safepoint overhead (H1 + H2).**

These amplify the auto-save spikes. During chunk processing, more Java code paths are exercised, potentially triggering JIT recompilation. Each safepoint pause (for JIT installation, CodeCache sweeping, class unloading) adds microseconds-to-milliseconds of TTSP that grows with thread count (33→39) and compiled method count (CodeHeap growing). Metaspace at 98% may trigger periodic class unloading → safepoints.

**The profiler does NOT cause the spikes.** Its contributions are:

| Profiler Contribution | Type | Magnitude | Visible In |
|----------------------|------|-----------|------------|
| ~1,157 draw calls/frame | Constant baseline elevation | ~5.2 ms/frame | "Unattributed" band (raises floor) |
| Interval-boundary JMX + refresh | Periodic per-frame cost | ~2–5 ms on 1 frame/30 | cpuMsPeak sparkline only (averaged away in stacked area) |
| ~950 extra sprites for render thread | Reduces render slack | ~1 ms less gpu-wait | gpu-wait metric |

The profiler raises the CPU FLOOR by ~5.2ms (constant), making engine-side spikes MORE visible because they start from a higher baseline (closer to the 16.7ms budget). But it does not create the periodic pattern or the growth.

### 4.2 Evidence Chain

1. **Budget graph shows 30-tick averages** (code: `cpuMs = _cpuMsSum / _cpuMsCount` in dumpIntervalReport) → single-frame events are diluted to invisibility → only SUSTAINED multi-frame events create visible spikes.
2. **Auto-save processes 1 chunk/frame** for many consecutive frames (code: ChunkSaveWorker) → sustained elevation visible in averaged graph.
3. **cpu-wait = 0.0** (code: `SpriteRenderer.getWaitTime()`) → game thread never blocks on render thread → spikes are pure CPU work, not render sync.
4. **Profiled mods = 0.4–0.7ms** → Lua callbacks are not the cause.
5. **Unattributed = 88–95%** → the cause is native/JVM, invisible to Lua instrumentation.
6. **CodeHeap growing + Metaspace 98%** → JIT is actively compiling, metaspace is pressured → safepoint activity.
7. **Thread count growing (33→39)** → TTSP increases → safepoint pauses get longer.

### 4.3 What Cannot Be Proven From Code Alone

- The exact frequency of observed spikes (need to examine graph screenshots to count bars between spikes and map to real-time intervals)
- Whether safepoint TTSP correlates with spike amplitude (need to analyze `safepointSyncMs` deltas already collected by ZBPerfBridge)
- Whether auto-save timing correlates with spike timing (need to add a chunk-save probe or analyze save-related log entries)
- The exact per-call cost of Lua→Java bridge draw calls (estimated ~3–6 μs; need microbenchmark to verify)

### 4.4 Recommended Verification Steps

**Step 1 (no code change):** Look at the profiler's existing data. The `safepointCount`, `safepointSyncMs`, `safepointTotalMs` fields are already collected per interval. If these deltas correlate with spike amplitude in the budget graph, H2 is confirmed.

**Step 2 (no code change):** Check `compileDeltaMs` per interval (also already collected). If compilation time spikes correlate with budget spikes, H1 is confirmed.

**Step 3 (observation):** Note the bar-spacing of visible spikes in the budget graph. Count how many bars (each = 0.5s) between spikes:
- ~60 bars apart → auto-save (~30 seconds)
- ~10 bars apart → zombie pop update (5 seconds real-time)
- ~120 bars apart → climate tick (~1 game minute)
- Every bar → constant overhead (not periodic)

**Step 4 (possible code addition):** Add a "save activity" indicator to the profiler — probe `ChunkSaveWorker.instance.getQueueSize()` or similar per interval. If queue size > 0 correlates with elevated bars, auto-save chunk processing is confirmed as the spike source.

---

## 5. The Observer Effect: How the Profiler Makes Spikes Look Worse

The profiler's ~5.2ms constant drawing cost raises every frame from ~1.6ms (hypothetical engine-only) to ~6.8ms. This means:

- **Without profiler:** A 3ms engine spike → frame at 4.6ms → 27% of budget → barely visible
- **With profiler:** Same 3ms engine spike → frame at 9.8ms → 59% of budget → clearly visible
- **Without profiler:** A 12ms engine spike → frame at 13.6ms → 81% of budget → visible
- **With profiler:** Same 12ms engine spike → frame at 17.2ms → 103% of budget → **OVER BUDGET (red zone)**

The profiler doesn't create the spikes, but its constant overhead pushes the same spikes from "comfortable" to "alarming" or from "within budget" to "over budget." This is the pure observer effect.

The profiler's drawing overhead could be reduced by:
1. Reducing drawStackedArea from 300 samples to fewer (e.g., 60 → 180 draw calls saved → ~0.8ms)
2. Batch-rendering stacked bars as larger rectangles where consecutive values are similar
3. Only rendering visible portion (if panel is partially off-screen)
4. Switching to TAB_MEMORY (403 calls) or TAB_WORLD (101 calls) when not actively analyzing mods
