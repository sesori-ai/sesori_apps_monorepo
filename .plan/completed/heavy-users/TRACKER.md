# Heavy users tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Retired 2026-10-29: all 19 steps delivered. The agent-runnable L3 cells pass; the user accepted the remaining
  cells as unexecuted (see Evidence and decisions).
- User decisions: D1–D7 in `PLAN.md`, agreed 2026-10-28 on the review page `heavy-users-r1` and the follow-up in
  chat (D7).

## Delivery

| Step | Repository | Outcome | State | PR/evidence |
|---|---|---|---|---|
| 1/19 | monorepo | Publish the plan | Merged | #2178 |
| 2/19 | monorepo | 10,000-session Claude fixture and baseline | Merged | #2179 |
| 3/19 | monorepo | Session list rebuilds only when it changes | Merged | #2181 |
| 4/19 | monorepo | Prego lists animate only on-screen rows | Merged | #2184; device feel check owed (follow-ups) |
| 5/19 | monorepo | Import writes only changed rows | Merged | #2180 |
| 6/19 | monorepo | One reload per import; off-UI decode | Merged | #2183 |
| 7/19 | monorepo | Claude metadata cache | Merged | #2182 |
| 8/19 | monorepo | Pi metadata cache | Merged | #2188 |
| 9/19 | monorepo | Codex enumeration off the main isolate | Merged | #2186 |
| 10/19 | monorepo | OpenCode import without a call per session | Merged | #2189 |
| 11/19 | monorepo | Row action cubits keep to their session | Merged | #2187 |
| 12/19 | monorepo | Shared running and search rules | Merged | #2190 |
| 13/19 | monorepo | Bridge session pages | Merged | #2191; timing below |
| 14/19 | monorepo | Client window service | Merged | #2193 |
| 15/19 | monorepo | Palette search through the bridge | Merged | #2195; recording owed (follow-ups) |
| 16/19 | monorepo | Session list on pages | Merged | #2196; recording owed (follow-ups) |
| 17/19 | monorepo | Launch rows on the window; inventory removed | Merged | #2197 |
| 18/19 | monorepo | Reconcile regression documents | Merged | #2198 |
| 19/19 | monorepo | Run the L3 matrix; retire | Merged | L3 matrix below; user cells accepted unexecuted |

## Baseline (step 2)

Measured 2026-10-29 on an Apple M4 Pro (14 cores, 48 GB), macOS 27.0.1, Dart 3.13.7. The tree was `origin/main`
`dacd7c02e4` plus this step's benchmark tools (PR #2179). The tools add no production code, so the numbers
describe the bridge and Claude plugin at `dacd7c02e4`. Other agent sessions shared the machine, so timings varied
by up to 2x between runs; each cell shows the range of three runs. Later steps add their after-numbers next to
these.

Commands, from `bridge/app/` (fixtures live in `/tmp`, never in the repository):

```sh
dart run tool/benchmarks/claude_session_fixture.dart --out /tmp/heavy-users-claude-10k
dart run tool/benchmarks/claude_session_fixture.dart --out /tmp/heavy-users-claude-50k --sessions 50000
dart run tool/benchmarks/claude_catalog_benchmark.dart --fixture /tmp/heavy-users-claude-10k
dart run tool/benchmarks/claude_catalog_benchmark.dart --fixture /tmp/heavy-users-claude-50k
```

Fixtures (default seed 2026, reference time 2026-10-01): 40 projects, the largest holding 40% of roots; about 20% of roots have 1–3
sub-agent children; titles split evenly between `/rename`, `ai-title` and first prompt; 5% of roots padded to
200–400 KB.

| Fixture | Roots / children | On disk |
|---|---|---|
| 10k | 10,000 / 4,090 | 194 MB |
| 50k | 50,000 / 19,966 | 895 MB |

Bridge, headless (`claude_catalog_benchmark.dart`: the plugin's real catalog repository over the fixture, then the
real `CatalogImportRepository` and `SessionRepository` over a temporary bridge database):

