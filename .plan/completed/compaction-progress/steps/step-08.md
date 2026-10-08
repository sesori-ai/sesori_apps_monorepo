# Step 8 — Reconcile The Docs With Shipped Compaction Progress

Branch `compaction-progress/step-8-docs`, from `origin/main` at `f4700fdc71`
(step 5 merged). Docs and plan only. There is no user-visible, wire or
database change.

## Method

Each compaction claim in the four documents was checked against the code on
`main`, not against the plan:

- `ChatHistoryService` (`_endUnfinishedPart`, `_sweepUnlessTurnRunning`,
  `_storedOnlyPage`);
- `ClaudeEventDispatcher._mapStatus`, `_mapCompactBoundary` and `_mapUser`;
- `PiHistoryMapper` (live and history compaction rows).

Steps 6a–7 had already written most of the lines. Step 5 merged last, onto
their text, so the reconciliation is mostly Claude gaps and stale wording.

## Changes

- **`docs/HARNESS_CAPABILITIES.md`:**
  - the Claude row says a failure writes no *dedicated compaction* record
    (step 5's probe found the caveat, command and stdout records), and that
    Stop or a process exit leaves the running row to the sweep;
  - the footnote names apps at v1.9.0 or older, which ignore the compaction
    state. The old "summary field" wording described a field that no public
    release carried.
- **`docs/regression/tools-and-file-changes.md`:**
  - Claude joins the live-row list (from its first `compacting` status), the
    bridge-stamped timer and the unfinished-compaction sweep;
  - the old-app limitation names Claude and says what the running `compact`
    card loss replaces, instead of a tombstone about older bridges;
  - the failure signal says "a `compact` tool card beside the row" instead of
    the removed running tool.
- **`docs/regression/session-turns.md`:** the Claude line records Stop or a
  process exit mid-compaction ending through the idle sweep.
- **`docs/regression/session-history-and-recovery.md`:**
  - the read sweep skips busy *and* retrying sessions and every stored-only
    read, as `_sweepUnlessTurnRunning` and `_storedOnlyPage` do;
  - Pi's live/replay parity names the settled compaction row, with the
    trigger on the live row only.

## Capability Table Shape

Kept the two-column table (Compaction row, Summary) that steps 6a–7 wrote and
step 5 extended. The plan's four-column split (Live row, Failure note,
Details, Summary) was not applied. Each harness's row reads as one sentence
per fact, and most facts qualify one another (a failure that is not
persisted, a trigger shown only live). Splitting them would rewrite every
row for no reader gain. The plan and the tracker record this.

## Plan Bookkeeping

- `steps/step-05.md`: #1911's two review waves, the main merge, the declined
  message-list finding, the merge commit and the measured size.
- `steps/step-07.md`: #1908's five review waves, the main merge, the two
  declines (the same-millisecond Pi stamp and the wave-5 queued-turn case),
  the merge commit, the outage wording and the measured size.
- `TRACKER.md`: R1 and the table shape under decisions, the guardrail's real
  exceptions (Pi's failure note, Claude's one re-key), and this step's branch.
- `PLAN.md`: the table-shape outcome under Regression Coverage.

## Evidence

- No Dart or Flutter checks: docs and plan only.
- Every touched prose line stays within 120 characters; capability table
  rows stay one line each, as before.
- No Markdown link or anchor was added or changed, and the docs' section
  headings are untouched.

## Size

About 190 changed lines against `origin/main`: about 40 in the four
documents and the rest plan bookkeeping, this file included.
