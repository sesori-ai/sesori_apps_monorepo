# Bridge PR monitor and Sesori tool groups

Read against `origin/main` at `ffc98ee6f3` (2026-11-24). Product version
1.16.0 (unreleased; v1.15.0 is the latest public release). The plugin
behaviour being ported is in [PR_MONITOR_SPEC.md](PR_MONITOR_SPEC.md).

## Goal

- **The PR monitor moves into the bridge.** Today it is a harness plugin
  (`sesori-ai/opencode-pr-monitor` v0.10.0). It disarms when Sesori restarts,
  when the session or the network drops, and it behaves differently on each
  harness. In the bridge, a watch is a Sesori MCP tool call. The bridge polls
  GitHub through the user's `gh` CLI, and reports arrive as Sesori Automation
  messages on every harness that gets the Sesori MCP. Watches are stored, so
  they resume after a restart.
- **The Sesori MCP server gets tool groups.** There is one server. Each group
  has a purpose: Pages, Wake-ups, Scheduled tasks, PR monitor. Groups follow
  one Dart interface that future Sesori tool plugins (community ones included)
  will implement. Each group has a global on/off toggle, and a session's
  `tools/list` shows only its enabled groups.
- **Context stays lean.** A group's long how-to goes into a skill, injected
  where the harness allows. A `get_guide` tool is the fallback. Tool
  descriptions say plainly when to reach for each tool. The duplicated task
  text is removed.

## Scope

In phase 1:

- The tool-group interface package, and the MCP server restructured around
  groups (the existing tools become in-app groups).
- Per-group toggles in bridge settings, the CLI and the app.
- A durable tool host: record storage, session notices and approvals for
  groups.
- The PR monitor package, with v0.10.0's rules, fan-out polling, persistence
  and restart resume.
- A `configure_pr_monitor` tool.
- Guides: `get_guide`, plus skill injection on Claude Code, Codex, Pi, Oh My
  Pi, Grok and GitHub Copilot, each verified live. Pi also gets deferred tools
  and the server instructions.
- A per-session mark: the session row mark and the composer chip.
- The watched-PR list across sessions (option B, chosen by the owner): a PR
  button in the home top bar opening a grouped sheet, and a "Pull requests"
  sidebar row on desktop (step 14).
- Sesori tools on OpenCode (step 15; client-MCP WebSocket relay). Hermes
  gets the Sesori MCP from a separate small PR outside this plan
  (`injectsSesoriTools` on, version-gated at Hermes 0.22.3, which scopes MCP
  per ACP session), so the PR monitor reaches it with no step here.
- Regression docs and `docs/HARNESS_CAPABILITIES.md`.