The step 19 columns are the same benchmark on `origin/main` `6c44829229` (all of steps 3–18), three runs each, on
freshly regenerated fixtures (same seed, same sizes).

| Measure | 10k | 10k, step 19 | 50k | 50k, step 19 |
|---|---|---|---|---|
| Claude catalog scan, first (isolate) | 2.2–4.6 s | 2.8–5.1 s (cold, expected) | 10.6–21.4 s | 12.4–17.0 s |
| Claude catalog scan, second, nothing changed | 2.1–2.3 s | 0.27–0.28 s | 11.2–19.1 s | 1.27–1.38 s |
| First import, scan included | 2.7 s | 0.84–0.87 s (scan served by the cache) | 13.0–13.3 s | 3.5–3.9 s |
| Rescan import, nothing changed | 2.7 s | 0.53–0.56 s | 14.3–25.5 s | 2.68–2.72 s |
| Session rows written per rescan | 14,090 (every row) | 0 | 69,966 (every row) | 0 |
| Project rows written per rescan | 40 (every row) | 0 | 40 (every row) | 0 |
| Progress events per import (repository) | 5 (3 enumerating, committing, completed) | 5 | 5 | 5 |
| Chat-history checks queued per import | 14,090 | 0 (14,090 activity entries published; the service drops sessions without stored history) | 69,966 | 0 (69,966 entries) |
| `/sessions` body, largest project | 1.56 MB (4,000 roots), 35–38 ms read, enrich and encode | 1.56 MB, 43–48 ms (legacy route, unchanged) | 7.82 MB (20,000 roots), 162–175 ms | 7.82 MB, 231–246 ms |
| `/sessions` bodies, all projects | 3.90 MB | 3.90 MB | 19.56 MB | 19.56 MB |
| `/sessions/page`, first page (best of five) | — | 6.7–8.0 ms, 78 KB | — | 22.0–26.1 ms, 79 KB |
| `/sessions/page`, counts only | — | 2.2–2.8 ms | — | 9.7–11.8 ms |

Notes:
- Claude imports are bridge-derived, so the progress flood measured in "Current behavior" does not apply to them;
  it is the OpenCode native-projects walk (step 10).
- A rescan that changes nothing costs the same as the first import: the scan re-reads every transcript (step 7) and
  every row is rewritten (step 5).
- `/sessions` bytes come from the route's own repository read and `SessionViewService.enrichMany`, JSON-encoded as
  the relay sends it. The client gets one such body per project on each reload.

Not measured here, deferred to the L3 run in step 19 (they need a logged-in local bridge, which an agent cannot set
up without an interactive `claude auth login`):
- Desktop: macOS profile build timed with DevTools: worst frame and total UI-thread time for cold list open, pull
  to refresh until idle, Running on/off, typing a five-letter search, and clearing it.
- Phone: headless iOS simulator (debug), freeze durations for the same actions.
- End-to-end import and rescan time through the live plugin, including relay transfer of the `/sessions` bodies.

Run recipe for step 19:
1. Generate `/tmp/heavy-users-claude-10k` as above.
2. `CLAUDE_CONFIG_DIR=/tmp/heavy-users-claude-10k claude auth login` with a dev account (the default `~/.claude`
   stays untouched).
3. Start a local bridge on its own `--data-dir` slot per the `sesori-local-testing` skill, with
   `CLAUDE_CONFIG_DIR=/tmp/heavy-users-claude-10k` in its environment; wait for the first Claude import.
4. macOS: `flutter run --profile` the desktop app against that bridge, open DevTools → Performance, and record the
   five actions above. iOS: the headless simulator in debug, timing each freeze from a screen recording.
5. Record the numbers here beside the bridge rows.

## Session pages timing (step 13)

Measured 2026-10-29 on the same machine with `claude_catalog_benchmark.dart` (now also times `/sessions/page`): the
route's repository read, enrichment and JSON encoding across all 40 projects, best of five runs, no running sessions.
Same commands as the baseline, run from `bridge/app/` on PR #2191's tree (the benchmark's `sessionsPageRoute`
section).

