# Tracker: bridge-pr-monitor

| Step | Title | Status | PR |
|---|---|---|---|
| 1 | 🌱 Raise the plan | Done | #2908 |
| 2 | ⚙️ Tool-group interface and grouped MCP server | Done | #2909 |
| 3 | 🌿 Per-group toggles and leaner task text | Done | #2911 |
| 4 | 🚧 Tool host: records, notices and approvals | Done | #2913 |
| 5 | ⚙️ PR monitor package: `gh` API and snapshots | Done | #2910 |
| 6 | ⚙️ PR monitor rules | Done | #2912 |
| 7 | 🚧 Watches: fan-out polling, delivery and restart | Done | #2916 |
| 8 | 🚧 Readiness, auto-merge, feedback and reply | Done | #2919, #2920 |
| 9 | ⚙️ `configure_pr_monitor` | Done | #2921 |
| 9.b | 🌿 Allow for an agent's per-PR auto-merge | Done | #2925 |
| 10 | ⚙️ Guides and skills on Claude Code and Codex | Done | #2917. Step 11 reuses `SesoriMcpAccess.skillBundle` (`pluginRoot` for `--plugin-dir`-style harnesses, `skillsRoot` for plain skill roots), which lives in `<data-dir>/agent-skills`. |
| 11 | ⚙️ Pi deferred tools and instructions; skills on Pi, Oh My Pi, Grok and Copilot | Done | #2922 |
| 12 | ⚙️ Bridge projection, status and app actions | Done | #2923 |
| 13 | ⚙️ App: row mark, composer chip and group toggles | Done | #2926 (13.a), #2927 (13.b) |
| 14 | ⚙️ App: watched-PR list | Done | #2929 (14.a), #2930 (14.b) |
| 15 | ⚙️ Sesori tools on OpenCode | Done | #2914 |
| 16 | 🌱 Reconcile regression docs | Done | #2932 |
| 17 | 🌿 Verify and retire | Done | #2946 (Grok skill fix, `get_guide` pointer), plus this retire PR. Matrix in `docs/regression/pull-request-monitor.md` ("L3 run, 2026-11-26"); Hermes pending its MCP. |

## Notes for later steps

- The owner answered the first round of questions on 2026-11-25; see
  Decisions in `PLAN.md`.
- Step 14 has no other-computer rows (owner, 2026-11-25): the sheet lists
  only the current computer's PRs.
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
    report (closed, not found, 10 failures). Since step 12 a merged watch's
    record is kept as `merged` until local midnight.
  - A `dropped` delivery marks the PR dirty again, so the next poll re-reports;
    there is no delivery-failure stop. `skippedInactive` ends the watch.
  - Step 8 hooks: `PullRequestActionRepository` holds the cached `selfLogin`
    (add merge, label and reply there); `_recordReport` is where readiness and
    auto-merge run after a report; the idle reminder already skips a PR that
    has the ready label unless auto-merge is on.
  - No `watchesChanged` stream yet; step 12 adds what its projection needs.
- Step 8 as built (8.a: GitHub writes, feedback and reply; 8.b: readiness):
  - `PullRequestMergeService` is stateless; the runtime's in-memory
    `PullRequestMergeState` holds the typed retry (`ready` plus the caught
    exception) and the last `PullRequestMergeAttempt` (head and outcome).
    `PullRequestReportBuilder` owns every readiness sentence, and the group
    uses it for `mark_pr_ready` texts. A restart starts from the initial
    state, so the first poll after it cannot invalidate a ready label.
  - The baseline stores `ready`. There is no "merge stuck" state: the idle
    reminder's stuck line covers it, and step 12 can derive it from
    ready + auto-merge + open.
  - A standalone (unwatched) mark or unmark only labels, with no runtime;
    step 9 decides whether its auto-merge default applies there.
    `get_pr_feedback` and `reply_on_pr` call GitHub outside the op queue.
  - A merge result or new readiness failure reports to every watcher once;
    a `get_pr_report` that shows it consumes it for all of them, and a
    dropped report restores it. `get_pr_report` stays read-only: only a due
    report labels or merges. Notice settlement runs in the PR's op queue.
- Step 9 as built:
  - `PullRequestWatchService` owns `PullRequestMonitorConfig` (the group's
    bridge record `config`, loaded in `resume`). `watch_pr` without
    `auto_merge` takes the repo override, else the global default.
  - `SesoriToolHost.requestApproval` now returns `SesoriToolApproval`:
    `Allowed` (approve everything, no card), `Dropped`, or `Shown` with the
    answer's future, so the tool can answer at once under YOLO and say
    "Sent to the user" otherwise. An allowed answer applies on top of the
    settings at that time, and the session gets an allowed or declined
    notice.
  - A call that widens applies its timings at once and only its auto-merge
    part waits. Idle reminders off is a null `idleReminderMinutes`.
    Clearing a repo's `off` override under a global `on` counts as widening.
  - A standalone (unwatched) `mark_pr_ready` stays label-only: the default
    applies to new watches only.
