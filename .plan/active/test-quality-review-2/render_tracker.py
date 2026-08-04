#!/usr/bin/env python3
"""Render TRACKER.md from the review state TSV."""
import sys
from collections import OrderedDict

STATE = "/var/folders/1t/n10rx4qj3dl47thlh4fgqd140000gn/T/opencode/tqr2/state.tsv"
OUT = ".plan/active/test-quality-review-2/TRACKER.md"

status_badge = {
    "pending": "pending",
    "reviewing": "reviewing",
    "keep": "keep",
    "cleanup": "cleaned",
    "deleted": "deleted",
    "speedup": "speedup",
    "sprint": "sprint",
}

rows = []
packages = OrderedDict()
with open(STATE) as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        status, note, path = parts[0], parts[1], parts[2]
        pkg = "/".join(path.split("/test/")[0].split("/")[-2:])
        rows.append((status, note, path))
        packages.setdefault(pkg, []).append((status, note, path))

def fmt(note):
    note = note.replace("|", "\\|")
    return note or "-"

with open(OUT, "w") as out:
    out.write("# Test Quality Review Round 2: Tracker\n\n")
    out.write("Review each test file one by one; mark status in the state file and regenerate.\n\n")
    total = len(rows)
    done = sum(1 for s, _, _ in rows if s != "pending")
    out.write(f"- Total files: {total}\n- Reviewed: {done} ({100 * done // total}%)\n\n")
    for pkg, items in packages.items():
        out.write(f"## `{pkg}` ({len(items)})\n\n")
        out.write("| # | status | file | note |\n|---|---|---|---|\n")
        for i, (status, note, path) in enumerate(items, 1):
            short = path.split("/test/")[1]
            out.write(f"| {i} | {status_badge.get(status, status)} | `{short}` | {fmt(note)} |\n")
        out.write("\n")
print("wrote", OUT, "files:", len(rows), "done:", done)
