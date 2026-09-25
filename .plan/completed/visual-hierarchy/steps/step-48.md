# Step 48 — Reconcile regression docs

Branch `visual-hierarchy/regression-docs`. Docs only.

## Audit

Each merged PR of steps 40–47 and 50 was checked against `docs/regression/`.
Steps 42, 43, 45.a, 45.b, 46, 47 and 50 updated their own documents
(`tools-and-file-changes.md`, `desktop-cockpit-shell.md`,
`quota-auto-continuation.md`, `permission-auto-approval.md`). The gaps filled
here:

- `projects-and-sessions.md` — the touch up button draws at 40 px and keeps
  a 44 × 44 "Parent folder" target (40), with its L2 coverage; session rows
  show "Resumes <time>" in place of the time while scheduled (50).
- `desktop-cockpit-shell.md` — the recovery card's centred icon and xs Retry
  and Open logs buttons (41); sidebar rows show the resume time (50).
- `design-catalog.md` — the new `xs` solid-button size (41).
- `permission-auto-approval.md` — the Settings row shares the chip's YOLO
  shield icon (44).
- `session-creation-and-options.md` — the fast-mode bolt is yellow while on
  (follow-up to 44).
- `native-activity-indicators.md` — the sparkle also leads transcript live and
  "Working…" rows and a running session's desktop title (42).

Step 39 was dropped, so `glass-presentation.md` needs no backdrop entry.

## Verification

Docs only; no Dart suites run.
