# Tracker: bridge-pr-monitor

| Step | Title | Status | PR |
|---|---|---|---|
| 1 | 🌱 Raise the plan | Done | #2908 |
| 2 | ⚙️ Tool-group interface and grouped MCP server | Done | #2909 |
| 3 | 🌿 Per-group toggles and leaner task text | Done | #2911 |
| 4 | 🚧 Tool host: records, notices and approvals | In review | #2913 |
| 5 | ⚙️ PR monitor package: `gh` API and snapshots | Done | #2910 |
| 6 | ⚙️ PR monitor rules | Done | #2912 |
| 7 | 🚧 Watches: fan-out polling, delivery and restart | Not started | |
| 8 | 🚧 Readiness, auto-merge, feedback and reply | Not started | |
| 9 | ⚙️ `configure_pr_monitor` | Not started | |
| 10 | ⚙️ Guides and skills on Claude Code and Codex | Not started | |
| 11 | ⚙️ Pi deferred tools and instructions; skills on Pi, Oh My Pi, Grok and Copilot | Not started | |
| 12 | ⚙️ Bridge projection, status and app actions | Not started | |
| 13 | ⚙️ App: row mark, composer chip and group toggles | Not started | |
| 14 | ⚙️ App: watched-PR list | Not started | |
| 15 | ⚙️ Sesori tools on OpenCode | Not started | |
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
- For step 7, from step 4 as built:
  - The orchestrator already builds `ToolGroupApprovalService` and starts and
    disposes every group (`OrchestratorSession._startToolGroups`, after the
    MCP drain on shutdown). No host exists yet: step 7 builds one
    `SesoriToolRecordRepository(dao: SesoriToolRecordDao(...), clock: clock)`
    and a `BridgeSesoriToolHostImpl` for the PR monitor group.
  - Store values are JSON maps; `put…` replaces by key, and a session record
    for an unstored session throws (foreign key). A claim that must not
    resurrect an ended watch should check the record inside the claim.
  - `host.enabled` is false while either the group's toggle or the
    `agent-tools` master switch is off; `enabledChanges` emits only this
    group's flips.
  - `requestApproval` skips the card only when both the caller and its root
    session approve everything, as wake-up commands do, and returns
    `dropped` for an unstored session or at bridge stop.
- Group ids live in `bridge/app/lib/src/repositories/models/sesori_tool_group_ids.dart`
  (`SesoriToolGroupIds.all`), because launches, the CLI and scheduled runs
  read them before the groups are built. Step 7 adds the PR monitor's id there,
  in `tools/list` order, beside adding its group to the orchestrator's list;
  the orchestrator asserts the two match.
- Step 13's wire is in place: `GET /settings` sends `toolGroups` (id, title,
  summary, enabled) and `PATCH /settings` takes `BridgeSettingUpdate.toolGroup`.
  An older bridge omits the list and answers the update with 400 `unknown`.
- `test/bridge/sesori_mcp/goldens/tools_list.json` pins `tools/list`; rewrite
  it with `SESORI_UPDATE_GOLDENS=1` after an intended change.
- Hermes gets the Sesori MCP from a separate PR outside this plan. The
  verification matrix includes it once that PR lands.
- Step 6 added `PullRequestBaseline` (seen comment ids per channel and the
  unresolved-thread count) as the report builder's input; a null baseline is
  a watch's first report. Step 7 extends it with the signatures, state and
  mergeable it stores, and appends the plugin's startup assessment paragraph
  to a new watch's first report. `PullRequestComment` now carries `body` for
  the feedback builder; the stored baseline must not. Step 8 adds the
  readiness-error and auto-merge-notice report lines and the auto-merge
  guidance text. Report and feedback texts name the bridge tools
  (`mark_pr_ready`, `reply_on_pr` with `thread_id`) instead of `pr_monitor`.