| Request | 10k | 50k |
|---|---|---|
| First page, 200 rows | 9.7 ms, 78 KB | 32.5 ms, 79 KB |
| Page 21 (after 4,000 rows) | 9.8 ms | 29.0 ms |
| Counts only (`limit: 0`) | 3.1 ms | 13.1 ms |
| Two-word search, first page | 7.7 ms | 32.1 ms |
| Unread chip | 7.9 ms | 24.7 ms |

- Under the ~50 ms bar, so no index or migration was added.
- The Running chip was not timed: the fixture has no live sessions. Its page filter is a primary-key `IN` over the
  running ids, and every request above already computes the Running count. The plugins' activity call per request
  is the cost the plan accepts.
- The first build took 183 ms at 50k. Without `ANALYZE` statistics, which the bridge never gathers, SQLite read
  every root through `idx_sessions_roots` and then looked each row up by primary key. The page query now keeps its
  scope terms off the indexes (`+column`) and reads the table once, the plan SQLite picks itself after `ANALYZE`.

## L3 matrix (step 19)

Run 2026-10-29 by an agent on the baseline machine, `origin/main` `6c44829229`. The /tmp harnesses named here are
not in the repository. The agent must not use the user's own harness accounts or data, so cells that need a live
harness session are left to the user with a recipe below.

Client runs used a slot-1 bridge per `sesori-local-testing` (isolated `HOME`, dev account, only Claude reachable,
`CLAUDE_CONFIG_DIR` = the 10k fixture). A logged-out Claude blocks the import (setup `authenticationRequired`, so
`startAllowed` is false), so the bridge ran with `/tmp/hu19/bin/claude-shim`: it answers `--version` and
`auth status` and fails every other call. Imports and list routes are real; launching or sending is not possible.
After the first import the DB was edited: the bridge's own cwd project hidden, 300 roots archived, 40 roots unread.

