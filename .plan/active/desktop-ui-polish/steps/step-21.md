# Step 21 — Reconcile regression documents

## Scope

- Every step from 2 to 20 rewrote the regression lines it invalidated in its
  own PR, so this sweep compares the eight documents the plan names against the
  merged code and step 15, and fixes only what still disagrees.
- `desktop-cockpit-shell.md` and `projects-and-sessions.md`: the session
  page's menu, on both shells, also offers "Archive, keep worktree" when the
  session has a worktree, because the shared dispatcher adds it for every
  caller.
- `session-archiving-and-deletion.md`: "new-task" becomes "new-session" (D5);
  the single-alert-slot limit of the Undo offer applies to both shells since
  step 18, not only the desktop; the coverage list names the shared
  `pending_archive_alerts_test` instead of the deleted desktop one.
- `session-creation-and-options.md`: the sub-agents pill sentence names the
  staged command, the recording hint and the saved-recording actions instead
  of "the voice controls", as agreed on the step 15 review (cubic, #1587).
- `popup-alerts.md`, `native-activity-indicators.md`, `voice-input.md` and
  `docs/HARNESS_CAPABILITIES.md` needed nothing: the sweep for retired terms
  ("task" for a session, "All sessions", "Running" section, `VerticalDivider`,
  native macOS chrome, Plan/Ask offered as agents, a Mark unread toggle on the
  open page, rail chips) found no remaining claim.
- Documentation only. No code, wire, database, string or user-visible change.

## Deviations From The Plan

- None.

## Automated Evidence

Measured checkpoint: commit `HEADSHA` against base `BASESHA`. Documentation
validation only, as the plan sets for this step: every added line stays within
120 bytes, checked with `git diff -U0 <base> <head>` piped through `awk`.

- Size: SIZE changed lines across FILES files, all documentation and plan
  files.
