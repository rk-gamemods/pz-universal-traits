"""pz_log_query.py — Ingest PZ console.txt into SQLite and query it.

Usage:
    python pz_log_query.py ingest                  Ingest latest console.txt
    python pz_log_query.py search PATTERN           Search log lines (regex)
    python pz_log_query.py freeze                   Show all [FREEZE] diagnostic dumps
    python pz_log_query.py errors                   Show all ERROR/exception lines
    python pz_log_query.py utcore                   Show all UTCore-related lines
    python pz_log_query.py profiler                 Full ModProfiler analysis (sessions, trends, spikes)
    python pz_log_query.py tail [N]                 Show last N lines (default 50)
    python pz_log_query.py around LINE_NUM [N]      Show N lines around a line number
    python pz_log_query.py stats                    Summary: line count, freeze count, errors
"""
import sqlite3
import sys
import re
import os
from pathlib import Path

ZOMBOID_DIR = Path(os.environ.get("ZOMBOID_DIR", r"C:\Users\Admin\Zomboid"))
CONSOLE_TXT = ZOMBOID_DIR / "console.txt"
DB_PATH = ZOMBOID_DIR / "console_log.db"


def get_db():
    db = sqlite3.connect(str(DB_PATH))
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("""
        CREATE TABLE IF NOT EXISTS log_lines (
            line_num INTEGER PRIMARY KEY,
            raw      TEXT NOT NULL,
            tag      TEXT,
            ts       TEXT
        )
    """)
    db.execute("CREATE INDEX IF NOT EXISTS idx_tag ON log_lines(tag)")
    db.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS log_fts
        USING fts5(raw, content=log_lines, content_rowid=line_num)
    """)
    return db


# Timestamp patterns PZ uses:  [05-04-26 11:35:53.825] or 1775403353825
TS_RE = re.compile(r"\[(\d{2}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)\]")

# Tag extraction: [FREEZE], LOG, ERROR, WARNING, UTCore, etc.
TAG_PATTERNS = [
    (re.compile(r"\[MODPROFILER\]"), "MODPROFILER"),
    (re.compile(r"\[FREEZE\]"), "FREEZE"),
    (re.compile(r"\bERROR\b", re.I), "ERROR"),
    (re.compile(r"\bEXCEPTION\b", re.I), "ERROR"),
    (re.compile(r"\bWARNING\b", re.I), "WARNING"),
    (re.compile(r"\bUTCore\b"), "UTCORE"),
    (re.compile(r"\bstack tracance\b|\bat\s+\w+\.\w+\(", re.I), "STACKTRACE"),
]


def classify_line(raw):
    for pat, tag in TAG_PATTERNS:
        if pat.search(raw):
            return tag
    return None


def ingest():
    if not CONSOLE_TXT.exists():
        print(f"ERROR: {CONSOLE_TXT} not found")
        sys.exit(1)

    db = get_db()

    # Check existing line count
    existing = db.execute("SELECT COUNT(*) FROM log_lines").fetchone()[0]

    with open(CONSOLE_TXT, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    total = len(lines)
    if existing == total:
        print(f"Already up-to-date ({total} lines)")
        return

    # Full re-ingest (console.txt is overwritten each PZ session)
    db.execute("DELETE FROM log_lines")
    db.execute("DELETE FROM log_fts")

    batch = []
    for i, raw in enumerate(lines, 1):
        raw = raw.rstrip("\n\r")
        tag = classify_line(raw)
        ts_match = TS_RE.search(raw)
        ts = ts_match.group(1) if ts_match else None
        batch.append((i, raw, tag, ts))

        if len(batch) >= 5000:
            db.executemany("INSERT INTO log_lines VALUES (?,?,?,?)", batch)
            db.executemany(
                "INSERT INTO log_fts(rowid, raw) VALUES (?,?)",
                [(b[0], b[1]) for b in batch]
            )
            batch.clear()

    if batch:
        db.executemany("INSERT INTO log_lines VALUES (?,?,?,?)", batch)
        db.executemany(
            "INSERT INTO log_fts(rowid, raw) VALUES (?,?)",
            [(b[0], b[1]) for b in batch]
        )

    db.commit()
    print(f"Ingested {total} lines from {CONSOLE_TXT}")
    print(f"Database: {DB_PATH}")

    # Quick stats
    for tag_name in ["FREEZE", "ERROR", "WARNING", "UTCORE"]:
        count = db.execute(
            "SELECT COUNT(*) FROM log_lines WHERE tag=?", (tag_name,)
        ).fetchone()[0]
        if count > 0:
            print(f"  {tag_name}: {count} lines")


def search(pattern):
    db = get_db()
    pat = re.compile(pattern, re.IGNORECASE)
    all_rows = db.execute("SELECT line_num, raw FROM log_lines").fetchall()
    rows = [(n, r) for n, r in all_rows if pat.search(r)]

    print(f"Found {len(rows)} matching lines:")
    for num, raw in rows:
        print(f"  L{num}: {raw}")


def search_fts(query):
    db = get_db()
    try:
        rows = db.execute(
            """SELECT l.line_num, l.raw
               FROM log_fts f
               JOIN log_lines l ON f.rowid = l.line_num
               WHERE log_fts MATCH ?
               ORDER BY l.line_num""",
            (query,)
        ).fetchall()
        print(f"Found {len(rows)} matching lines:")
        for num, raw in rows:
            print(f"  L{num}: {raw}")
    except sqlite3.OperationalError:
        # FTS might not be populated yet
        search(query)


def show_tag(tag, label=None):
    db = get_db()
    rows = db.execute(
        "SELECT line_num, raw FROM log_lines WHERE tag=? ORDER BY line_num",
        (tag,)
    ).fetchall()
    label = label or tag
    if not rows:
        print(f"No {label} lines found. Has the game been played since deploying the logger?")
        return
    print(f"{len(rows)} {label} lines:")
    for num, raw in rows:
        print(f"  L{num}: {raw}")


def show_freeze():
    """Show FREEZE blocks with surrounding context."""
    db = get_db()
    freeze_lines = db.execute(
        "SELECT line_num FROM log_lines WHERE tag='FREEZE' ORDER BY line_num"
    ).fetchall()

    if not freeze_lines:
        print("No [FREEZE] lines found.")
        print("The freeze logger hasn't fired yet. Play until a freeze occurs,")
        print(f"then run: python pz_log_query.py ingest && python pz_log_query.py freeze")
        return

    # Group consecutive freeze lines into blocks
    blocks = []
    current_block = []
    prev_num = None
    for (num,) in freeze_lines:
        if prev_num is not None and num - prev_num > 5:
            if current_block:
                blocks.append(current_block)
            current_block = []
        current_block.append(num)
        prev_num = num
    if current_block:
        blocks.append(current_block)

    print(f"Found {len(blocks)} freeze event(s), {len(freeze_lines)} total [FREEZE] lines:\n")

    for i, block in enumerate(blocks):
        start = max(1, block[0] - 3)
        end = block[-1] + 3
        rows = db.execute(
            "SELECT line_num, raw FROM log_lines WHERE line_num BETWEEN ? AND ? ORDER BY line_num",
            (start, end)
        ).fetchall()
        print(f"--- Freeze Event #{i+1} (lines {block[0]}-{block[-1]}) ---")
        for num, raw in rows:
            marker = ">>>" if num in block else "   "
            print(f"  {marker} L{num}: {raw}")
        print()


def show_tail(n):
    db = get_db()
    total = db.execute("SELECT MAX(line_num) FROM log_lines").fetchone()[0] or 0
    start = max(1, total - n + 1)
    rows = db.execute(
        "SELECT line_num, raw FROM log_lines WHERE line_num >= ? ORDER BY line_num",
        (start,)
    ).fetchall()
    for num, raw in rows:
        print(f"  L{num}: {raw}")


def show_around(target, context):
    db = get_db()
    start = max(1, target - context)
    end = target + context
    rows = db.execute(
        "SELECT line_num, raw FROM log_lines WHERE line_num BETWEEN ? AND ? ORDER BY line_num",
        (start, end)
    ).fetchall()
    for num, raw in rows:
        marker = ">>>" if num == target else "   "
        print(f"  {marker} L{num}: {raw}")


def show_stats():
    db = get_db()
    total = db.execute("SELECT COUNT(*) FROM log_lines").fetchone()[0]
    print(f"Total lines: {total}")
    for tag_name in ["FREEZE", "ERROR", "WARNING", "UTCORE", "MODPROFILER"]:
        count = db.execute(
            "SELECT COUNT(*) FROM log_lines WHERE tag=?", (tag_name,)
        ).fetchone()[0]
        print(f"  {tag_name}: {count}")

    # First/last timestamp
    first_ts = db.execute(
        "SELECT ts FROM log_lines WHERE ts IS NOT NULL ORDER BY line_num LIMIT 1"
    ).fetchone()
    last_ts = db.execute(
        "SELECT ts FROM log_lines WHERE ts IS NOT NULL ORDER BY line_num DESC LIMIT 1"
    ).fetchone()
    if first_ts:
        print(f"  First timestamp: {first_ts[0]}")
    if last_ts:
        print(f"  Last timestamp:  {last_ts[0]}")


def percentile(sorted_vals, p):
    """Return the p-th percentile from a pre-sorted list (0-100 scale)."""
    if not sorted_vals:
        return 0
    k = (len(sorted_vals) - 1) * p / 100
    f = int(k)
    c = f + 1 if f + 1 < len(sorted_vals) else f
    d = k - f
    return sorted_vals[f] + d * (sorted_vals[c] - sorted_vals[f])


def show_profiler():
    """Professional performance analytics report from ModProfiler data."""
    db = get_db()

    profiler_count = db.execute(
        "SELECT COUNT(*) FROM log_lines WHERE tag='MODPROFILER'"
    ).fetchone()[0]
    if profiler_count == 0:
        print("No [MODPROFILER] lines found. Is 00_ModProfiler enabled?")
        return

    rows = db.execute(
        "SELECT line_num, raw FROM log_lines WHERE tag='MODPROFILER' ORDER BY line_num"
    ).fetchall()

    # --- Regexes ---
    frame_re = re.compile(r"f:(\d+)")
    summary_re = re.compile(r"SESSION SUMMARY \((\d+) mods, (\d+) calls, (\d+)ms total\)")
    mod_re = re.compile(
        r"\s*(\d+)\.\s+(\S+)\s+([\d.]+)%\s+\|\s+tot=\s*(\d+)ms\s+avg=([\d.]+)ms\s+n=(\d+)"
        r"(?:\s+spikes=(\d+)\s+worst=(\d+)ms@(\S+))?"
        r"\s*\|\s*(.*)"
    )
    interval_re = re.compile(r"INTERVAL \((\d+) ticks, (\d+)ms total\)(?:\s*\[idx=(\d+)\])?")
    self_cost_re = re.compile(
        r"\[MODPROFILER\]\s+SELF\s+(\S+)\s+n=(\d+)\s+"
        r"p50=([\d.]+)ms\s+p95=([\d.]+)ms\s+p99=([\d.]+)ms\s+max=([\d.]+)ms"
        r"(?:\s+mean=([\d.]+)ms)?(?:\s+total=(\d+)ms)?(?:\s+calls=(\d+))?"
    )
    # Per-callback interval line:  Event | Mod | avg=X.XXXms pk=Xms n=N tot=Xms | source
    callback_re = re.compile(
        r"\[MODPROFILER\]\s*!?\s*(\S+)\s+\|\s+(\S+)\s+\|\s+avg=([\d.]+)ms\s+pk=(\d+)ms\s+n=(\d+)\s+tot=(\d+)ms\s+\|\s+(.*)"
    )
    spike_re = re.compile(r"SPIKE (\d+)ms \| (\S+) \| (\S+) \| (.+)")

    # =====================================================================
    # PARSE ALL DATA
    # =====================================================================

    # 1. Session summaries
    summaries = []
    current_summary = None
    for line_num, raw in rows:
        m = summary_re.search(raw)
        if m:
            fm = frame_re.search(raw)
            frame = int(fm.group(1)) if fm else 0
            current_summary = {
                "line": line_num, "frame": frame,
                "n_mods": int(m.group(1)), "n_calls": int(m.group(2)),
                "total_ms": int(m.group(3)), "mods": [],
            }
            summaries.append(current_summary)
            continue
        if current_summary and "END SESSION SUMMARY" in raw:
            current_summary = None
            continue
        if current_summary:
            mm = mod_re.search(raw)
            if mm:
                entry = {
                    "rank": int(mm.group(1)), "mod": mm.group(2),
                    "pct": float(mm.group(3)), "tot_ms": int(mm.group(4)),
                    "avg_ms": float(mm.group(5)), "calls": int(mm.group(6)),
                    "spikes": int(mm.group(7)) if mm.group(7) else 0,
                    "worst_ms": int(mm.group(8)) if mm.group(8) else 0,
                    "worst_event": mm.group(9) if mm.group(9) else "",
                    "events_str": mm.group(10).strip(),
                }
                current_summary["mods"].append(entry)

    # 2. Intervals
    intervals = []
    for line_num, raw in rows:
        m = interval_re.search(raw)
        if m:
            fm = frame_re.search(raw)
            frame = int(fm.group(1)) if fm else 0
            intervals.append({"frame": frame, "total_ms": int(m.group(2)), "callbacks": []})

    # 3. Per-callback interval data — attach to parent interval
    current_interval_idx = -1
    for line_num, raw in rows:
        if interval_re.search(raw):
            current_interval_idx += 1
            continue
        if current_interval_idx >= 0 and current_interval_idx < len(intervals):
            m = callback_re.search(raw)
            if m:
                intervals[current_interval_idx]["callbacks"].append({
                    "event": m.group(1), "mod": m.group(2),
                    "avg_ms": float(m.group(3)), "pk_ms": int(m.group(4)),
                    "n": int(m.group(5)), "tot_ms": int(m.group(6)),
                    "source": m.group(7).strip(),
                })

    # 4. Spikes
    spikes = []
    for line_num, raw in rows:
        m = spike_re.search(raw)
        if m:
            fm = frame_re.search(raw)
            frame = int(fm.group(1)) if fm else 0
            spikes.append({
                "frame": frame, "ms": int(m.group(1)),
                "event": m.group(2), "mod": m.group(3),
                "source": m.group(4).strip(),
            })

    # 4b. Self-cost lines (one block emitted per session summary)
    self_cost_by_summary = []   # list of dicts keyed by component name
    current_self_block = None
    for line_num, raw in rows:
        if "----- SELF-COST -----" in raw:
            current_self_block = {}
            self_cost_by_summary.append(current_self_block)
            continue
        if current_self_block is not None and "END SESSION SUMMARY" in raw:
            current_self_block = None
            continue
        if current_self_block is not None:
            m = self_cost_re.search(raw)
            if m:
                current_self_block[m.group(1)] = {
                    "n": int(m.group(2)),
                    "p50": float(m.group(3)),
                    "p95": float(m.group(4)),
                    "p99": float(m.group(5)),
                    "max": float(m.group(6)),
                    "mean": float(m.group(7)) if m.group(7) else None,
                    "total": int(m.group(8)) if m.group(8) else None,
                    "calls": int(m.group(9)) if m.group(9) else None,
                }

    # 5. Freeze events
    freeze_frames = []
    freeze_rows = db.execute(
        "SELECT raw FROM log_lines WHERE tag='FREEZE' AND raw LIKE '%DETECTED%'"
    ).fetchall()
    for (raw,) in freeze_rows:
        fm = frame_re.search(raw)
        if fm:
            freeze_frames.append(int(fm.group(1)))

    # =====================================================================
    # REPORT
    # =====================================================================
    W = 90
    def header(title):
        print(f"\n{'='*W}")
        print(f"  {title}")
        print(f"{'='*W}")
    def section(title):
        print(f"\n--- {title} ---")

    header(f"PERFORMANCE ANALYTICS REPORT — {profiler_count} profiler lines")

    if intervals:
        first_frame = intervals[0]["frame"]
        last_frame = intervals[-1]["frame"]
        frame_span = last_frame - first_frame
        print(f"  Session: frame {first_frame:,} → {last_frame:,} ({frame_span:,} frames, {len(intervals)} intervals)")
        if summaries:
            print(f"  Summaries: {len(summaries)} ({summaries[0]['frame']:,} → {summaries[-1]['frame']:,})")
        print(f"  Spikes: {len(spikes)} (≥3ms threshold)")
        print(f"  Freeze events: {len(freeze_frames)}")

    # =====================================================================
    # SECTION 1: INTERVAL DISTRIBUTION (the "1% lows" analysis)
    # =====================================================================
    if intervals:
        section("INTERVAL LATENCY DISTRIBUTION (what you FEEL)")
        ms_values = sorted([iv["total_ms"] for iv in intervals])
        n = len(ms_values)
        avg = sum(ms_values) / n
        median = percentile(ms_values, 50)
        p90 = percentile(ms_values, 90)
        p95 = percentile(ms_values, 95)
        p99 = percentile(ms_values, 99)
        worst_1pct_count = max(1, n // 100) or 1
        worst_1pct = ms_values[-worst_1pct_count:]
        worst_5pct_count = max(1, n * 5 // 100)
        worst_5pct = ms_values[-worst_5pct_count:]

        print(f"    Intervals: {n}")
        print(f"    Min:        {ms_values[0]}ms")
        print(f"    Median:     {median:.0f}ms")
        print(f"    Average:    {avg:.0f}ms")
        print(f"    P90:        {p90:.0f}ms        ← 10% of intervals worse than this")
        print(f"    P95:        {p95:.0f}ms        ← 5% of intervals worse than this")
        print(f"    P99:        {p99:.0f}ms        ← 1% of intervals worse than this")
        print(f"    Max:        {ms_values[-1]}ms")
        print(f"    Worst 1%:   {', '.join(str(v) for v in worst_1pct)}ms (avg {sum(worst_1pct)/len(worst_1pct):.0f}ms)")
        print(f"    Worst 5%:   avg {sum(worst_5pct)/len(worst_5pct):.0f}ms ({len(worst_5pct)} intervals)")

        # Histogram
        section("INTERVAL HISTOGRAM")
        buckets = [150, 200, 250, 300, 350, 400, 450, 500]
        prev = 0
        for b in buckets:
            count = sum(1 for v in ms_values if prev <= v < b)
            pct = count / n * 100
            bar = "█" * int(pct * 0.5)
            print(f"    {prev:>4}-{b:<4}ms  {count:>3} ({pct:>5.1f}%)  {bar}")
            prev = b
        overflow = sum(1 for v in ms_values if v >= buckets[-1])
        if overflow:
            pct = overflow / n * 100
            bar = "█" * int(pct * 0.5)
            print(f"    {buckets[-1]:>4}+    ms  {overflow:>3} ({pct:>5.1f}%)  {bar}")

    # =====================================================================
    # SECTION 2: TEMPORAL DEGRADATION (does it get worse over time?)
    # =====================================================================
    if intervals and len(intervals) >= 6:
        section("TEMPORAL DEGRADATION ANALYSIS")
        n = len(intervals)
        # Split into 5 equal windows
        window_size = max(1, n // 5)
        windows = []
        for i in range(5):
            start = i * window_size
            end = min(start + window_size, n)
            if start >= n:
                break
            window_ms = [intervals[j]["total_ms"] for j in range(start, end)]
            window_ms_sorted = sorted(window_ms)
            windows.append({
                "label": f"W{i+1}",
                "frame_start": intervals[start]["frame"],
                "frame_end": intervals[end - 1]["frame"],
                "avg": sum(window_ms) / len(window_ms),
                "median": percentile(window_ms_sorted, 50),
                "p95": percentile(window_ms_sorted, 95),
                "max": max(window_ms),
                "count": len(window_ms),
            })

        print(f"    Session split into {len(windows)} windows of ~{window_size} intervals each:\n")
        print(f"    {'Window':<8} {'Frames':<20} {'Avg':>6}  {'Median':>7}  {'P95':>6}  {'Max':>6}  {'Count':>5}")
        print(f"    {'-'*8} {'-'*20} {'-'*6}  {'-'*7}  {'-'*6}  {'-'*6}  {'-'*5}")
        for w in windows:
            print(f"    {w['label']:<8} {w['frame_start']}-{w['frame_end']:<8}  {w['avg']:>5.0f}   {w['median']:>6.0f}   {w['p95']:>5.0f}   {w['max']:>5}  {w['count']:>5}")

        # Trend detection
        first_w = windows[0]
        last_w = windows[-1]
        avg_change = ((last_w["avg"] - first_w["avg"]) / first_w["avg"] * 100) if first_w["avg"] else 0
        p95_change = ((last_w["p95"] - first_w["p95"]) / first_w["p95"] * 100) if first_w["p95"] else 0
        max_change = ((last_w["max"] - first_w["max"]) / first_w["max"] * 100) if first_w["max"] else 0

        print(f"\n    Trend W1→W{len(windows)}:")
        print(f"      Average:  {first_w['avg']:.0f}ms → {last_w['avg']:.0f}ms  ({avg_change:+.1f}%)")
        print(f"      P95:      {first_w['p95']:.0f}ms → {last_w['p95']:.0f}ms  ({p95_change:+.1f}%)")
        print(f"      Max:      {first_w['max']}ms → {last_w['max']}ms  ({max_change:+.1f}%)")

        if avg_change > 10 or p95_change > 15:
            print(f"      ** DEGRADATION DETECTED — performance worsens over time **")
        elif avg_change < -10:
            print(f"      ** IMPROVEMENT detected over session **")
        else:
            print(f"      Trend: stable")

    # =====================================================================
    # SECTION 3: SPIKE ANALYSIS (the stutters you FEEL)
    # =====================================================================
    if spikes:
        section(f"SPIKE ANALYSIS ({len(spikes)} spikes ≥3ms)")

        all_spike_ms = sorted([s["ms"] for s in spikes])
        print(f"    All spikes: min={all_spike_ms[0]}ms  median={percentile(all_spike_ms, 50):.0f}ms  "
              f"avg={sum(all_spike_ms)/len(all_spike_ms):.1f}ms  P95={percentile(all_spike_ms, 95):.0f}ms  "
              f"max={all_spike_ms[-1]}ms")

        # Per-mod spike table with tail stats
        section("SPIKE BREAKDOWN BY MOD")
        by_mod = {}
        for s in spikes:
            by_mod.setdefault(s["mod"], []).append(s)

        print(f"    {'Mod':<26} {'Count':>5}  {'Avg':>5}  {'P50':>4}  {'P95':>4}  {'Max':>4}  {'Total':>6}  Top Source")
        print(f"    {'-'*26} {'-'*5}  {'-'*5}  {'-'*4}  {'-'*4}  {'-'*4}  {'-'*6}  {'-'*40}")
        for mod_name, mod_spikes in sorted(by_mod.items(), key=lambda x: -sum(s["ms"] for s in x[1])):
            magnitudes = sorted([s["ms"] for s in mod_spikes])
            total = sum(magnitudes)
            avg_spike = total / len(magnitudes)
            med = percentile(magnitudes, 50)
            p95 = percentile(magnitudes, 95)
            # Top source
            sources = {}
            for s in mod_spikes:
                sources.setdefault(s["source"], []).append(s["ms"])
            top_src = max(sources.items(), key=lambda x: sum(x[1]))
            src_short = top_src[0].split("/")[-1] if "/" in top_src[0] else top_src[0]
            print(f"    {mod_name:<26} {len(mod_spikes):>5}  {avg_spike:>4.0f}ms {med:>3.0f}ms {p95:>3.0f}ms {magnitudes[-1]:>3}ms {total:>5}ms  {src_short} (×{len(top_src[1])})")

        # =====================================================================
        # SPIKE CLUSTERING — multiple spikes in same interval = compounding stutter
        # =====================================================================
        section("SPIKE CLUSTERING (compound stutters)")
        # Group spikes by which interval they fall in
        spike_by_interval = {}
        for s in spikes:
            # Find nearest interval
            best_frame = None
            for iv in intervals:
                if iv["frame"] >= s["frame"]:
                    best_frame = iv["frame"]
                    break
            if best_frame is None and intervals:
                best_frame = intervals[-1]["frame"]
            if best_frame is not None:
                spike_by_interval.setdefault(best_frame, []).append(s)

        multi_spike_intervals = {f: sl for f, sl in spike_by_interval.items() if len(sl) >= 2}
        total_compound = sum(len(sl) for sl in multi_spike_intervals.values())

        print(f"    Intervals with 2+ spikes: {len(multi_spike_intervals)} / {len(spike_by_interval)} spike-intervals")
        print(f"    Spikes in compound bursts: {total_compound} / {len(spikes)} ({total_compound/max(1,len(spikes))*100:.0f}%)")
        if multi_spike_intervals:
            print(f"\n    Worst compound intervals:")
            worst_compounds = sorted(multi_spike_intervals.items(),
                                     key=lambda x: -sum(s["ms"] for s in x[1]))[:10]
            for frame, sl in worst_compounds:
                combined_ms = sum(s["ms"] for s in sl)
                mods = ", ".join(f"{s['mod']}({s['ms']}ms)" for s in sorted(sl, key=lambda x: -x["ms"]))
                print(f"      frame={frame}  {len(sl)} spikes  combined={combined_ms}ms  [{mods}]")

        # =====================================================================
        # SPIKE FREQUENCY OVER TIME — does stutter rate accelerate?
        # =====================================================================
        if len(spikes) >= 5 and intervals:
            section("SPIKE FREQUENCY ACCELERATION")
            first_frame = intervals[0]["frame"]
            last_frame = intervals[-1]["frame"]
            session_span = last_frame - first_frame

            # Split session into 5 equal time windows
            n_windows = 5
            window_frames = session_span / n_windows
            for i in range(n_windows):
                w_start = first_frame + i * window_frames
                w_end = first_frame + (i + 1) * window_frames
                w_spikes = [s for s in spikes if w_start <= s["frame"] < w_end]
                w_spike_ms = [s["ms"] for s in w_spikes] if w_spikes else [0]
                w_total_ms = sum(w_spike_ms)
                w_max = max(w_spike_ms)
                w_count = len(w_spikes)
                rate = w_count / (window_frames / 300) if window_frames > 0 else 0  # per interval
                bar = "▓" * w_count if w_count < 40 else "▓" * 40 + f"..+{w_count-40}"
                p95_val = percentile(sorted(w_spike_ms), 95) if w_spikes else 0
                print(f"    W{i+1} f:{int(w_start)}-{int(w_end)}  "
                      f"{w_count:>3} spikes  rate={rate:.1f}/intv  "
                      f"sum={w_total_ms:>4}ms  max={w_max:>3}ms  P95={p95_val:.0f}ms  "
                      f"{bar}")

            # Formal acceleration metric
            first_half = [s for s in spikes if s["frame"] < first_frame + session_span / 2]
            second_half = [s for s in spikes if s["frame"] >= first_frame + session_span / 2]
            first_rate = len(first_half) / (session_span / 2) * 1000 if session_span > 0 else 0
            second_rate = len(second_half) / (session_span / 2) * 1000 if session_span > 0 else 0
            accel = ((second_rate - first_rate) / first_rate * 100) if first_rate > 0 else 0
            print(f"\n    First half:  {len(first_half)} spikes ({first_rate:.1f}/1000f)")
            print(f"    Second half: {len(second_half)} spikes ({second_rate:.1f}/1000f)")
            if abs(accel) > 10:
                print(f"    ** Spike rate change: {accel:+.0f}% {'ACCELERATING' if accel > 0 else 'DECELERATING'} **")
            else:
                print(f"    Spike rate stable ({accel:+.0f}%)")

    # =====================================================================
    # SECTION 4: PER-CALLBACK PEAK ANALYSIS (who causes the worst frames?)
    # =====================================================================
    if intervals and intervals[0].get("callbacks"):
        section("PER-CALLBACK PEAK LATENCY (pk_ms) — who ruins your worst frames")

        # Collect all peak values per callback identity
        callback_peaks = {}  # (mod, source_short) -> list of pk_ms across intervals
        for iv in intervals:
            for cb in iv["callbacks"]:
                key = (cb["mod"], cb["source"].split("/")[-1] if "/" in cb["source"] else cb["source"])
                callback_peaks.setdefault(key, []).append(cb["pk_ms"])

        # Rank by P95 of peak values (what's the peak in your worst 5% of intervals?)
        ranked = []
        for (mod, src), peaks in callback_peaks.items():
            sorted_peaks = sorted(peaks)
            ranked.append({
                "mod": mod, "src": src,
                "avg_pk": sum(peaks) / len(peaks),
                "p50_pk": percentile(sorted_peaks, 50),
                "p95_pk": percentile(sorted_peaks, 95),
                "p99_pk": percentile(sorted_peaks, 99),
                "max_pk": sorted_peaks[-1],
                "intervals": len(peaks),
            })

        ranked.sort(key=lambda x: -x["p95_pk"])
        print(f"\n    {'Mod':<20} {'Source':<36} {'AvgPk':>6} {'P50':>5} {'P95':>5} {'P99':>5} {'Max':>5} {'#Intv':>5}")
        print(f"    {'-'*20} {'-'*36} {'-'*6} {'-'*5} {'-'*5} {'-'*5} {'-'*5} {'-'*5}")
        for r in ranked[:20]:
            flag = " !!!" if r["p95_pk"] >= 10 else (" !" if r["p95_pk"] >= 5 else "")
            print(f"    {r['mod']:<20} {r['src']:<36} {r['avg_pk']:>5.1f}ms {r['p50_pk']:>4.0f}ms {r['p95_pk']:>4.0f}ms {r['p99_pk']:>4.0f}ms {r['max_pk']:>4}ms {r['intervals']:>5}{flag}")

        # Per-callback temporal trend for top offenders
        section("TOP OFFENDER TEMPORAL TREND (peak ms over time)")
        top_offenders = ranked[:5]
        for off in top_offenders:
            key = (off["mod"], off["src"])
            peaks = callback_peaks[key]
            n_int = len(peaks)
            if n_int < 4:
                continue
            q = max(1, n_int // 4)
            q1 = peaks[:q]
            q4 = peaks[-q:]
            q1_avg = sum(q1) / len(q1)
            q4_avg = sum(q4) / len(q4)
            q1_max = max(q1)
            q4_max = max(q4)
            change = ((q4_avg - q1_avg) / q1_avg * 100) if q1_avg > 0 else 0
            arrow = "↑" if change > 15 else ("↓" if change < -15 else "=")
            print(f"    {off['mod']:<20} {off['src']:<36}  Q1avg={q1_avg:.1f}ms Q4avg={q4_avg:.1f}ms ({arrow}{abs(change):.0f}%)  Q1max={q1_max}ms Q4max={q4_max}ms")

    # =====================================================================
    # SECTION 4b: PER-MOD INTERVAL PERCENTILES
    # Aggregates per-interval tot_ms per mod from the parsed callback data,
    # then shows the full distribution (p25/p50/p95/p99/max/mean) per mod.
    # This is the "who spikes badly vs who is consistently heavy" view.
    # =====================================================================
    if intervals and intervals[0].get("callbacks"):
        section("PER-MOD INTERVAL PERCENTILES")

        # Build {mod: [tot_ms per interval]}
        mod_per_interval = {}
        for iv in intervals:
            iv_totals = {}
            for cb in iv["callbacks"]:
                iv_totals[cb["mod"]] = iv_totals.get(cb["mod"], 0) + cb["tot_ms"]
            for mod, tot in iv_totals.items():
                mod_per_interval.setdefault(mod, []).append(tot)

        # Rank by p95 (the metric that matters for perceived performance)
        rows_stats = []
        for mod, tots in mod_per_interval.items():
            if len(tots) < 5:
                continue  # not enough samples for percentile to be meaningful
            sorted_tots = sorted(tots)
            rows_stats.append({
                "mod": mod,
                "n": len(tots),
                "p25": percentile(sorted_tots, 25),
                "p50": percentile(sorted_tots, 50),
                "p95": percentile(sorted_tots, 95),
                "p99": percentile(sorted_tots, 99),
                "max": sorted_tots[-1],
                "mean": sum(tots) / len(tots),
            })
        rows_stats.sort(key=lambda r: -r["p95"])

        print(f"    {'Mod':<26} {'#Intv':>5}  {'P25':>6}  {'P50':>6}  {'P95':>6}  {'P99':>6}  {'Max':>7}  {'Mean':>6}")
        print(f"    {'-'*26} {'-'*5}  {'-'*6}  {'-'*6}  {'-'*6}  {'-'*6}  {'-'*7}  {'-'*6}")
        for r in rows_stats[:20]:
            flag = ""
            if r["p95"] >= 50:
                flag = " !!"
            elif r["p95"] >= 20:
                flag = " !"
            print(f"    {r['mod']:<26} {r['n']:>5}  {r['p25']:>5.0f}ms {r['p50']:>5.0f}ms {r['p95']:>5.0f}ms {r['p99']:>5.0f}ms {r['max']:>6.0f}ms {r['mean']:>5.0f}ms{flag}")
        if len(rows_stats) > 20:
            print(f"    ... +{len(rows_stats) - 20} more mods (ranked by P95)")

    # =====================================================================
    # SECTION 4c: PER-CALLBACK AVG_MS PERCENTILES
    # Same idea but for per-callback avg timing, answering "which specific
    # handler is consistently expensive" rather than "which spikes".
    # =====================================================================
    if intervals and intervals[0].get("callbacks"):
        section("PER-CALLBACK AVG_MS PERCENTILES")

        cb_avg_samples = {}  # (mod, source_short) -> [avg_ms per interval]
        for iv in intervals:
            for cb in iv["callbacks"]:
                src = cb["source"].split("/")[-1] if "/" in cb["source"] else cb["source"]
                cb_avg_samples.setdefault((cb["mod"], src), []).append(cb["avg_ms"])

        ranked = []
        for (mod, src), avgs in cb_avg_samples.items():
            if len(avgs) < 5:
                continue
            s = sorted(avgs)
            ranked.append({
                "mod": mod, "src": src, "n": len(avgs),
                "p25": percentile(s, 25), "p50": percentile(s, 50),
                "p95": percentile(s, 95), "p99": percentile(s, 99),
                "max": s[-1], "mean": sum(avgs) / len(avgs),
            })
        ranked.sort(key=lambda r: -r["p95"])

        print(f"    {'Mod':<20} {'Source':<32} {'#Intv':>5}  {'P25':>6}  {'P50':>6}  {'P95':>6}  {'P99':>6}  {'Max':>6}")
        print(f"    {'-'*20} {'-'*32} {'-'*5}  {'-'*6}  {'-'*6}  {'-'*6}  {'-'*6}  {'-'*6}")
        for r in ranked[:15]:
            print(f"    {r['mod']:<20} {r['src']:<32} {r['n']:>5}  {r['p25']:>4.2f}ms {r['p50']:>4.2f}ms {r['p95']:>4.2f}ms {r['p99']:>4.2f}ms {r['max']:>4.1f}ms")

    # =====================================================================
    # SECTION 5: FREEZE ANALYSIS
    # =====================================================================
    if freeze_frames:
        section(f"FREEZE EVENT ANALYSIS ({len(freeze_frames)} events)")

        # Inter-freeze gaps
        gaps = [freeze_frames[i+1] - freeze_frames[i] for i in range(len(freeze_frames) - 1)]
        if gaps:
            sorted_gaps = sorted(gaps)
            print(f"    Inter-freeze gap: min={sorted_gaps[0]}f  median={percentile(sorted_gaps, 50):.0f}f  "
                  f"avg={sum(gaps)/len(gaps):.0f}f  max={sorted_gaps[-1]}f")

        # Freeze frequency over time windows
        if len(freeze_frames) >= 3 and intervals:
            first_frame = intervals[0]["frame"]
            last_frame = intervals[-1]["frame"]
            session_span = last_frame - first_frame
            n_windows = 5
            window_frames = session_span / n_windows

            print(f"\n    Freeze frequency by time window:")
            for i in range(n_windows):
                w_start = first_frame + i * window_frames
                w_end = first_frame + (i + 1) * window_frames
                w_freezes = [f for f in freeze_frames if w_start <= f < w_end]
                bar = "█" * len(w_freezes)
                print(f"      W{i+1} f:{int(w_start)}-{int(w_end)}  {len(w_freezes):>2} freezes  {bar}")

            first_half_f = [f for f in freeze_frames if f < first_frame + session_span / 2]
            second_half_f = [f for f in freeze_frames if f >= first_frame + session_span / 2]
            print(f"\n    First half: {len(first_half_f)} freezes")
            print(f"    Second half: {len(second_half_f)} freezes")
            if len(second_half_f) > len(first_half_f) * 1.3:
                print(f"    ** FREEZE RATE INCREASING OVER TIME **")
            elif len(second_half_f) < len(first_half_f) * 0.7:
                print(f"    ** Freeze rate decreasing **")
            else:
                print(f"    Freeze rate: stable")

        # Freeze-spike co-occurrence
        if spikes and freeze_frames:
            section("FREEZE ↔ SPIKE CO-OCCURRENCE")
            nearby_radius = 300  # frames: 1 interval
            co_occur = 0
            for ff in freeze_frames:
                nearby_spikes = [s for s in spikes if abs(s["frame"] - ff) <= nearby_radius]
                if nearby_spikes:
                    co_occur += 1
            print(f"    Freezes with a spike within ±{nearby_radius} frames: {co_occur}/{len(freeze_frames)} ({co_occur/len(freeze_frames)*100:.0f}%)")

            # What mods spike near freezes?
            near_freeze_mods = {}
            for ff in freeze_frames:
                for s in spikes:
                    if abs(s["frame"] - ff) <= nearby_radius:
                        near_freeze_mods.setdefault(s["mod"], []).append(s["ms"])
            if near_freeze_mods:
                print(f"    Mods spiking near freezes:")
                for mod, ms_list in sorted(near_freeze_mods.items(), key=lambda x: -sum(x[1])):
                    print(f"      {mod:<26} {len(ms_list)} spikes  total={sum(ms_list)}ms  max={max(ms_list)}ms")

    # =====================================================================
    # SECTION 6: SESSION SUMMARY COMPARISON
    # =====================================================================
    if summaries:
        section(f"SESSION SUMMARY COMPARISON ({len(summaries)} summaries)")

        if len(summaries) >= 2:
            # Show condensed first and last
            for label, s in [("FIRST", summaries[0]), ("LAST", summaries[-1])]:
                print(f"\n    {label} (frame={s['frame']}, {s['total_ms']:,}ms total, {s['n_calls']:,} calls):")
                for m in s["mods"][:10]:
                    spike_str = f"spk={m['spikes']}" if m["spikes"] > 0 else ""
                    worst_str = f"worst={m['worst_ms']}ms" if m["worst_ms"] > 0 else ""
                    print(f"      {m['rank']:<3} {m['mod']:<26} {m['pct']:>5.1f}%  {m['tot_ms']:>8,}ms  {spike_str:<10} {worst_str}")

            # Delta between first and last for key mods
            section("SESSION DELTA (first → last summary)")
            last_mods = {m["mod"]: m for m in summaries[-1]["mods"]}
            first_mods = {m["mod"]: m for m in summaries[0]["mods"]}

            frame_span = summaries[-1]["frame"] - summaries[0]["frame"]
            print(f"    Frame span: {frame_span:,} frames between first and last summary\n")
            print(f"    {'Mod':<26} {'Δms':>8}  {'Δspikes':>8}  {'ms/1000f':>10}  {'spikes/1000f':>12}")
            print(f"    {'-'*26} {'-'*8}  {'-'*8}  {'-'*10}  {'-'*12}")
            deltas = []
            for mod_name, last_m in last_mods.items():
                first_m = first_mods.get(mod_name)
                if first_m:
                    d_ms = last_m["tot_ms"] - first_m["tot_ms"]
                    d_spk = last_m["spikes"] - first_m["spikes"]
                    ms_per_1kf = d_ms / frame_span * 1000 if frame_span > 0 else 0
                    spk_per_1kf = d_spk / frame_span * 1000 if frame_span > 0 else 0
                    deltas.append((mod_name, d_ms, d_spk, ms_per_1kf, spk_per_1kf))
            deltas.sort(key=lambda x: -x[1])
            for mod_name, d_ms, d_spk, ms_rate, spk_rate in deltas[:15]:
                print(f"    {mod_name:<26} {d_ms:>+7,}  {d_spk:>+8}  {ms_rate:>9.1f}  {spk_rate:>11.1f}")
        else:
            # Single summary
            s = summaries[0]
            print(f"\n    Single summary (frame={s['frame']}, {s['total_ms']:,}ms total):")
            for m in s["mods"]:
                spike_str = f"spk={m['spikes']}" if m["spikes"] > 0 else ""
                print(f"      {m['rank']:<3} {m['mod']:<26} {m['pct']:>5.1f}%  {m['tot_ms']:>8,}ms  {spike_str}")

    # =====================================================================
    # SECTION 6b: PROFILER SELF-COST
    # Breaks out the profiler engine's own cost (wrapper overhead, dump I/O,
    # summary I/O, spike-log I/O) so the user can distinguish profiler overhead
    # from user-mod overhead. Only present if the Lua side emitted SELF lines.
    # =====================================================================
    if self_cost_by_summary:
        # Use the most recent self-cost block
        sc = self_cost_by_summary[-1]
        section("PROFILER SELF-COST")

        print(f"    {'Component':<22} {'#Samp':>5}  {'P50':>9}  {'P95':>9}  {'P99':>9}  {'Max':>9}  {'Total/Calls':>12}")
        print(f"    {'-'*22} {'-'*5}  {'-'*9}  {'-'*9}  {'-'*9}  {'-'*9}  {'-'*12}")

        # Wrapper: p50/p95/p99 are per-call ms; total = p50 × calls
        if "wrapper_per_call" in sc:
            w = sc["wrapper_per_call"]
            calls = w["calls"] or 0
            est_total = w["p50"] * calls if calls else 0
            print(f"    {'wrapper':<22} {w['n']:>5}  "
                  f"{w['p50']:>7.4f}ms  {w['p95']:>7.4f}ms  {w['p99']:>7.4f}ms  {w['max']:>7.4f}ms  "
                  f"~{est_total:>8.0f}ms")

        for label, key in [("interval dumps", "interval_dumps"),
                           ("summary dumps",  "summary_dumps"),
                           ("spike logs",     "spike_logs")]:
            if key in sc:
                d = sc[key]
                total = d["total"] if d["total"] is not None else 0
                print(f"    {label:<22} {d['n']:>5}  "
                      f"{d['p50']:>7.0f}ms  {d['p95']:>7.0f}ms  {d['p99']:>7.0f}ms  {d['max']:>7.0f}ms  "
                      f"{total:>9}ms")

        # Estimated total self-cost
        est_total = 0
        if "wrapper_per_call" in sc and sc["wrapper_per_call"]["calls"]:
            est_total += sc["wrapper_per_call"]["p50"] * sc["wrapper_per_call"]["calls"]
        for key in ("interval_dumps", "summary_dumps", "spike_logs"):
            if key in sc and sc[key]["total"] is not None:
                est_total += sc[key]["total"]
        if est_total > 0:
            if intervals:
                frame_span = intervals[-1]["frame"] - intervals[0]["frame"]
                if frame_span > 0:
                    per_1kf = est_total / frame_span * 1000
                    print(f"\n    Estimated total self-cost: ~{est_total:.0f}ms over {frame_span:,} frames = {per_1kf:.1f} ms/1000f")
                else:
                    print(f"\n    Estimated total self-cost: ~{est_total:.0f}ms")
            else:
                print(f"\n    Estimated total self-cost: ~{est_total:.0f}ms")

    # =====================================================================
    # SECTION 7: KEY INSIGHTS (auto-generated)
    # =====================================================================
    section("KEY INSIGHTS")
    insights = []

    # Degradation
    if intervals and len(intervals) >= 6:
        ms_values = [iv["total_ms"] for iv in intervals]
        n = len(ms_values)
        third = max(1, n // 3)
        early = ms_values[:third]
        late = ms_values[-third:]
        early_avg = sum(early) / len(early)
        late_avg = sum(late) / len(late)
        deg = ((late_avg - early_avg) / early_avg * 100) if early_avg > 0 else 0
        if deg > 10:
            insights.append(f"DEGRADATION: Interval cost grew {deg:+.0f}% from early to late ({early_avg:.0f}ms → {late_avg:.0f}ms avg)")

    # Spike acceleration
    if spikes and intervals and len(spikes) >= 5:
        first_frame = intervals[0]["frame"]
        last_frame = intervals[-1]["frame"]
        session_span = last_frame - first_frame
        if session_span > 0:
            first_half = [s for s in spikes if s["frame"] < first_frame + session_span / 2]
            second_half = [s for s in spikes if s["frame"] >= first_frame + session_span / 2]
            first_rate = len(first_half) / (session_span / 2) * 1000
            second_rate = len(second_half) / (session_span / 2) * 1000
            if second_rate > first_rate * 1.15:
                insights.append(f"SPIKE ACCELERATION: spike rate grew from {first_rate:.1f}/1kf → {second_rate:.1f}/1kf")

    # Freeze acceleration
    if freeze_frames and len(freeze_frames) >= 4 and intervals:
        first_frame = intervals[0]["frame"]
        last_frame = intervals[-1]["frame"]
        session_span = last_frame - first_frame
        if session_span > 0:
            first_half_f = [f for f in freeze_frames if f < first_frame + session_span / 2]
            second_half_f = [f for f in freeze_frames if f >= first_frame + session_span / 2]
            if len(second_half_f) > len(first_half_f) * 1.3:
                insights.append(f"FREEZE ACCELERATION: {len(first_half_f)} → {len(second_half_f)} freezes (first→second half)")

    # Top spike source
    if spikes:
        by_mod_total = {}
        for s in spikes:
            by_mod_total[s["mod"]] = by_mod_total.get(s["mod"], 0) + s["ms"]
        top_spike_mod = max(by_mod_total.items(), key=lambda x: x[1])
        insights.append(f"TOP SPIKE SOURCE: {top_spike_mod[0]} ({by_mod_total[top_spike_mod[0]]}ms total spike time)")

    # Compound spikes
    if spikes and intervals:
        spike_by_interval = {}
        for s in spikes:
            best = None
            for iv in intervals:
                if iv["frame"] >= s["frame"]:
                    best = iv["frame"]
                    break
            if best:
                spike_by_interval.setdefault(best, []).append(s)
        multi = {f: sl for f, sl in spike_by_interval.items() if len(sl) >= 2}
        if multi:
            worst_compound = max(multi.values(), key=lambda sl: sum(s["ms"] for s in sl))
            compound_total = sum(s["ms"] for s in worst_compound)
            insights.append(f"WORST COMPOUND STUTTER: {len(worst_compound)} spikes in one interval totaling {compound_total}ms")

    if not insights:
        insights.append("No major issues detected in this session.")

    for i, insight in enumerate(insights, 1):
        print(f"    {i}. {insight}")

    print(f"\n{'='*W}")
    print("END PERFORMANCE ANALYTICS REPORT")
    print(f"{'='*W}\n")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)

    cmd = sys.argv[1].lower()

    if cmd == "ingest":
        ingest()
    elif cmd == "search" and len(sys.argv) >= 3:
        ingest()  # auto-refresh
        search(sys.argv[2])
    elif cmd == "fts" and len(sys.argv) >= 3:
        ingest()
        search_fts(sys.argv[2])
    elif cmd == "freeze":
        ingest()  # auto-refresh
        show_freeze()
    elif cmd == "errors":
        ingest()
        show_tag("ERROR", "error/exception")
    elif cmd == "utcore":
        ingest()
        show_tag("UTCORE", "UTCore")
    elif cmd == "tail":
        ingest()
        n = int(sys.argv[2]) if len(sys.argv) >= 3 else 50
        show_tail(n)
    elif cmd == "around":
        ingest()
        target = int(sys.argv[2])
        ctx = int(sys.argv[3]) if len(sys.argv) >= 4 else 10
        show_around(target, ctx)
    elif cmd == "profiler":
        ingest()
        show_profiler()
    elif cmd == "stats":
        ingest()
        show_stats()
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