| Cell | Result | Evidence |
|---|---|---|
| Claude fixture, headless: rescan twice | Pass | Second import writes 0 session and 0 project rows, sends 5 progress events and reports `sessionsImported: 0`; 0.53–0.56 s at 10k (baseline 2.7 s) and 2.68–2.72 s at 50k (baseline 14.3–25.5 s). Table above. |
| Claude fixture, headless: send to an old session lists no directory | Pass | Harness `/tmp/hu19/send_listing.dart` counts `ClaudeTranscriptApi.listTranscriptPaths` calls. After one scan of the 10k fixture, resolving the oldest root (2025-10-11) through `findSessionById` and `findTranscriptPath`, the lookups `sendPrompt` makes via `_findSession`, listed 0 directories in 0.3 ms; an unknown id (control) listed once. `claude_transcript_catalog_repository_test.dart` passes (29). |
| Claude fixture, headless: `/sessions/page` | Pass | Harness `/tmp/hu19/page_check.dart` imports the fixture, archives 300 roots, marks 120 unseen, reports 3 running through the plugin's activity summary, then compares the route's repository read, enrichment and JSON round trip with an independent Dart reading of the rows. Passed at 10k (9,700 active rows over 49 pages) and 50k (49,700 over 249): order with id tie-break, cursor walk without duplicates or children, counts (all, running, unread), `limit: 0`, Running and Unread chips, project filter (largest and smallest project), search (two words, case, project name, no match, `%`/`_` literal), archived view paged newest-archive first and absent from the active walk, and project + search + Unread combined. The step 13 tests pass (26). |
| Live plugins: Pi, Codex, OpenCode (running and dormant) | Needs user | Pi 1.4.0, Codex 0.165.0 and OpenCode 2.2.0 are installed, but a session and a send need a harness account. An isolated home has none, and copying the user's would use their account. Catalog tests pass: Pi (15), Codex (17), OpenCode (12). |
| Client end to end: iOS simulator (debug), 10k fixture | Pass, one feel finding | List opened with counts (All 9,700, Unread 40); flung through pages to row ~2,600 and opened a session there; search and clear (counts match an SQL count: 551 matches, 3 unread); Running and Unread chips; rename and archive from a row (persisted: title, 301 archived); Archived view paged to its last rows; pull to refresh (rescan ran, "No new sessions"). Rough feel, from a 170 s 120 fps recording and ffmpeg scene scores, not a profiler: no stall during a fling; every pause of 100 ms or more (longest 533 ms) starts as a fling decelerates, where the next page lands. Opening a session took about 10 s because the shim fails the harness spawn (not a product issue). Feel finding (pre-existing, same DAO write in v1.10.1): renaming a deep row sets `updatedAt`, so the row moves to the top and, with a new "Today" heading above the viewport, the rows on screen shift down by about two rows. |
| Client end to end: launch a session | Needs user | Needs a logged-in Claude. |
| Client end to end: macOS desktop profile timings, palette | Needs user | The desktop build shares bundle id `com.sesori.desktop` with the installed Sesori.app (same Application Support and keychain items) and supervises a helper bridge, so a dev run would touch the user's real desktop state. The agent also has no macOS GUI driver here. |
| #2196 recording: loader row and Retry | Pass | `/tmp/hu19/2196-loader-retry.mp4` (1.2 MB, 60 s, fixture data): bridge paused with SIGSTOP while paging, loader row, "Bridge disconnected", Retry after the 30 s relay request timeout, bridge resumed, Retry loads the next page. The loader spins the full 30 s before Retry shows, and Retry does not fire by itself after the bridge reconnects. |
| #2195 recording: palette typing | Needs user | Desktop only; see the macOS row. |
| New app ↔ bridge v1.10.1 | Pass | Wire: the v1.10.1 router answers 404 `no handler found for POST /sessions/page`, which `SessionRepository._isMissingRoute` maps to Unsupported; complete-mode tests pass (64). UI, iOS debug against a v1.10.1 bridge (git archive at `/tmp/hu19/v1101`, own `HOME` and data dir, same fixture and edits): full list with counts (All 9,700, Unread 40) after the refresh, Unread chip, search narrowing to one row, Archived view. Typing in search lags behind key input in the debug build (the field showed "S" while 12 characters were sent, then caught up). That is a rough debug-mode check over 9,700 local rows, not a profile. Palette: desktop only, needs user. |
| App v1.10.1 ↔ new bridge | Pass (wire); UI needs user | The new bridge still serves `GET /projects` and `GET /sessions`. An unchanged rescan completes with `projectsImported: 0, sessionsImported: 0` and `newItems` 0/0, so the v1.10.1 `CatalogRescanService` (reload only when either count is above 0) adds no import reload to the refresh's own. |
| External: the reporting user's machine | Pending (D6) | After release. |

Left for the user:
1. Launch a session against the fixture: `CLAUDE_CONFIG_DIR=/tmp/heavy-users-claude-10k claude auth login` with a
   dev account, then a slot bridge per `sesori-local-testing` with that variable set (the fixture is regenerated by
   the baseline commands).
2. macOS desktop, with the fixture bridge: `flutter run --profile` of `client/desktop` with DevTools. Record the worst
   frame and UI-thread time for cold open, pull to refresh, Running on/off, a five-letter search and clearing it. Then
   record palette typing for #2195 (fixture data only).
