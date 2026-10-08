# Step 9 — Verify And Retire

Branch `compaction-progress/retire`, from `origin/main` at `57d736b9e4` (step 8
merged). `origin/main` was merged in three times afterwards: at `48bcaaf080`
(step 5b), at `002478109d` (steps 7b and 7c, and #1916) and at `0b2da1ea81`
before the on-screen run. Plan only. There is no user-visible, wire or
database change.

## Status

**Retired on 2026-10-08.** Every wire-level live cell passes after the fixes
of step 5b (#1914), step 7b (#1917), step 7c (#1918) and #1916; see
[Findings](#findings). The on-screen cells then ran on the slot's own iOS
simulator, a desktop debug build and the slot's Android emulator; see
[Live Cells, On Screen](#live-cells-on-screen). The new findings F6–F11 are
follow-ups outside this PR. The cells that stay unexecuted, and the
reductions, are under [Not Executed And Reductions](#not-executed-and-reductions).

## User Decisions

- **V1 (2026-10-08):** run a cheap wire-level live check on every harness
  before retiring.
- **OpenCode v1 is excluded by the user's decision (2026-10-08).** Only
  OpenCode v2 is tested from now on.
- **V2 (2026-10-08):** keep the plan open until the device tools reconnect,
  then run the on-screen and device cells and retire. A Claude automatic
  compaction and the v1.9.0 App Store cell may be recorded as not executed,
  with the reason, when they cost too much or cannot be installed. Bugs found
  on screen become their own follow-ups, not fixes in this PR.

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
Motion, the timer and semantics are covered by the on-screen run below.

There were two runs. The first ran at `57d736b9e4`, with the Claude re-check
after step 5b. The second ran after the fixes merged (at `002478109d`), with
`ulimit -n 8192` before the bridge started (#1920). It re-ran only the cells
that had failed or been blocked. The table shows the final result of each
cell.

| Harness | Running → settled, one part id | Failure note | Stop mid-compaction | One row after reload |
|---|---|---|---|---|
| Claude Code 2.1.294 | Pass (`freedTokens`, `trigger: manual`, summary) | Pass (empty session: "Not enough messages to compact.") | Pass (sweep note) | Pass after step 5b (F1), also after a later turn |
| Codex | Pass (no details, as documented) | Not triggerable (Codex reports no failure) | Pass (sweep note) | Pass after step 7b (F2), also after a later turn |
| Pi 1.1.0 | Pass after step 7c (F3): running, then completed, then idle | Pass after step 7c (F4): "Already compacted" note, no 502, no `session.error` | Pass (row moves off the reserved id, then the sweep note) | Pass |
| DeepSeek | Pass (no details, as documented) | Not triggerable (no failure kind) | Pass (sweep note) | Pass; the documented gap did not show after two later turns |
| OpenCode v2 2.0.25 | Pass after #1916 (F5): running, 127 summary deltas, completed with summary and `trigger: manual` | Pass: Stop gave OpenCode's own "Compaction cancelled" note | Pass (same run as the failure note) | Pass, also after a later turn |

Notes:

- **Pi needed a project setting.** Pi refuses `/compact` on a tiny session
  ("Nothing to compact (session too small)") because it keeps the last 20,000
  tokens. A scratch-only `.pi/settings.json` with
  `{"compaction":{"keepRecentTokens":10}}` made two one-word turns
  compactable. It was removed afterwards. Threshold compaction and a
  `willRetry` row stay unexecuted: they need a full context window or a provider
  error.
- **OpenCode v2 used `deepseek/deepseek-flash`.** OpenCode's default Anthropic
  model failed with "OAuth access token has been revoked." on this host. The
  first prompt then went through ten provider retries
  (`getaddrinfo ENOTFOUND api.deepseek.com`) before it answered. That is a
  host network blip, not a finding. The first create attempt right after
  startup returned 409 ("OpenCode no longer offers the selected model") while
  the plugin was still degraded; the retry a moment later worked.
- **Pi rows after a re-import** have no `time.created` and sort above their own
  `/compact` bubble; the trigger is gone, as documented ("history entries carry
  no reason"). This is low damage and recorded only.

## Live Cells, On Screen

Run on 2026-10-08 at `3c203b1802` (`origin/main` `0b2da1ea81` merged in), on
the same slot bridge and dev account, against tiny scratch sessions. The
surfaces were the slot's own `sesori-dev-1` iOS simulator (iPhone 17,
`client/app` debug), a macOS `client/desktop` debug build under a throwaway
bundle id with its bridge helper disabled (it reached the slot bridge through
the relay; the bundle id edit was reverted), and the slot's own `sesori-dev-1`
Android emulator. Compactions were sent through the debug server, as in the
wire run, while the surface showed the session. Evidence (screen recordings,
contact sheets and event captures) stays local under `/tmp/cp9/v2/`.

| Cell | Result | Evidence (local) |
|---|---|---|
| iOS, Claude manual `/compact` | Pass. "Compacting context" ticks 0 → 7 s with the sparkle, then settles in place to "Context compacted · freed 23k tokens"; no jump. Details open the summary. | `ios_claude_compact.mp4`, `ios_claude_sheet.png` |
| iOS, Claude Stop mid-compaction | Pass. The row settles in place to "Compaction failed · The turn ended before compaction finished." | `ios_claude_stop.mp4` |
| iOS, one row after reload | Pass. Reopening a Claude session, also after a bridge restart, shows one row per compaction. The other harnesses' reloads are covered by the wire run. | `ios_autoc_end.png`, `claude_compact.txt` |
| iOS, semantics | Pass, reduced. The row's accessibility label is fixed for the build ("Compacting context · 0s") while the visual timer ticks, so a reader announces it once. Read from the XCTest accessibility tree, not VoiceOver speech. | agent-device snapshots |
| iOS, Codex | Pass. Ticks 0 → 9 s, settles in place; no details, as documented. No `/compact` bubble is shown. | `ios_codex.mp4` |
| iOS, Pi | Pass. Ticks, settles in place, no failed flash (F3 fixed). A rejected `/compact` shows "Compaction failed · Compaction failed: Already compacted" (wording repeats; F9). | `ios_pi.mp4` |
| iOS, DeepSeek | Pass with F7. Ticks and settles, but inside an "Automation" card. | `ios_deepseek.mp4` |
| iOS, OpenCode v2 | Pass with F7 and F8. The summary strip streams under the row and the row settles with the summary. No `/compact` bubble is shown. | `ios_opencode.mp4`, `ios_opencode_sheet.png` |
| macOS desktop, Claude manual `/compact` | Pass. Ticks 0 → 10 s, settles in place to "Context compacted · freed 23k tokens"; no jump. | `mac_claude.mov`, `mac_claude_sheet.png` |
| Android emulator, Claude manual `/compact` | Pass, smoke. Ticks 0 → 8 s and is settled ("freed 19k tokens") in place afterwards. The recording stops before the settle frame (Android `screenrecord` stops encoding), so the settle motion itself is not recorded. | `and_compact.mp4`, `and_settled.png` |
| Claude automatic compaction | Pass with F9 and F10. With `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=1` on the bridge, turns 1–2 failed (`too_few_groups`) and turn 3 compacted: the row ticked 0 → 10 s and settled to "Context compacted · freed 34k tokens · auto". | `ios_autoc.mp4`, `ios_autoc_t3.png`, `autoc_t1.txt`–`autoc_t3.txt` |
| Claude, one row after a catalog re-import | Pass, reduced. After a bridge restart and three later turns, both Claude sessions read back one row per compaction, on the wire and on iOS and Android. The log does not show whether a full history re-import ran; the P10 path itself is covered by step 5b's capture test and the F1 re-check. | `ios_autoc_end.png`, `and_reload.png` |
| ACP harness without a signal (OMP) | Partial. OMP refused every `/compact` on a tiny session ("Nothing to compact (session too small)"), also with a scratch `.omp/config.yml` lowering `compaction.keepRecentTokens`. The refusal shows as plain agent text with no row, which is correct, but "Working…" during a real OMP compaction was not observed. | `ios_omp3.mp4`, `omp_compact3.txt` |

## Findings

### F1 — Claude: two compaction rows after a reload (fixed)

At `57d736b9e4`, a reload after a manual `/compact` returned the history row
(keyed by the summary record) and the live row (keyed by the first
`compacting` frame), both completed with the same summary, details and
`time.created`. Step 5b (#1914, `48bcaaf080`) fixed it. The re-run returned
one row, re-keyed to the summary record's id, and still one after a later turn.

### F2 — Codex: two compaction rows after a reload (fixed)

Fixed by step 7b (#1917, `002478109d`). On the re-check, the reload after a
manual `/compact` returned one row (the live `item/started` id), and still one
after a later turn.

In the first run, a manual `/compact` settled in place live, but every reload
returned two completed rows:

```text
01a11bdb-de9b-…          created 1791468756635  compaction completed  (live row, `item/started` id)
codex-compaction-3       created 1791468767429  compaction completed  (rollout `compacted` row)
```

Neither row has a summary or details, and their creation times differ by
about 11 s: the live row is stamped at `item/started`, the rollout row at the
`compacted` record. Step 5b's match needs equal content *and* a known equal
creation time, so it cannot pair them. This is the failure signal "two
compaction rows after reload".

### F3 — Pi: a successful compaction flashes the sweep's failure note (fixed)

Fixed by step 7c (#1918, `d6ec43c493`). On the re-check, the row went running,
then `session.compacted` and completed with the summary and `trigger: manual`.
Only then did the session go idle, with no failed state in between.

In the first run this reproduced twice. The turn goes idle while the compaction
is still running, the idle sweep fails the row, and Pi's `compaction_end` then
completes it under the same id:

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

### F4 — Pi: a rejected `/compact` also fails the request and raises a session error (fixed)

Fixed by step 7c (#1918). On the re-check, a second `/compact` right after a
compaction was rejected by Pi ("Compaction failed: Already compacted"). It left
only the failure note: the send returned success, and the session got no
`session.error`.

In the first run, when Pi rejects `compact` ("Nothing to compact (session too
small)"), the failure note appears correctly. The send request also returns HTTP 502 ("Pi
did not accept the command"), and the bridge emits an empty `session.error`.
That is the generic Pi command-failure path in `PiSessionService`, which this
series did not change. The note, the failed send and the session error then
report one failure three ways. Step 7 verified "no session error" only for the
dispatcher's `compaction_end` path.

### F5 — OpenCode v2: live events never reach the bridge (fixed, outside this series)

Fixed by #1916 (`8a517bba79`). On the re-check, the same slot store, with its
stale project folders, delivered the session's live events, and the OpenCode v2
compaction cell ran in full.

In the first run, with OpenCode 2.0.25, a session was created and answered
(`/session/messages` returned the reply), but the bridge received no message or status events for
it. A `/compact` then never ran; the bridge still considered the first turn
running. The bridge log repeats `[SseConnection][sse-conn] stream loop error`
with `OpenCode v2 request failed: GET /api/permission/request (HTTP 404)`. The
404 bodies are `LocationNotFoundError` for project directories that no longer
exist: stale scratch projects in the slot's store and entries from OpenCode's
own project list. Over a thousand of these requests failed in one run. The
managed runtime also exited once with code 130 during startup. The v2 adapter
seems to let one missing location break the shared event stream. That would
affect any bridge whose OpenCode knows a deleted directory. This belonged to
the `opencode-v2` work, and it blocked the OpenCode v2 compaction cell until
#1916.

### F6 — Codex: a session's first prompt shows twice (open, outside this series)

A new Codex session stores and shows its first prompt as two user messages
with different ids. An older Codex session on the same slot shows the same.
It is unrelated to compaction and has no existing issue. Follow-up.

### F7 — DeepSeek and OpenCode v2: the compaction row sits in an "Automation" card (open)

Both harnesses send the compaction message with the `system` sender, which the
client renders as a labelled "Automation" card around the row. Claude, Codex
and Pi show the bare row. DeepSeek's sender came with step 7 (#1908,
`_compactionRow` in `deepseek_event_mapper.dart`); OpenCode v2's predates this
series. Follow-up.

### F8 — OpenCode v2: the summary strip shifts the transcript (open)

When the first summary delta opens the strip under the row, the content above
it jumps up by about 8 pt with no transition. When the strip collapses at the
settle, the content moves down by about 18 pt over roughly 100–150 ms. Both
hit "content must never jump". Evidence: `ios_opencode.mp4`. Follow-up.

### F9 — Failure notes show harness wording raw (open)

- Pi's rejected `/compact` reads "Compaction failed · Compaction failed:
  Already compacted": Pi's own message repeats the label.
- Claude's automatic compaction failure reads "Compaction failed ·
  too_few_groups", the raw `compact_result` code.

Low damage; both are readable. Follow-up for the wording.

### F10 — Claude automatic compaction: the row and the new prompt swap places (open)

On a turn that auto-compacts, the running row (and a failed note) appears
above the user's just-sent prompt, which still shows "Sending to Claude
Code…". When Claude accepts the prompt, the prompt bubble jumps above the row.
After a reload the row sorts above the prompt again, so the live and reloaded
orders differ. It reproduced on all three turns. Evidence: `ios_autoc_t3.png`,
`ios_autoc_working.png`, `and_reload.png`. Follow-up.

### F11 — "Working…" starts from a stale time (open, likely outside this series)

While a new prompt is still "Sending", the "Working…" timer counts from an
earlier start: "2m 34s" on the first turn after a bridge restart (the previous
`/compact`'s start), "7s" on the next turn. It resets when the turn starts.
Evidence: `ios_autoc_working.png`. This is the turn timer, not the compaction
row. Follow-up.

## Not Executed And Reductions

- **v1.9.0 App Store app with the new bridge (L5): not executed.** The App
  Store build installs only on a real device, and the user's physical iPhones
  are off-limits for this run; the simulator cannot install it.
- **OMP "Working…" during a real compaction: not executed** (see the table).
  OMP refuses `/compact` on a session small enough to test cheaply.
- **Pi threshold compaction and a `willRetry` row: not executed.** They need a
  full context window or a provider error.
- **Real devices: reduced** to the slot's iOS simulator and Android emulator.
- **VoiceOver: reduced** to the accessibility tree; no speech was recorded.
- **Android settle motion: reduced** to before-and-after frames.
- **Catalog re-import: reduced**; see the table row.

OpenCode v1 is not listed: the user excluded it on 2026-10-08.

## Size

This file, the move to `.plan/completed/` and small `PLAN.md` and `TRACKER.md`
status edits.
