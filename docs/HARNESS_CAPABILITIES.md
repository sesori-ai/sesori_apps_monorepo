# Harness Capability Matrix

Sesori strives for feature parity across harnesses. This matrix records the
capabilities of the Sesori integration that not every harness has, so a gap is
a deliberate, visible state rather than an accident. Update it whenever a
capability lands for some harnesses but not others, or a harness limitation is
verified or lifted.

Capability tables include registered plugins where the relevant integration behavior has been verified. Antigravity is
included below, including the bounded authenticated sub-agent assessment completed on 2026-09-12. Its sub-agent cells
describe what Sesori can expose through the official ACP seam, not whether the native runtime delegates internally.

## Legend

| Mark | Meaning |
|---|---|
| ✅ | Implemented: Sesori exposes the capability for this harness. |
| ⬜ | Not implemented: the harness and the seam Sesori drives can provide it, Sesori does not yet. |
| 🚫 | Not supported: the harness or the protocol seam Sesori drives cannot provide it. The footnote names the verified version. |

## Automation transcript attribution

| Harness | Native evidence | Sesori availability |
|---|---|---|
| Pi | Visible `custom` messages / `custom_message` entries | ✅ Automation attribution live and after history load. |
| Claude Code | User-role frames, transcript records and `queued_command` attachments with `origin.kind: peer` | ✅ Automation attribution live and after history load, including `isMeta` peer records and peers queued mid-turn. |
| Claude Code (task notifications) | User-role `<task-notification>` turns with `origin.kind: task-notification`, `queued_command` attachments in `task-notification` mode, or a whole envelope on CLIs without origin | ✅ A notification no known Agent/Bash task absorbs renders as an Automation step live and after history load, including one queued mid-turn. |
| OpenCode (task notifications) | Unknown | Unverified: needs a probe of whether a background child's completion is injected as a user turn. |
| Codex (task notifications) | None | Not applicable: no background-task completion arrives as a user turn. |

Claude attribution uses host provenance, not plugin names or text matching. It
covers any sender using that peer/socket path, but `origin.from: unknown` does
not identify which plugin sent it. Missing/unmodelled origins and channels that
may forward human input are not promoted to automation. Existing task-outcome,
tool-result, compaction and hidden-metadata behavior remains separate.

Claude task notifications fold into the launching Agent/Bash tile when the
tracker knows the envelope's tool-use id. Otherwise (a SendMessage-resumed
agent, an unknown id or no tool-use id) the turn becomes one completed
Automation step labelled by the envelope's summary, with its result as output
and the summary as error on failure; note, usage and output-file are dropped.
An envelope that does not parse still renders as Automation text, never as a
user bubble. Only a text block that is a whole envelope counts as one without
provenance, so a prompt quoting the protocol stays user input.

Verified on **2026-09-25** with native Claude Code **2.1.281**, an isolated MCP
socket sender and a loopback model fixture: idle wake-up, live stdout provenance
and persisted records. Native captured frames/history also pass through the
production Claude parsers/mappers. Shared client fixture tests cover the existing
Automation surface; authenticated-provider and full client/relay journeys were
not exercised for this change.

