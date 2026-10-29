# Heavy users tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Current step: 1/19, publishing the plan.
- User decisions: D1–D7 in `PLAN.md`, agreed 2026-10-28 on the review page `heavy-users-r1` and the follow-up in
  chat (D7).

## Delivery

| Step | Repository | Outcome | State | PR/evidence |
|---|---|---|---|---|
| 1/19 | monorepo | Publish the plan | In progress | This change |
| 2/19 | monorepo | 10,000-session Claude fixture and baseline | Not started | |
| 3/19 | monorepo | Session list rebuilds only when it changes | Not started | |
| 4/19 | monorepo | Prego lists animate only on-screen rows | Not started | |
| 5/19 | monorepo | Import writes only changed rows | Not started | |
| 6/19 | monorepo | One reload per import; off-UI decode | Not started | |
| 7/19 | monorepo | Claude metadata cache | Not started | |
| 8/19 | monorepo | Pi metadata cache | Not started | |
| 9/19 | monorepo | Codex enumeration off the main isolate | Not started | |
| 10/19 | monorepo | OpenCode import without a call per session | Not started | |
| 11/19 | monorepo | Row action cubits keep to their session | Not started | |
| 12/19 | monorepo | Shared running and search rules | Not started | |
| 13/19 | monorepo | Bridge session pages | Not started | |
| 14/19 | monorepo | Client window service | Not started | |
| 15/19 | monorepo | Palette search through the bridge | Not started | |
| 16/19 | monorepo | Session list on pages | Not started | |
| 17/19 | monorepo | Launch rows on the window; inventory removed | Not started | |
| 18/19 | monorepo | Reconcile regression documents | Not started | |
| 19/19 | monorepo | Run the L3 matrix; retire | Not started | |

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

| Measure | 10k | 50k |
|---|---|---|
| Claude catalog scan, first (isolate) | 2.2–4.6 s | 10.6–21.4 s |
| Claude catalog scan, second, nothing changed | 2.1–2.3 s | 11.2–19.1 s |
| First import, scan included | 2.7 s | 13.0–13.3 s |
| Rescan import, nothing changed | 2.7 s | 14.3–25.5 s |
| Session rows written per rescan | 14,090 (every row) | 69,966 (every row) |
| Project rows written per rescan | 40 (every row) | 40 (every row) |
| Progress events per import (repository) | 5 (3 enumerating, committing, completed) | 5 |
| Chat-history checks queued per import | 14,090 | 69,966 |
| `/sessions` body, largest project | 1.56 MB (4,000 roots), 35–38 ms read, enrich and encode | 7.82 MB (20,000 roots), 162–175 ms |
| `/sessions` bodies, all projects | 3.90 MB | 19.56 MB |

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

## Evidence and decisions

- 2026-10-28: two read-only investigations, one of the bridge and plugins and one of the client, ranked every path
  that grows with the session count. `PLAN.md` → "Current behavior" records the findings with file references.
- 2026-10-28: the review page `heavy-users-r1` settled D1–D6. The user then asked for one plan covering both phases
  in detail (D7).
- No reduction of the retirement matrix has been requested or accepted.

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
