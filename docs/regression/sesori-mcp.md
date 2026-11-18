# Sesori MCP For Agents

## Capability

The bridge serves its own MCP server, `sesori_bridge`, to agents in the harness sessions it launches, so an agent can
read the computer's scheduled tasks, their runs and a run's transcript, and propose task changes the user allows on
their phone, through the same bridge services the app uses.
The server is streamable HTTP on `127.0.0.1` with an ephemeral port, JSON responses only, and a per-launch bearer token
that names the calling session. `sesori-bridge config agent-tools on|off` (default on) decides whether launches get a
token at all.

Claude Code sessions get the server; the other harnesses get it in later steps of the plan, and until then their
checks run headlessly against the endpoint. Per-harness status is in [harness capabilities](../HARNESS_CAPABILITIES.md).

| Tool | Effect |
|---|---|
| `list_tasks` | Every task not yet done: id, name, project (the caller's marked), schedule, on or off, next run, last outcome. Optional `project_id` filter. |
| `get_task` | One task's full definition and state; without `task_id`, the caller's own task when the caller is a scheduled run. |
| `list_task_runs` | A task's newest runs, newest first, with the start of each run session's final reply. |
| `get_task_run_transcript` | One run's session as text, newest page first, about 20,000 characters a page, with a `page` cursor to older messages. Archived run sessions work. |
| `create_task` | Proposes a new text task in the caller's project (or `project_id`) with the caller's harness; worktree off, fast mode off, default agent. |
| `update_task` | Proposes changes to name, prompt text (or a command task's arguments), schedule, time zone, missed-run policy, run mode, model, effort and approval mode. Left-out fields keep their value. |
| `pause_task`, `resume_task`, `run_task_now` | Propose pausing, resuming or running a task once now. |

## Required Behavior

- The endpoint binds only the loopback interface before any plugin starts and closes at shutdown after in-flight
  answers finish.
- It refuses before reading the body: any `Origin` header (403), a `Host` other than `127.0.0.1` or `localhost` with its
  own port (403), another path (404), another method (405 with `Allow: POST`), a non-JSON content type (415), a
  declared body over 1 MiB (413), and a missing or non-Bearer `Authorization` (401). A streamed body over 1 MiB is read
  without being kept and refused with 413.
- Tokens are 256 random bits, held in memory only, one per launch. A token the bridge never minted, including one from
  before a restart, gets HTTP 401 for every method. A minted token that is not yet bound to a backend session may
  `initialize`, `ping` and list tools, but every tool call answers that the session is not linked yet.
- A bound token resolves to the Sesori session that holds its plugin and backend session id, read from the session row
  at each call. A token never resolves to another plugin's session with the same backend id.
- With `agent-tools` off, `SesoriMcpAccess.mint()` returns null, so no launch gets a token. The setting is read at each
  launch; a CLI change needs a bridge restart.
- `initialize` echoes a supported protocol version (`2024-11-05` through `2025-11-25`) and otherwise offers the newest.
  Notifications get 202 with no body. Malformed JSON is -32700, an unknown method -32601, an unknown tool -32602.
- Tool failures an agent can act on (bad arguments, an unknown task or run, a run without a session) come back as
  `isError` text results, not protocol errors. An unexpected failure is logged by tool name only and answered with a
  generic error.
- Results are text only, with no `structuredContent`. Read tools are advertised with `readOnlyHint: true`, proposing
  tools with `false`.
- A proposing tool changes nothing by itself. A create or update is first validated as the app's editor would, so the
  user never allows a task that cannot be saved. The tool then raises a bridge-owned permission request on the calling session (surfaced under its root session) and returns at once. The
  request reuses the permission wire, push, modal and reply route; it hides "Always", and its id is random, so a
  modal left over from before a restart cannot answer a newer one. Requests live in memory only.
- A session has at most one waiting request: a new proposal withdraws the earlier one (announced as rejected).
- The request text opens with a bold Approve everything warning whenever the resulting task acts without asking (not
  for a pause; a stronger one when an update turns the mode on), then names the project, the action, the fields (all
  of them for a create, old → new for an update, the schedule for a resume) and who asked. Agent-written names and
  titles are escaped; a prompt sits in a fence it cannot close.
- Allow applies the change through the same service calls as the app. Every change to an existing task carries the
  definition its text was built from; when the stored task differs or is gone, Allow applies nothing and the reply
  route answers 409 "The task changed since this was proposed". An allowed run now that does not start (failed or
  skipped) also answers 409, and its run record holds the reason. Reject drops it.
- A session with a waiting request is listed as awaiting input in project summaries, including the first summary
  after a reconnect, even when its run has finished.
- YOLO and per-session auto-approval never answer these requests.
- Transcript pages never overlap or skip a message; a message longer than a page is cut with a visible marker. Reads
  use only what the bridge stored, archived audit files included, and never start a harness. Reasoning is left out and
  tool results are cut to a short excerpt.
- Transcript content, prompts and tool arguments are never logged.
- A scheduled run's text prompt opens with a bridge-owned note naming the task and asking the agent to propose
  improvements through `update_task`, at most one per run. The note is added only while `agent-tools` is on and the
  task's harness declares that it injects the server (`BridgePluginDescriptor.injectsSesoriTools`); every plugin
  declares false until its injection step (Claude Code declares true). A command task gets no note. The note goes to the harness only: the run's
  user message shows the task's prompt, live and after reload, and a first prompt that also carries the worktree note
  hides both.
- Claude Code: every session launch, resume, rewind and idle respawn passes the server in an inline `--mcp-config`
  whose `Authorization` header names `${SESORI_MCP_TOKEN}`; the token itself is only in the child's environment. The
  launch adds `mcp__sesori_bridge` to `--allowedTools`, so the bridge's approval is the only prompt, and leaves out
  `--strict-mcp-config`, so the user's own servers still load. Each launch mints a fresh token bound to the Claude
  session id. Catalog probes get no server. The session's MCP list shows `sesori_bridge` without controls.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated: `sesori_mcp_access_test.dart` (mint, bind, unknown and post-restart tokens, the setting, caller resolution from session rows), `sesori_mcp_server_test.dart` (loopback bind, Origin, Host, path, method, content type, bearer and size refusals), and `sesori_mcp_endpoint_test.dart` (protocol handshake, unbound and unknown tokens, every read tool, transcript paging end to end, an archived run, each proposing tool, the stale check for update, pause, resume, run now and a deleted task, one request per session, a run now that does not start, a grandchild's request on the root session, refused proposals), `scheduled_task_change_description_builder_test.dart` (order, the Approve everything line, escaping), the run note in `scheduled_task_run_service_test.dart` (text runs on a flagged harness with the setting on, both run start paths, none for a command, an unflagged harness or the setting off), `session_creation_service_test.dart` (after the worktree note, hidden from the user text), `session_prompt_service_test.dart` and `system_context_test.dart` (every leading note stripped), and the agent-approval case in `orchestrator_emit_bridge_event_test.dart` (a finished run stays awaiting input across a reconnect, YOLO on never answers, Allow over the reply route applies and clears it). Claude Code: `claude_launch_spec_test.dart` (the config, the env-only token, `--allowedTools`, no strict flag, nothing without a launch), `claude_session_process_repository_test.dart` (a bound token per launch, none for a probe) and `claude_mcp_mapper_test.dart` (the server without controls). |
| L3 Release | Per injected harness, on an isolated home with the local test proxy: the server is listed and connected in the session's MCP list beside a user-scope server; a scheduled run calls `get_task` and resolves to its own task while a concurrent plain session resolves to itself; an `update_task` raises the approval on the run's session, Allow changes the next run's prompt, and that run's note reaches the harness but not the app; no token in argv, the bridge log or harness files; resuming the session in the harness's own CLI lists only the user's servers and leaves the user config unchanged. Claude Code 2.1.325 passed on 2026-11-17. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Vary the token (missing, wrong scheme, unknown, minted but unbound, bound to a deleted session), the Host header
(`localhost`, another port, a public name) and the body size around 1 MiB. Page a transcript of a long same-session
task to its start and compare it with the app's view of the session. Use fixture tasks and prompts only.

## Material Failure Signals

- The endpoint answers on a non-loopback address, or accepts a request carrying `Origin` or a foreign `Host`.
- A token appears in argv, a URL, a log line or a harness config file.
- A user's own MCP server stops loading in a Sesori-started session, or a session resumed in the harness's own CLI
  still has `sesori_bridge`.
- An unknown or pre-restart token gets anything but 401, or an unbound token reads any task data.
- A call resolves to the wrong session or another plugin's session.
- A transcript page repeats or drops a message, or a read starts a harness or fails on an archived session.
- The run note shows in the app, reaches a command's arguments, or reaches a harness that has no Sesori server.
- A proposal changes a task before the user allows it, YOLO answers it, Allow applies a change after the user edited
  the task, or the request text omits the Approve everything warning.
- Transcript text, a prompt or tool arguments show up in bridge logs.

## Known Limitations

- Only Claude Code injects the server so far; the other harnesses land with their injection steps and are recorded
  in [harness capabilities](../HARNESS_CAPABILITIES.md).
- On Claude Code, a session's server keeps the token it launched with until the process exits or is reaped; a
  resumed process gets a new one. Claude keeps a per-server MCP log folder (`mcp-logs-sesori-bridge`) in its cache.
- Tokens are not revoked when a harness process exits; they live until the bridge stops.
- A bridge restart drops waiting requests; the phone's modal for one then fails to reply.
- Agents cannot delete tasks or change a task's project, harness, agent, fast mode or worktree.
- `get_task` and `list_tasks` cover tasks not yet done; a finished one-off task is not listed.

## Harness Scope

The endpoint and tools are harness-neutral and live in `bridge/app`. Injected: Claude Code
(`bridge/sesori_plugin_claude`, `ClaudeLaunchSpec`). Each later injection step adds its harness here.

## Related Coverage and Sources

- [Scheduled tasks](scheduled-tasks.md), [MCP management](mcp-management.md),
  [Session history and recovery](session-history-and-recovery.md).
- Bridge: `SesoriMcpServer` (`foundation/`), `SesoriMcpRequestDispatcher`, `SesoriMcpResultFormatter` and the tool
  catalog (`routing/sesori_mcp/`), `SesoriMcpAccessService`, `ScheduledTaskAgentService`,
  `ScheduledTaskChangeDescriptionBuilder`, `AgentApprovalRepository`,
  `SesoriMcpGrantRepository` and `BridgeSesoriMcpAccessImpl` under `bridge/app/lib/src/`, with tests under
  `bridge/app/test/bridge/sesori_mcp/`.
- Plugin contract: `SesoriMcpAccess` and `SesoriMcpLaunch` in `bridge/sesori_plugin_interface`.
- Plan: [.plan/active/sesori-mcp/PLAN.md](../../.plan/active/sesori-mcp/PLAN.md).