A command Claude queues while a turn runs (a follow-up, a peer message or a
task outcome) is persisted as a `queued_command` attachment instead of a user
record. History maps it like its live replay frame: the attachment's
`source_uuid` (the record's own `uuid` on CLIs that omit it) as the id, the same
sender and parts, at the point the model received it. Verified on
**2026-09-26** with native Claude Code **2.1.281** captures and live rows the
bridge stored from CLIs 2.1.237 to 2.1.281.

## Quota-reset auto continuation

Claude/Pi also implement named-session readiness for idle, retry, queued work
and pending input, including known persisted sessions without a resident process.
Other harnesses return unavailable readiness. The bridge implements durable,
session-level opt-in through `PATCH /session/auto-continuation`, scheduled sending,
and the authoritative setting/outcome in session responses and updates. Phone
and desktop chat share opt-in, a persistent menu toggle and outcome notices.

Audit date: **2026-09-24**. Internal terminal quota reporting is implemented for
the Claude Code and Pi cases below. Scheduled continuation is implemented through
the headless API for those reporting formats; live post-reset provider recovery
remains unverified. The
[active plan](../.plan/active/quota-auto-continuation/PLAN.md) tracks remaining
live-provider and platform verification.
The [evidence record](../.plan/active/quota-auto-continuation/EVIDENCE.md)
distinguishes observed local errors from upstream contracts and open checks.

Eligibility depends on a terminal quota interruption **and** a usable reset
time for the selected provider/account/model. Native transient retries are a
different capability. “Not implemented; unverified” means the control is
unavailable and protocol support has not yet been established. It is not a claim that
the harness cannot support this feature; do not mark it 🚫 without verification.

| Harness | Reset evidence | Sesori availability |
|---|---|---|
| Claude Code | Tagged session-limit error with IANA zone | ✅ Conditional; root terminal error only. |
| Pi | Recognized `openai-codex` error text | ✅ Conditional; final RPC settlement verified on 0.85.1 / 0.84.1. |
| Codex | Local and documented reset timestamps | Not implemented; failed-turn bucket binding unverified. |
| OpenCode | Raw error data reaches mapper | Not implemented; reset payload/provider attribution unverified. |
| GitHub Copilot | ACP payload needs inspection | Not implemented; reset reporting unverified. |
| Cursor | Headless payload needs inspection | Not implemented; reset reporting unverified. |
| Hermes Agent | ACP payload needs inspection | Not implemented; reset reporting unverified. |
| Oh My Pi | ACP seam differs from Pi RPC | Not implemented; reset reporting unverified. |
| DeepSeek | ACP payload needs inspection | Not implemented; reset reporting unverified. |
| Grok Build | ACP payload needs inspection | Not implemented; reset reporting unverified. |
| Antigravity | Official ACP payload needs inspection | Not implemented; reset reporting unverified. |

- Claude recognizes the tagged `rate_limit` assistant error beginning “You've
  hit your session limit”. The observed time/zone format yields a UTC reset
  only when it identifies one future time on the original local date. Unrecognized
  dates, past times, unknown zones, and ambiguous/nonexistent DST times remain
  unknown. Root errors report only after an unsuccessful, non-aborted result;
  forwarded subagent traffic cannot arm or replace the root candidate.
  Process-wide SDK rate-limit frames remain ignored because their rejected
  window has no verified message attribution.
- Pi's local `openai-codex` assistant errors sometimes report a relative retry
  duration; others give no reset. Other providers/formats remain unverified.
  A positive duration is anchored to the original assistant timestamp. Unknown
  or malformed resets remain unknown. Synthetic-provider RPC probes on the
  managed target (0.85.1) and PATH floor (0.84.1) confirmed that `agent_settled`
  follows final retry resolution. Those probes did not exhaust a real account;
  provider-format evidence comes from local errors and pinned upstream source.
  This evidence does not establish support for Oh My Pi's ACP seam.
- Codex local rollouts and documented app-server account limits contain reset
  timestamps; terminal usage-limit errors are already rendered. Bind the failed
  turn to its applicable exhausted buckets; an account snapshot cannot schedule.
- OpenCode raw backend errors reach the mapper before presentation flattening.
  Generic 429 responses and native retries do not establish quota exhaustion.
- Generic ACP has no universal reset field. Inspect each adapter's actual error
  data/extensions; provider behavior can differ. Billing/credit exhaustion with
  no reset is unschedulable. Native application UI or displayed text alone does
  not establish a usable timestamp through Sesori's driven protocol.

Existing error messages remain visible, including errors with unknown resets.
Other descriptors report quota support as unavailable until their provider and
terminal-turn binding are verified. There is no shared model-name allowlist.
Enabling an unavailable harness returns 501; disabling an existing preference
remains available. Known resets use a two-minute buffer and one ordinary
`Continue.` attempt. Non-idle readiness pauses checks for five minutes; unknown
resets never schedule. Manual send, Stop, archive and newer native activity cancel
the current wait while retaining the preference for later quota interruptions.

## Individual queued-prompt cancellation

| Harness / boundary | Status |
|---|---|
| Pi and Claude, still bridge-pending | ✅ Implemented before dispatch; successful cancellation prevents backend submission. |
| Pi and Claude, already dispatched and awaiting user echo | 🚫 Individual cancellation is not supported through the driven seam; retained rows show Sending without trash. Immediate steering remains enabled. |
| ACP adapters, including OMP, before prompt-frame writing | ✅ Implemented; a cancelled pending entry never writes its prompt. Once writing starts, cancellation is refused and the row reports Sending until the user-message projection arrives. |
| OpenCode and Codex | No retained queue entries through this API; this does not claim a native per-item cancellation capability. |

Pi's installed 0.85.1 RPC `clear_queue` clears **all** steering/follow-up work,
including extension-owned input, and carries no Sesori prompt IDs. It cannot
safely implement deletion of one row; Sesori does not clear/replay that native
queue. This limit is verified from installed native source. Dispatch-state and
cancellation evidence is synthetic plugin/bridge/core/widget coverage, not a new
live authenticated run. Older public bridge payloads without dispatch ownership
remain explicitly unknown and retain best-effort cancellation. Only a reported
dispatched state suppresses trash. A late cancellation refusal is not success:
the client reports it without hiding still-live input; existing queue events and
reconnect snapshots keep the displayed state authoritative.

## Explicit shell-command presentation

Ordinary tools retain name, bounded title, status and attachments; only
adapter-verified shell commands retain command/output/error. Subtask outcome/error
summaries are separate and remain available. All retained tool text is
rune-bounded at live/history wire projection; the released title alias remains
available to older clients.

| Harness | Status and established command source |
|---|---|
| Claude | Implemented: exact `Bash` input command, retained through tool-result correlation and transcript replay. |
| OpenCode | Implemented: exact `bash` tool input command in generated SSE/REST tool parts. |
| Codex | Implemented: `commandExecution.command`, `exec_command` arguments, literal single-invocation code-mode commands, and correlated command-execution evidence. Normalized `shell` names and arbitrary JavaScript/title text are not authority. |
| Pi | Implemented: `bash` tool-call arguments and typed `bashExecution.command`, live and replay. |
| Grok | Implemented: exact `_meta["x.ai/tool"].name == "run_terminal_command"` plus typed `rawInput.command`. Evidence is the owning repository fixture, not a fresh upstream capture. |
| Antigravity | Implemented: canonical native command normalized from `CommandLine`, `command_line`, `commandLine`, `command`, or native output command aliases. Evidence is owning generated DTOs corroborated against pinned `AntigravityProtocol.ts` and synthetic fixtures; no new upstream/runtime verification. |
| Cursor, OMP, Hermes, DeepSeek, Copilot | Not implemented / command source not yet verified. Existing execute permission/kind or launch-command fixtures do not establish session shell-command provenance. This does **not** mean not supported by the harness. |

Generic ACP does not infer commands from titles, execute kinds, arbitrary content,
or command-shaped inputs. Adapter command evidence merges through the same live
and replay hook; status/output-only updates retain the last verified command.
Codex code-mode extraction accepts JSON argument objects or a literal first `cmd`
property in one real `tools.exec_command` invocation (single/double quotes and
whitespace accepted). Expressions, multiple commands and other JavaScript forms
need trustworthy correlated command-execution evidence; raw scripts never become
commands. No general JavaScript parser or runtime execution is involved.

## Ordinary tool titles

Non-shell tool cards show a bounded title naming what the tool touched (file
path, search pattern, skill, URL) instead of only the tool name; output and
errors stay stripped. Skills load through a file read of their `SKILL.md` on
harnesses without a dedicated skill tool, so the read path is the skill signal.

| Harness | Status and title source |
|---|---|
| Claude | ✅ Tool input `skill`, `file_path`, `notebook_path`, `pattern`, `path`, `url`, or `query`, first present; live tracker and transcript replay. |
| Pi | ✅ Tool-call arguments `pattern`, then `path`; live from `toolcall_end`/`message_end` and replay. `toolcall_start` carries no arguments, so the title first appears with the running or terminal update. |
| OpenCode | ✅ Native tool part `title`. |
| Codex | ✅ Argument-derived title (`cmd`, `command`, `path`, `filePath`, `query`, else bounded raw arguments). |
| Grok, Antigravity, Copilot, Cursor, OMP, Hermes, DeepSeek | ✅ Agent-supplied ACP `tool_call` title, when the agent sends one; Sesori does not derive titles from ACP inputs. A call without `kind` uses its title as the tool name and drops the title, so the card does not say it twice. |

## Tool kinds

Each plugin classifies its own tool names into read, edit, command, search or
other, and the transcript summary names calls by kind (“read 2 files · ran 1
command”). Other calls count as plain steps.

| Harness | Status and kind source |
|---|---|
| Claude | ✅ Built-in names: `Read`/`NotebookRead`; `Edit`/`MultiEdit`/`NotebookEdit`/`Write`; `Bash`; `Grep`/`Glob`/`LS`/`WebSearch`. MCP and other tools are other. |
| OpenCode | ✅ Built-in names: `read`; `edit`/`multiedit`/`write`/`patch`/`apply_patch`; `bash`; `grep`/`glob`/`list`/`codesearch`/`websearch`. |
| Pi | ✅ Built-in names: `read`; `edit`/`write`; `bash`; `grep`/`find`/`ls`. Extension tools are other. |
| Codex | ✅ Partial: shell calls are commands, file changes are edits and web searches are searches. Codex reads and searches files through shell commands, so those count as commands, not reads. |
| Grok, Antigravity, Copilot, Cursor, OMP, Hermes, DeepSeek | ✅ The ACP tool `kind`: `read`; `edit`/`delete`/`move`; `execute`; `search`. A call without a `kind`, or with `fetch`, `think` or `other`, counts as a plain step. |

## Managed runtime

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Sesori-managed runtime installed on request | 🚫 | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | 🚫 |
| Superseded managed runtime upgraded automatically on bridge start | 🚫 | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | 🚫 |
| Outdated PATH runtime has safe self-updater metadata | ✅ | ✅ | 🚫 | ✅ | 🚫 | ✅ | ✅ | ✅ | ✅ | 🚫 | ✅ |

Antigravity can explicitly download Google's proprietary official runtime pair directly from `dl.google.com`. Before
choosing Install, review [Google's terms](https://antigravity.google/terms) and
[Antigravity documentation](https://antigravity.google/docs/). Sesori independently pins and verifies six
archives: macOS x64/arm64, Linux x64/arm64, and Windows x64/arm64. macOS x64 support is **implemented** for
package `1.2.1`, including managed installation and explicit/PATH pair selection. Every archive keeps the server
and local harness as siblings, uses a conservative two-minute bound for each archive listing/extraction command,
and must pass the isolated initialize-only
identity check before placement. A configured `--antigravity-bin` remains authoritative and removes Install. Native
managed-pipeline correctness previously ran on macOS arm64 for `1.1.1`; `1.2.1` has native initialize/teardown
coverage but no completed managed-pipeline run. macOS x64 has verified archive integrity, hardened extraction,
executable modes and binary architecture; native execution and installation on Intel Macs remain unverified.
Linux and Windows native correctness remains unverified.
Linux requires Info-ZIP `unzip` with ZipInfo support, checked before download.
The [Antigravity operator guide](ANTIGRAVITY.md) covers the exact pair, manual setup, remote personal login and
retained-history behavior. Implemented marks here do not claim completed authenticated end-to-end verification.

Claude, Hermes, and Grok have no Sesori-managed runtime at all: they resolve a
user-installed CLI from PATH or an explicit binary option, so the managed
install and startup-upgrade rows do not apply. Separately, standard descriptors
can identify an outdated default PATH runtime and retain metadata for a verified
non-interactive harness-owned updater. This metadata is not yet executable
through the management API. Copilot, DeepSeek, and Antigravity remain manual,
as do all explicit binary overrides and OpenCode attach mode.

The managed startup upgrade only replaces a runtime Sesori already manages. A machine with no
managed version directory keeps the explicit Install action; it never downloads
a runtime the user has not asked for.

### Harness settings contract limitations (verified 2026-09-07)

These gaps apply to every registered harness through the current management wire seam
(`shared/sesori_shared/lib/src/models/sesori/plugin_management.dart` and install-progress SSE).
They do not claim that a harness's native CLI could never implement an equivalent feature.

| Capability through the current management seam | Status |
|---|---|
| Client-controlled automatic-update preference | 🚫 Not supported: no preference or command; existing bridge-start managed upgrades are unchanged. |
| Pause/stop/cancel a managed installation | 🚫 Not supported: no command or stopped outcome; these UI controls remain hidden. |
| Distinct update-required setup status | ✅ `runtimeOutdated` with optional sanitized version; no update action yet. |
| Enabled preference when runtime is unknown | 🚫 Not supported: unknown does not prove disabled; clients omit the switch. |
| Overall installation percentage or active-session count | 🚫 Not supported: only optional download percentage and idle/busy/unknown work state are reported. |
| Replay a failed installation observed by this client within the connection | ✅ Implemented for every harness advertising installation; memory only, not cross-device history. |

## Pre-start catalog import

| Capability | OpenCode |
|---|---|
| Metadata-only import before harness startup | ✅ |

OpenCode can read a safely identified local SQLite database as a coherent,
read-only snapshot. The reader consumes the pinned v1.18.19 project,
project-directory, and session schema and safely falls back to live import when
that contract is absent or invalid. Other harnesses retain their existing
plugin-backed import; no pre-start capability claim is made for them.
All harnesses cold-started only by import fallback or by session options
discovery use the shared five-minute transient idle residency cap.

## Option pickers

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Effort variants listed strongest first, default declared separately | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫¹⁷ | ✅ | ✅ | ✅ | ✅ |
| Anthropic and OpenAI models listed strongest first | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫¹⁸ | ✅ |

The picker shows each plugin's declared order. Every plugin ranks through the
shared `CatalogStrengthOrder`; models of other vendors keep the plugin's own
order after the ranked ones (OpenCode newest release first, others backend
order). Antigravity's account-advertised order remains for its unranked models.
Exact account IDs ending in `-high`, `-medium`, or `-low` become strongest-first
variants only when labels carry the matching suffix. Its pre-chat catalog uses
one retained hidden no-prompt native session because the pinned runtime exposes
models only from new/resume responses and has no deletion capability.

## Fast mode

| Harness | Status |
|---|---|
| Codex | ✅ Implemented. |
| Claude | ✅ Implemented for the Opus models the CLI reports as supporting it; fast turns draw on the account's extra usage. |
| OpenCode, Antigravity, Copilot, Cursor, Hermes, Pi, OMP, DeepSeek, Grok | ⬜ Not implemented (not assessed). |

Codex advertises fast mode per model as a `model/list` service tier: a model
offering a `serviceTiers` entry with id `"priority"` (Codex's "Fast" tier, e.g.
"2x speed, increased usage") reports `PluginModel.fastMode` as available with
a 30-minute prompt-cache lifetime; Codex has no account-level availability
signal. A selected
session's `fastMode` is sent as `serviceTier` on every `turn/start` —
`"priority"` when on, `"default"` when off, which explicitly returns the
thread to standard speed rather than leaving it on whatever tier a prior turn
set (verified against codex-cli 0.156.1's `generate-json-schema` output: the
sibling `TurnStartParams.serviceTierForTurn` field documents 'Use "default"
for standard speed', and `serviceTier` shares the same tier vocabulary) — and
on `thread/start` when a new session is created with fast mode on, so its
first turn already runs fast.

Claude Code reports fast-mode support per model as `supportsFastMode: true` in
the stream-json `initialize` response (omitted for models without it; in CLI
2.1.281 only some Opus models carry it), which sets `PluginModel.fastMode` with a
60-minute prompt-cache lifetime. Fast mode is not a launch flag: a fresh process
starts with it off, and the plugin sends the `apply_flag_settings`
control request (`{"subtype":"apply_flag_settings","settings":{"fastMode":…}}`, the shape the Agent SDK's `applyFlagSettings` sends) before a turn whenever the session's choice
differs from what the resident process last applied. The CLI acknowledges the
setting even when the model or account cannot use fast mode (for example, extra
usage turned off) and then serves at standard speed. The plugin reads the
handshake's account-level `fast_mode_disabled_reason` and reports those models
as unavailable with a closed reason: extra usage disabled (`extra_usage_disabled`),
not on the plan (`free`), disabled by the organization (`preference`,
`model_not_allowed`), or unknown (`not_first_party`, `disabled_by_env`,
`unknown`, and unmapped values, which are logged). In CLI 2.1.281 the
`sdk_opt_in_required` reason precedes the account checks and masks them, so the
global catalog probe opts in with `apply_flag_settings {fastMode: true}` and
sends a second `initialize`, whose reason is the real account state (verified
live: `sdk_opt_in_required` became `extra_usage_disabled`). The flag is
process-scoped (no settings file changes) and the probe is torn down afterwards.
Only the probe feeds the catalog; user-session handshakes are never used for
availability. If the opt-in or re-read fails, the failure is logged and fast
mode stays offered. The transient `network_error` and `pending` reasons also
keep it offered, with a log. Per-turn reasons from result messages are not tracked.

## Agent selection and harness modes

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Agent choice offered in the composer | 🚫 | ✅ | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 |
| Harness mode control (for example Plan or Ask) | ⬜ | ✅ | 🚫 | ⬜ | ⬜ | ⬜ | 🚫 | 🚫 | ⬜ | 🚫 | 🚫 |

Only OpenCode has real agents, and its plan agent is how its mode is chosen.
The composer shows the agent entry only when a harness advertises more than
one selectable agent, so it appears for OpenCode alone. Claude, Codex,
Copilot, Cursor and OMP have modes such as Plan and Ask that Sesori used to
list as agents; since 2026-09-21 each advertises only its default mode
(Cursor always its Agent mode) and Sesori offers no mode control. A mode name
that still arrives from a catalog captured earlier is honoured, never run in
the default mode. Naming the advertised default returns a session left in
another mode to the default with its next prompt.

## Read-only run details

Child sessions and archived sessions cannot prompt, so where the composer would
sit they show the agent, model and effort variant the session ran with as
read-only pills. A value Sesori does not know leaves its pill out. The agent
pill follows the composer's rule and appears only for a harness with an agent
choice; every other harness stamps a placeholder agent. What a child session
shows (verified from plugin code on 2026-09-26):

| Harness | Agent | Model | Variant |
|---|---|---|---|
| Claude | ⬜ placeholder | ✅ | ✅ after a history read |
| OpenCode | ✅ | ✅ | ✅ |
| Codex | ⬜ placeholder | ✅ from history | ✅ from history |
| DeepSeek | 🚫 | ✅ live, 🚫 after a restart | 🚫 |
| Grok | ⬜ placeholder | ✅ live, unverified from history | Unverified from history, 🚫 live |
| Pi (forks) | 🚫 | ✅ | ✅ |

Antigravity, Copilot, Cursor, Hermes and OMP produce no child sessions.

- Claude, Codex and Grok record the sub-agent's type natively, but it only
  labels the parent's subtask tile.
- Claude streams no effort, so a child seen only live names no variant until
  the bridge reads its history. A model the catalog does not list shows its raw
  id.
- OpenCode leaves the variant pill out when the child ran without one. Right
  after a child compacts, its agent reads `compaction` until its next reply.
- Codex takes a child's model and effort from its rollout's `turn_context`. A
  running child whose rollout is not flushed yet is stamped live with the
  `config.toml` default model until its history is read again. A turn that
  recorded no effort shows no variant.
- DeepSeek's protocol records no model or effort for a child. A child seen live
  carries the root's model at spawn, which is the model the adapter runs it on.
  After a bridge restart its history is stamped with the process default, so
  the model pill shows a guess.
- Grok names a child's model at spawn. History values come from the child's
  `session/load` and have not been checked against a live child.
- Pi has no sub-agents. A session forked in Pi records its parent, so it opens
  as a child session.

Archived sessions of every harness show the agent and model of their newest
agent reply. Archiving clears the bridge's stored defaults and a reply records
no variant, so the variant pill never shows (⬜). Display names and the
OpenCode agent choice come from the cached option catalog, so opening an
archived session never wakes its harness. Without a cached catalog the model
shows its id and the agent pill is left out.

## ACP multi-select form questions

| Harness | Sesori implementation | Verification boundary |
|---|---|---|
| OMP | ✅ Live ACP `items.anyOf` string-choice arrays render as checkbox questions; separate string properties render as separate custom-text questions | Mapper, synthetic ACP plugin, shared bridge contract, and widget tests pass; live `18.1.19` `askDialog`/ACP/client roundtrip not run |

Property keys, order, independent required flags, and option/custom provenance
are retained, including identical submitted text in separate questions.
Optional omission uses the existing per-question decline in multi-question
forms; single-question decline still rejects the request. Catalog/cleanup
scratch connections do not advertise form support. Other plugins keep their
existing question channels and capability policy; this change makes no new
upstream-support claim for them. See [question regression coverage](regression/questions-and-permissions.md)
for the supported array shape and remaining live check.

## Codex question input

**Implemented:** Codex synchronous user-input requests and asynchronous
assistant-message questions use the existing Sesori question UI and reply API.
Both preserve multiple questions and ordered choices. Async answers steer a
running conversation or resume it while idle; the immediate tool acknowledgement
does not answer the question. Async message metadata was verified against Codex
0.153.4. Older runtimes continue to use their synchronous request path.

**Not implemented:** Masked secret-question entry. Codex requests containing an
`isSecret` question receive an explicit unsupported-input error before any
question card is shown; secret prompts are never downgraded to plain text.

## Setup detection

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Logged-out backend reported as `authenticationRequired` | ✅ | 🚫¹² | ✅ | ✅ | ⬜¹³ | ✅ | ✅ | ✅¹¹ | ✅¹⁴ | ⬜¹⁵ | ✅¹⁶ |

`inspectSetup` owns this state. Where a plugin does not probe credentials it
returns `PluginSetupReady` as soon as it resolves a runtime, so a harness that
is installed but logged into nothing is shown as ready and fails at session
start instead. Sesori-managed installs make this visible: installing the
runtime never authenticates it.

A probe belongs here only when it answers "can this harness serve a turn right
now" without starting a backend or initiating authentication. Counting stored
credentials is not equivalent: a harness with bundled free models or an
environment-supplied key is usable with an empty credential store, and blocking
those installs is worse than the stale ready state this capability replaces.

The marks above cover setup inspection only. A plugin that raises
`PluginAuthenticationRequiredException` while running still moves the slot to
`authenticationRequired` and blocks further starts; the ⬜ plugins do not do
that either.

## Managed runtime platform coverage

| Capability | Harness | Sesori implementation | Native verification |
|---|---|---|---|
| Windows ARM64 managed installation | OMP | Implemented: official `omp-windows-arm64.exe`, pinned digest and existing direct-binary install path | Not run for `18.1.19`; install/version/ACP/teardown still needs a native ARM64 host |

OMP's eight mappings retain separate Linux glibc/musl binaries and macOS/Windows
architecture selection. This implementation status is not a native verification
claim. See [runtime installation regression coverage](regression/plugin-runtime-installation.md)
for the platform checks and existing PATH/explicit-binary policy.

## Login initiation

Login is separate from detecting a logged-out backend or installing its runtime.
This table records the current **Sesori-initiated harness/provider login action**,
not login to the Sesori account. "Not implemented" means no such Sesori action;
it does not claim an unprobed upstream ACP/RPC login API is supported or unsupported.

| Harness | Login initiated from Sesori | Current local alternative/setup |
|---|---|---|
| Claude | Implemented: claude.ai pasted-code login on mobile and desktop | `claude auth login` on the bridge machine remains an alternative. |
| OpenCode | Not implemented | Local `opencode auth login` or provider configuration. |
| Codex | Implemented: ChatGPT device-code login | Local Codex login/configuration remains an alternative. |
| Copilot | Not implemented | `copilot login` on the bridge machine. |
| Cursor | Not implemented | Local Cursor CLI login, or `CURSOR_API_KEY`. |
| Hermes | Not implemented | Configure the provider/model through `hermes setup` or `hermes model`. |
| Pi | Not implemented | Run `pi` locally and use `/login`, or configure supported provider credentials. |
| OMP | Not implemented | Run `omp` locally and log into/configure a provider. |
| DeepSeek | Not implemented | Local provider setup; adapter `check` verifies readiness. |
| Grok | Not implemented | `grok login` on the bridge machine. |
| Antigravity | Implemented: automatic personal Google browser OAuth on mobile and desktop | No copy/paste fallback; current client required. |

Claude, Codex, and Antigravity implement `InteractivePluginAuthenticationDescriptor.authenticate`.
Claude drives `claude auth login --claudeai` on the bridge: the user opens the sign-in page from the app and pastes the
code it shows, for claude.ai subscription accounts only. The login sets `BROWSER=true` to keep the host browser closed,
which is verified on macOS but not on Windows, where the host may still open a sign-in tab. See
[Claude Code authentication](regression/claude-code-authentication.md).
Codex uses the existing Sesori device-code UI; Antigravity implements automatic browser return. Current iOS/Android
clients use a system authentication browser and nonce-only app return; remote desktop uses exact loopback capture and
a static return page, while desktop connected to its exact supervised bridge lets the bridge receive callback directly.
Browser kickoff survives settings dismissal, retained phases replay on reopening, and the one callback-listener lifetime
is bounded to five minutes; only launch failure can retry an issued challenge against that same live listener.
Synthetic iOS Simulator and Android emulator coverage proves raw loopback-to-app return; real Google OAuth remains a
manual verification gap. It permits personal Google OAuth only, suppresses
the bridge host's browser, and uses the same isolated profile for login and live
sessions. Ambient Google login is not imported. Neither row is a general API-key
entry form or a claim of support for every provider authentication method.

Antigravity deliberately omits every persistent `allow_always` choice because
Sesori's current permission contract cannot safely represent persistent approval.
Independently, it excludes any choice of any kind carrying a non-null
`agy.security.warning`, because the warning cannot cross the current contract.
Only unambiguous warning-free `allow_once` and optional `reject_once` choices are
shown. Enterprise OAuth, Gemini API key, and Agent Platform authentication are
not implemented; no upstream support limitation is asserted for those methods.

Local login/configuration must apply to the profile/environment used by that
bridge's harness. Provider keys and local/free models may make a backend usable
without an OAuth login. Setup detection above does **not** imply that Sesori
can initiate login, and managed installation does **not** authenticate a harness.

## Context compaction row

The transcript marks a finished context compaction with a "Context compacted"
row, which opens the carried-forward summary when the harness exposes it.

| Harness | Compaction row | Summary |
|---|---|---|
| Claude | ✅ | ✅ The synthetic summary message after `compact_boundary` live, and the `isCompactSummary` transcript record in history (verified on 2.1.281). |
| OpenCode | ✅ | ✅ The text of the `summary: true` assistant message. |
| Pi | ✅ | ✅ `compaction_end.result.summary` live and the compaction entry in history (verified on 0.87.1). |
| Codex | ✅ | 🚫 Mostly: live compaction items carry no summary, and remote compaction stores it encrypted, so only a plain rollout `compacted.message` is shown. |
| DeepSeek | ⬜ | ⬜ The runtime reports a live `compaction_completed` status without message identity or a replayable history record, so Sesori maps it only to a session-compacted event; a live-only row would vanish on reload. |
| Antigravity, Copilot, Cursor, Hermes, OMP, Grok | ⬜ | ⬜ The ACP session updates Sesori consumes (message, thought and user chunks, tool calls, plan, commands, session info) have no compaction variant, so a compaction, such as Cursor's `/summarize` behind Sesori's `compact` command, arrives as ordinary agent text. A row needs a harness extension signal; none was probed live. |

A row without a summary is inert. Older clients ignore the summary field and
show no row.

## Command limitations

Pi 0.84.4 advertises its bundled `/llama` command over RPC, but the handler
supports only the interactive TUI. Sesori excludes this bundled command source,
including numbered invocation aliases, while preserving user commands with the
same name. This command is **not supported** through Pi RPC; ordinary extension,
prompt, and skill commands remain available.

## Accepted prompts without transcript output

An accepted prompt must gain a bridge-queue or transcript representation, or
end with `session.prompt-settled` so clients can remove its optimistic row.

| Harness | Status and settlement source |
|---|---|
| Claude | ✅ Command dispatch publishes a correlated synthetic user message. |
| OpenCode | ✅ Reserved message identity correlates the backend user echo. |
| Codex | ✅ Turn-backed commands correlate their user echo; native `compact` emits explicit prompt settlement because it returns no turn identity. |
| Pi | ✅ User echoes and agent-running fallback synthesis remain transcript-backed; an accepted slash command with no agent work emits explicit prompt settlement after its state barrier. |
| Antigravity, Copilot, Cursor, Hermes, OMP, DeepSeek, Grok | ✅ Shared ACP dispatch publishes a correlated user message; no silent accepted-command path is exposed. |

The explicit event is additive across the client/bridge wire boundary. Older
clients ignore it and converge on refresh; newer clients retain snapshot
reconciliation when connected to an older bridge.

## Sub-agents

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Sub-agents rendered as inline subtask tiles | ✅ | ✅ | 🚫¹⁹ | ✅³ | 🚫⁴ | ✅⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅¹⁰ |
| Sub-agent transcripts exposed as child sessions | ✅ | ✅ | 🚫¹⁹ | ✅³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅¹⁰ |
| Scoped stop: confirmation while sub-agents run, `stop` cancels them all | ✅ | ✅ | 🚫¹⁹ | ✅ (snapshot)³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅ (snapshot)¹⁰ |
| Stop the sub-agents only while the main agent is idle (`stop`) | ✅ | ✅ | 🚫¹⁹ | ✅³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅¹⁰ |
| Stop the main agent only while it runs, keeping its sub-agents | 🚫¹ | 🚫² | 🚫¹⁹ | ✅³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | 🚫¹⁰ |

ACP plugins declare one closed scoped-stop capability: `unsupported`, `rootSessionCancel` (Cursor),
`perChildSnapshot` (Grok), or `completeNativeAtomic` (DeepSeek). Plugins that report a scoped-stop rejection declare
whether "main agent only" is honored through `mainAgentOnlySupported`; the app offers that action only when it is
true.

¹ Claude Code's only stop primitive (`interrupt`, verified on 2.1.257) stops
background sub-agents together with the running main turn.

² OpenCode's task tool cancels a foreground child when its root is aborted
(verified on 1.18.25); background children survive, and the tracker cannot tell
the two apart, so the option is not offered.
Atomic subtree completion acknowledgment is **not implemented** for OpenCode;
its observed-child snapshot retains legacy client fanout.

³ Codex (managed codex-cli 0.153.4, probed 2026-09-08): live children announce
through parent activity and status, never `thread/started`; persisted activity
is `event_msg/item_completed/item/SubAgentActivity`, whose item id exactly
matches `spawn_agent.call_id`. Normal initial child input is encrypted in the
rollout and absent from `thread/read`. Live/replayed tiles join by exact
parent-local call ID and use that spawn call's exact nonblank message for the
encrypted-input fallback; they never use parent user history, task names,
labels, order, timing, or the encrypted envelope header. Validated initial
child-owned plaintext `NEW_TASK` can override the fallback. Missing activity
leaves the generic tool card. Native-plugin QA verified forked/nonforked tiles,
cold replay, busy-root handling, and disconnect cleanup. Duplicate display
names, plaintext input, and a differently-terminal resumed child were not run
live. Direct app-server `turn/start` input to v2 sub-agents is **not supported**
by Codex 0.153.4; this does not establish a parent-mediated messaging limit.
Sesori exposes child threads under their direct parent and keeps running
descendants in root busy state. Metadata-only
`thread/read(includeTurns: false)` retains parent and nickname enrichment.
Raw task paths are formatted for display, not used for tile correlation.
`turn/interrupt` works per child with its `turnId`, while parent interrupt
leaves children running, so main-agent-only stop is implemented. Full scoped
stop snapshots the named thread's known running descendants and fans out exact
per-thread interrupts; it is not atomic subtree authority, so accepted results
deliberately report `subAgentsHandled: false` and retain client fallback.
Managed-0.153.4 actual-plugin QA on 2026-09-10 passed its executed scope:
side-effect-free root and named-child confirmation, accurate descendant counts
and named-thread state, root-only `keep`, named-child subtree isolation,
full-root snapshot fanout, authoritative `turn_aborted` for every selected
target, and a surviving runtime. Full-stop targets became non-busy in plugin
status; root `keep` stopped its own turn while effective root status remained
busy for retained descendants. Live matrix is partial: no
pending-input request surfaced, so that case remains automated rather than
live-plugin coverage.

⁴ Copilot CLI (plugin targets 1.0.80) runs custom agents as subagents, but its
Agent Client Protocol server exposes no subagent lifecycle, no child session,
and only the turn-wide `session/cancel`.

⁵ Cursor (managed target `cursor-agent 2026.08.11-e8db854`, probed
2026-09-11) emits a standard `Task: …` call and then one correlated
`cursor/task` JSON-RPC request when that Task-tool invocation completes. A
foreground invocation's completion is also sub-agent completion; a background
invocation completes at launch and exposes `isBackground: true`, while the
background work continues without a later terminal lifecycle or child
transcript. `session/load` replays stable full standard Task input/result facts,
not `cursor/task`; Sesori now replaces an exact completed foreground replay card
with the same childless tile while preserving replay-local identity and order.
The live request's nested tagged presentation is `custom → unspecified`; replay
uses the distinct `unspecified` tag directly. Separate typed boundary DTOs map
both exact shapes to one closed presentation value, while unknown or malformed
variants stay generic. Pending/in-progress calls lack presentation facts and `isBackground`, so their
mode is unknown and they remain generic; cancelled foreground calls also remain
generic cancelled cards because no `cursor/task` follows cancellation. Sesori
now replaces only an exact live standard completion with explicit
`isBackground: false` plus a complete correlated request, producing one
completed childless tile with stable part identity. Missing/unknown/malformed,
unmatched, background, and failed cases with standard facts stay generic. A cancelled
Task is absent from replay when Cursor emits no standard frame; no completed tile is synthesized. Standard `session/cancel`
authoritatively cancels an active root prompt. Safe Task confirmation is
side-effect-free with exact active count; named-root stop waits up to 20 seconds,
then rechecks background and active work. Timeout or survivors yield HTTP 502
after cancellation, never false success. A background Task survives root cancel,
so “`stop` cancels them all” remains **not supported**. While that observation is
unresolved, every policy returns concrete HTTP 409 `notPerformed` before input or
cancellation. Client drain pauses; that variant retains queued prompts and shows
restart recovery even for unknown reasons. Malformed bodies, unknown variants,
and post-cancel failures remain ambiguous. The observation keeps only ACP process
work state busy until session cleanup or process reset; root `end_turn` and UI
idle never claim background completion. Bounded managed-target production-
composition QA passed live terminal replacement, two equivalent cold loads,
mode-unknown generic presentation, exact active-Task confirmation/keep
rejection, named-root cancellation with a generic cancelled card, process/session
reuse, root idle before later background permission, residency, and identical
non-mutating post-background refusal for all three policies. One bounded race
attempt cancelled before background resolution, so post-cancel background
transition remains automated rather than native evidence. No phone, desktop,
child, background completion, or full-background-stop coverage is inferred.

⁶ Hermes (hermes-agent 0.19.0) has `delegate_task`, but its ACP adapter
flattens delegation into an ordinary tool call and maps `session/cancel` to a
hard interrupt of the whole agent; no child ids or per-delegate stop cross the
seam.

⁷ Pi (0.84.4) has no native sub-agents. Delegation exists only through
third-party extensions (`pi-subagents`) that spawn separate `pi` processes with
their own control channel, invisible to the RPC stream Sesori drives.

⁸ Oh My Pi (18.0.3) has subagents, but its ACP mode maps the task tool to a
generic `tool_call` with no ids or lifecycle notifications; those exist only in
`--mode rpc`, which Sesori does not drive. `session/cancel` aborts the whole
turn.

⁹ DeepSeek's published adapter 0.1.7 over dsh 0.1.5-rc.2 is the managed target;
adapter 0.1.5 remains the minimum accepted runtime. ACP uses native subtree stop for the named scope
and every independently resident descendant root, while ordered input cancel,
exact-child authority, lifecycle, tiles, and child catalogs remain native-backed.
Released clients retain their own child fanout. Phone QA on unchanged published
adapter 0.1.4 passed the requested stop/input scope after the shared transport fix:
confirmation dismissal, main-only keep, root/independently resumed child/grandchild
cancellation, authoritative settlement, runtime reuse, a follow-up turn, earlier
pending-input cleanup, and one later question preserved and answered. The
permission sheet's generic label and opaque call ID are not presentation coverage,
and surviving root-owned shell jobs do not imply failed descendant cancellation or
broader process-stop support. Cold tile/history reload, read-only child navigation,
push delivery, restart/reconnect, multiple clients, alternate mobile platforms,
and macOS desktop remain unexecuted in this gate; desktop was deferred by explicit
user choice. This 0.1.4 evidence does not requalify the current 0.1.7 managed target.
Adapter 0.1.7 loads explicitly installed local plugins from only the application-owned
`$DSH_HOME/profiles/sesori` profile on startup, including after `dsh --profile sesori`
rewrites the profile root, then reapplies Sesori's mandatory
runtime constraints; profile changes require restart and profile failure falls back
to the pinned in-memory graph. These plugins are trusted local in-process code, not a
trust grant for future cloud or otherwise managed-trust runtimes.
The native model catalog includes `deepseek-flash` (DeepSeek V4.1 Flash) with
image input and reasoning controls. Refresh rereads the installed harness's
configured catalog; it does not upgrade that harness or fetch a live provider catalog.
Native `web_search` and `web_fetch` tools are enabled: outbound requests occur
when invoked, without a Web BFF, HTTP listener, extra process, or telemetry exporter.

¹⁰ Grok Build (1.0.5, probed 2026-09-03, 2026-09-10, and 2026-09-12) sends
`subagent_spawned`/`subagent_progress`/`subagent_finished` with parent and child
session ids as `_x.ai/session_notification` extension notifications and streams
child updates under the child id. Root `session/load` replays lifecycle as
`_x.ai/session/update`; an unfinished loaded episode can settle later through
`_x.ai/session_notification`, so both remain in the replay drain. Sesori exposes
persisted/live children, loads child transcripts by exact native id, and rebuilds
root tiles from each exact child's first user-message run only when that run is
nonblank, without reading live tracker state. A blank or missing first run
produces no tile; later runs never substitute. Permission denial persistence is
unverified and has no outcome model. Grok scoped stop snapshots the named
scope before mutation, sends root `session/cancel` first, and fans out exact
`_x.ai/subagent/cancel {subagentId}` requests for its running children. This is
not complete native subtree authority: accepted results deliberately report
`subAgentsHandled: false` and retain current-client fallback. Main-agent-only
stop is unsupported because root cancellation stopped every observed child;
idle-root child-only `keep` remains side-effect free. Automated coverage proves
rejection, fanout, outcome mapping, lifecycle-only settlement, and exact pending
permission/queue isolation. Production-composition QA after PR #1429 passed its
executed named-isolation, full-stop, idle-keep/wake, already-finished, replay,
settlement, fresh-session, and runtime-reuse scope; root confirmation reuses an
earlier passing run. That unchanged headless run emitted no permission request.
Subsequent owned-phone QA exercised one genuine request with `Once`; no question
support is claimed. The bounded phone matrix passed creation, tile lifecycle,
exact Stop dismissal and full cancellation, same-session/runtime reuse, cold root
history, and exact read-only child navigation. Final fixed-build QA showed one
stable child-owned initial row plus one assistant/tool/assistant sequence on two
opens. Background completion delivery was attempted, but no OS notification was
observed; notification and push delivery remain unclaimed.

¹⁹ Antigravity's official managed ACP pair (package 1.0.0, runtime
`agy_acp_server_20260818_01_RC01`, probed 2026-09-12) can invoke native internal
sub-agents. Two authenticated default-mode turns returned the expected bounded
reasoning result after `invoke_subagent` activity and one warning-free
`allow_once` decision each. The official ACP projection does not expose a
trustworthy Sesori subtask seam, however: every update carried only the parent
session id; no child session, child id, child lifecycle extension, background
fact, or child-cancel method appeared. Live `invoke_subagent` calls moved from
`pending` to `failed` even though the root reported the delegated result, while
`session/load` replayed those same calls as `completed`, string-encoded their
structured input, and supplied blank raw output. Nested work appeared only as
additional generic parent-local tool calls without correlation to the invocation.
Sesori therefore keeps these calls generic and does not infer tiles, child
history, descendant busy state, or scoped stop from call order, prompt text, or
replay's contradictory status. Standard turn-wide `session/cancel` remains
available, but it cannot implement any sub-agent-specific stop row above. This
is a limitation of the ACP projection Sesori drives, not a claim that native
Antigravity lacks delegation. Details:
[completed probe record](../.plan/completed/claude-inline-subtasks/followups/antigravity-probe.md).

¹¹ Pi (0.84.4, probed 2026-09-05) reports it from `pi --list-models`, which
prints one row per usable model and otherwise prints the
"No models available. Use /login…" text that
`PiRpcClient.noModelsDiagnosticPrefix` already matches on the session path, so
an empty listing is the logged-out signal. Listing resolves every credential
source Pi accepts — `~/.pi/agent/auth.json`, inline provider keys in
`~/.pi/agent/models.json`, and environment API keys — which reading the auth
file alone would not: a user carrying only an environment key or a local
provider has no `auth.json` entry and a working install. `pi auth check` is
unusable here because it requires an explicit `--provider` or `--model` and Pi
exposes no global variant. Verified against a fresh Sesori-managed 0.84.2
install with no credentials.

¹² OpenCode (1.18.25, probed 2026-09-05) has no logged-out state to report.
`opencode models` lists the bundled free `opencode/…` models identically with
five credentials and with zero, so an install with an empty credential store
is usable and ready is the correct state for it. `opencode auth list` counts
credentials, but that count is not this capability: reporting authentication
required from it would block working installs. Ready remains correct for
OpenCode regardless of stored credentials.

¹³ Copilot has not been probed for a non-interactive credential check.

¹⁴ Oh My Pi (18.1.10, probed 2026-09-05) reports it from `omp models --json`,
which returns `{"models":[]}` with no credentials and a populated list
otherwise — the same signal Pi exposes, in a structured form. Only a listing
that parses and reports no models downgrades setup: supported releases reach
back to 17.3.8 and `models --json` is not guaranteed across that range, so an
unparsable or failing listing leaves setup ready instead of regressing a
working older install.

¹⁵ DeepSeek already probes readiness in `inspectSetup` but maps a negative
result to `PluginSetupUnknown`, so a logged-out install is reported as
undetermined rather than as authentication required.

¹⁶ Grok Build (1.0.5, probed 2026-09-05) reports it from `grok models`, which
prints `You are logged in with <account>.` or `You are not authenticated.`
ahead of a model list that is identical either way, so the authentication line
is the signal and the listing itself is not one. Only that line downgrades
setup; unrecognized wording leaves setup ready rather than blocking a working
install on a phrase a later release may change.

¹⁷ Hermes (hermes-agent 0.19.0) exposes no effort or thinking levels over its
ACP seam, so there is nothing to order.

¹⁸ DeepSeek model ids are deliberately opaque tokens with no vendor signal, so
its models keep DeepSeek's catalog order; its efforts are ordered.
