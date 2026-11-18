# Sesori MCP for agents

Slug: `sesori-mcp`.

## Status

- **Date:** 2026-11-17. Code facts come from `origin/main` at `062376863b`
  (product version 1.14.1, bridge drift schema 30).
- **Stage:** steps 1–3 done (the endpoint, caller identity, bridge setting
  and read tools); step 4 (approvals with pause, resume and run now) is in
  review. No plugin injects yet, so no harness reaches the server. Steps 2 and
  4 were each split in two for size, so the series has 11 steps.
- **Settled by the owner:**
  - Any agent create or modify of a task asks the user for approval. That
    includes a scheduled run editing its own prompt, so self-improvement
    happens through approval requests. Read tools need no approval.
  - No versioning or revert history.
  - Round-1 answers (2026-11-17) are recorded under "Owner decisions". No
    owner questions are open.
- **Relationship to earlier plans:**
  - `.plan/completed/scheduled-tasks/PLAN.md` "Later Phases" names this work
    ("A Sesori MCP server injected when the bridge starts a harness, so an
    agent can list, create, pause and run tasks through the same bridge
    services the app uses"). It also asks how an agent-created task is
    attributed and confirmed, and whether it may use Approve everything. This
    plan is that phase. Confirmation is the approval request; attribution is
    not persisted (no history, by decision).
  - `.plan/completed/mcp-management/` manages the user's own servers. This plan
    adds one Sesori-owned server. It adds no management route, configuration
    writer or credential store.
  - `.plan/completed/sesori-system-note/` is the precedent for Sesori-owned,
    per-session harness input. That input goes through each harness's launch
    seam, never through user config.

## Goal

Every harness session Sesori starts sees a small Sesori MCP server
(`sesori_bridge`). Its tools act on the bridge that started the session,
through the bridge services the app's routes already call.

The first capability is scheduled tasks on this computer. Agents can read
any task, its runs and their full transcripts freely. They can propose
creating a task, editing one, pausing, resuming or running one now. Every
proposal waits for the user's Allow on the phone.

The self-improvement loop in its smallest safe form:

1. A scheduled run's prompt opens with a short bridge-owned note. The note
   says the message is a scheduled recurring run and asks the agent to propose
   improvements to its own task. The note is hidden in the app.
2. The run reads its task and recent runs.
3. It proposes a better prompt or schedule.
4. The user gets "Permission requested", sees what would change, and taps
   Allow.
5. The next run uses the new definition.

There is no other trigger machinery.

Nothing changes outside Sesori-started sessions. Sesori writes nothing to
global, project or repository configuration. A session the user later resumes
in a terminal has no Sesori server.

## Product direction and threat model

- **North Star:** humans and automation control Sesori through the same API
  seam. The tools are a thin adapter over `ScheduledTaskService`,
  `ScheduledTaskRunService` and `ChatHistoryService`, the services behind the
  app's routes. There is no second task model, validator or scheduler.
- **Persistence path:** a tool that creates or changes unattended work is one.
  Prompt injection from a repository, a web page or a tool result could plant
  work that runs later without a human. The owner's rule closes it: no agent
  write takes effect without the user's approval.
  - The approval is bridge-owned. Neither the harness's approval mode nor
    Sesori's "Approve everything" can grant it.
  - The phone shows exactly what will change.
- **Honest limit:** an agent with shell access already runs as the user's OS
  account. It can read the token Sesori hands its session, call the endpoint
  directly, or edit the bridge's SQLite file. Same-user isolation is not the
  goal and is not achievable.
  - The guardrails bound what the **tool surface** offers a model that follows
    instructions it should not.
  - The session's approval mode stays the boundary for shell access.
  - A direct call to the endpoint still lands in the same approval gate.
- **Trust postures:** the endpoint lives inside one bridge process. That
  process belongs to one account and holds only its own tasks (scheduled-tasks
  D12).
  - Tokens are random, in memory, and valid only on the bridge that minted
    them, so another slot or account's bridge rejects them.
  - Nothing new crosses the relay. Approval requests and replies travel as
    ordinary permission events and replies, so local E2E and managed trusted
    modes keep their existing guarantees. Neither posture is weakened.
- **Owner-accepted risk (Q5, Q6, Q7):**
  - Reads cover every task on this computer and full run transcripts. Another
    project's prompts and transcripts can therefore reach the calling
    session's model provider, like any tool output.
  - A session in one project, possibly prompt-injected, can propose changes to
    a task in any project, including switching it to "Approve everything".
    That would let the task's runs act without asking.
  - The owner accepted both for usefulness. The mitigations:
    - Every change still needs one explicit Allow, and Sesori never
      auto-allows one.
    - The request text starts with the approval mode whenever the resulting
      task uses "Approve everything", then the project, then the action.

## Current behavior (code evidence)

- **Tasks:**
  - `bridge/app/lib/src/services/scheduled_task_service.dart` handles list,
    create, update (whole definition, validated, next run computed),
    setEnabled, delete and listRuns, plus a `Stream<void> changes`.
  - `scheduled_task_run_service.dart` holds `runNow` and the tick.
  - Route handlers (`routing/*scheduled_task*_handler.dart`) are one-line
    delegations to those services.
  - A run session carries `sessions.scheduledTaskId`
    (`api/database/tables/session_table.dart:102`).
- **Run results:** `ScheduledTaskRun` rows hold the outcome and `sessionId`.
  The output is the run session's transcript. `ChatHistoryService
  .getSessionMessages` reads it in `HistoryWindow` pages, the same paging the
  app uses. Each task keeps 20 run rows, and archived run transcripts stay
  readable.
- **Bridge-owned prompt notes:** `sesori_bridge_foundation`'s
  `buildWorktreeSystemContext` / `stripWorktreeSystemContext`
  (`worktree_system_context.dart`) is the precedent. A
  `[SYSTEM CONTEXT — IMPORTANT]` … `---` note is added to the execution parts
  only (`session_creation_service.dart:246,314`,
  `session_prompt_service.dart:587`), while `userVisibleText` stays
  user-authored. The note is stripped again wherever user text surfaces on
  reload: `plugin_message_mapper.dart:108`, `plugin_command_mapper.dart:21`
  and the Claude transcript catalog (`:580`).
- **Run start path:** `ScheduledTaskRunService._createSession`
  (`createScheduledRunSession`) for a new session, and `_continueIn`
  (`sendPromptAlreadyReserved`) for a same-session run.
- **Permission seam, which approvals reuse:**
  - Wire:
    - `PendingPermission{id, sessionID, displaySessionId, tool, description,
      allowAlways}` (`shared/.../pending_permission.dart`).
    - `SesoriSseEvent.permissionAsked` / `permissionReplied`, with
      `allowAlways` since v1.8.0.
    - `PermissionReply{once, always, reject}`.
  - Client: `permission_modal.dart` renders `description` as Markdown, shows
    the `tool` label, and hides "Always" when `allowAlways` is false.
  - Push: `push_notification_content_builder.dart:46` turns a
    `SesoriPermissionAsked` into "Permission requested" with the description
    as plain text. `push_session_state_tracker.dart:77` and
    `completion_notifier.dart:58` hold off completion while a request is
    pending.
  - Reads: `PermissionRepository.getPendingPermissions` is plugin-only. It is
    read by `get_session_permissions_handler.dart:33` (through
    `PermissionAutoApprovalService.resolveSnapshot`), by
    `permission_auto_approval_service.dart:123`, and by
    `session_send_service.dart:392`.
  - Replies: `ReplyToPermissionHandler` → `PendingInteractionService
    .replyToPermission` (session dispatcher, archived check) →
    `PermissionRepository.replyToPermission`.
  - YOLO: `PermissionAutoApprovalService` acts only on plugin
    `BridgeSsePermissionAsked` events (orchestrator 1877/1885) and on
    `PermissionRepository` snapshots.
  - Delivery: `Orchestrator._deliverSseEvent` feeds local observers (push),
    the wire, unseen activity and project activity.
- **Harness launch seams:** see the matrix.
  - The ACP family shares `AcpAgentApi._sessionActivationParams()`
    (`acp_agent_api.dart:240-243`), which always sends `mcpServers: []`. Its
    comment says "The bridge never injects MCP servers".
- **Plugin access to the bridge:** plugins reach bridge capabilities through
  `PluginHost`. `BridgePluginApi.createSession` gets no Sesori session id; the
  bridge binds the returned backend id to its session row.

## Harness capability matrix

Evidence: **L** verified live (isolated HOME, local test proxy, pinned or
adjacent version), **S** from source or docs, **U** unverified.

| Harness | Injection seam (per session?) | Model can call it | Native prompt before a Sesori tool | Residue when resumed outside Sesori | Same-name collision | Session-only skills | Phase 1 |
|---|---|---|---|---|---|---|---|
| Claude Code 2.1.325 | `--mcp-config` without `--strict`, on every launch and resume; process per session (L) | yes (L, stdio; HTTP+headers S) | `can_use_tool` unless allowed; `--allowedTools mcp__sesori_bridge` pre-allows (L) | none in session files (L); per-server MCP log folder in the user's cache (L) | session server silently replaces user's (L) | `--plugin-dir` (L) | ✅ |
| Codex 0.169.0 | per-thread `config` on `thread/start`/`thread/resume`, dotted keys only (L); `-c` is process-wide (L) | yes (L, stdio; HTTP S) | elicitation form unless `default_tools_approval_mode: "approve"` (L) | none; must re-send on each resume (L) | thread > `-c` > config.toml, silent (L) | none per session; `skills/extraRoots/set` is process-wide (L) | ✅ |
| Pi 1.5.2 | startup extension: `pi.registerMcpServer` (L) or `pi.registerTool` forwarder (S) | yes (L) | none (L) | none (L) | user's mcp.json wins, `-` and `_` the same (L) | `--skill` (L) | ✅ via `registerTool` forwarder |
| OMP 18.21 | ACP `mcpServers`, HTTP (L) | yes (L) | none (L) | transcript only (L) | none: ACP mode ignores config MCP (L+S) | none | ✅ |
| Grok 1.0.30 | ACP `mcpServers`, HTTP (L) | yes (L) | `session/request_permission` (L); pre-allow U | `events.jsonl` keeps URL, not headers (L) | session wins (L) | none | ✅ |
| Copilot 1.0.113 | ACP `mcpServers`, HTTP only, stdio rejected (L) | yes, HTTP (L) | `session/request_permission` (L); pre-allow U | none found (L) | config wins (L) | none | ✅ |
| Antigravity 1.5.0 | ACP `mcpServers`, HTTP; connects on first prompt (L), `_meta.antigravity.eagerMcpServers` (S) | U (needs a Gemini key) | U | none found in profile (L) | session wins (S) | none | ✅ after a live tool call |
| Hermes 0.21.5 | ACP `mcpServers`, HTTP (L) | yes, no prompt (L) | none (L) | schema cache and spawn ledger (L) | config wins (L) | none | ⚠️ only after the two-session identity check |
| Cursor 2026.07 | ACP `mcpServers`, HTTP (S); `session/new` needs login (L) | U | U | U | session wins (S) | none | ⚠️ when verified with a signed-in account |
| DeepSeek adapter 0.2.3 | rejected: "MCP servers are not supported" (L, same check in 0.2.4 S) | n/a | n/a | n/a | n/a | none | 🚫 adapter limit |
| OpenCode 2.3.0 | only server-wide: `OPENCODE_CONFIG_CONTENT`, per-directory `PUT /api/experimental/mcp` and client-mcp socket (L+S) | n/a | allowed by default (L) | none (L) | n/a | none | 🚫 the shared background service would expose it to non-Sesori sessions |

Notes that shape the design:

- **Transport.** Every injectable harness accepts streamable HTTP, and Copilot
  accepts nothing else. A stdio shim is therefore unnecessary.
- **Token placement.** Grok persists the server URL, so the token never goes
  in the URL or argv. It travels in an `Authorization` header.
- **Hermes identity risk.** Hermes keeps one MCP registry per agent process,
  keyed by server name. Sesori runs one ACP process for many sessions, so a
  second session's header may be ignored in favour of the first session's
  connection. That would attribute the second session's calls to the first.
  Hermes is enabled only after a live check shows two sessions get separate
  identities.
- **ACP loads.** OMP and Grok replace a session's servers on every
  `session/load`, so the history reload on a live process
  (`acp_plugin.dart:2803`) must send the same list. Catalog probes keep the
  empty list.
- **Collisions.** Claude lets a session server silently replace a user server
  of the same name. Hermes, Copilot and Pi let the user's win. The distinctive
  name `sesori_bridge` makes both cases implausible, so no runtime check is
  added.

## Architecture

### Where the server runs

```
harness ──streamable HTTP, Authorization: Bearer <token>──┐
                                                          ▼
foundation: SesoriMcpServer (127.0.0.1, ephemeral port, transport only)
        ▼ stream of inbound requests; the Orchestrator routes them
routing: SesoriMcpRequestDispatcher (the single agent entry point)
        ▼ caller = SesoriMcpAccessService.resolve(token)
ScheduledTaskAgentService (reads; proposals; applying approved changes)
        ▼ the same calls the route handlers make
ScheduledTaskService / ScheduledTaskRunService / ChatHistoryService
```

- **`SesoriMcpServer`** (`bridge/app/lib/src/foundation/sesori_mcp_server.dart`)
  is a Layer 0 transport with no upward dependencies.
  - `BridgeRuntimeRunner` binds it on `127.0.0.1`, on an ephemeral port,
    before it builds `PluginGenerationFactory`. Plugins need the URL at their
    first launch.
  - It closes at shutdown.
  - It exposes a stream of inbound requests: bearer token, raw body, and a
    respond handle. The Orchestrator subscribes and hands each
    request to the dispatcher.
  - It accepts `POST /mcp` and answers with `application/json`; it has no SSE
    stream and no `Mcp-Session-Id`.
  - It rejects an `Origin` header, a non-loopback `Host`, an oversized body,
    and any other method or path.
  - It makes no decisions.
  - It runs headlessly, with or without a desktop app.
- **`SesoriMcpRequestDispatcher`** (`routing/sesori_mcp/`) answers
  `initialize`, `ping` and `tools/list`, resolves the caller, parses
  `tools/call` arguments into Freezed models (`routing/sesori_mcp/models/`),
  calls `ScheduledTaskAgentService`, and formats results with
  `SesoriMcpResultFormatter` (`routing/sesori_mcp/`). These models stay out of
  `sesori_shared`, which is only for client-to-bridge payloads.
  - Notifications are acknowledged.
  - An unknown token gets HTTP 401. Harnesses report the server as failed or
    the call as an error; nothing crash-loops.
  - Protocol types are hand-written (step 2). `package:dart_mcp` assumes one
    long-lived stream per client and has no HTTP transport or per-request
    caller.
- Literally replaying app routes through `RequestRouter` was rejected. It
  would expose every route (session deletion, settings) to agents and has no
  caller identity.

### Caller identity

- **Token lifecycle.** Each harness launch gets its own 256-bit token. A
  plugin always does two steps: `mint()` before launch, and `bind(launch,
  backendSessionId)` once the backend id is known. For Claude that is
  immediately (the id is pre-generated). For a resume or load it is also
  immediate. After `thread/start` or ACP `session/new` it is right after the
  call returns.
- **Layers in `bridge/app`.** Minting and binding are separate from caller
  resolution. This avoids a construction cycle: `SessionRepository` is built
  inside the Orchestrator from `PluginRuntime`, which needs the plugin hosts
  first.
  - `repositories/sesori_mcp_grant_repository.dart`:
    `SesoriMcpGrantRepository` holds the in-memory map from token to plugin id
    plus an optional backend id, as a `repositories/models/` grant record. It
    can mint, bind and look up; tokens live until the bridge stops. It is constructed in
    `BridgeRuntimeRunner` before `PluginGenerationFactory`.
  - `server/host/bridge_sesori_mcp_access_impl.dart`:
    `BridgeSesoriMcpAccessImpl` is one per plugin, like `BridgeHostPortService`
    and `BridgeHostInfoImpl`. It holds the plugin id and server URL, reads the
    `agent-tools` setting, and calls the grant repository.
    `PluginGenerationFactory._buildHost` constructs it.
  - `services/sesori_mcp_access_service.dart`: `SesoriMcpAccessService` is
    stateless. It is built in the Orchestrator and used only by the
    dispatcher. `resolve(token)` returns a `SesoriMcpCaller(sessionId)`
    (`repositories/models/`) through the grant repository and
    `SessionRepository.getStoredSessionByBackendId`
    (`session_repository.dart:2106`).
- **Resolution.** The caller is only the Sesori session id. Project and
  scheduled task are read from the session row at each call, so nothing is
  cached.
- **Unknown tokens.** An unknown or post-restart token gets HTTP 401 for every
  method. Tokens die with the bridge, which restarts its harness processes
  anyway. A minted token not yet bound may `initialize` and list tools, since
  Codex and ACP connect before the backend id exists, but every tool call
  answers "not linked to a Sesori session yet".
- **Plugin contract.** `PluginHost.sesoriMcp` exposes `SesoriMcpAccess`.
  `SesoriMcpAccess`, `SesoriMcpLaunch` and the server-name constant live in
  `sesori_plugin_interface`; the app implements the interface.
  - `SesoriMcpLaunch? mint()` returns `{serverName, url, token}`, or null when
    the bridge setting is off.
  - `void bind({required SesoriMcpLaunch launch, required String
    backendSessionId})` completes the binding.
  - Each plugin turns the value into its native shape at its existing launch
    seam. The bridge never learns a harness's config syntax.
- **Process-wide harnesses.** A harness that can only take a process-wide
  server (OpenCode) does not inject. An unattributable server cannot show who
  asked, and it would reach sessions Sesori did not start. The gap is recorded in
  `docs/HARNESS_CAPABILITIES.md`.

### Per-harness injection (plugin-owned)

- **Claude:** `--mcp-config` with inline JSON on every launch, resume and
  respawn. The entry is `type: http`, the URL, and a header
  `Authorization: Bearer ${SESORI_MCP_TOKEN}`, with the token in the child's
  environment.
  - Argv is world-readable; the environment is not.
  - If `${VAR}` header expansion does not work for `--mcp-config`, fall back
    to a 0600 file in Sesori's state directory, deleted when the process
    exits.
  - Also add `mcp__sesori_bridge` to `--allowedTools`. Without it the user
    would be asked twice: once natively, once by the bridge.
  - Catalog probes keep `--strict-mcp-config` with no server.
- **Codex:** dotted per-thread `config` keys on `thread/start` and
  `thread/resume`: `mcp_servers.sesori_bridge.url`, `.http_headers`, and
  `.default_tools_approval_mode = "approve"`.
  - Never `-c`, which applies to every thread.
  - An already-loaded thread keeps the config it was loaded with
    (`_loadedThreads`). The token stays valid because the bridge and its
    app-server restart together.
- **ACP:** `_sessionActivationParams` takes the session's server list, used for
  `session/new`, `session/load`, `session/resume` and the resident-history
  reload.
  - The entry is HTTP with an `Authorization` header.
  - Probes and short-lived history clients pass an empty list.
  - Each ACP plugin opts in through one descriptor flag. DeepSeek stays off.
    The same flag drives the run note (below).
  - Antigravity sets `eagerMcpServers` only if lazy connection delays the
    first call noticeably.
  - The stale comment goes.
- **Pi:** the existing startup extension gets the URL and token through the
  Pi process's environment (one process per launch).
  - On load it fetches `tools/list` and registers each tool with
    `pi.registerTool`; each call POSTs `tools/call`.
  - This avoids `registerMcpServer`, which fails when the user runs an
    MCP-replacing extension (the owner does: pi-mcp-adapter).
- **MCP inventory:** where a plugin's inventory lists session servers (Claude
  `source: "dynamic"`, Codex), the mapper matches the exact injected name and
  shows it without controls. A disable or remove on it would otherwise target
  user config that does not contain it.

### Phase 1 tools

Results are compact text only: Codex forwards `structuredContent` in place of
the text, which would hide transcripts. Long text is truncated with
a visible marker, and times use the task's time zone, like the app. Scope is
every task on this computer (Q6).

| Tool | Approval | Effect |
|---|---|---|
| `list_tasks` | no | All tasks: id, name, project, schedule summary, enabled, next run, last outcome. An optional `project_id` filters. |
| `get_task` | no | One task's full definition and state. Without `task_id`, it returns the caller's own task when the session is a scheduled run; otherwise "This session isn't a scheduled run". |
| `list_task_runs` | no | The newest runs of a task, up to 20: run id, when, outcome, ran late, and an excerpt of about 500 characters from each started run's final assistant reply. |
| `get_task_run_transcript` | no | The full transcript of one run's session (Q7), as text: user and assistant messages plus tool names and short tool results. Pages are about 20,000 characters. The result carries a `next_page` cursor backed by `HistoryWindow`, so the agent pulls only what it needs. Archived run sessions work too. |
| `create_task` | yes | Proposes a new task. The project is the caller's by default, or an optional `project_id`. The harness is the caller's. The agent sets name, prompt text, schedule, time zone, missed-run policy, run mode, model, effort and approval mode (Q5). Worktree is off. |
| `update_task` | yes | Proposes changes to any task: name, prompt text (a command prompt keeps its command; arguments may change), schedule, time zone, missed-run policy, run mode, model, effort and approval mode. |
| `pause_task` | yes (Q3) | Proposes `setEnabled(false)`. |
| `resume_task` | yes | Proposes `setEnabled(true)`. |
| `run_task_now` | yes | Proposes `runNow`. |

- **Not in phase 1:**
  - Delete; pause covers stopping.
  - Changing a task's project, harness or worktree.
  - Unlisted tools do not exist for the agent.
- **What a proposing tool does:**
  - It validates the full resulting definition through
    `ScheduledTaskService`'s validator before asking, so the user never
    approves something that cannot be saved. That validator also rejects
    unknown projects.
  - It then returns at once: "Sent to the user for approval. If they allow it,
    it applies to the next run."
  - It does not block the agent's turn (see "Decided in this plan").
- **Transcript text** comes from `SesoriMcpResultFormatter`. Transcripts are
  user data handed to the model on purpose (Q7), so they are never logged.

### Approval flow: reusing the permission seam

The approval is a permission request that the bridge owns. It reuses the
existing wire, push, client modal and reply route unchanged.

- **Model** (`bridge/app/lib/src/repositories/models/`):
  - `ScheduledTaskAgentChange` is sealed: `CreateTask(definition)`,
    `UpdateTask(taskId, before, after)`, `SetTaskEnabled(taskId, before,
    enabled)`, `RunTaskNow(taskId, before)`. Every variant that names a stored
    task carries `before`, the definition its description was built from.
  - `AgentApproval{requestId, sessionId, displaySessionId, change,
    description}` holds it.
  - `AgentApprovalEvent` is sealed: `asked` or `settled`.
- **State:** `repositories/agent_approval_repository.dart`.
  `AgentApprovalRepository` holds the in-memory map, with no separate storage
  class.
  - Operations: add, take, `pendingPermissions(sessionId)`, and a
    `Stream<AgentApprovalEvent>` of asked and settled events.
  - It maps through `AgentApprovalMapper` (`repositories/mappers/`), so the
    list and the stream already carry the shared `PendingPermission` shape.
  - Approvals are lost on bridge restart; the next run can propose again.
- **Description:** the pure `ScheduledTaskChangeDescriptionBuilder`
  (`services/`) turns a `ScheduledTaskAgentChange` into the Markdown text the
  user approves. This text is what the security model relies on, so it is its
  own responsibility with its own tests.
- **Policy:** `ScheduledTaskAgentService`.
  - **Propose:** load the task (any project), build and validate the
    definition, and get the description from the builder. Then
    `AgentApprovalRepository.add`. A session holds at most one pending
    approval; a new one withdraws the previous one, and the agent is told.
  - **Settle on Allow (`once` or `always`):** first re-read the task. One
    shared check covers every variant that names a task: a deleted task, or a
    `before` that no longer matches the stored definition, fails with "The
    task changed since this was proposed". The user's edit wins, and there is
    no merge. Without the check on resume, run now and pause, another approved
    change could turn on "Approve everything" before the user allows an older
    run-now request, which would then run a task whose warning was never
    shown. Otherwise apply through
    `ScheduledTaskService.create`, `update` or `setEnabled`, or through
    `ScheduledTaskRunService.runNow`. Those calls emit
    `scheduledTasks.changed` as today.
  - **Settle on Reject:** drop the approval.
- **Events:** the Orchestrator listens to the repository stream and only
  wraps the mapped values.
  - An asked event becomes `SesoriSseEvent.permissionAsked`, with
    `tool: "Sesori: <action> task"` and `allowAlways: false` already set by
    the mapper.
  - A settled event becomes `permissionReplied`.
  - Both go through the same delivery path as plugin events: local observers
    (push), the wire, unseen activity and project activity. A bridge-origin
    entry point skips the plugin source and generation check.
  - Push and the modal therefore work on every released app that has
    `allowAlways` (v1.8.0+).
- **"Needs you":** `permissionAsked` alone does not put a session on the
  app's attention list. The app's `SseEventTracker` ignores permission events
  (`client/module_core/lib/src/services/sse_event_tracker.dart`) and takes
  `awaitingInput` from project summaries. Those come from
  `plugin.getActiveSessionsSummary()` (`SessionRepository`'s project activity
  collection), which cannot see the agent-approval repository. A finished
  scheduled run with a pending approval would drop off the list, including
  after a reconnect.
  - So the bridge overlays pending agent approvals on the summaries it
    builds: a session with one is marked awaiting input, and an asked or
    settled event triggers a fresh summary. Step 4 picks the owner of the
    overlay with its architecture review; no wire or client change.
- **Reads:** `GetSessionPermissionsHandler` appends
  `ScheduledTaskAgentService.pendingPermissions(sessionId)` after
  `resolveSnapshot`. The handler does no mapping.
  - Auto-approval never sees them, because they are not in
    `PermissionRepository` and are not plugin events.
  - `session_send_service` still looks at plugin permissions only, so a
    pending task approval does not block sending into the session.
- **Replies:** `ReplyToPermissionHandler` takes `ScheduledTaskAgentService`
  beside `PendingInteractionService`, which stays unchanged. Adding the agent
  service there would close a cycle through `ScheduledTaskRunService` →
  `YoloSettingsService` → `PermissionAutoApprovalService`.
  - `ScheduledTaskAgentService.settle(...)` returns a sealed result:
    `Settled` or `NotAgentApproval`.
  - The handler falls through to `PendingInteractionService` only on
    `NotAgentApproval`, which mirrors the read merge.
  - Settling skips the archived-session check, because the change targets a
    task, not the session.
- **Description content** (from the builder, rendered as Markdown by the
  existing modal; the push uses its plain-text form):
  - **First, only when the resulting task uses "Approve everything"** (a
    create or update that sets or keeps it, or a resume or run now of such a
    task): a bold line, "**Approve everything: this task's runs act without
    asking you.**" When the change switches the mode, the line says it is
    being turned on.
  - Then the project name, then the action and task: **Update "Nightly
    deps"**.
  - Then only the changed fields, as before → after. A prompt change shows the
    full new prompt in a block.
  - A create shows every field, with approval mode, schedule and model first.
  - A final line names who asked: "Asked by a scheduled run of this task", "…
    of task "X"", or "Asked from session "Y"".

### Naming

- The server name is `sesori_bridge`, one constant in
  `sesori_plugin_interface`.
  - Claude keeps `[A-Za-z0-9_-]`; Pi treats `-` and `_` as the same name.
  - Lowercase with an underscore gives the same name everywhere
    (`mcp__sesori_bridge__get_task` on Claude).
  - A plain `sesori` is avoided because of the collision behaviour above.
- Tools are short verbs on task nouns, and full tool names stay under 64
  characters.

### Scheduled-run note

- **Where:** `ScheduledTaskRunService` composes the note on both run start
  paths:
  - `_createSession` passes it to `createScheduledRunSession`.
  - `_continueIn` passes it to `sendPromptAlreadyReserved`.
  - Both gain a required `runContext: String?` parameter. The note goes into
    the execution parts only, as the worktree note does, so `userVisibleText`
    and the app's live message stay the user's prompt.
- **When:** only for text prompts, and only when Sesori tools are injected for
  the task's harness. That means the bridge setting is on and the plugin
  declares injection: a `sesoriToolsSupported(pluginId)` read beside
  `inlineImagesSupported`, backed by the same per-plugin flag the injection
  steps turn on. Command prompts get no note: their arguments are command
  input. `ponytail:` add it to command arguments if command tasks need the
  loop.
- **Hidden on reload:** it uses the same `[SYSTEM CONTEXT — IMPORTANT]` …
  `---` frame, built by `buildScheduledRunContext` in
  `sesori_bridge_foundation` beside the worktree note.
  - The existing strip becomes `stripSystemContext` and removes every leading
    frame, so a first prompt that carries both notes is fully hidden.
  - It is called at the same three places as today.
  - The model sees the note; the user sees only their prompt.
- **Wording**, with name and id filled in:

  ```
  [SYSTEM CONTEXT — IMPORTANT]
  This message is a scheduled run of the Sesori task "<name>" (id <id>). It repeats on a schedule, usually while nobody is watching.

  Do the task below. If you learn something that would make future runs better, such as a clearer instruction, a step that keeps failing or a schedule that no longer fits, propose a change to this task with the update_task tool from the sesori_bridge server. The user approves each change on their phone, so propose at most one focused change per run. get_task and list_task_runs show the current task and how recent runs went.

  ---
  ```

  The wording is a plain draft, not a design choice.

### Bridge setting

`sesori-bridge config agent-tools on|off` uses the existing
`ConfigSwitchCommand` pattern and defaults to on (Q1). When it is off,
`mint()` returns null and no plugin injects. Phase 1 adds no app switch.

## Delivery series (phase 1)

Every PR title has the form `<emoji> [sesori-mcp] <description> [step x/11]`.
There is no migration, no wire change and no client code change.

1. 🌱 **Publish the plan.** No user-visible or database change.
2. 🚧 **Endpoint and identity.**
   - `SesoriMcpServer`, the dispatcher with the protocol handshake and an
     empty tool list, the grant repository, `BridgeSesoriMcpAccessImpl`, and
     `PluginHost.sesoriMcp`. All plugins are updated in lockstep to receive
     it; none inject yet.
   - The bridge setting.
   - Headless tests drive the endpoint over HTTP.
   - New `docs/regression/sesori-mcp.md`.
3. ⚙️ **Read tools.** `ScheduledTaskAgentService` reads and the text
   formatter: `list_tasks`, `get_task`, `list_task_runs`,
   `get_task_run_transcript`, with paging and archived runs.
4. 🚧 **Approvals and proposing tools.**
   - The approval model, repository, mapper and description builder.
   - Proposal and settle in the agent service.
   - Orchestrator delivery, the permissions-handler merge, reply routing,
     and the awaiting-input overlay on project summaries.
   - `pause_task`, `resume_task`, `run_task_now`.
5. ⚙️ **Create and update tools.** `create_task` and `update_task`, the
   pre-approval validation, and the full field list in the request text.
6. 🌿 **Scheduled-run note.**
   - `buildScheduledRunContext`, generalising the strip to
     `stripSystemContext`, the `runContext` parameter on both run start
     paths, and the `sesoriToolsSupported` read.
   - Every plugin flag is still off, so nothing changes for users yet.
   - About 300–500 lines.
7. ⚙️ **Claude injection.** Launch-spec arguments, `--allowedTools`, the
   inventory mapper, turning the flag on, and live verification. Updates
   `docs/HARNESS_CAPABILITIES.md`.
8. ⚙️ **Codex injection.** Per-thread config, the approve mode, inventory,
   the flag, and live verification.
9. ⚙️ **ACP injection.**
   - The shared seam with a descriptor flag, the resident-history reload, and
     the stale comment.
   - Enabled for OMP, Grok, Copilot and Antigravity.
   - Hermes is enabled after the two-session identity check, or recorded as a
     gap.
   - Cursor is enabled when verified, otherwise recorded as unverified.
   - DeepSeek is recorded as not supported.
10. 🌿 **Pi forwarder** in the startup extension, the flag, and live
   verification.
11. 🌱 **Run the regression and retire the plan.**

- **Order:**
  - Steps 7–10 depend on 4–6, so no harness ever sees write tools without
    the gate, and the note arrives with the tools.
  - Steps 7–10 are independent of each other.
  - Each injection step updates its rows in `docs/HARNESS_CAPABILITIES.md`
    and `sesori-mcp.md`.
- **Estimates:** injection steps run 200–500 lines each.

## Verification

The highest level is **L3**: real harnesses on a real bridge, plus the
approval flow on the iOS simulator. Security cases run in every relevant step.

| Boundary | Cases |
|---|---|
| Bridge unit and headless | Token mint, bind, unknown and post-restart cases. Caller resolution from session rows. Origin, Host, bearer and size rejection. Transcript paging, including an archived run. Validation before asking, including an unknown `project_id`. Description order: Approve everything first, then project. The run note appears only for text prompts on flagged harnesses with the setting on, and is stripped on reload and in titles, including alongside a worktree note. One pending approval per session. Stale-before refusal for update, pause, resume and run now. A deleted task. A session with a pending agent approval is awaiting input in project summaries, after settling it is not, and a reconnect's summary still shows it. Allow applies through the same service (next run time and `scheduledTasks.changed`). Reject drops. Auto-approval never answers an agent approval, even with Approve everything on. The handler merge. Reply routing. |
| Live harness (macOS, isolated HOME, local test proxy) | For each enabled harness: the server is listed; a scheduled run that receives the note calls `get_task`, and `update_task` raises a permission request; Allow changes the next run's prompt; a user's own MCP server still loads; resuming the session in the harness's own CLI shows no `sesori_bridge` and leaves no config change; a second concurrent session gets its own identity. |
| Client (iOS simulator only) | A released app shows the task approval in the existing modal without "Always", with the Approve-everything line first. Allow and Reject work. The push arrives for a scheduled run's approval. The run's user message shows no note, both live and after reload. |
| Security | A cross-project proposal names its project before the action. A switch to Approve everything leads the request. A direct curl with a session's token still produces only an approval request. Another slot's bridge rejects the token. A browser-origin request is rejected. No token appears in argv, URLs or harness session files. |

Affected regression documents: the new `sesori-mcp.md`, plus
`scheduled-tasks.md`, `mcp-management.md`, `permission-auto-approval.md` and
the `README.md` index.

## Cleanup assessment

- The ACP comment "The bridge never injects MCP servers" and the constant
  empty list are replaced in step 9.
- Claude's catalog-probe `--strict-mcp-config` stays: probes must load no MCP
  server, Sesori's included.
- The scheduled-tasks "Later Phases" bullet is superseded by this plan. No code
  depends on it.
- No compatibility shims are added. Approvals reuse a wire shape every
  supported app already reads.

## Complexity budget

| Addition | Owner and reason |
|---|---|
| Loopback HTTP listener | `SesoriMcpServer`. Every injectable harness speaks HTTP, so one transport is needed and no shim. |
| In-memory token map | `SesoriMcpGrantRepository`. Harness launches outlive one request. |
| In-memory approval map | `AgentApprovalRepository`. An approval outlives the proposing turn. |

Accepted losses and leaks:

- Pending approvals are lost on bridge restart.
- An approval left on a deleted session stays in memory until restart.
  `ponytail:` withdraw on session deletion if that ever shows up.
- One pending approval per session. `ponytail:` allow a small batch if
  interactive users ask for several tasks at once.

## Decided in this plan

These are not owner questions. The owner can override them.

- **`list_task_runs` stays compact, and full transcripts come through
  `get_task_run_transcript` in pages** (the coordinator's engineering choice
  under Q7).
- **Proposals do not block the turn.** A blocking call would hold an
  unattended run open until morning. It would also hit harness tool timeouts
  (Codex `tool_timeout_sec`) and cause overlap skips. The agent learns the
  outcome from `get_task` later.
- **One transport, HTTP.** It replaces the earlier stdio-shim idea after the
  probes.
- **Sesori's server is not hidden.** It shows in harness MCP lists under its
  name, without controls, and gets no special label.

## Later phases (rough intent only)

- **More agent surfaces:** sessions, projects and pushes as tools on the same
  dispatcher and approval seam. Why: one API seam for humans and agents.
- **A dedicated approval view** on the phone, showing a prompt diff and
  letting the user edit before allowing. Why: if the Markdown card proves too
  coarse for long prompts.
- **Session-only skills** (Claude `--plugin-dir`, Pi `--skill`) that teach the
  loop. Why: better use of the tools without touching the user's skills.
- **OpenCode and DeepSeek** once their harnesses offer a per-session seam. Why:
  harness parity.
- **Analytics** on approval outcomes once the app has a reason to change.
  Why: adoption and trust of the loop.

## Owner decisions

Settled 2026-11-17 on the round-1 review page:

- **Q1. On by default:** A. On, with `sesori-bridge config agent-tools off`.
- **Q2. Which sessions get the server:** A. Every Sesori-started session.
- **Q3. Pause, resume and run now:** B. All three need Allow, so every write
  tool goes through approval.
- **Q4. How the request looks:** A. The existing permission card and push.
- **Q5. Approve everything:** B. Agents may propose it on create and update.
  The request shows it first, prominently.
- **Q6. Scope:** B. Every task on this computer. Creates default to the
  caller's project, and an agent may name another project.
- **Q7. Run results:** C. Full transcripts, served by
  `get_task_run_transcript` in pages. `list_task_runs` stays compact.
- **Owner note:** the run prompt itself tells the agent it is a scheduled
  recurring task and that it should propose updates to its own task. That is
  the "Scheduled-run note" section, with no separate trigger machinery.

## Plan review record

- **2026-11-17, `architecture-plan-review` (sub-agent, opus): rejected with
  seven findings. All seven were valid and applied without re-review, as the
  skill directs:**
  1. A dependency cycle in reply routing. Fix: routing moved to
     `ReplyToPermissionHandler` with a sealed settle result.
  2. A construction cycle around `PluginHost.sesoriMcp`. Fix: mint and bind
     moved to a per-plugin `BridgeSesoriMcpAccessImpl` plus a grant repository
     built in `BridgeRuntimeRunner`; resolution stays in the Orchestrator.
  3. The server was in the wrong place. Fix: it moved to `foundation/` with an
     inbound-request stream the Orchestrator routes.
  4. In-memory maps were placed as `api/` storages. Fix: the maps live in the
     repositories.
  5. Model locations. Fix: `repositories/models/`, `routing/sesori_mcp/`, and
     the interface types in `sesori_plugin_interface`.
  6. Mapping outside the repository layer. Fix: `AgentApprovalMapper`.
  7. Presentation inside the policy class. Fix:
     `ScheduledTaskChangeDescriptionBuilder`.
- The reviewer confirmed:
  - the same-seam adapter;
  - the bridge-origin delivery path;
  - the Orchestrator's stream subscription;
  - plugin-owned injection;
  - the existing `ConfigSwitchCommand`.
- The round-1 owner answers changed:
  - scope (every task);
  - the approval-mode rule;
  - pause approval;
  - the transcript tool;
  - the run note.

  They add no new layer or dependency direction. The note reuses the worktree
  note's seam, so no re-review was run.
