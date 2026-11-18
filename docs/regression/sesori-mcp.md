# Sesori MCP For Agents

## Capability

The bridge serves its own MCP server, `sesori_bridge`, to agents in the harness sessions it launches, so an agent can
read the computer's scheduled tasks, their runs and a run's transcript, and propose pausing, resuming or running a
task, which the user allows on their phone, through the same bridge services the app uses.
The server is streamable HTTP on `127.0.0.1` with an ephemeral port, JSON responses only, and a per-launch bearer token
that names the calling session. `sesori-bridge config agent-tools on|off` (default on) decides whether launches get a
token at all.

No plugin injects the server yet, so no harness can reach it; until a plugin does, every check below runs headlessly
against the endpoint. The per-harness injection is a later step of the plan.

| Tool | Effect |
|---|---|
| `list_tasks` | Every task not yet done: id, name, project (the caller's marked), schedule, on or off, next run, last outcome. Optional `project_id` filter. |
| `get_task` | One task's full definition and state; without `task_id`, the caller's own task when the caller is a scheduled run. |
| `list_task_runs` | A task's newest runs, newest first, with the start of each run session's final reply. |
| `get_task_run_transcript` | One run's session as text, newest page first, about 20,000 characters a page, with a `page` cursor to older messages. Archived run sessions work. |
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
- A proposing tool changes nothing by itself. It raises a bridge-owned permission request on the calling session (surfaced under its root session) and returns at once. The
  request reuses the permission wire, push, modal and reply route; it hides "Always", and its id is random, so a
  modal left over from before a restart cannot answer a newer one. Requests live in memory only.
- A session has at most one waiting request: a new proposal withdraws the earlier one (announced as rejected).
- The request text opens with a bold Approve everything warning whenever the task keeps running and acts without
  asking (not for a pause), then names the project, the action (a resume also shows the schedule) and who asked.
  Agent-written names and titles are escaped.
- Allow applies the change through the same service calls as the app. Every change carries the task definition its
  text was built from; when the stored task differs or is gone, Allow applies nothing and the reply
  route answers 409 "The task changed since this was proposed". Reject drops it.
- A session with a waiting request is listed as awaiting input in project summaries, including the first summary
  after a reconnect, even when its run has finished.
- YOLO and per-session auto-approval never answer these requests.
- Transcript pages never overlap or skip a message; a message longer than a page is cut with a visible marker. Reads
  use only what the bridge stored, archived audit files included, and never start a harness. Reasoning is left out and
  tool results are cut to a short excerpt.
- Transcript content, prompts and tool arguments are never logged.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included: no harness reaches the server yet. |
| L2 Routine | Automated: `sesori_mcp_access_test.dart` (mint, bind, unknown and post-restart tokens, the setting, caller resolution from session rows), `sesori_mcp_server_test.dart` (loopback bind, Origin, Host, path, method, content type, bearer and size refusals), and `sesori_mcp_endpoint_test.dart` (protocol handshake, unbound and unknown tokens, every read tool, transcript paging end to end, an archived run, each proposing tool, the stale check for pause, resume, run now and a deleted task, one request per session, refused proposals), `scheduled_task_change_description_builder_test.dart` (order, the Approve everything line, escaping) and the agent-approval case in `orchestrator_emit_bridge_event_test.dart` (a finished run stays awaiting input across a reconnect, YOLO on never answers, Allow over the reply route applies and clears it). |
| L3 Release | No additional coverage: no plugin injects the server yet. Each injection step adds its live harness check here (the server listed, a call resolving to the right session, no token in argv, URLs or harness session files). |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Vary the token (missing, wrong scheme, unknown, minted but unbound, bound to a deleted session), the Host header
(`localhost`, another port, a public name) and the body size around 1 MiB. Page a transcript of a long same-session
task to its start and compare it with the app's view of the session. Use fixture tasks and prompts only.

## Material Failure Signals

- The endpoint answers on a non-loopback address, or accepts a request carrying `Origin` or a foreign `Host`.
- A token appears in argv, a URL, a log line or a harness config file.
- An unknown or pre-restart token gets anything but 401, or an unbound token reads any task data.
- A call resolves to the wrong session or another plugin's session.
- A transcript page repeats or drops a message, or a read starts a harness or fails on an archived session.
- A proposal changes a task before the user allows it, YOLO answers it, Allow applies a change after the user edited
  the task, or the request text omits the Approve everything warning.
- Transcript text, a prompt or tool arguments show up in bridge logs.

## Known Limitations

- No harness injects the server yet; per-harness support lands with the injection steps and is recorded in
  [harness capabilities](../HARNESS_CAPABILITIES.md).
- Tokens are not revoked when a harness process exits; they live until the bridge stops.
- A bridge restart drops waiting requests; the phone's modal for one then fails to reply.
- Agents cannot create, edit or delete tasks yet.
- `get_task` and `list_tasks` cover tasks not yet done; a finished one-off task is not listed.

## Harness Scope

Harness-neutral: the endpoint and tools live in `bridge/app`. Each injection step adds its harness here.

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