Not in phase 1 (see [Later phases](#later-phases-rough-intent-only)): the
GitHub App and webhooks, labels and profiles for non-dev sessions, and
out-of-process community plugins.

**Reversal noted.** `.plan/completed/pr-tracking-removal/PLAN.md` records "The
bridge never runs `gh` and never calls GitHub". The owner has reversed that for
this feature. GitHub access is still opt-in by use: the bridge calls `gh` only
for PRs an agent asked it to watch, and only while the PR monitor group is
enabled.

## Current behaviour this builds on

- **MCP server.** The transport is `bridge/app/lib/src/foundation/sesori_mcp_server.dart`:
  loopback streamable HTTP, JSON replies only, with no SSE stream. A server
  push such as `notifications/tools/list_changed` is therefore impossible, and
  `initialize` advertises `listChanged: false`. The protocol is
  `routing/sesori_mcp/sesori_mcp_request_dispatcher.dart`. It has one switch
  over the closed `SesoriMcpTool` enum (14 tools: 8 for tasks, `send_page`, and
  3 for wake-ups), one shared instructions string, and an unfiltered
  `tools/list`. Formatting lives in `sesori_mcp_result_formatter.dart`, and the
  argument models in `models/sesori_mcp_tool_arguments.dart`.
- **Identity.** A harness plugin calls `PluginHost.sesoriMcp.mint()`
  (`SesoriMcpAccess`, `sesori_plugin_interface`) before each launch and
  `bind()` once it knows the backend session id. `SesoriMcpGrantRepository`
  keeps token → `SesoriMcpGrantUnbound`/`Bound` in memory.
  `SesoriMcpAccessService.resolve` maps a bound grant to
  `SesoriMcpCaller(sessionId)`.
- **Gating.** The global `agentTools` bridge setting is CLI-only
  (`sesori-bridge config agent-tools on|off`); `mint()` returns null when it is
  off. Each descriptor declares `injectsSesoriTools`. Claude Code, Codex, Pi,
  Oh My Pi, Grok and Copilot are on. Hermes is off on `main`; a separate PR
  turns it on from Hermes 0.22.3, whose gateway scopes MCP per ACP session.
  OpenCode has no verified launch-time seam yet (step 15),
  DeepSeek rejects MCP, and Cursor and Antigravity are unverified.
- **Size.** `tools/list` is about 17.5 KB (about 4.4k tokens). `create_task` and
  `update_task` are about 43% of it, because `update_task` repeats every
  setting's description with "leave out to keep".
- **Delivery.** `SessionNoticeService.deliver(sessionId, notice, timing, claim)`
  sends a `PromptStampNotice` that the app shows as a Sesori Automation row.
  It returns `sent | skippedInactive | claimLost | dropped`; `claim` runs on
  the session lane right before the send. `SessionWakeUpService` is the
  durable precedent: the `session_wake_ups` table (cascade on session delete),
  a 30 s `SessionWakeUpTimerListener`, claim-before-send (lose, never
  duplicate), the family root as target, and a direct
  `SessionMutationDispatcher.armingUpdated` call republishing the session.
- **Approvals.** `AgentApprovalRepository` holds the sealed
  `AgentApprovalChange` (`ScheduledTaskAgentChange`, `WakeUpCommandChange`).
  `ScheduledTaskAgentService.settle` routes replies. YOLO never answers agent
  approvals, and a restart drops pending ones.
- **App marks.** `Session.wakeUps` and `Session.arming` (`SessionArming`:
  `unreported | notArmed | armed(name, nextAt)`) are unreleased v1.16.0
  fields. `SessionScheduledMarkCalculator` (`module_core`) picks the row mark
  and the chip's time. `session_wake_up_chip.dart` (`module_app_ui`) is the
  composer chip and its menu with Cancel.
- **Bridge settings over the wire.** `BridgeSettingsResponse` and the
  `BridgeSettingUpdate` union (`yolo`, `warmUpPluginsOnSessionOpen`, …) through
  `patch_bridge_settings_handler.dart`. The app's settings screens are in
  `client/app` and `client/desktop`.
- **Processes.** `CommandExecutor` / `HostProcessCommandExecutor`
  (`sesori_bridge_foundation`) runs a binary with a timeout. A supervised
  desktop bridge gets the user's login-shell environment, so `gh` on the
  user's PATH and `GH_TOKEN` work as in a terminal. The deleted `GhCliApi`
  (`git show 13a534e9c5^:bridge/app/lib/src/api/gh_cli_api.dart`) is the
  pattern for the API class: availability and auth checks with actionable
  messages, and typed Freezed results.
- **Pi.** `bridge/sesori_plugin_pi/lib/src/api/pi_rpc_startup_extension.dart`
  calls `tools/list` at load and registers every tool up front with
  `pi.registerTool`. It never forwards the server's `instructions`.

## Design

### Packages and layers

| Package | Depends on | Owns |
|---|---|---|
| `bridge/sesori_tool_interface` (new) | `sesori_plugin_interface` (`Log`) | The contract between the bridge and a tool group: `SesoriToolGroup`, `SesoriToolDefinition`, `SesoriToolCaller`, `SesoriToolResult`, `SesoriToolGuide`, `SesoriToolHost` and its store, notice and approval types, plus the strict-schema argument helpers that `_requiredText` and `_optionalText` implement today. Pure, with no I/O. |
| `bridge/sesori_tool_pr_monitor` (new) | the tool interface, `sesori_bridge_foundation` (`CommandExecutor`), `sesori_shared` (JSON helpers, Freezed) | The PR monitor: `GhCliApi`, the snapshot mapper, pure rules, the watch service, the group with its tools, and its guide text. |
| `bridge/app` | both | The host implementation, the in-app groups (pages, wake-ups, tasks), the MCP protocol, settings, projection and routes. `orchestrator.dart` composes the PR monitor package: it builds `GhCliApi`, the package's repositories, services and listener, and `PullRequestMonitorToolGroup`. Beyond the orchestrator, only `SessionViewService` (reads `PullRequestWatchRepository`) and `StopPullRequestWatchHandler` (calls `PullRequestWatchService`) import the package's exported API. |

The module order in `bridge/AGENTS.md` and the structure list in
`bridge/app/AGENTS.md` gain the two packages. The interface sits after
`sesori_plugin_interface`, and the PR monitor sits beside the harness plugins.
Tool packages never import harness plugins, and harness plugins never import
tool packages.

**Task management stays in the app**, behind the same interface. Pages,
wake-ups and tasks become in-app `SesoriToolGroup` classes in
`bridge/app/lib/src/routing/sesori_mcp/groups/`. They are layer 4 and call
today's services, so every group has one shape. They do not move into their
own packages. Their services are woven into the app's scheduling, approval and
session core, and a package would only add a host surface wide enough to
reach all of it. This is recorded as decided, not deferred.

### The tool-group interface

```dart
abstract class SesoriToolGroup {
  SesoriToolGroupId get id;            // "pr_monitor", "tasks", "wake_ups", "pages"
  String get title;                    // settings toggle label
  String get summary;                  // settings subtitle
  String get instructions;             // one sentence for MCP `instructions`
  List<SesoriToolDefinition> get tools; // name, description, inputSchema, readOnly
  SesoriToolGuide? get guide;          // name, when-to-use line, Markdown body
  Future<void> start();                // begins resume and triggers; deps arrive via the constructor
  Future<SesoriToolResult> call({required String tool, required SesoriToolCaller caller,
                                 required Map<String, Object?> arguments});
  Future<void> dispose();
}
```

- `SesoriToolGroupId` is a small value type over the wire id. Ids are open
  strings, as plugin ids are, because future plugins name their own. Every
  in-repo id is a named constant.
- A tool name is unique across groups. The dispatcher asserts this when it is
  constructed, in tests and debug builds.
- `SesoriToolResult` is a sealed `ok(text)` or `error(text)`. An
  `InvalidToolArguments` exception thrown inside `call` becomes the existing
  "Invalid arguments for X: …" result, so groups keep today's parse style.
- **The host** (`SesoriToolHost`) is implemented in the app as
  `BridgeSesoriToolHostImpl` in `server/host/`, beside
  `bridge_sesori_mcp_access_impl.dart`. There is one instance per group, and
  the orchestrator builds it before the group, which receives it, or the
  pieces of it the group's own repositories need, through its constructor.
  Its constructor takes the group id, `SesoriToolRecordRepository`,
  `SessionNoticeService`, `SessionRepository`, `BridgeSettingsRepository` and
  `ToolGroupApprovalService`. It offers:
  - `store`: a `SesoriToolStore` scoped to the group (see below).
  - `enabled` and `Stream<bool> enabledChanges`, fed from
    `BridgeSettingsRepository.settingsChanges`, so a group can pause work
    while its toggle is off.
  - `deliverNotice({sessionId, summary, guidance, timing, claim})` returns the
    `SesoriToolNoticeOutcome` mirror of `SessionNoticeOutcome` and delegates
    to `SessionNoticeService.deliver`. `timing` mirrors `SessionNoticeTiming`.
  - `sessions({required Set<String> sessionIds})` returns
    `Map<String, SesoriToolSession>` (root session id, working directory,
    `archived`). Unknown ids are absent. It is read through
    `SessionRepository`, with root resolution through
    `resolveSessionFamily`, as wake-ups do. One call serves a whole poll.
  - `requestApproval({sessionId, title, body})` returns
    `Future<SesoriToolApprovalOutcome>` (`allowed | rejected | dropped`). It
    delegates to one app-level `ToolGroupApprovalService` (`services/`). That
    service adds a `ToolGroupAgentChange` family to `AgentApprovalChange`
    through `AgentApprovalRepository`, holds the completers keyed by request
    id, and is the target `ScheduledTaskAgentService.settle` routes
    `ToolGroupAgentChange` replies to, as it routes `WakeUpCommandChange` to
    `applyCommandApproval`. The existing card and push show it. A restart
    drops it (`dropped`), as for every agent approval. **With YOLO on, it
    returns `allowed` at once and shows no card** (owner decision for tool
    groups; task approvals keep their own rule). The group applies an
    allowed change and sends its own outcome notice.
- **Labels.** "Development" and other labels are not part of the phase-1
  interface: nothing would read them. Adding a field later is an in-repo
  lockstep change.

### Tool storage

Two Drift tables (schema 34 → 35). The app owns the database. A package
cannot add tables, and every future group would otherwise need an app schema
change.

| Table | Columns | Key |
|---|---|---|
| `sesori_tool_session_records` | `groupId`, `sessionId` (FK `sessions_table`, `onDelete: cascade`), `recordKey`, `valueJson`, `updatedAt` | (`groupId`, `sessionId`, `recordKey`) |
| `sesori_tool_records` | `groupId`, `recordKey`, `valueJson`, `updatedAt` | (`groupId`, `recordKey`) |

- `SesoriToolStore` offers `get`, `put`, `delete` (returning whether the record
  existed) and `list` for each scope, plus `listSessionRecords()` across
  sessions for restart resume. The DAO stays dumb, and the repository
  (`SesoriToolRecordRepository`) maps rows.
- Each group owns its JSON format, parsed with Freezed at the group's boundary.
- A session's records go with the session through the cascade. Nothing else
  sweeps them.

### Grouped MCP server

- The orchestrator constructs every group, in the order tasks, pages,
  wake-ups, PR monitor (the first three keep today's `tools/list` order
  byte for byte), and hands the `List<SesoriToolGroup>` to
  `SesoriMcpRequestDispatcher`, which checks tool-name uniqueness at
  construction. There is no separate registry class. The orchestrator
  starts each group after the database opens, and disposes them after
  `SesoriMcpRequestDispatcher.drain()` and before the database closes.
- **The grant snapshots the enabled groups at mint.**
  `SesoriMcpGrantUnbound`/`Bound` gain `groups: Set<SesoriToolGroupId>`, read
  from settings in `BridgeSesoriMcpAccessImpl.mint()`. `mint()` returns null
  when `agentTools` is off or no group is enabled. A session's list therefore
  stays stable for its launch, which matches "read at each launch". A toggle
  takes effect at the next launch or resume. Later per-session profiles
  change only what goes into this set.
- **The dispatcher** keeps `initialize`, `ping`, `tools/list` and `tools/call`,
  and drops the enum and the switch.
  - `tools/list` lists the grant's groups' tools, plus `get_guide` when any of
    those groups has a guide.
  - `tools/call` finds the owning group among the grant's groups. A tool
    outside the grant gets the same "Unknown tool" error as a name that does
    not exist.
  - Caller resolution, `_InvalidArguments` mapping and the failure log stay
    where they are.
- **Instructions** are one line about Sesori, then each enabled group's
  `instructions` sentence, then "For a group's full how-to, load its
  `sesori-…` skill if you have it, otherwise call `get_guide`." That last line
  appears only when a guide exists.
- **`get_guide(topic)`** (read-only) takes an enum of the grant's guide
  topics. Its description reads: "Read the how-to for a Sesori tool group
  before you first use it, unless its Sesori skill is already loaded. Topics:
  `pr_monitor`: watching a GitHub PR after you open it or are asked to watch
  one, and handling `[PR Monitor]` messages." Each topic adds one when-to-use
  clause. The result is the guide's Markdown body.
- **Dedupe.** `create_task` keeps the full setting descriptions. Each
  `update_task` field drops the repeated text for "Same as create_task." The
  tool's own description says once that left-out fields keep their value. The
  shared constants in `sesori_mcp_tool.dart` move with the tasks group.
  Measure `tools/list` before and after and record both sizes in the PR.
  Copilot's strict-schema evidence in `HARNESS_CAPABILITIES.md` shows models
  fill every field, so the "leave out" rule stays once, in the description.

### Gating and settings

- **Bridge.** `BridgeSettings` gains
  `agentToolGroups: BridgeAgentToolGroupSettings(disabled: Set<String>)`,
  modelled on `plugins.disabled`: a group is enabled unless it is listed.
  Unknown ids are kept and ignored. The master `agentTools` switch stays,
  and since step 13 the app sets it too.
  - CLI: `sesori-bridge config tool-group <id> [on|off]`. With no id it lists
    each group with its state.
- **Wire, additive.**
  - `BridgeSettingsResponse.toolGroups: List<BridgeToolGroupSetting>` (id,
    title, summary, enabled), `@Default([])` with the dated
    `COMPATIBILITY 2026-11-24 (v1.16.0)` comment that older bridges omit it.
  - `BridgeSettingUpdate.toolGroup(id, enabled)`.
  - An older app ignores both. A newer app hides the section when the list is
    empty.
  - Step 13 adds the master switch: `BridgeSettingsResponse.agentToolsEnabled`
    (`bool?`, null from v1.15.0 bridges, with a dated `COMPATIBILITY` comment)
    and `BridgeSettingUpdate.agentTools(enabled)`. An older bridge answers
    the update with 400 `unknown`, which the app shows as needing a bridge
    update. The CLI command keeps working.
- **App.** `module_core`'s `BridgeSettingsRepository` and
  `BridgeSettingsCubit` gain the tool-group list and a `setToolGroupEnabled`
  action. The phone and desktop settings screens render an "Agent tools"
  section from that state, with one switch per group: the bridge's title and
  summary, and a footnote that changes apply to sessions started or resumed
  afterwards. The bridge sends titles, so a future group needs no app
  release.
- **When a group is off,** its tools are not listed. The PR monitor group
  also stops polling: its poll listener skips ticks while
  `host.enabled` is false, and its watches stay stored and resume when the
  group is turned on again.

### Guides and skills

- A group's `SesoriToolGuide` is the single source for both its skill and its
  `get_guide` text. Phase 1 has one guide, the PR monitor's. It is adapted
  from the plugin's `skills/monitor-pr/SKILL.md` to the bridge's tools and
  delivery: there is no keep-alive and no `await-activity`, and reports simply
  arrive. Its frontmatter `description` is the when-to-use line: "Use right
  after you open a GitHub PR, when asked to watch or babysit a PR, and every
  time a `[PR Monitor]` message arrives." The body keeps the plugin's rules on
  acting on every report, prefixed replies, readiness and auto-merge.
- **The bundle.** `SesoriSkillBundleStorage` (app, layer 1, plain file
  writes) owns `~/.sesori/agent-skills/` (a new
  `sesoriAgentSkillsDirectory()` in foundation). `SesoriSkillBundleListener`
  (`listeners/`) runs once at start and on
  `BridgeSettingsRepository.settingsChanges`, works out the enabled groups
  that have guides, and calls the storage. The bundle holds one skill per
  enabled group with a guide, in two layouts:
  - a Claude-style plugin root (`.claude-plugin/plugin.json` named `sesori`
    plus `skills/pr-monitor/SKILL.md`), which surfaces as `sesori:pr-monitor`;
  - a plain skills root (`skills-root/sesori-pr-monitor/SKILL.md`).

  The paths are stable, so process-level seams stay valid across toggles, and
  the files hold no secrets.
- **The seam.** `SesoriMcpAccess` (plugin interface) gains
  `SesoriSkillBundle? get skillBundle` (`pluginRoot`, `skillsRoot`). It is null
  when agent tools are off or no enabled group has a guide. Each harness
  plugin maps it onto its own seam:

| Harness | Seam (to verify live in its step) | Scope |
|---|---|---|
| Claude Code | `--plugin-dir <pluginRoot>` on launch, resume and respawn | Per process (one per session) |
| Codex | `skills/extraRoots/set` with `skillsRoot` on the app-server | App-server wide |
| Pi | `--skill <skillsRoot>/<name>`, or `resources_discover` in the startup extension | Per process |
| Oh My Pi | `acp --config` overlay with `skills.customDirectories` | Process wide |
| Grok | `agent --plugin-dir` | Process wide |
| GitHub Copilot | `COPILOT_SKILLS_DIRS`, or `--plugin-dir` | Process wide |

  A seam that fails live verification is not wired. That harness relies on
  `get_guide`, and the gap is recorded in `HARNESS_CAPABILITIES.md`.
  Process-wide seams pick up a toggle when the harness process restarts;
  until then the stale skill only points at a tool that is no longer listed,
  and its text says to call `get_guide` or skip it when the tools are absent.
- **Pi.** The startup extension forwards the server's `instructions` through
  Pi's system-prompt hook for extensions. It registers Sesori tools deferred
  if the pinned Pi offers deferred or searchable tool registration. If Pi
  offers none, tools stay registered up front and the gap is recorded. Verify
  both against the pinned Pi version.

### PR monitor

The rules port v0.10.0 one-for-one: actions, GraphQL fields and pagination,
normalization, activity, the quiet window (2 min), the CI hold (30 min),
urgent triggers, idle reminders (25 min), report text, handled-thread and
readiness rules, the `agent-ready` label, and auto-merge (one squash pinned to
the head with the PR title and an empty body, then the `automatically-merged`
label). These deliberate differences follow from running in the bridge:

| Topic | Plugin | Bridge |
|---|---|---|
| Polling | One poll per watch per harness process | One poll per PR per bridge every 60 s, fanned out to every watching session |
| State | In memory; lost with the process | Watches stored per session and resumed after a restart |
| Delivery | Harness-specific push, spool, hooks, keep-alive | `host.deliverNotice` with a claim; no keep-alive is needed |
| `gh` | No timeout | 60 s timeout per call. A timeout is an ordinary poll failure, and ten in a row stop the watch, as today |
| Reply prefix | Configurable (`ignoreCommentTag`) | Fixed `[Sesori reply]`, which this repo and the owner's merge gate already use |
| Labels | Configurable `readyLabel` | Fixed `agent-ready` and `automatically-merged` |
| Config | Global and project JSON files, env var | `configure_pr_monitor` only. The plugin's files are not read |
| Start report | Every existing comment counts as new, and a start-time label reset applies under auto-merge | Kept for a new watch. After a restart, a watch compares against its stored baseline instead |
| Identifier | Explicit `owner/repo#N` or URL | Same |

**Ownership inside the package** (`lib/src/{api,repositories,services,listeners,group}/`):

| Layer | Class | Owns |
|---|---|---|
| api | `GhCliApi` | `gh` on PATH through `CommandExecutor`: availability, `api user`, the GraphQL poll and its follow-up pages, labels, merge, comment and thread reply. Typed Freezed DTOs; it throws a typed `GhCliException` (`notFound`, `httpStatus`, `timedOut`, `unavailable`, `unauthenticated`) that carries the original error. |
| repositories | `PullRequestSnapshotRepository` | Calls `GhCliApi` and maps the DTOs to the normalized `PullRequestSnapshot` (spec §2), with pagination. |
| repositories | `PullRequestActionRepository` | The GitHub writes and identity: labels, the pinned squash merge, top-level comments and thread replies, and the cached `gh api user` login. |
| repositories | `PullRequestWatchRepository` | Maps the store's session records (key `owner/repo#n`, lowercased) to `StoredPullRequestWatch` and its bridge record to `PullRequestMonitorConfig`. |
| services | `PullRequestActivityCalculator`, `PullRequestReadinessCalculator`, `PullRequestReportBuilder`, `PullRequestFeedbackBuilder` | The rules in spec §3–§6 and §9, as pure classes with direct tests. |
| services | `PullRequestMergeService` | The readiness-label and auto-merge flow (spec §6–§7) through `PullRequestActionRepository`. It is stateless: it takes the PR's merge state and the snapshot, and returns the new merge state. |
| services | `PullRequestWatchService` | The single owner of the per-PR runtime (including its merge state) and op queue. It runs `pollDue()`, fan-out, timing, delivery and claims, and restart resume, and backs every tool action, calling `PullRequestMergeService` inside the op queue. A `mark_pr_ready` or `unmark_pr_ready` on an unwatched PR only changes the label, directly, with no runtime. Exposes `Stream<Set<String>> watchesChanged` (session ids). |
| listeners | `PullRequestPollListener` | The 30 s periodic tick, as `SessionWakeUpTimerListener` does for wake-ups. It calls `pollDue()` while `host.enabled`. |
| group | `PullRequestMonitorToolGroup` | Tool definitions, argument parsing, result texts and the guide. All nine tools call `PullRequestWatchService`, which reads and writes through the repositories. `get_pr_feedback` and `reply_on_pr` call GitHub directly, outside the op queue: they change no watch state. `configure_pr_monitor` also goes through the service, which owns the config record. |

The package exports `PullRequestWatchService`, `PullRequestWatchRepository`
and the group for the app's composition, projection and stop route.

**Fan-out model:**

- **Per PR, shared, in memory** (`_PullRequestRuntime`, keyed by the
  lowercased `owner/repo#n`):
  - the last snapshot and `lastDefiniteMergeable`;
  - the activity clock (`dirty`, `urgent`, `lastActivityAt`, `holdStartedAt`);
  - readiness and merge state (retry and error, `mergeStuck`,
    `readinessResetPending`);
  - one serial op queue.

  It exists while at least one watch on that PR exists. Because labels and
  merges are PR facts, a `mark_pr_ready` from any session applies to the PR,
  and every watcher's next report shows it.
- **Per watch, stored:** session id, PR key, URL and title, `autoMerge`, the
  baseline (a compact `PullRequestBaseline`: comment, review and thread ids
  with their signatures, the CI signature, state and mergeable, and no
  bodies), `lastReportAt`, and `announced`.
- **Reports.** When the PR's clock says a report is due, each watcher gets a
  report rendered against its own baseline. A watcher whose baseline already
  matches gets nothing. `get_pr_report` (flush) renders for the caller only
  and advances only the caller's baseline.
- **Auto-merge** is stored per watch. It is effective for the PR when any
  watcher has it on, and status shows which. Turning it off in one session
  never vetoes another session's opt-in.
- **Polling.** A periodic timer (30 s) polls each PR whose last poll is 60 s
  old or more, sequentially, through its op queue. A tick is skipped for a PR
  whose op is still running, as in the plugin. There is no parallelism.
  GraphQL cost is about one point per poll, so 50 watched PRs use about 3,000
  of the 5,000 points per hour. The guide says so, and status shows the count
  of watched PRs.
- **Session target and lifetime.**
  - The watch lands in the caller's family root, as wake-ups do.
  - Each poll drops watchers whose session is archived or gone, with one
    batched `host.sessions` lookup.
  - A deleted session's records go by cascade.
  - A watch ends on a terminal report's claim, on `unwatch_pr`, on the app's
    Stop, on not-found, or after ten consecutive poll failures. Each end
    except unwatch and Stop sends the stop notice.
  - **Merged stays listed until end of day.** A merged report's claim marks
    the record `merged` with `mergedAt` instead of deleting it. It no longer
    polls. The first tick after local midnight deletes merged records, and
    the session cascade still applies. Every other end deletes the record.
- **Delivery.**
  - Reports use `SessionNoticeTiming.derived`: a steering harness hears an
    urgent report mid-turn, as Claude Code does with the plugin today, and the
    others after the turn.
  - Idle reminders use `afterTurn`.
  - Summary line: `PR monitor: owner/repo#12 — <reason>` (for example "2 new
    comments, CI failing"). The guidance is the report.
  - Each watch has at most one delivery in flight. Activity that arrives while
    one waits goes into the next report.
- **The claim, which is the restart rule.** Inside the lane right before the
  send, the claim checks that the watch record still exists and writes the
  watch's new baseline and `lastReportAt`. A terminal report's claim deletes
  the record instead (or marks it merged, above). A crash between the claim and the send loses that one
  report and never duplicates it, as for wake-ups. `claimLost` (the watch
  ended while waiting) drops the report. `dropped` leaves the baseline alone,
  so the next due check re-reports.
- **Restart.** At `start`, the service loads every watch record and builds
  the per-PR runtimes. The first poll compares each watcher's stored baseline
  with the fresh snapshot. A difference counts as activity at that moment, so
  a merge, close, conflict or new CI failure while the bridge was off reports
  at once (urgent), and everything else after the quiet window. That report
  starts with "Resumed after the bridge restarted; this covers changes since
  the last report." In-memory readiness retry and `mergeStuck` reset. The
  next report or reminder recomputes them from the label and snapshot, which
  can cost one extra idle reminder. That is accepted.
- **Identity.** `gh api user` is resolved once per bridge, retried on failure,
  and checked at each `watch_pr`. A missing `gh` or failed auth returns an
  actionable error: install `gh` or run `gh auth login` / `gh auth status`.

**Tools** (one per action). Every description says when to use it:

| Tool | Read-only | Notes |
|---|---|---|
| `watch_pr(pr, auto_merge?)` | no | "Call right after you open a PR, or when asked to watch one." Reports arrive as messages: end the turn and don't poll. With `auto_merge` left out, the configured default for the repo applies |
| `unwatch_pr(pr)` | no | Only this session's watch |
| `pr_watch_status()` | yes | This session's watches (the plugin's status line) and the effective config |
| `get_pr_report(pr)` | yes | The plugin's flush; the caller's baseline only |
| `get_pr_feedback(pr)` | yes | Feedback awaiting a reply, with bodies (spec §9). No watch needed |
| `reply_on_pr(pr, body, thread_id?)` | no | Adds the `[Sesori reply]` prefix. No watch needed |
| `mark_pr_ready(pr)` / `unmark_pr_ready(pr)` | no | The label, and merge when effective auto-merge is on. Standalone when unwatched (spec §7) |
| `set_pr_auto_merge(pr, enabled)` | no | This session's watch |
| `configure_pr_monitor(...)` | no | Below |

Reading `readOnly` this way matches today's `send_page` (read-only, since it
writes nothing on GitHub). Copilot asks its own permission before every
non-read-only tool, as recorded in `HARNESS_CAPABILITIES.md`.

**`configure_pr_monitor`**:

- Arguments: `auto_merge` (`on | off`), with an optional `repository`
  (`owner/repo`) for a per-repo override; `clear_repository` to remove an
  override; `quiet_minutes` (1–60), `ci_wait_minutes` (5–240) and
  `idle_reminder_minutes` (0 = off, else 5–240). Timeouts are global only.
- It is stored in the group's bridge record as `PullRequestMonitorConfig`.
  The defaults are the plugin's, with auto-merge off everywhere. Nothing is
  imported or migrated from the plugin's config files or `.pr-monitor.json`.
- The repo override wins over the global default when `watch_pr` leaves
  `auto_merge` out. Existing watches keep their choice. New timeouts apply to
  every watch at the next poll.
- **Approval (owner decision).** A change that widens auto-merge (the global
  default to on, or a repo override to on) goes through
  `host.requestApproval`. The card names the scope. The tool returns "Sent to
  the user for approval…" and the session hears the outcome through the
  usual notice. With YOLO on there is no card: the change applies at once
  and the tool says so. Narrowing changes and timeouts apply at once. Per-PR
  opt-in through `watch_pr` and `set_pr_auto_merge` stays as today, with no
  Allow.

### Wire and app

- **`Session.pullRequestWatches: List<SessionPullRequestWatch>`** (additive):
  `repository`, `number`, `title`, `url`, `autoMerge`, `status`. It defaults
  to empty with `// COMPATIBILITY 2026-11-24 (v1.16.0): bridges before the
  bridge PR monitor omit the list, which honestly means none. Remove the
  default once the minimum supported bridge always sends it.`
  - `status` is a sealed `PullRequestWatchStatus` (unionKey `kind`, fallback
    `unknown`): `needsYou(reasons)`, `waiting`, `ready`, `merged(mergedAt)`.
    `reasons` is a non-empty list of the closed enum `ciFailing | conflict |
    newReviewComments | readyWithoutAutoMerge`. This is the owner's red-count
    rule: a Ready PR whose auto-merge is off needs the user.
  - `PullRequestWatchService` computes it from the PR's last snapshot and
    the watch: unhandled threads (no `[Sesori reply]`) are new review
    comments, the `agent-ready` label is ready, and merged records are
    merged. "Needs you" wins over the others.
  - `SessionViewService` reads it through `PullRequestWatchRepository` (the
    app composes the package, as wake-ups compose their repository).
  - The orchestrator subscribes to `watchesChanged` and maps each session id
    to `SessionMutationDispatcher.armingUpdated`, the call
    `SessionWakeUpService` makes directly (the package cannot import the app,
    hence the stream).
- **`SessionArming` is unchanged.** A watch has no next time, and the app can
  derive the mark from the list. `SessionScheduledMarkCalculator` gains a
  `watchingPullRequests(lead, others)` mark. `lead` is the PR that needs the
  user most (needs you, then ready, then waiting, then merged; ties by
  number), and `others` is the "+N". A timed `armed` mark wins; a watch wins
  over the plain task mark.
- **App actions on one watch.** `POST /session/pull-request-watch/stop` and
  `POST /session/pull-request-watch/auto-merge`, with
  `StopPullRequestWatchRequest(sessionId, repository, number)` and
  `SetPullRequestWatchAutoMergeRequest(sessionId, repository, number,
  enabled)` in `sesori_shared`. Their handlers call
  `PullRequestWatchService.stopFromApp` and `setAutoMergeFromApp`. The user
  needs no Allow for their own per-PR choice. The agent is not told, as for a
  wake-up cancelled in the app. An older bridge never sends watches, so the
  app never offers these to it.
- **The cross-session list.** `GET /pull-request-watches` returns
  `PullRequestWatchListResponse(watches: [PullRequestWatchListItem(sessionId,
  sessionTitle, projectId, watch)])` for every watch on this bridge,
  including today's merged ones. A `pullRequestWatchesChanged` event on
  `SesoriSseEvent` tells the app to refetch; older apps already skip unknown
  event types. The orchestrator emits it from `watchesChanged`.
- **`module_core`.**
  - `SessionApi` and `SessionRepository` gain `stopPullRequestWatch` and
    `setPullRequestWatchAutoMerge`, called by `SessionDetailCubit` and the
    list cubit, as `cancelWakeUp` is today.
  - A `PullRequestWatchApi` → `PullRequestWatchRepository` (client) serves
    the list route and the change event. A `PullRequestWatchListCubit` holds
    the grouped list, the needs-you count, and an optional session filter.
  - The calculator change.
  - **Other computers.** The sheet lists only the current computer's PRs
    (owner, 2026-11-25). A cross-computer "pending input" highlight is a
    separate future feature, not part of this plan.
- **`module_app_ui`, the session and composer.** This follows the wake-up
  precedent:
  - The session row shows the lead PR (`#123`, coloured by its status) plus
    `+N` with a pull-request glyph, unless a timed armed mark wins.
  - The composer chip shows while a wake-up or a watch exists. With watches
    it shows the glyph and the count; with a wake-up too, the wake-up's time
    leads. With the list sheet in place (step 14), tapping the PR part opens
    the sheet filtered to this session. Before that (step 13), its menu lists
    this session's PRs with Stop watching. This interim menu is small and is
    replaced in step 14.
  - The chip fades in place in its existing row, and mark changes cross-fade,
    so nothing above the transcript moves.
- **`module_app_ui`, the list (option B).** The owner approved the option-B board
  mock in the design review (a temporary local copy is at
  `/tmp/pr-list-mocks/option-B-board.png`). The step attaches its own
  fixture visuals.
  - **Home top bar:** a PR button left of the computer and Settings buttons.
    It shows only while at least one PR is watched, and appears and
    disappears with a fade and scale, without moving the other buttons. It
    shows a red badge with the needs-you count only when that count is above
    zero, and the count rolls when it changes.
  - **The sheet** opens over home. It groups rows as Needs you, Waiting,
    Ready, and Merged today. Each row shows `owner/repo#N`, the title, the
    session, the reasons or state, and an auto-merge mark.
    - Tap opens the session. Swipe shows Auto-merge (toggle) and Stop.
    - While the sheet is open, a row changes its state in place; it does
      not jump between groups. It regroups on the next open, so nothing
      moves under the user's finger.
    - Opened from the composer chip, it is filtered to that session.
  - **Desktop:** a "Pull requests" sidebar row under Scheduled opens the same
    list in the cockpit's content area.
- **Each app step** brings its l10n, widget tests, and before and after
  visuals in the PR.

## Complexity budget

- **New persistent parts:**
  - the two tool-record tables: one generic home instead of one table per
    future group;
  - `agentToolGroups.disabled` in bridge settings;
  - the PR monitor's watch records (one per session and PR) and its config
    record; merged ones stay until local midnight for the list;
  - the skill bundle folder, regenerated whole, holding no state.
- **New in-memory parts:**
  - the grant's immutable group set;
  - `_PullRequestRuntime` per watched PR, because one poll serves many
    watchers;
  - one periodic timer;
  - one in-flight delivery flag per watch;
  - the cached `gh` login;
  - pending approval completers, held by `ToolGroupApprovalService` and keyed
    by request id, for the configure approval only;
  - in the app, the list cubit's state, plus the open sheet's frozen group
    order, which lives only until the sheet closes.
- **Deliberately not added:**
  - SSE or `listChanged` pushes;
  - per-session profiles or labels;
  - parallel polling, rate-limit backoff beyond the 60 s cadence and the
    ten-failure stop, and webhooks;
  - reading the plugin's config files or the `SESORI_PR_MONITOR_AUTO_MERGE`
    env var;
  - a configurable prefix or label;
  - persisting per-PR readiness retry or `mergeStuck`;
  - a generic "tool marks" wire shape: the PR list is typed, because the
    app renders PR-specific details;
  - moving tasks, pages or wake-ups into packages;
  - analytics: the authoritative outcomes happen on the bridge, which has no
    product-analytics path, as in the wake-ups plan.

## Steps

Titles follow `<emoji> [bridge-pr-monitor] … [step x/17]`. Line estimates
count additions plus deletions, excluding generated files unless noted.

1. 🌱 **Raise the plan.**
2. ⚙️ **Tool-group interface and grouped MCP server** (~1,300; mostly moves).
   - New `sesori_tool_interface` package.
   - Pages, wake-ups and tasks become in-app groups, built by the
     orchestrator.
   - The dispatcher takes the group list, checks name uniqueness, and lists
     and dispatches by group. `SesoriMcpTool` goes, and
     the formatter splits per group.
   - Instructions are assembled from groups.
   - Bridge `AGENTS.md` module order, and `bridge/app/AGENTS.md` structure.
   - No behaviour change: `tools/list` stays byte-identical, and the
     `initialize` instructions are reassembled from the groups' sentences.
     A golden test proves it.
   - As built: the interface holds only what step 2 uses (`instructions`,
     `tools`, `call`). `id` (with `SesoriToolGroupId`), `title` and
     `summary` land in step 3,
     `start`, `dispose` and the host in step 4 (with the
     `sesori_plugin_interface` dependency for `Log`), and `guide` in step 10.
     `SesoriToolCaller` replaced the app's `SesoriMcpCaller`. The in-app
     groups share the existing `models/sesori_mcp_tool_arguments.dart`, so
     the step regenerates no Freezed output.
3. 🌿 **Per-group toggles and leaner task text** (~700).
   - `agentToolGroups` and the CLI `config tool-group`.
   - The grant snapshots groups at mint, and `mint()` returns null with no
     enabled groups.
   - Filtered `tools/list` and calls, with filtered instructions.
   - The settings route with `BridgeSettingsResponse.toolGroups` and
     `BridgeSettingUpdate.toolGroup` (`sesori_shared`).
   - The `update_task` dedupe, with before and after sizes.
4. 🚧 **Tool host: records, notices and approvals** (~1,000 plus Drift
   output).
   - Schema 35 with the two tables, the DAO, `SesoriToolRecordRepository`
     and `BridgeSesoriToolHostImpl` (with `enabled` and `enabledChanges`).
   - `ToolGroupApprovalService`, `ToolGroupAgentChange` and its `settle`
     route.
   - Group `start` and `dispose` in startup and shutdown order.
   - Tests: cascade on session delete; claim passing through to `deliver`;
     approval allow, reject and restart drop; YOLO allows without a card.
5. ⚙️ **PR monitor package: `gh` API and snapshots** (~1,400).
   - `sesori_tool_pr_monitor` skeleton, `GhCliApi` with its DTOs, the
     GraphQL query with follow-up pages, and `PullRequestSnapshotRepository`
     normalization.
   - Tests on recorded `gh` JSON fixtures (privacy-safe, synthetic): CheckRun
     and StatusContext mapping, pagination, a repeated cursor, `errors`
     payloads, not-found versus host errors, and the timeout.
6. ⚙️ **PR monitor rules** (~1,500).
   - The activity and readiness calculators, the report builder and the
     feedback builder, as pure classes with the spec's texts.
   - Tests port the plugin's `core.test.ts` cases one for one, including the
     same-second ties, the unthreaded channel and the forced CI line.
7. 🚧 **Watches: fan-out polling, delivery and restart** (~1,500).
   - `PullRequestWatchRepository`, `PullRequestWatchService` (without
     readiness mutations or merging), `PullRequestPollListener` and the
     group.
   - Tools: `watch_pr`, `unwatch_pr`, `pr_watch_status`, `get_pr_report`.
   - Composed in the orchestrator, with a first version of the guide.
   - Tests: two sessions on one PR poll once; per-watcher baselines; the quiet
     window, CI hold and urgent triggers; claim and claimLost; restart resume,
     including a merge while the bridge was off; archived and deleted
     sessions; ten failures and not-found stops; a disabled group stops
     polling.
   - As built: no guide text yet (step 10 adds `guide` and writes it), and
     `watch_pr` has no `auto_merge` argument until step 8. See TRACKER notes.
8. 🚧 **Readiness, auto-merge, feedback and reply** (~1,400).
   - `PullRequestActionRepository` and the stateless
     `PullRequestMergeService`: automatic and manual labels, invalidation,
     standalone mark, the squash pinned to the head with reconciliation, and
     the merged label.
   - Tools: `mark_pr_ready`, `unmark_pr_ready`, `set_pr_auto_merge`,
     `get_pr_feedback`, `reply_on_pr`.
   - Tests port `merge.test.ts` and the readiness cases, plus effective
     auto-merge across two watchers.
9. ⚙️ **`configure_pr_monitor`** (~600).
   - The config record and the tool.
   - Widening goes through `requestApproval` (no card under YOLO), and the
     timeouts are applied.
   - The description builder for the card.
10. ⚙️ **Guides and skills on Claude Code and Codex** (~900).
    - `get_guide`, the final guide text, `SesoriSkillBundleStorage`,
      `SesoriSkillBundleListener`, the foundation directory, and
      `SesoriMcpAccess.skillBundle`.
    - Claude `--plugin-dir`; Codex `skills/extraRoots/set`.
    - Live verification on both through the test proxy: the skill is listed
      and loads on a "watch this PR" request.
    - `HARNESS_CAPABILITIES.md`.
11. ⚙️ **Pi deferred tools and instructions; skills on Pi, Oh My Pi, Grok and
    Copilot** (~900).
    - The Pi startup-extension changes, and each seam in the table.
    - Live verification per harness. A failed seam is left unwired and
      recorded.
12. ⚙️ **Bridge projection, status and app actions** (~1,100).
    - `Session.pullRequestWatches` with `PullRequestWatchStatus`, the
      `SessionViewService` read, and the orchestrator subscription.
    - Merged records kept until local midnight.
    - The stop and auto-merge request models, handlers and routes.
    - `GET /pull-request-watches` and the `pullRequestWatchesChanged` event.
13. ⚙️ **App: row mark, composer chip and group toggles** (~2,000, split).
    - 13.a ⚙️ bridge and wire: the master-switch field and update, watches
      hidden while the PR monitor is off with a republish on each change,
      and the `module_core` settings repository and cubit.
    - 13.b ⚙️ app UI: the `module_core` session action and calculator; the
      row mark (lead PR plus `+N`); the chip with its interim per-session
      menu and Stop; the Agent tools settings section, master switch
      first, on phone and desktop.
14. ⚙️ **App: watched-PR list** (~1,400).
    - `PullRequestWatchApi`, the client repository and
      `PullRequestWatchListCubit`.
    - The home top-bar button with its rolling red count, and the grouped
      sheet with tap, swipe (Auto-merge, Stop), in-place updates and
      regroup on next open.
    - The composer chip opens the sheet filtered to its session, replacing
      the interim menu.
    - The desktop "Pull requests" sidebar row under Scheduled.
15. ⚙️ **Sesori tools on OpenCode** (`sesori_plugin_opencode` only).
    **Mechanism decided by the owner 2026-11-25:** keep OpenCode's shared
    server (no bridge-owned server, no launch-time config) and use the
    client-MCP WebSocket relay. Every OpenCode session that calls a Sesori
    tool, including sessions started in OpenCode's own app, gets a token
    bound to its `_meta` session id on first call, so the tools work for all
    sessions with no "is this a Sesori session" detection. Verified live
    (~500–800 lines plus tests, no bridge or interface change):
    - Version-gated at OpenCode ≥ 2.2.0. Per open project folder, the plugin
      opens a WebSocket to OpenCode's experimental
      `GET /api/experimental/client-mcp?location[directory]=…&name=sesori_bridge`.
    - `initialize` and `tools/list` are relayed to the bridge's loopback
      server with one folder grant (minted, never bound). The dispatcher
      already lets any minted token list (`isMinted`), and only `tools/call`
      needs a bound grant.
    - On `tools/call`, the plugin reads `params._meta["ai.opencode/sessionID"]`,
      mints and binds one grant per session (cached, as Pi binds), and
      forwards the call with it. The tools vanish when the socket closes.
    - **Filtering is per folder, not per session**, because `tools/list`
      carries no session id. With phase 1's global toggles the folder grant's
      snapshot equals a session's. A toggle between the folder mint and a
      session mint can list a tool that then answers "Unknown tool" until the
      socket reconnects. That is accepted. Later per-session profiles would
      need per-folder lists or a re-list on OpenCode.
    - Limitations to record in `HARNESS_CAPABILITIES.md`: the endpoint is
      experimental; the server `instructions` don't reach the prompt for
      WebSocket-attached servers; OpenCode has no skill seam, so `get_guide`
      is its only guide path (the tool descriptions point at it).
    - Live verification on OpenCode through the test proxy, as in the
      matrix. Hermes needs nothing here: it gets the Sesori MCP from a
      separate PR (below).
16. 🌱 **Reconcile regression docs.**
    - A new `docs/regression/pull-request-monitor.md`.
    - `sesori-mcp.md`: groups, gating, `get_guide`, skills.
    - The session list and detail docs for the mark and chip, and the home
      and desktop docs for the PR list.
    - `HARNESS_CAPABILITIES.md` checked against the verified results.
17. 🌿 **Verify and retire.** Run the matrix below, record it, and move the plan
    to `completed/`.

**Dependencies:**

- Step 3 needs 2.
- Step 4 needs 2.
- Steps 5 and 6 need only the interface package from step 2, and can run
  beside 3 and 4.
- Step 7 needs 4, 5 and 6.
- Step 8 needs 7.
- Step 9 needs 4 and 7.
- Step 10 needs 7 (for the guide text; it can start once step 7 is open).
- Step 11 needs 10.
- Step 12 needs 7.
- Step 13 needs 3 and 12.
- Step 14 needs 13.
- Step 15 needs 3 (it is plugin-only and can run any time after it; live
  verification of the PR monitor on OpenCode needs 7).
- Steps 16 and 17 come last.

Steps 6, 7, 8 and 14 are the ones likeliest to exceed 1,500 lines. Each splits
cleanly (for example 6.a feedback builder, 7.a delivery and restart) without
asking.

## Verification

- **L2.** The automated tests named in each step.
- **Headless bridge plus GitHub** (the packaged-or-external boundary).
  - Setup: a private scratch repository under the owner's account, with no
    real code, and `gh` signed in as the owner.
  - One watch receives a report about 2 minutes after a comment, and at once
    after a failing check and after a merge.
  - `reply_on_pr` makes the thread count as handled, and the label lands with
    the next quiet report.
  - `mark_pr_ready` with auto-merge squash-merges at the head, with the title
    only, and adds `automatically-merged`.
  - A push after the mark cancels a stale merge.
  - Restarting the bridge mid-watch resumes it, and a merge during downtime
    reports at once.
  - Two sessions watching one PR cause one poll per minute (debug log
    counter), and both get reports.
  - Turning the group off stops polling and listing.
  - Archiving a session ends its watch.
- **Live plugin, on Claude Code, Codex, Pi, Oh My Pi, Grok, Copilot,
  OpenCode and Hermes** (Hermes once its separate PR has landed) through the
  local test proxy:
  - The tools are listed only when the group is on.
  - `watch_pr` works.
  - A report notice arrives and the agent acts on it.
  - The skill loads where its seam was wired, and `get_guide` works
    everywhere; on OpenCode and Hermes it is the only guide path.
  - A mid-turn report waits on Grok and steers on Claude Code.
  - OpenCode: two sessions in one folder each call with their own bound
    grant, so reports land in the right session; closing the socket removes
    the tools.
- **`configure_pr_monitor`.** Widening shows the card and applies on Allow.
  With YOLO on, it applies with no card. Narrowing applies at once.
- **App, headless iOS simulator only:**
  - the chip with only watches and with a wake-up too, and opening the
    session-filtered sheet from it;
  - the row mark (lead PR plus `+N`) against a timed armed mark;
  - the top-bar button appearing and disappearing without moving the other
    buttons, the red count only for needs-you, and the count rolling;
  - the sheet's groups, tap to session, swipe Auto-merge and Stop, a row
    changing state in place while open and regrouping on the next open, and
    Merged today until midnight;
  - the other-computers rows;
  - the settings toggles and their round trip;
  - an older-bridge fixture shows no section, no chip and no button.
- **Desktop:** the "Pull requests" sidebar row under Scheduled opens the
  list. This runs on the desktop shell, because the row is desktop-only.
- **Material failure signals:**
  - A report is duplicated, delivered to the wrong session, or lost on an
    ordinary restart.
  - Two polls happen per PR.
  - A disabled group still polls or lists.
  - A tool outside the grant runs.
  - A merge is not pinned to the head.
  - Auto-merge widens without Allow.
  - The `gh` token or the Sesori MCP token reaches logs or argv.
  - Watches outlive their deleted or archived session.
  - The plugin-v0.10.0 signals in [PR_MONITOR_SPEC.md §11](PR_MONITOR_SPEC.md).

## Documentation

- `docs/regression/pull-request-monitor.md` (new): the capability, the
  required behaviour, levels, failure signals, limitations (the 100-comment
  windows, the restart reset of retry and stuck state, process-wide skill
  staleness) and harness scope.
- `docs/regression/sesori-mcp.md`: tool groups, toggles, the grant snapshot,
  `get_guide` and skills.
- `docs/HARNESS_CAPABILITIES.md`:
  - "Sesori agent tools" gains a per-harness skill-injection row set.
  - It gains Pi's deferred-tools and instructions result.
  - It gains a PR-monitor paragraph like the wake-ups one: delivery timing
    per harness, and Copilot's permission prompts.
  - OpenCode's chosen mechanism and its limitations (step 15), and that
    OpenCode and Hermes have no skill seam, so `get_guide` is their only
    guide path.
- `bridge/README.md` and `bridge/app/README.md`: the `config tool-group`
  command, and `gh` as an optional dependency of the PR monitor.

## Cleanup assessment

- **In this plan:**
  - `SesoriMcpTool`, the dispatcher switch and the single formatter are
    replaced in step 2.
  - The duplicated `update_task` text goes in step 3.
- **Outside this repository, after phase 1:**
  - The plugin stays for non-Sesori sessions (owner decision), and for
    OpenCode until step 15.
  - This repository's `.pr-monitor.json` serves only the plugin, so it stays
    while the plugin does.
  - The owner's global instructions name `pr_monitor` actions and
    `await-activity.mjs` in the merge gate. They need rewording to the new
    tool names once the owner switches. That is the owner's own file, so the
    final report flags it.
- **Nothing else becomes obsolete.** The `agentTools` master switch stays, and
  `SessionArming` is untouched.

## Risks

- **GitHub rate limits** with many watches. About one GraphQL point per PR
  per minute is far under the limit for realistic counts. Status shows the
  count. Webhooks are the later fix.
- **Two monitors in one session** while the plugin is still installed. The
  guide says to use Sesori's tools when both are present. The plugin is kept
  for non-Sesori sessions.
- **A stale skill after a toggle** on process-wide seams. Its text tells the
  agent to skip it when the tools are absent.
- **Readiness retry and stuck state reset on restart.** At most one extra
  idle reminder results. Accepted.
- **Copilot's double prompt** on non-read-only tools is an existing gap.
- **OpenCode's endpoint is experimental** and may change between OpenCode
  releases. The plugin version-gates it, and a failed socket only removes
  the tools.

## Decisions

**Owner (from the brief):**

- GitHub access goes through the user's `gh`. An optional GitHub App with
  webhooks comes later.
- The interface package and the PR-monitor package are separate Dart
  packages in this repository.
- There is one MCP server, and each session lists only its enabled groups.
- Each group has a global toggle in bridge settings.
- Skills are injected where the harness allows, with a `get_guide`-style
  fallback. Descriptions and skills say plainly when to use them.
- The app shows a per-session mark that reuses the arming mark path and the
  wake-up chip. A session with several PRs shows the PR that needs attention
  most plus "+N" on its row; the composer chip shows the count and opens the
  list filtered to that session.
- The watched-PR list is option B, in phase 1 as its own step: the home
  top-bar button (shown only while a PR is watched, red rolling count only
  when something needs the user), the grouped sheet (Needs you, Waiting,
  Ready, Merged today), tap to the session, swipe for Auto-merge and Stop,
  in-place updates and regroup on next open, and a desktop "Pull requests"
  sidebar row under Scheduled. The sheet lists only this computer's PRs
  (2026-11-25: other computers' rows are not relevant to the PR monitor; a
  cross-computer "pending input" highlight is a separate future feature,
  outside this plan).
- 2026-11-25, for step 13: the app gets the master "Agent tools" switch
  above the group switches ("everything should be able to change from
  phone directly"). While it is off, the group switches are dimmed, and a
  tap on one says why. The bridge leaves watches out of sessions and the
  list while the PR monitor (or agent tools) is off, and republishes their
  sessions when that changes, so the marks fade out and back in.
- The red count covers CI failure, conflict and new review comments, plus
  Ready PRs whose auto-merge is off. Merged PRs stay listed until the end of
  the day.
- Auto-merge keeps the per-PR opt-in.
- A `configure` tool sets auto-merge globally or per repo, and changes
  timeouts. Only widening auto-merge shows an Allow card, and YOLO skips the
  card. Narrowing and timeouts apply directly; per-PR opt-in needs no Allow.
- Auto-merge defaults to off everywhere, with no import or migration of the
  plugin's config or `.pr-monitor.json`.
- New groups are on by default, the PR monitor included.
- The `pr-monitor` plugin is kept for non-Sesori sessions.
- OpenCode and Hermes are to be supported. Research (verified live): Hermes
  works with per-session tokens from 0.22.3 and ships in a separate PR.
  For OpenCode (step 15) the owner chose, on 2026-11-25, to keep OpenCode's
  shared server and use the verified client-MCP WebSocket relay, binding
  every calling session on first call, instead of config at launch. A third
  option,
  `PUT /api/experimental/mcp/sesori_bridge` with one token and a new
  `_meta`-resolving grant type, ranks last because it needs a bridge grant
  change.

**Engineering (open to veto):**

- One poll per PR per bridge every 60 s, fanned out. Watches are stored per
  session, cascade with it, and resume under the claim-before-send rule.
- v0.10.0's rules, with the differences in the PR-monitor table.
- Separate small tools, one per action.
- Pi gets deferred tools and forwarded instructions.
- The duplicated task text is removed.
- In-app groups for pages, wake-ups and tasks. Moving them into packages is
  not planned.
- Generic two-table tool storage.
- The grant snapshots groups at mint.
- Toggles apply from the next launch or resume.
- The master `agentTools` switch is kept, and the app can set it (see the
  owner's 2026-11-25 decision).
- Labels are left out of the phase-1 interface.
- A stable skill-bundle folder with Claude and plain layouts.
- A seam that fails live verification falls back to `get_guide`.
- Effective auto-merge is any watcher's opt-in.
- Reports use derived timing; idle reminders wait for the turn.
- Watches target the family root. Archiving ends a watch.
- A fixed `[Sesori reply]` prefix and fixed labels. The plugin's config files
  are not read.
- A 60 s `gh` timeout.
- A typed `Session.pullRequestWatches` instead of a new arming variant.
- App Stop does not notify the agent.
- No analytics.

## Open questions

None. The owner answered every question on 2026-11-25, the OpenCode
mechanism included (recorded under Decisions).

## Architecture plan review

One pass (`architecture-plan-review`, sub-agent): rejected with 13 findings.
All were valid and applied without re-review:

1. The orchestrator composes the PR monitor package. The host goes through
   group constructors, and `start()` takes no host. The package exports what
   the projection and stop route use.
2. No `SesoriToolGroupRegistry`. The orchestrator builds the groups, and the
   dispatcher takes the list and checks uniqueness.
3. Added `PullRequestActionRepository` for GitHub writes and the cached
   login. Every tool goes through `PullRequestWatchService`.
4. Added `PullRequestPollListener` for the tick. `PullRequestWatchService`
   solely owns the runtime and op queue. `PullRequestMergeService` is
   stateless (state in, state out). Unwatched mark and unmark run as a
   queued one-off op.
5. Added an app-level `ToolGroupApprovalService` that owns the completers
   and receives `settle`'s routing. The group sends its own outcome notice.
6. `BridgeSesoriToolHostImpl` lives in `server/host/`, and its constructor
   dependencies are listed.
7. The host gains `enabled` and `enabledChanges`. The session lookup is
   batched (`sessions`) with an `archived` flag and `resolveSessionFamily`.
8. `SesoriSkillBundleStorage` (layer 1) plus `SesoriSkillBundleListener`.
9. The calculators are renamed, and the package layout mirrors the layers.
10. Dropped the pass-through client `SessionPullRequestWatchService`.
11. Named `BridgeSettingsRepository` and `BridgeSettingsCubit` for the
    toggles.
12. `toolGroups` uses `@Default([])` instead of nullable.
13. Corrected the wake-up republish precedent (`armingUpdated`).

The OpenCode step (now step 15) was added after the review, from the separate research.
It changes only `sesori_plugin_opencode`, with no new bridge or interface
contract.

## Later phases (rough intent only)

- **An optional Sesori GitHub App with webhooks.** Why: faster and more
  reliable than polling, and no rate-limit ceiling. It is opt-in, with `gh`
  remaining the default.
- **Labels and profiles,** such as "Development", so non-dev sessions don't
  load dev groups. Why: context cost and relevance as groups multiply. It
  extends the grant's group set per session.
- **Out-of-process community tool plugins** behind the same interface. Why:
  third-party groups without shipping them in the bridge.
- **Live PRs from every computer in one list**, instead of the phase-1
  "N watched · Switch" rows. Why: one place for everything, without
  switching computers.
- **App editing of PR-monitor config,** if the agent-only `configure` proves
  insufficient. Why: humans and agents should use the same API.
- **Harness parity follow-ups** for Cursor and Antigravity once their MCP
  injection is verified. Why: parity.
