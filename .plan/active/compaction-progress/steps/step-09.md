# Step 9 — Verify And Retire

Branch `compaction-progress/retire`, from `origin/main` at `57d736b9e4` (step 8
merged). Plan only. There is no user-visible, wire or database change.

## Status

**Not retired.** One live cell failed (two compaction rows after a reload), and
most L3 cells and the L5 cell are unexecuted. The plan stays in
`.plan/active/` until the user decides on the failure and on each unexecuted
cell. [Regression Coverage](../PLAN.md#regression-coverage) requires that
acceptance in this plan before retirement.

## Automated Matrix

Every package the series changed (steps 2–7), at `57d736b9e4`, with Flutter
3.47.5-stable (Dart 3.13.4) first on `PATH`. Each command ran from the package
directory after `flutter pub get` in the `bridge` and `client` workspaces and
in `shared/sesori_shared`.

| Package | `dart analyze --fatal-infos` | Tests | Result |
|---|---|---|---|
| `bridge/app` | No issues | `dart test` | 3,145 passed, 3 skipped (host-only, such as no PowerShell) |
| `bridge/sesori_plugin_interface` | No issues | `dart test` | 181 passed |
| `bridge/sesori_plugin_claude` | No issues | `dart test` | 393 passed |
| `bridge/sesori_plugin_codex` | No issues | `dart test` | 480 passed |
| `bridge/sesori_plugin_deepseek` | No issues | `dart test` | 122 passed |
| `bridge/sesori_plugin_opencode` | No issues | `dart test` | 610 passed |
| `bridge/sesori_plugin_pi` | No issues | `dart test` | 349 passed |
| `shared/sesori_shared` | No issues | `dart test` | 463 passed |
| `client/module_core` | No issues | `dart test` | 2,235 passed |
| `client/module_app_ui` | No issues | `flutter test` | 760 passed |

No failures. The series changed no shell (`client/app`, `client/desktop`) and
no `module_desktop_core` code, so their suites were not run; CI covers them.

## Live Cell: Claude Code, Wire Level

One tiny session through a source-run bridge (debug port of a free local slot,
dev account), Claude Code 2.1.294, in an empty scratch Git directory. Requests
went to the bridge's local debug server, as the app sends them (`command:
"compact"`); the bridge's event stream and `/session/messages` were read back.
No device rendered the row, so motion, the timer and semantics are not covered.

| Check | Result |
|---|---|
| Failure note: `/compact` on an empty session | Pass. One part id: `running`, then `failed` with "Not enough messages to compact."; no echoed error text. |
| Manual `/compact` after one prompt | Pass. One part id: `running`, `completed`, then `completed` with the summary, `freedTokens` 28271 and `trigger: manual`. |
| Stop mid-compaction | Pass. The running row became `failed` with "The turn ended before compaction finished."; the session went idle. |
| Details after reload | Pass. The reloaded row keeps the summary, freed tokens and trigger. |
| **One row after reload (re-import)** | **Fail.** Two completed compaction rows with the same summary, details and `time.created`. |

### Failure: two compaction rows after reload

Failure signal "two compaction rows after reload" (PLAN, Regression Coverage).
The reload after the manual `/compact` returned, in order:

```text
sesori-user-2                         user       /compact
58380ffb-…  (summary record uuid)     assistant  compaction completed (history row)
c1444893-…  (first `compacting` uuid) assistant  compaction completed (live row)
```

Both rows carry `time.created` 1791463154313. A second reload, after a later
turn, still had both, so the re-import did not re-key the live row as P10
option 2 intends.

Hypothesis, not yet confirmed: the replay match uses ordered context. The P10
capture test places the live row right after a prompt that matches a history
prompt. In a real `/compact`, the live row follows the bridge's synthesized
`/compact` bubble, which history does not have. The transcript also writes the
`compact_boundary` and the summary record *before* the caveat, the
`<command-name>/compact` envelope and its stdout, so the neighbours differ on
both sides.

The scratch session is still in the slot's store and its Claude transcript is
still on disk, so the case can be reproduced.

## Unexecuted Cells

No device tooling was available (the agent-device and peekaboo servers were
disconnected), so nothing was rendered or recorded on a surface.

- **iOS phone, real device:** live row ticking, settle with no jump (a
  recording), details, failed note, VoiceOver reading the row once, and one row
  after reload. No device control or recording.
- **macOS desktop:** the same rows and the settle. No screen control or
  capture.
- **Android phone:** smoke of the live row and the settle. No device control.
- **Claude Code, the rest:** one automatic compaction (it needs a full context
  window, so it is neither tiny nor cheap), one row after a catalog history
  re-import, and every visual part of the cell. The wire-level checks above
  stand in for the rest.
- **OpenCode v1:** live row with strip, "Working…" back after the settle, and
  the summary modal. Client rendering; outside the one tiny session.
- **OpenCode v2:** live row with strip from deltas, settle, and the failure
  note. Client rendering; outside the one tiny session.
- **Codex:** live row, settle, and Stop mid-compaction. Outside the one tiny
  session.
- **Pi:** manual and threshold compaction, the failure note, and a `willRetry`
  row staying live. Threshold compaction and `willRetry` need a full context
  window or a provider error; outside the one tiny session.
- **DeepSeek:** live row and settle, and the reload gap. Outside the one tiny
  session.
- **One ACP harness without a signal:** plain "Working…". Client rendering.
- **v1.9.0 App Store app with the new bridge (L5):** "Working…" during a
  compaction, nothing while an OpenCode summary streams, no decode failure, and
  the transcript loading after reload. Needs a device with the store build.

## Size

This file only, before the retirement edits.
