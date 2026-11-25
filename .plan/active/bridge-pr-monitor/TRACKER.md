# Tracker: bridge-pr-monitor

| Step | Title | Status | PR |
|---|---|---|---|
| 1 | 🌱 Raise the plan | Done | #2908 |
| 2 | ⚙️ Tool-group interface and grouped MCP server | Done | #2909 |
| 3 | 🌿 Per-group toggles and leaner task text | Done | #2911 |
| 4 | 🚧 Tool host: records, notices and approvals | Done | #2913 |
| 5 | ⚙️ PR monitor package: `gh` API and snapshots | Done | #2910 |
| 6 | ⚙️ PR monitor rules | Done | #2912 |
| 7 | 🚧 Watches: fan-out polling, delivery and restart | In review | #2916 |
| 8 | 🚧 Readiness, auto-merge, feedback and reply | Not started | |
| 9 | ⚙️ `configure_pr_monitor` | Not started | |
| 10 | ⚙️ Guides and skills on Claude Code and Codex | Not started | |
| 11 | ⚙️ Pi deferred tools and instructions; skills on Pi, Oh My Pi, Grok and Copilot | Not started | |
| 12 | ⚙️ Bridge projection, status and app actions | Not started | |
| 13 | ⚙️ App: row mark, composer chip and group toggles | Not started | |
| 14 | ⚙️ App: watched-PR list | Not started | |
| 15 | ⚙️ Sesori tools on OpenCode | Done | #2914 |
| 16 | 🌱 Reconcile regression docs | Not started | |
| 17 | 🌿 Verify and retire | Not started | |

## Notes for later steps

- The owner answered the first round of questions on 2026-11-25; see
  Decisions in `PLAN.md`.
- Step 14 starts by checking what multi-computer knows about other bridges,
  for the `N watched` rows. If N is not available, ask on a review page.
- Step 15 mechanism decided by the owner 2026-11-25: keep OpenCode's shared
  server (no bridge-owned server, no launch-time config). Use the client-MCP
  WebSocket relay; every OpenCode session that calls a Sesori tool —
  including sessions started in OpenCode's own app — gets a token bound to
  its `_meta` session id on first call, so the tools work for all sessions
  with no "is this a Sesori session" detection.
- Step 4 added `start`, `dispose` and `SesoriToolHost` (with `SesoriToolStore`)
  to the interface, which now depends on `sesori_plugin_interface` and
  re-exports `Log`. Step 10 adds `guide`.
- Step 7 as built (`PullRequestWatchService` owns the watches):
  - The orchestrator builds the PR monitor's `BridgeSesoriToolHostImpl` and
    passes it to the service and the poll listener, not to the group itself.
    `SesoriToolGroupIds.prMonitor` is last in `all`.
  - `watch_pr` takes only `pr`: step 8 adds `auto_merge`. Each record stores
    `autoMerge` (always false so far); a PR's effective auto-merge is any
    watcher's. Status already prints `auto-merge: squash` when set.
  - `watch_pr` returns the first report (every existing comment new, plus the
    startup assessment) in its result instead of sending a notice.
  - A watch ends, and its record is deleted, inside the claim of its terminal
    report (merged, closed, not found, 10 failures). Step 12's "merged PRs stay
    listed until end of day" needs its own record of ended watches.
  - A `dropped` delivery marks the PR dirty again, so the next poll re-reports;
    there is no delivery-failure stop. `skippedInactive` ends the watch.
  - Step 8 hooks: `PullRequestActionRepository` holds the cached `selfLogin`
    (add merge, label and reply there); `_recordReport` is where readiness and
    auto-merge run after a report; the idle reminder already skips a PR that
    has the ready label unless auto-merge is on.
  - No `watchesChanged` stream yet; step 12 adds what its projection needs.
- Step 13's wire is in place: `GET /settings` sends `toolGroups` (id, title,
  summary, enabled) and `PATCH /settings` takes `BridgeSettingUpdate.toolGroup`.
  An older bridge omits the list and answers the update with 400 `unknown`.
- `test/bridge/sesori_mcp/goldens/tools_list.json` pins `tools/list`; rewrite
  it with `SESORI_UPDATE_GOLDENS=1` after an intended change.
- Hermes gets the Sesori MCP from a separate PR outside this plan. The
  verification matrix includes it once that PR lands.
- Step 6 added `PullRequestBaseline` (seen comment ids per channel and the
  unresolved-thread count) as the report builder's input; a null baseline is
  a watch's first report. Step 7 stores it as JSON (relevant comment ids only,
  no bodies) with state, head, mergeable and CI and review signatures. Step 8 adds the
  readiness-error and auto-merge-notice report lines and the auto-merge
  guidance text. Report and feedback texts name the bridge tools
  (`mark_pr_ready`, `reply_on_pr` with `thread_id`) instead of `pr_monitor`.