3. Decide on the rename feel finding: a renamed deep row jumps to the top and shifts the visible rows.
4. Prego list feel check on a real device (#2184).
5. Live plugins, with your accounts: for Pi, Codex and OpenCode, with one session running and one dormant, rescan
   from the app, check the list, rescan again (the bridge log shows 0 rows written), and send to an old session.
6. Compatibility: palette search against a v1.10.1 bridge on macOS, and the v1.10.1 app (store build) against the new
   bridge: the list loads and a refresh that changes nothing reloads once.

## Evidence and decisions

- 2026-10-28: two read-only investigations, one of the bridge and plugins and one of the client, ranked every path
  that grows with the session count. `PLAN.md` → "Current behavior" records the findings with file references.
- 2026-10-28: the review page `heavy-users-r1` settled D1–D6. The user then asked for one plan covering both phases
  in detail (D7).
- 2026-10-29 (step 19): the user accepted retiring with the "Needs user" L3 cells unexecuted: "I won't run
  anything myself for macos. I'll just tell you later if there's issues." Issues they report later become
  standalone fixes. The reporting user's retest (D6) stays external and non-blocking.
- 2026-10-29 (step 18): `HARNESS_CAPABILITIES.md` needs no change. Paging, search and counts are bridge-owned and
  harness-neutral; the scanner work fixed each harness that scans files (Claude, Pi, Codex) and OpenCode's import.

## Follow-ups

Open items outside the 19 steps, carried as standalone work after retirement. Q1–Q5 of the review page
`heavy-users-r2` (2026-10-29) ask the user about the decisions below; the page was still unanswered at retirement.
- The `idx_sessions_archive` index is unused after step 13; dropping it needs migration v22.
- The Prego list (step 4, #2184) still needs a feel check on a real device: filter, chip and page changes with
  rows entering and leaving off screen.
- #2196's recording is posted on the PR (`pr-media/heavy-users-step-16/loader-retry.mp4`). #2195's palette
  recording is not captured: it needs the macOS desktop, which the user accepted as unexecuted.
- Renaming a row far down the list moves it to the top and shifts the visible rows about two rows down
  (pre-existing; v1.10.1 does it too).
- With the bridge disconnected, the loader row waits for the 30 s request timeout before Retry and does not
  reload on reconnect.
- In a debug build, search on a v1.10.1 bridge (complete mode, 9,700 rows) fell behind typing once; unmeasured
  in a profile build.
- The palette's sessions before typing are the sidebar list's loaded rows, so on a paged bridge they follow the
  list's project filter, search and chip; typed search does not. Step 15 described the palette as ignoring the
  list's key throughout. Decide whether the blank palette should ask the bridge for the newest sessions of every
  project.

## Review record

- 2026-10-28: `architecture-plan-review` rejected the first revision with 12 findings. All were applied in the same
  revision:
  1. There is one window per mode (an injectable factory). The scope owns the active window and the archived route
     owns its own. Refresh, launch rows and the palette read the active window.
  2. Palette search moved into a new `SessionSearchCubit`.
  3. The window now has named layers: `SessionApi.getSessionPage`, and `SessionRepository.getSessionPage`
     returning a sealed result with an Unsupported variant. The legacy path is the window's complete mode, which
     makes `RecentSessionInventoryService` removable (step 17).
  4. The window owns the one matching rule. The cubit's debounce goes in step 16, and the hidden-row count
     adjustment was dropped and accepted as a risk.
  5. The bridge chain is named: handler → `SessionRepository.getSessionPage` → DAO, then
     `SessionViewService.enrichMany`. Running ids come from `getProjectActivitySummaries()`, and the per-request
     cost is accepted.
  6. The SQL forms of the unseen rule and the displayed time stay in the DAO, with parity tests.
  7. A shared `ActiveSessionRunningCalculator` is applied once in `SseEventTracker`, and `SessionActivityCalculator`
     is deleted (new step 12).
  8. OpenCode keeps the runtime's dormant-only snapshot. A live `NativeProjectsPluginApi.readCatalogSnapshot`
     replaces the per-parent walk.
  9. The cache owners are named: the Claude, Pi and Codex catalog repositories. Pi's process repository receives
     resolved sessions.
  10. One page limit, 0..1000, applies on both sides; anything outside is a 400.
  11. The compatibility baseline is v1.10.1, the latest public release.
  12. The search words and own-name rule move to `sesori_shared` (step 12).

  The series grew from 17 to 19 steps. Per `AGENTS.md` the applied fixes are not re-reviewed.
