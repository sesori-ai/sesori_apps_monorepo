# Step 9 — Verify And Retire

Branch `compaction-progress/retire`, from `origin/main` at `57d736b9e4` (step 8
merged). `origin/main` at `48bcaaf080` (step 5b) was merged in afterwards.
Plan only. There is no user-visible, wire or database change.

## Status

**Not retired.** Wire-level live checks found two compaction defects (Codex,
Pi) and one OpenCode v2 blocker; see [Findings](#findings). The screen,
device and L5 cells are unexecuted and wait on the user's decision (V2).
[Regression Coverage](../PLAN.md#regression-coverage) requires that acceptance
in this plan before retirement.

## User Decisions

- **V1 (2026-10-08):** run a cheap wire-level live check on every harness
  before retiring.
- **OpenCode v1 is excluded by the user's decision (2026-10-08).** Only
  OpenCode v2 is tested from now on.
- **V2 (unexecuted screen and device cells):** pending.

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
Step 5b (#1914) ran its own checks; the matrix was not re-run after the merge.

## Live Cells, Wire Level

A source-run bridge on a free dev slot (dev account), driven through its local
debug server the way the app sends requests (`command: "compact"`), in an empty
scratch Git directory. Each harness got tiny sessions with one-word prompts.
The bridge's event stream and `/session/messages` (the reload) were read back.
No device rendered a row, so motion, the timer and semantics are not covered.

| Harness | Running → settled, one part id | Failure note | Stop mid-compaction | One row after reload |
|---|---|---|---|---|
| Claude Code 2.1.294 | Pass (`freedTokens`, `trigger: manual`, summary) | Pass (empty session: "Not enough messages to compact.") | Pass (sweep note) | Fail at `57d736b9e4`; **pass after step 5b**, also after a later turn |
| Codex | Pass (no details, as documented) | Not triggerable (Codex reports no failure) | Pass (sweep note) | **Fail:** two rows |
| Pi 1.1.0 | **Fail:** a sweep failure note flashes before the completion | Pass, but see the Pi command-failure finding | Pass (row moves off the reserved id, then the sweep note) | Pass |
| DeepSeek | Pass (no details, as documented) | Not triggerable (no failure kind) | Pass (sweep note) | Pass; the documented gap did not show after two later turns |
| OpenCode v2 2.0.25 | **Blocked:** no live events reach the bridge | Blocked | Blocked | Blocked |

Notes:

- **Pi needed a project setting.** Pi refuses `/compact` on a tiny session
  ("Nothing to compact (session too small)") because it keeps the last 20,000
  tokens. A scratch-only `.pi/settings.json` with
  `{"compaction":{"keepRecentTokens":10}}` made two one-word turns
  compactable. It was removed afterwards. Threshold compaction and a
  `willRetry` row stay unexecuted: they need a full context window or a provider
  error.
- **OpenCode v2 used `deepseek/deepseek-flash`.** OpenCode's default Anthropic
  model failed with "OAuth access token has been revoked." on this host.
- **Pi rows after a re-import** have no `time.created` and sort above their own
  `/compact` bubble; the trigger is gone, as documented ("history entries carry
  no reason"). This is low damage and recorded only.

## Findings

### F1 — Claude: two compaction rows after a reload (fixed)

At `57d736b9e4`, a reload after a manual `/compact` returned the history row
(keyed by the summary record) and the live row (keyed by the first
`compacting` frame), both completed with the same summary, details and
`time.created`. Step 5b (#1914, `48bcaaf080`) fixed it. The re-run returned
one row, re-keyed to the summary record's id, and still one after a later turn.

### F2 — Codex: two compaction rows after a reload

A manual `/compact` settled in place live, but every reload returned two
completed rows:

```text
01a11bdb-de9b-…          created 1791468756635  compaction completed  (live row, `item/started` id)
codex-compaction-3       created 1791468767429  compaction completed  (rollout `compacted` row)
```

Neither row has a summary or details, and their creation times differ by
about 11 s: the live row is stamped at `item/started`, the rollout row at the
`compacted` record. Step 5b's match needs equal content *and* a known equal
creation time, so it cannot pair them. This is the failure signal "two
compaction rows after reload".

### F3 — Pi: a successful compaction flashes the sweep's failure note

Reproduced twice. The turn goes idle while the compaction is still running,
the idle sweep fails the row, and Pi's `compaction_end` then completes it under
the same id:

```text
214 compaction:1-tool  running
218 session.status     idle
222 compaction:1-tool  failed "The turn ended before compaction finished."
228 session.compacted
232 compaction:1-tool  completed (summary, trigger manual)
```

The stored row ends completed, so a reload is correct. Live, the user sees a
running row, then "Compaction failed", then "Context compacted". This hits the
failure signals "the row jumping, flashing or re-inserting when it settles" and
a wrong interim failure. The likely cause is the `compact` command's turn
finishing on Pi's command response before the `compaction_end` event arrives.
This is unconfirmed.

### F4 — Pi: a rejected `/compact` also fails the request and raises a session error

When Pi rejects `compact` ("Nothing to compact (session too small)"), the
failure note appears correctly. The send request also returns HTTP 502 ("Pi
did not accept the command"), and the bridge emits an empty `session.error`.
That is the generic Pi command-failure path in `PiSessionService`, which this
series did not change. The note, the failed send and the session error then
report one failure three ways. Step 7 verified "no session error" only for the
dispatcher's `compaction_end` path.

### F5 — OpenCode v2: live events never reach the bridge (blocker, outside this series)

With OpenCode 2.0.25, a session was created and answered (`/session/messages`
returned the reply), but the bridge received no message or status events for
it. A `/compact` then never ran; the bridge still considered the first turn
running. The bridge log repeats `[SseConnection][sse-conn] stream loop error`
with `OpenCode v2 request failed: GET /api/permission/request (HTTP 404)`. The
404 bodies are `LocationNotFoundError` for project directories that no longer
exist: stale scratch projects in the slot's store and entries from OpenCode's
own project list. Over a thousand of these requests failed in one run. The
managed runtime also exited once with code 130 during startup. The v2 adapter
seems to let one missing location break the shared event stream. That would
affect any bridge whose OpenCode knows a deleted directory. This belongs to
the `opencode-v2` work, but it blocks the OpenCode v2 compaction cell.

## Unexecuted Cells

No device tooling was available (the agent-device and peekaboo servers were
disconnected), so nothing was rendered or recorded on a surface. These wait on
the user's V2 decision.

- **iOS phone, real device:** live row ticking, settle with no jump (a
  recording), details, failed note, VoiceOver reading the row once, and one row
  after reload. No device control or recording.
- **macOS desktop:** the same rows and the settle. No screen control or
  capture.
- **Android phone:** smoke of the live row and the settle. No device control.
- **Claude Code:** one automatic compaction (it needs a full context window),
  one row after a catalog history re-import, and every visual part.
- **OpenCode v2:** the whole cell, blocked by F5; the strip from deltas is a
  screen check in any case.
- **Codex:** the visual parts.
- **Pi:** threshold compaction, a `willRetry` row staying live, and the visual
  parts.
- **DeepSeek:** the visual parts.
- **One ACP harness without a signal:** plain "Working…". Client rendering.
- **v1.9.0 App Store app with the new bridge (L5):** "Working…" during a
  compaction, nothing while an OpenCode summary streams, no decode failure, and
  the transcript loading after reload. Needs a device with the store build.

OpenCode v1 is not listed: the user excluded it on 2026-10-08.

## Size

This file only, before the retirement edits.
