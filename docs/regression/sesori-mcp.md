# Sesori MCP For Agents

## Capability

The bridge serves its own MCP server, `sesori_bridge`, to agents in the harness sessions it launches, so an agent can
read the computer's scheduled tasks, their runs and a run's transcript, and propose task changes the user allows on
their phone, through the same bridge services the app uses.
The server is streamable HTTP on `127.0.0.1` with an ephemeral port, JSON responses only, and a per-launch bearer token
that names the calling session. `sesori-bridge config agent-tools on|off` (default on) decides whether launches get a
token at all.

Codex threads and Pi, Oh My Pi, Grok and GitHub Copilot sessions get the server; the other harnesses get it in later
steps of the plan or stay off, and until then their checks run headlessly against the endpoint. Per-harness status
is in [harness capabilities](../HARNESS_CAPABILITIES.md).

| Tool | Effect |
|---|---|
| `list_tasks` | Every task not yet done: id, name, project (the caller's marked), schedule, on or off, next run, last outcome. Optional `project_id` filter; one no task or project has is an argument error. |
| `get_task` | One task's full definition and state; without `task_id`, the caller's own task when the caller is a scheduled run. |
| `list_task_runs` | A task's newest runs, newest first, with the start of each run session's final reply. |
| `get_task_run_transcript` | One run's session as text, newest page first, about 20,000 characters a page, with a `page` cursor to older messages. Archived run sessions work. |
| `create_task` | Proposes a new text task in the caller's project (or `project_id`) with the caller's harness; worktree off, fast mode off, default agent. |
| `update_task` | Proposes changes to name, prompt text (or a command task's arguments), schedule, time zone, missed-run policy, run mode, model, effort and approval mode. Left-out or empty fields keep their value, so an agent cannot clear a command's arguments (the app can). The request lists only fields that differ from the task. |
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
- An empty string in any tool argument reads as left out, since strict-schema providers make the model fill every
  field. Arguments that still do not parse are refused with the field and the reason, for example
  `schedule.time is required when schedule.kind is daily.`
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
  declares false until its injection step (Codex, Pi, Oh My Pi, Grok and GitHub Copilot declare true). A command task gets no note. The note goes to the harness only: the run's
  user message shows the task's prompt, live and after reload, and a first prompt that also carries the worktree note
  hides both.
- ACP harnesses (Oh My Pi, Grok, GitHub Copilot): `session/new`, `session/load` and `session/resume` carry the server
  in `mcpServers` as a streamable-HTTP entry with the token in an `Authorization` header. Neither argv, a URL nor the
  agent's environment holds the token, so `env` in the agent's shell shows none. Each session mints one token, bound
  to its ACP session id once the agent names it, and keeps it for the bridge's lifetime; every later load of the
  session, including the live-process history reload, re-sends that same entry, because OMP and Grok replace a
  session's servers on each load. Catalog probes and the short-lived history process send an empty list. One agent
  process serves many sessions, and each call resolves to its own session.
- Grok: the plugin answers Grok's own permission request allow-once for a `use_tool` call named
  `sesori_bridge__<tool>` in a session it gave the server; every other tool, and the same name in a session without
  Sesori's server, still asks the user.
- Pi: the startup extension that every session process loads registers each listed tool with `pi.registerTool` as
  `mcp__sesori_bridge__<tool>` and forwards calls to the endpoint. Only the resident session process gets the URL and a
  fresh token, bound at once to its session id, through its environment; history, rename and catalog processes get
  none. The extension removes the variables at load, keeping them for a `/reload`. A refused or unreachable tool list
  leaves the session without Sesori tools and logs only the status.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated: `sesori_mcp_access_test.dart` (mint, bind, unknown and post-restart tokens, the setting, caller resolution from session rows), `sesori_mcp_server_test.dart` (loopback bind, Origin, Host, path, method, content type, bearer and size refusals), and `sesori_mcp_endpoint_test.dart` (protocol handshake, unbound and unknown tokens, every read tool, transcript paging end to end, an archived run, each proposing tool, the stale check for update, pause, resume, run now and a deleted task, one request per session, a run now that does not start, a grandchild's request on the root session, refused proposals), `scheduled_task_change_description_builder_test.dart` (order, the Approve everything line, escaping), the run note in `scheduled_task_run_service_test.dart` (text runs on a flagged harness with the setting on, both run start paths, none for a command, an unflagged harness or the setting off), `session_creation_service_test.dart` (after the worktree note, hidden from the user text), `session_prompt_service_test.dart` and `system_context_test.dart` (every leading note stripped), the agent-approval case in `orchestrator_emit_bridge_event_test.dart` (a finished run stays awaiting input across a reconnect, YOLO on never answers, Allow over the reply route applies and clears it), `acp_sesori_mcp_test.dart` (the server on new, load and the live-process reload, none for the history process or with agent tools off) and `grok_approval_registry_test.dart` (Grok's prompt allowed only for Sesori's tools), for Pi `pi_session_process_repository_test.dart` (only the resident process gets the environment, bound to its session, nothing in argv) and `pi_rpc_startup_extension_test.mjs` (tool names, schemas and forwarded calls, the variables removed and a reload, a refused list), and for Codex the `config` of `thread/start`, `thread/resume` and `thread/fork` and its binding in `codex_plugin_write_path_test.dart` and `codex_plugin_rewind_test.dart`, the inventory entry in `codex_mcp_repository_test.dart`. |
| L3 Release | Per injected harness, on an isolated home with the local test proxy and a user MCP server in the harness config: the tools are listed beside the user's; a scheduled run gets the note, calls `get_task` and resolves to its own task, and its proposal waits on the run session while a concurrent plain session's lands on that session; Allow applies and Reject leaves the task; no token in argv, URLs, the bridge log or harness session files; resuming in the harness's own CLI shows no `sesori_bridge` and leaves the config unchanged. Pi: also the agent's own `env` shows no `SESORI_MCP_` variables. Codex: a scheduled run gets the note, calls `get_task` and `update_task` with no Codex prompt, and the request names the run's own task; Allow changes the next run's prompt; the thread inventory lists `sesori_bridge` and the user's server; a concurrent plain session's `get_task` answers that it is not a scheduled run; after a bridge restart a resumed thread's tool call works; a resume in Codex's own app-server lists only the user's server, `config.toml` is unchanged, and no token or server URL is in `CODEX_HOME`; the agent's own `env` shows no token. ACP harnesses: also two concurrent runs each resolve to their own task and the agent's `env` shows no token. Oh My Pi 18.21.0, Grok 1.0.30 and GitHub Copilot 1.0.113 passed on 2026-11-17, except that a user server and resuming in the harness's own CLI were not rechecked; on Copilot with an OpenAI-compatible test provider, `update_task` arguments came back with every optional field empty and were rejected. |
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

- Only Codex, Pi, Oh My Pi, Grok and GitHub Copilot inject the server so far; the other harnesses land with their
  injection steps or stay off, as recorded in [harness capabilities](../HARNESS_CAPABILITIES.md). Antigravity, Hermes
  and Cursor stay off until a live check passes; DeepSeek's adapter rejects MCP servers.
- On Pi, the token stays in the process's initial environment block, which only the same OS user can read.
- Copilot asks its own permission before each proposing tool, so an unattended Copilot run that proposes a change
  waits for the user twice. Grok's own prompt for a Sesori tool is answered by the plugin.
- Tokens are not revoked when a harness process exits; they live until the bridge stops.
- A bridge restart drops waiting requests; the phone's modal for one then fails to reply.
- Agents cannot delete tasks or change a task's project, harness, agent, fast mode or worktree.
- `get_task` and `list_tasks` cover tasks not yet done; a finished one-off task is not listed.

## Harness Scope

The endpoint and tools are harness-neutral and live in `bridge/app`. Injected: Pi (`bridge/sesori_plugin_pi`,
`piRpcStartupExtensionSource`, `PiSessionProcessRepository`), Codex (below), and Oh My Pi, Grok and GitHub Copilot through the shared ACP seam
(`bridge/sesori_plugin_acp`, `AcpAgentApi` and `AcpPlugin`). Each later injection step adds its harness here.

- Codex: per-thread `config` on `thread/start`, `thread/resume` and `thread/fork` (`CodexSessionService`,
  `CodexAppServerApi`), never process-wide `-c`. An already-loaded thread keeps the token it was loaded with; the
  bridge and its app-server restart together.

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
