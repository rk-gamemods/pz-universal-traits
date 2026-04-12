"""pz_log_query.py — Ingest PZ console.txt into SQLite and query it.

Usage:
    python pz_log_query.py ingest                  Ingest latest console.txt
    python pz_log_query.py search PATTERN           Search log lines (regex)
    python pz_log_query.py freeze                   Show all [FREEZE] diagnostic dumps
    python pz_log_query.py errors                   Show all ERROR/exception lines
    python pz_log_query.py utcore                   Show all UTCore-related lines
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
    for tag_name in ["FREEZE", "ERROR", "WARNING", "UTCORE"]:
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
    elif cmd == "stats":
        ingest()
        show_stats()
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
