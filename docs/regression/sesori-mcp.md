# Sesori MCP For Agents

## Capability

The bridge serves its own MCP server, `sesori_bridge`, to agents in the harness sessions it launches, so an agent can
read the computer's scheduled tasks, their runs and a run's transcript, propose task changes the user allows on
their phone, send the user a page of questions, and set wake-ups for their own session, through the same bridge
services the app uses.
The server is streamable HTTP on `127.0.0.1` with an ephemeral port, JSON responses only, and a per-launch bearer token
that names the calling session. `sesori-bridge config agent-tools on|off` (default on) decides whether launches get a
token at all.

Claude Code sessions, Codex threads and Pi, Oh My Pi, Grok and GitHub Copilot sessions get the server. Antigravity,
Hermes and Cursor stay off until a live check passes, and OpenCode and DeepSeek have no per-session seam for it; their
checks run headlessly against the endpoint. Per-harness status is in [harness capabilities](../HARNESS_CAPABILITIES.md).

| Tool | Effect |
|---|---|
| `list_tasks` | Every task not yet done: id, name, project (the caller's marked), schedule, on or off, next run, last outcome. Optional `project_id` filter; one no task or project has is an argument error. |
| `get_task` | One task's full definition and state; without `task_id`, the caller's own task when the caller is a scheduled run. |
| `list_task_runs` | A task's newest runs, newest first, with the start of each run session's final reply. |
| `get_task_run_transcript` | One run's session as text, newest page first, about 20,000 characters a page, with a `page` cursor to older messages. Archived run sessions work. |
| `create_task` | Proposes a new text task in the caller's project (or `project_id`) with the caller's harness; worktree off, fast mode off, default agent. An optional `command` runs before each run's prompt. |
| `update_task` | Proposes changes to name, prompt text (or a command task's arguments), schedule, time zone, missed-run policy, run mode, model, effort and approval mode. Left-out or empty fields keep their value, so an agent cannot clear a command's arguments (the app can). The request lists only fields that differ from the task: each old value struck through beside the new one, and a prompt change as a git-style line diff (removed lines red, added lines green, two unchanged lines around each change and an `@@` line for the rest). An older app shows the same text with the diff untinted. `command` sets or replaces the shell command each run runs first and `remove_command: true` removes it; passing both is an argument error, and a task that runs a slash command cannot take one. |
| `pause_task`, `resume_task`, `run_task_now` | Propose pausing, resuming or running a task once now. |
| `send_page` | Shows the user a page: a title, an optional intro, and sections with headings, Markdown bodies, images and single, multiple or text questions. Returns at once; the answer arrives as a notice. |
| `schedule_wakeup` | Sets a wake-up for the caller's root session: a label, a prompt and `when` (`in` or `every` N minutes, or `daily`, `weekdays` or `weekly` at `HH:MM` in `time_zone`, default the bridge computer's), and an optional `command` to run first. Needs no approval unless it runs a command outside Approve everything. |
| `list_wakeups` | The root session's wake-ups, soonest first: label, id, next time and how it repeats. |
| `cancel_wakeup` | Cancels one of the root session's wake-ups by `wakeup_id`. |

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
- Results are text only, with no `structuredContent`. Read tools, `list_wakeups` and `send_page` are advertised with
  `readOnlyHint: true`, proposing tools with `false`.
- A proposing tool changes nothing by itself. A create or update is first validated as the app's editor would, so the
  user never allows a task that cannot be saved. A model the agent names, other than the task's current one, must be
  one the task's harness offers (an unreadable list lets it through), so an allowed change cannot leave runs failing
  with "model not offered". The tool then raises a bridge-owned permission request on the calling session (surfaced under its root session) and returns at once. The
  request reuses the permission wire, push, modal and reply route; it hides "Always", and its id is random, so a
  modal left over from before a restart cannot answer a newer one. Requests live in memory only.
- A session can have several requests waiting at once (for example a pause and then a prompt edit of the same task).
  Each is answered on its own; the app's banner counts them and its modal opens the next after each answer.
- The request text opens with a bold Approve everything warning whenever the resulting task acts without asking (not
  for a pause; a stronger one when an update turns the mode on), then names the project, the action, the fields (all
  of them for a create, old → new for an update, the schedule for a resume) and who asked. Agent-written names and
  titles are escaped; a prompt sits in a fence it cannot close.
- Allow applies the change through the same service calls as the app. Every change to an existing task carries the
  definition its text was built from, and Allow checks only what that text showed: the fields the change sets (a
  schedule with its time zone, a model with its effort), the project, harness and approval mode it was described for
  (not for a pause), a resume's schedule, and whether a pause or resume is still needed. An update applies only its own fields on top of the current task, so allowing a pause and
  a prompt edit works in either order. When one of those changed (by the user or by another allowed request, so of
  two requests changing the same field the second loses), when the result no longer validates, or when the task is
  gone, Allow applies nothing and the reply route answers 409 "The task changed since this was proposed". An allowed
  run now that does not start (failed or skipped) also answers 409, and its run record holds the reason. Reject drops
  it. The app takes either 409 as an answer: the sheet closes and the next waiting request opens as after any answer,
  with no failure alert and no chat reload.
- Once the user answers, Sesori messages the session that shows the request (the root session for a sub-agent's) with
  the outcome: a bridge notice the app shows as a Sesori row with only its summary, addressed to the user, for
  example "You allowed pausing “Nightly”." or "You didn’t allow running “Nightly” now.". The agent also reads guidance:
  what was saved and when it applies, a created task's id, "Read it with get_task" for a stale change, why a run now
  did not start, not to propose a rejected change again, that a sub-agent asked when one did, and to reply in one
  short line (Grok fails a turn that ends with no visible text). Proposal results and tool descriptions say this message follows, so agents do not poll `get_task`.
- A harness that steers (Claude Code, Codex, Pi, Oh My Pi, OpenCode) takes the notice into a running turn; on the
  others it waits until the session is quiet and nothing waits on the user. The session's lane re-checks just before
  sending, so a turn started meanwhile makes it wait again. A scheduled run's session always hears it after the turn,
  so a notice never lands inside the run's own turn and the run's final reply stays its own. A finished scheduled run
  is woken by it. Archived and
  deleted sessions get nothing; a bridge restart drops a notice still waiting. The notice is not user activity: it
  leaves the session's last user message time alone.
- `send_page` does not block. It returns at once with "Sent “Title” to the user. Sesori will message this session
  with their answer.", and the answer arrives later as a notice. There is no cap on pages per session and pages do not
  queue: several can wait at once, and each is answered on its own.
- `send_page`'s description and its `sections[].questions` field tell the agent that every question has its own note
  field and every page ends with a free-text "Anything else?" field, so it adds no catch-all question of its own. An
  agent-written "Anything else?" question would show a second box and count toward the unanswered questions.
- `send_page` parses strictly: an unknown key at any level is refused naming it (`sections[].questions[].colour is
  not an argument`), and other errors name the indexed field (`sections[0].questions[1].options[2].label is required.`).
  A single or multiple question needs options and a text question takes none. Caps: a 200-character title, 50
  questions, 12 options a question, 20 images, 20 MiB an image and 50 MiB a page. The image cap counts every declared
  image, in sections, questions and options. Question ids are unique in the page and option ids in their question.
- Every refusal is an `isError` result that names what failed and stores nothing: a parse error, a cap, a duplicate
  id, a refused image, or a caller whose session row is gone ("This session is no longer known to Sesori.").
- A page image is an absolute path to a png, jpg, gif or webp file whose content matches its extension; a relative,
  missing, unreadable, oversized or non-image path is refused naming it. An image whose path and caption are both empty
  reads as no image, because strict-schema providers fill in the images they leave out that way. An empty path with a
  caption is refused as a missing path. Each distinct path is copied once into the bridge's page-images folder with its
  width and height, so the page keeps the image however the original changes. A failed send removes its copies. Page
  content and answers are never logged, only ids and counts.
- A page from a sub-agent shows on its root session. It rides the pending-question pipeline as a marker
  (`interactionKind: page`) whose header and question are the title: `/session/questions` lists it after the harness's
  questions (never for an archived session), push says "Question requires input" with the title as its body, and the
  session counts as awaiting input in project summaries until the page settles.
- Apps before v1.10.1 show the marker as a plain question with one Cancel option. `/question/reject` and
  `/question/reply` with a page's id dismiss the page instead of reaching the harness, refused with 409 for an
  archived session; a page already answered or closed answers 404 "no longer pending", so only the dismiss that wins
  succeeds. A dismissal tells the session "You closed “Title” without answering." with guidance not to send the page
  again unless the user asks.
- `POST /page/submit` settles a page with the user's answers. It is refused with 409 for an archived session and
  answers 404 for an unknown id or another session's page. The first submit wins: a page already answered or closed
  answers `alreadySettled`. Answers that leave a required question unanswered (a note alone doesn't answer), name an
  option outside their own question (option ids are unique only within it), carry a value of another kind than the
  question, name an unknown question or answer one twice answer `invalid` naming those questions, and the page stays
  pending. An accepted submit tells the root session "You answered “Title”."; the guidance lists one line per question
  with its id and title, the chosen option ids and labels or the text answer and its note, then the "Anything else"
  note, marks those as the user's own words on one line each, names the sub-agent session that asked, and asks for a
  one-line acknowledgement.
- `POST /page` opens a page, pending, answered (with its answers and note) or dismissed, by its id on the page's own
  session or the root session it shows on. A pending page of an archived session is `missing`, because archiving
  withdraws it for good; answered and dismissed pages open archived or not. Anything else is `missing`.
- Answer and dismissal notices carry `[SESORI PAGE] <id>` as the first line after `[FOR THE AGENT]`. The bridge reads
  it only there, live and on reload, into the text part's `noticePageRequestId`, so the user's line can reopen the
  page; a reference line anywhere else, such as inside a user's note, never counts. Notices without it, and every
  notice written before it, show as before, and released apps ignore the field.
- A wake-up belongs to the caller's root session, so a sub-agent's wake-up wakes, lists and cancels from the root,
  and a session cannot list or cancel another family's. Wake-ups are stored in the bridge database
  (`session_wake_ups`), survive a restart, and are deleted with their session. `schedule_wakeup` refuses a label
  over 100 characters (it is collapsed to one line), minutes outside 1 to 10080, a weekly kind without days, a time
  that is not `HH:MM`, an unknown zone, and a calendar kind when no zone is given and the bridge cannot tell its own.
  Its result names the id and the next time in the bridge computer's local time with its UTC offset, and tells the
  agent to end its turn instead of waiting.
- A due wake-up sends its session a notice "Wake-up: <label>" once the session's turn has ended, on every harness,
  steering ones included. The guidance names the wake-up id, when it was set and due, how late it is when the bridge
  was off or asleep past a two-minute grace, whether it repeats (and that `cancel_wakeup` ends it), then the agent's
  prompt. The bridge checks for due wake-ups at start and every 30 seconds.
- A one-shot is removed right before its send, so a cancel that lands while it waits wins and a restart before then
  fires it again; a crash between removal and send loses it. A repeating wake-up moves to its first time after now
  before it is sent, so missed times never pile up, and an occurrence that comes due while the previous one still
  waits is skipped. Archiving the session removes its wake-ups when they come due, repeating ones included.
  Labels and prompts are never logged, only ids.
- `schedule_wakeup` takes an optional `command`, a shell command line run right before the prompt is sent. While
  Approve everything covers both the calling session and its root it is stored at once; otherwise it raises the usual permission card ("Sesori:
  wake-up command": the command verbatim, with each bidi or zero-width character shown as its `<U+XXXX>` code so it
  cannot make the command read differently, where it runs, when, the label) and nothing is stored until Allow, which
  counts the first time from the Allow. Reject stores nothing; either answer sends the session a notice. A command
  stored under Approve everything asks again at its time once the session no longer does: Allow runs it and is
  remembered, so later times never ask; Reject cancels the wake-up and tells the session. Wake-ups without a command
  never ask.
- A task can carry a shell command, set only through `create_task` or `update_task` and the user's Allow; the app
  shows it read-only on the task page and its edits keep it, except an edit to a slash-command prompt, which drops it.
  The request shows it fenced like a wake-up's, with invisible characters as codes: "Runs this command before each
  run's prompt" for a create, resume or run now, and for an update "Adds a command", a `diff` of the old and new
  command, or "Stops running this command". Allow is stale once the command differs from the one the request showed.
  When a run starts, the command runs in the project folder (a same-session task's session worktree or folder once it
  has one) before the prompt, outside the fire lock; the run counts as going until the prompt is sent, so a due time
  meanwhile is skipped and Run now refused. Its output goes under `command-output/task-<id>/`. The text prompt then
  opens with a hidden note, after the improvement note when there is one: "Before this run, Sesori ran the task's
  command in <dir>:", the command and its result, every line indented so output cannot end the note. A failing
  command still sends the prompt. `get_task` shows the command.
- A command runs through the login shell (`$SHELL -lc`, `/bin/sh` when unset; `cmd.exe /d /s /c` on Windows) in the
  session's worktree, or its folder, with stdin closed and a 10-minute limit that kills it; a bridge shutdown kills it too.
  A kill reaches every process below the shell: `taskkill /T /F` on Windows; on POSIX the shell is stopped, then its
  descendants in `ps` and the shell are killed. An output file that cannot
  be written, as on a full disk, leaves the command running and its result saying the full output could not be saved. Before it runs, an
  archived or deleted session's wake-up is removed without running, a one-shot's row is removed, and a repeating
  one has moved to its next time, so a restart during the command never runs it twice for one time. The notice then
  adds "Before this message, Sesori ran your command in <dir>:", the command, and its result: the exit code (or the
  timeout or failure to start) first, then stdout and stderr in their own sections, each shown whole up to 500 words
  and otherwise as "<stream> 32,131 words; full output at <path>" with its last 20 lines. Output files live under
  `~/.sesori/command-output/<session>/<date>-<random>/`, readable only by the user, and are deleted with the session
  or after seven days. Commands are never logged.
- Sessions carry their wake-ups (`Session.wakeUps`: id, next time, label, whether it repeats or runs a command) and
  their arming (`Session.arming`). A session is armed by its soonest pending wake-up or by the next run of an enabled
  same-session task that continues in it, whichever comes first; an archived session is never armed. Every schedule,
  cancel, fire and advance of a wake-up, and every task edit, pause, resume, delete, fire or new target, republishes
  the affected session. Older bridges omit both fields: no wake-ups and `unreported` arming, so the app keeps its
  plain task mark. `POST /session/wake-up/cancel` lets the user cancel any of a root session's wake-ups, repeating
  ones included, and answers with the updated session, also when the wake-up was already gone.
- In the app, a session with wake-ups shows an alarm chip in its composer's model row, "Wakes <time>" for the
  soonest one (the glyph alone on touch rows). The chip grows in beside the pickers as it fades up and folds away when
  the last wake-up goes; nothing above the composer moves. Its menu lists each wake-up with its label, time, a repeat
  or alarm glyph and a terminal glyph when it runs a command, and a Cancel button that closes the menu and cancels
  it. A failed cancel says so and keeps the wake-up. Older bridges send no wake-ups, so the chip never offers them.
- A run's final reply (`list_task_runs`) is the agent's last text in the newest turn a user prompt started, read from
  the newest 10 messages. A turn a notice started is skipped, so the agent's answer to a notice never replaces the
  run's reply and a Sesori row is never one. A later same-session run's reply replaces it.
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
  declares false until its injection step (Claude Code, Codex, Pi, Oh My Pi, Grok and GitHub Copilot declare true). A command task gets no note. The note goes to the harness only: the run's
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
- Claude Code: every session launch, resume, rewind and idle respawn passes the server through `--mcp-config <file>`.
  Only that file holds the token. It sits in a 0700 folder under the plugin's state directory and is deleted once the
  stdin handshake ends. Neither argv nor the child's environment holds the token, so `env` in the agent's Bash shows
  none. The launch adds `mcp__sesori_bridge` to `--allowedTools`, so the bridge's approval is the only prompt, and leaves out
  `--strict-mcp-config`, so the user's own servers still load. Each launch mints a fresh token bound to the Claude
  session id. Catalog probes get no server. The session's MCP list shows `sesori_bridge` without controls.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated: `sesori_mcp_access_test.dart` (mint, bind, unknown and post-restart tokens, the setting, caller resolution from session rows), `sesori_mcp_server_test.dart` (loopback bind, Origin, Host, path, method, content type, bearer and size refusals), and `sesori_mcp_endpoint_test.dart` (protocol handshake, unbound and unknown tokens, every read tool, transcript paging end to end, an archived run, each proposing tool, the stale check for update, pause, resume, run now and a deleted task, several requests per session in either order, two requests changing one field, an edit applied over other fields' changes, the warning's approval mode, a project move, a time zone change under a schedule edit, a rebased update that no longer validates, a run now that does not start, a grandchild's request on the root session, refused proposals, a model the harness
does not offer, `send_page` (copied images with their sizes, every cap, each refused image, strict nested arguments), the outcome notice for each answer with its target session, sub-agent line and created task id, and the final reply skipping notice turns, the wake-up tools with root scoping, another family's id and each refused argument, a command wake-up asked for and allowed, and stored at once under Approve everything), `session_notice_service_test.dart` (at once when quiet or on a steering harness, after the turn for a scheduled run's session or an after-turn notice, after the idle on others, waiting again when busy at the in-lane check, none for archived or deleted sessions, dropped at shutdown, the claim run in the lane and a lost claim), `session_wake_up_service_test.dart` (due one-shot removed by its claim, missed repeats collapsed, in-flight skip, cancel while waiting, re-fire after a dropped delivery and restart, archived and deleted sessions, a daylight-saving change, no zone; commands under Approve everything and by Allow, Reject, the ask at fire time after leaving Approve everything with Allow remembered and Reject cancelling, an archived session's command never run, a one-shot's row gone and a repeating one advanced before its command runs), `scheduled_command_repository_test.dart` (real `/bin/sh`: exit code, stream files in an owner-only folder, a long stream's count and tail, the timeout and stop kills, a background child killed with its shell, an unwritable file, a missing folder, stdin closed), task commands in `sesori_mcp_endpoint_test.dart` (create, set, change, keep across an app edit, remove, a stale command request, run now's text, both arguments and a slash-command task refused), the command phase in `scheduled_task_run_service_test.dart` (project folder, a same-session worktree, the note after the run note, Run now refused meanwhile, no prompt after a shutdown), `scheduled_task_command_migration_test.dart`, `scheduled_command_result_formatter_test.dart`, `session_wake_ups_migration_test.dart` (both versions), `local_time_zone_test.dart`, `scheduled_task_change_description_builder_test.dart` (order, the Approve everything line, escaping, each command line and invisible characters), the run note in `scheduled_task_run_service_test.dart` (text runs on a flagged harness with the setting on, both run start paths, none for a command, an unflagged harness or the setting off), `session_creation_service_test.dart` (after the worktree note, hidden from the user text), `session_prompt_service_test.dart` and `system_context_test.dart` (every leading note stripped; the page reference written and read only at its fixed position, a spoofed one ignored), the agent-approval case in `orchestrator_emit_bridge_event_test.dart` (a finished run stays awaiting input across a reconnect, YOLO on never answers, Allow over the reply route applies and clears it, the notice reaches the plugin and its echo leaves the last user message time alone; a sent page is a page question that marks the session awaiting, and closing it rejects the question and sends the dismissal notice; a submitted page sends the answer notice with its reference, and the echoed line carries `noticePageRequestId`), `page_handlers_test.dart` (lookup of pending, answered, dismissed, missing and another session's page, from the sub-agent and the root, archived; submit accepted with its notice, first submit wins, each invalid case, archived 409, unknown 404), `agent_page_answer_notice_builder_test.dart` (the answer lines, a spoofed reference in a note, the sub-agent line, both references), `plugin_message_mapper_test.dart` (a reloaded page notice keeps its reference), `get_session_questions_handler_test.dart` (page markers after the harness's questions, none for an archived session), `reject_question_handler_test.dart` and `reply_to_question_handler_test.dart` (a page id dismisses once, then 404; archived 409; another session's id reaches the harness), `acp_sesori_mcp_test.dart` (the server on new, load and the live-process reload, none for the history process or with agent tools off) and `grok_approval_registry_test.dart` (Grok's prompt allowed only for Sesori's tools), for Pi `pi_session_process_repository_test.dart` (only the resident process gets the environment, bound to its session, nothing in argv) and `pi_rpc_startup_extension_test.mjs` (tool names, schemas and forwarded calls, the variables removed and a reload, a refused list), and for Codex the `config` of `thread/start`, `thread/resume` and `thread/fork` and its binding in `codex_plugin_write_path_test.dart` and `codex_plugin_rewind_test.dart`, the inventory entry in `codex_mcp_repository_test.dart`. Claude Code: `claude_launch_spec_test.dart` (the config file argument, a token-free environment, `--allowedTools`, no strict flag, nothing without a launch), `claude_session_process_repository_test.dart` (a bound token per launch in a file deleted after the handshake, none for a probe) and `claude_mcp_mapper_test.dart` (the server without controls). |
| L3 Release | Per injected harness, on an isolated home with the local test proxy and a user MCP server in the harness config: the tools are listed beside the user's; a scheduled run gets the note, calls `get_task` and resolves to its own task, and its proposal waits on the run session while a concurrent plain session's lands on that session; Allow applies and Reject leaves the task; no token in argv, URLs, the bridge log or harness session files; resuming in the harness's own CLI shows no `sesori_bridge` and leaves the config unchanged. Pi: also the agent's own `env` shows no `SESORI_MCP_` variables. Codex: a scheduled run gets the note, calls `get_task` and `update_task` with no Codex prompt, and the request names the run's own task; Allow changes the next run's prompt; the thread inventory lists `sesori_bridge` and the user's server; a concurrent plain session's `get_task` answers that it is not a scheduled run; after a bridge restart a resumed thread's tool call works; a resume in Codex's own app-server lists only the user's server, `config.toml` is unchanged, and no token or server URL is in `CODEX_HOME`; the agent's own `env` shows no token. ACP harnesses: also two concurrent runs each resolve to their own task and the agent's `env` shows no token. Oh My Pi 18.21.0, Grok 1.0.30 and GitHub Copilot 1.0.113 passed on 2026-11-17, except that a user server and resuming in the harness's own CLI were not rechecked; Copilot's `update_task` passed in the closing regression, after the empty-field fix. Claude Code: also the agent's own `env` shows no token, and an `update_task` whose optional strings are empty is accepted. Claude Code 2.1.325 passed on 2026-11-17. Client on a headless iOS simulator: a request already waiting when the session opens shows in the Review card, and Review opens the existing modal without "Always", with the Approve everything line first; Allow applies and Don't allow leaves the task; the run's user message shows only the task's prompt, with the bridge live and again after an app restart. Security: a direct request with a session's token only raises an approval, another slot's bridge answers that token with 401, and any `Origin` gets 403. All passed on 2026-11-17; the push for a scheduled run's approval was not checked, since the simulator has no real APNs delivery. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Vary the token (missing, wrong scheme, unknown, minted but unbound, bound to a deleted session), the Host header
(`localhost`, another port, a public name) and the body size around 1 MiB. Page a transcript of a long same-session
task to its start and compare it with the app's view of the session. Use fixture tasks and prompts only.

## Material Failure Signals

- The endpoint answers on a non-loopback address, or accepts a request carrying `Origin` or a foreign `Host`.
- A token appears in argv, a URL, a log line, a harness config file or the agent's environment, or a Claude
  `--mcp-config` file outlives its launch handshake.
- A user's own MCP server stops loading in a Sesori-started session, or a session resumed in the harness's own CLI
  still has `sesori_bridge`.
- An unknown or pre-restart token gets anything but 401, or an unbound token reads any task data.
- A call resolves to the wrong session or another plugin's session.
- A transcript page repeats or drops a message, or a read starts a harness or fails on an archived session.
- The run note shows in the app, reaches a command's arguments, or reaches a harness that has no Sesori server.
- A proposal changes a task before the user allows it, YOLO answers it, Allow applies a change after the user edited
  the task, or the request text omits the Approve everything warning.
- Allowing a stale request shows a failure alert, reloads the chat ("Getting everything ready…"), or leaves the next
  waiting request unopened.
- Transcript text, a prompt or tool arguments show up in bridge logs.
- A page submit after another surface's settles the page again or sends a second notice, an archived session's page
  accepts answers, or a reference line inside a user's note links the notice to another page.
- A wake-up fires twice for one occurrence, fires inside a running turn, reaches an archived session, or is
  cancelled by another session.
- A wake-up command runs without the user's Allow outside Approve everything, runs twice for one time, runs for an
  archived session, outlives its 10-minute limit, or its output is readable by other users or kept past seven days.
- A session stays armed after its last wake-up is gone or its task stops continuing in it, or an older bridge's
  session reads as not armed instead of unreported.
- An outcome notice stops a running turn, lands while a question or permission waits on the user, reaches an
  archived session, shows as the user's own message, or moves the session's last user message time.

## Known Limitations

- Only Claude Code, Codex, Pi, Oh My Pi, Grok and GitHub Copilot inject the server, as recorded in
  [harness capabilities](../HARNESS_CAPABILITIES.md). Antigravity, Hermes and Cursor stay off until a live check
  passes; OpenCode has no per-session seam; DeepSeek's adapter rejects MCP servers.
- `update_task` and the scheduled-run note ask agents to leave out every field they are not changing, but a model
  that fills every schema field (seen with the OpenAI-compatible test provider through Claude Code and Copilot) can
  still send a whole `schedule` object when only the prompt should change. The request lists every field that
  differs from the task, so the user sees such a change before allowing.
- On Claude Code, a session's server keeps the token it launched with until the process exits or is reaped; a
  resumed process gets a new one. Claude keeps a per-server MCP log folder (`mcp-logs-sesori-bridge`) in its cache.
- On Pi, the token stays in the process's initial environment block, which only the same OS user can read.
- Copilot asks its own permission before each proposing tool, so an unattended Copilot run that proposes a change
  waits for the user twice. Grok's own prompt for a Sesori tool is answered by the plugin.
- Tokens are not revoked when a harness process exits; they live until the bridge stops.
- A bridge restart drops waiting task requests; the phone's modal for one then fails to reply. Pages are kept in the
  bridge database and survive it. It also drops an outcome
  notice still waiting for its session to go quiet.
- Agents cannot delete tasks or change a task's project, harness, agent, fast mode or worktree.
- A command's kill reads the process table once, after stopping the shell, so a process its child forks in that
  moment can outlive it. A command a shutdown kills loses that time's notice, and a task run's prompt; the run stays
  started with no session. Windows `cmd.exe` quoting and `taskkill /T` are not covered by tests.
- `get_task` and `list_tasks` cover tasks not yet done; a finished one-off task is not listed.

## Harness Scope

The endpoint and tools are harness-neutral and live in `bridge/app`. Injected: Claude Code (`bridge/sesori_plugin_claude`, `ClaudeLaunchSpec`), Pi (`bridge/sesori_plugin_pi`,
`piRpcStartupExtensionSource`, `PiSessionProcessRepository`), Codex (below), and Oh My Pi, Grok and GitHub Copilot through the shared ACP seam
(`bridge/sesori_plugin_acp`, `AcpAgentApi` and `AcpPlugin`).

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
  `bridge/app/test/bridge/sesori_mcp/`. Pages: `AgentPageService`, `AgentPageRepository`,
  `AgentPageAnswerNoticeBuilder` and the `/page` and `/page/submit` handlers. Wake-ups: `SessionWakeUpService`,
  `SessionWakeUpRepository`, `SessionWakeUpDescriptionBuilder`, `WakeUpCommandDescriptionBuilder`,
  `ScheduledCommandService`, `ScheduledCommandRepository`, `ShellCommandApi`, `SessionWakeUpTimerListener`, `readLocalTimeZone`, the
  projection in `SessionViewService` and `CancelSessionWakeUpHandler`;
  plan in [.plan/active/session-wakeups/PLAN.md](../../.plan/active/session-wakeups/PLAN.md). The app side is in
  [questions and permissions](questions-and-permissions.md#agent-question-pages).
- Plugin contract: `SesoriMcpAccess` and `SesoriMcpLaunch` in `bridge/sesori_plugin_interface`.
- Plan: [.plan/completed/sesori-mcp/PLAN.md](../../.plan/completed/sesori-mcp/PLAN.md).