- Step 12 as built (#2923):
  - `Session.pullRequestWatches` (repository, number, title, url, autoMerge,
    status). The red count is a `PullRequestWatchStatusNeedsYou`; its reasons
    are `ciFailing`, `conflict`, `newReviewComments`, `readyWithoutAutoMerge`.
    The lead PR for the row is the app's choice (needs-you first is natural).
  - The status is stored in each watch record and synced after every op in
    the PR's queue, so `SessionViewService` reads it via the repository. A
    merged watch stays as `merged(mergedAt)` until the first poll after the
    bridge's local midnight.
  - `GET /pull-request-watches` (session id, title, project, watch) for the
    step 14 list; `POST /session/pull-request-watch/stop` and `/auto-merge`
    answer with the updated session; `pullRequestWatches.changed` fires with
    every session republish caused by a watch change.
  - While `pr_monitor` is off, stored watches stay listed with frozen
    statuses, merged ones included. Step 13 decides whether the app hides
    them when the group is off.
- Step 17: Grok 1.0.30 left the Sesori skill out of the command list in the
  first live session; it appeared from the next session on. Probably the list
  was read before Grok loaded `_meta.pluginDirs`; not confirmed. Check during
  the final verification and fix if the command list can be refreshed after
  load. Resolved in #2946: the short-lived history process's `session/load`
  had no `_meta`, and its command list replaced the shared one.
- Step 13.a as built: `GET /settings` also sends `agentToolsEnabled`
  (`bool?`, null from v1.15.0 bridges) and `PATCH /settings` takes
  `BridgeSettingUpdate.agentTools`. `BridgeSettingsReady.agentTools` is null
  when the bridge sends no master or no groups (the section is hidden);
  otherwise it holds the master, the groups and one mutation state (idle,
  in progress, failed or uncertain, naming the switch where it applies).
  There is no unsupported state: only bridges that send the master see the
  switches. `SessionViewService`
  leaves watches out while `toolGroupEnabled(prMonitor)` is false (master
  included), and `PullRequestPollListener` republishes every watched session
  on each toggle, polling first when it comes back on. Step 14's list route
  and its `pullRequestWatches.changed` refetch therefore see an empty list
  while the group is off; the home button simply hides.
- Step 13.b as built: `pullRequestWatchLook` (`module_app_ui/lib/src/widgets/`)
  maps a status to its colour and words, for the row mark and the chip's
  menu; step 14's list can reuse it. `SessionDetailCubit.stopPullRequestWatch`
  and `SessionApi.stopPullRequestWatch` exist; step 14 adds the auto-merge
  route. The Agent tools section lives inside `BridgeSettingsSection`, so
  both surfaces get it.
- Step 14 as built: `PullRequestWatchListCubit` lives in `SessionScope`
  (one fetch for the home button, the sheet and the desktop row) and owns
  the computer-switch reset; `arrangePullRequestWatches` holds rows in
  place while a list stays open and applies the session filter. The sheet
  shows no "checked N ago" or per-row age: the wire has no poll time. No
  product analytics event: the list is a view, and its actions already
  reach the bridge as user actions. Step 16 should check the home,
  desktop sidebar and sesori-mcp regression docs agree after 14.b; step 17
  should check the button's fade and the badge roll on a device, and the
  list in dark mode.
- Step 14.b as built: the desktop sidebar's "Pull requests" row (always
  shown, red count at its end) opens `AppRoute.pullRequests()`, a page over
  the main pane (`PullRequestWatchesPage`) reporting the `sessions` screen
  (the warehouse's screen set is closed). The phone registers no such route: it uses the sheet. Loads retry
  through `ScheduledTaskRefreshDispatcher` (its name is now broader than its
  use; rename it only if a third user appears).
- Step 16 as built: the PR monitor's bridge and app behaviour, tests, failure
  signals and limits moved from `sesori-mcp.md` into
  `docs/regression/pull-request-monitor.md`; `sesori-mcp.md` keeps the groups,
  gating, the Agent tools settings, `get_guide` and skills, and links to it.
  Its L3 row is the step 17 matrix; report delivery per harness is recorded as
  not yet verified live in `HARNESS_CAPABILITIES.md`.
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
