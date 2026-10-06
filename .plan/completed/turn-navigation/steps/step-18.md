# Step 18 — Record The L3 Matrix And Retire The Plan

Branch `turn-navigation/retire`, published as PR 20/20. Documentation only.

## Scope

- Records every cell of the L3 matrix in
  [PLAN](../PLAN.md#regression-coverage) as it stands on `main` at
  `3f76e3ffc50dfb4e4d6cec64158d3fb26d61a7bb`, after every implementation PR
  merged (steps 2–16.b, last #1844) and step 17 reconciled the documents
  (#1847). A cell that was not executed is recorded as unexecuted, never as
  passed.
- Moves the plan to `.plan/completed/turn-navigation/` and points the
  regression document's source at the new path.
- No code, generated file, localization, analytics, wire or database change.

## L3 Matrix

| Cell | Result |
|---|---|
| Pinch in on real hardware (step 13's device check) | Passed: the user confirmed it on 2026-10-06 |
| iOS phone, the rest of the real-device list | Unexecuted |
| Pinch out on the Prompts screen, real device | Unexecuted; no device recording |
| macOS desktop | Unexecuted |
| Android phone smoke | Unexecuted |
| Windows and Linux smoke | Unexecuted; CI builds only |
| Bridge plus client, live | Unexecuted |
| Plugins, live plugin plus client | Unexecuted |

## What Covers The Unexecuted Cells Today

Automated only, from each step's own evidence and the CI that gated each
merged PR. Nothing below was rerun for this step.

- **iOS, macOS and Android gestures.** The pinch in (step 13) and the pinch
  out with every way out reversing the transition (step 16.b) are widget tests
  on the iOS, Android and macOS variants, including one-finger scroll, the
  peek, a nested horizontal scroll and the search field's selection. The iOS
  edge swipe and reduced motion are widget tests (step 12). Steps 11, 12 and
  16.b had no device servers; their PR media are fixture renders.
- **The Prompts screen.** Row shapes, order, day headers, the undated group,
  the opening anchor and its tint, tap-to-return to an unbuilt row and the
  transcript's unchanged offset are widget tests (step 11); search, the match
  count and "Load earlier prompts" keeping rows still are widget tests
  (step 16).
- **The pinned message.** Widget tests (step 8 and the standalone #1793 and
  #1842). Step 8's real-iPhone scroll check for visible lag was never run.
- **Bridge plus client.** The count on first, middle, last, unlimited and
  empty pages, the archived path and automation exclusion are DAO, repository
  and handler tests against real Drift; the no-field case against an older
  bridge is a client test (step 15). No live headless-bridge run.
- **Plugins.** Claude parser and mapper parity across a re-import (step 3) and
  the ACP prompt stamp (step 15) are plugin tests against fakes. No live
  plugin run, including the busy-send check `session-turns.md` shares.
- **Analytics.** `transcript_prompts_opened` with both entry values is a cubit
  test (steps 11 and 13); arrival in analytics was not checked.

## Acceptance

**Pending.** [README](../../../../docs/regression/README.md) and the plan's
matrix require the user's explicit acceptance, recorded in `PLAN.md`, of every
unexecuted cell above before the plan retires. This step does not claim that
acceptance. Until the user gives it in this PR, or asks for the cells to run
first, the PR must not merge.

## Handed Off, Not Decided Here

- **Pagination gaps.** The Prompts screen lists only the prompts the
  transcript has loaded, and the pinned prompt does not show while its opener
  is not loaded. A bridge prompt index that would close both is under the
  user's review as a separate future design; the plan's later phases F1 and F2
  are related intent. This plan takes no decision on it.
- **"Load earlier prompts" follow-up.** Disabling the control while the list
  refreshes and the wrapped-label sliver, promised in #1832's threads, ship as
  a standalone PR from `turn-navigation/load-earlier-follow-up`, outside this
  series.

## Regression Documents

`transcript-turn-navigation.md` records this run under "Release checks (L3)"
and its source path moves to `.plan/completed/`. Nothing else changed; step 17
reconciled the documents with the merged series.

## Evidence

- Every relative link touched here resolves from the moved files.
- No Dart or Flutter suite was run: the change is documentation only.
