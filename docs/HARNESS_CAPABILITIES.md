# Harness Capability Matrix

Sesori strives for feature parity across harnesses. This matrix records the
capabilities of the Sesori integration that not every harness has, so a gap is
a deliberate, visible state rather than an accident. Update it whenever a
capability lands for some harnesses but not others, or a harness limitation is
verified or lifted.

Capability tables include registered plugins where the relevant integration behavior has been verified. Antigravity is
included below for local runtime, options, setup, login, and permission behavior; its upstream sub-agent behavior has
not been verified, so the sub-agent table makes no claim about it.

## Legend

| Mark | Meaning |
|---|---|
| ✅ | Implemented: Sesori exposes the capability for this harness. |
| ⬜ | Not implemented: the harness and the seam Sesori drives can provide it, Sesori does not yet. |
| 🚫 | Not supported: the harness or the protocol seam Sesori drives cannot provide it. The footnote names the verified version. |

## Managed runtime

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Sesori-managed runtime installed on request | 🚫 | ✅ | ⬜ | ✅ | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | 🚫 |
| Superseded managed runtime upgraded automatically on bridge start | 🚫 | ✅ | ⬜ | ✅ | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | 🚫 |

Antigravity currently resolves only a user-supplied official runtime pair from
PATH or `--antigravity-bin`; managed installation is not implemented yet.
Claude, Hermes, and Grok have no Sesori-managed runtime at all: they resolve a
user-installed CLI from PATH or an explicit binary option, so there is nothing
for Sesori to install or upgrade. The upgrade follows the install capability
exactly — a harness configured with an explicit binary override, running on a
platform with no pinned asset, or attached to an externally managed server
(`--opencode-no-auto-start`) advertises neither.

The upgrade only replaces a runtime Sesori already manages. A machine with no
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
| Distinct update-required setup status | 🚫 Not supported: unavailable is broader and cannot truthfully be relabelled update-required. |
| Enabled preference when runtime is unknown | 🚫 Not supported: unknown does not prove disabled; clients omit the switch. |
| Overall installation percentage or active-session count | 🚫 Not supported: only optional download percentage and idle/busy/unknown work state are reported. |
| Replay a failed installation observed by this client within the connection | ✅ Implemented for every harness advertising installation; memory only, not cross-device history. |

## Pre-start catalog import

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Metadata-only import before harness startup | ⬜ | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

OpenCode can read a safely identified local SQLite database as a coherent,
read-only snapshot. Other harnesses retain their existing plugin-backed import;
these marks describe Sesori implementation gaps, not verified upstream limits.
All harnesses cold-started only by import fallback use the shared five-minute
import-only idle residency cap.

## Option pickers

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Effort variants listed strongest first, default declared separately | ✅ | ✅ | 🚫¹⁷ | ✅ | ✅ | ✅ | 🚫¹⁷ | ✅ | ✅ | ✅ | ✅ |
| Anthropic and OpenAI models listed strongest first | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫¹⁸ | ✅ |

The picker shows each plugin's declared order. Every plugin ranks through the
shared `CatalogStrengthOrder`; models of other vendors keep the plugin's own
order after the ranked ones (OpenCode newest release first, others backend
order). Antigravity's account-advertised order is what remains for its
unranked models, and before the first real session catalog in a process it
exposes no model choice and uses the account default.

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

## Login initiation

Login is separate from detecting a logged-out backend or installing its runtime.
This table records the current **Sesori-initiated harness/provider login action**,
not login to the Sesori account. "Not implemented" means no such Sesori action;
it does not claim an unprobed upstream ACP/RPC login API is supported or unsupported.

| Harness | Login initiated from Sesori | Current local alternative/setup |
|---|---|---|
| Claude | Not implemented | `claude auth login` on the bridge machine. |
| OpenCode | Not implemented | Local `opencode auth login` or provider configuration. |
| Codex | Implemented: ChatGPT device-code login | Local Codex login/configuration remains an alternative. |
| Copilot | Not implemented | `copilot login` on the bridge machine. |
| Cursor | Not implemented | Local Cursor CLI login, or `CURSOR_API_KEY`. |
| Hermes | Not implemented | Configure the provider/model through `hermes setup` or `hermes model`. |
| Pi | Not implemented | Run `pi` locally and use `/login`, or configure supported provider credentials. |
| OMP | Not implemented | Run `omp` locally and log into/configure a provider. |
| DeepSeek | Not implemented | Local provider setup; adapter `check` verifies readiness. |
| Grok | Not implemented | `grok login` on the bridge machine. |
| Antigravity | Implemented: personal Google browser OAuth | No local fallback; current client required. |

Codex and Antigravity implement `InteractivePluginAuthenticationDescriptor.authenticate`.
Codex uses the existing Sesori device-code UI; Antigravity implements the browser-return action:
a current phone/desktop client opens Google's authorization page and returns
the callback through Sesori. It permits personal Google OAuth only, suppresses
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

## Command limitations

Pi 0.84.4 advertises its bundled `/llama` command over RPC, but the handler
supports only the interactive TUI. Sesori excludes this bundled command source,
including numbered invocation aliases, while preserving user commands with the
same name. This command is **not supported** through Pi RPC; ordinary extension,
prompt, and skill commands remain available.

## Sub-agents

| Capability | Claude | OpenCode | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|
| Sub-agents rendered as inline subtask tiles | ✅ | ✅ | ✅³ | 🚫⁴ | ⬜⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ⬜¹⁰ |
| Sub-agent transcripts exposed as child sessions | ✅ | ✅ | ✅³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ⬜¹⁰ |
| Scoped stop: confirmation while sub-agents run, `stop` cancels them all | ✅ | ✅ | ⬜³ | 🚫⁴ | ⬜⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ⬜¹⁰ |
| Stop the sub-agents only while the main agent is idle (`stop`) | ✅ | ✅ | ⬜³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ⬜¹⁰ |
| Stop the main agent only while it runs, keeping its sub-agents | 🚫¹ | 🚫² | ⬜³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | 🚫¹⁰ |

Plugins that report a scoped-stop rejection declare whether "main agent only"
is honored through `mainAgentOnlySupported`; the app offers the action only
when it is true.

¹ Claude Code's only stop primitive (`interrupt`, verified on 2.1.257) stops
background sub-agents together with the running main turn.

² OpenCode's task tool cancels a foreground child when its root is aborted
(verified on 1.18.25); background children survive, and the tracker cannot tell
the two apart, so the option is not offered.
Atomic subtree completion acknowledgment is **not implemented** for OpenCode;
its observed-child snapshot retains legacy client fanout.

³ Codex (codex-cli 0.148.0, `multi_agent` stable, probed 2026-09-02): a child
announces itself through the parent's `subAgentActivity started`
(`agentThreadId`) and `thread/status/changed`, never `thread/started`;
`receiverThreadIds` stays empty. Sesori exposes the verified child thread and
persisted rollout under its direct parent and rolls running descendants into
the root's busy state. Spawn calls appear as inline subtask tiles both live
and in saved history, linked to the child thread; the tile follows the child's
session status instead of treating spawn completion as task completion.
Raw task-path fallbacks are formatted for display (for example,
`/root/architecture_review_1271` becomes `Architecture review · 1271`), while
raw paths remain the identity used to match saved spawn calls to children.
`turn/interrupt` works per child thread with its
`turnId`, and interrupting the parent leaves children running, so
main-agent-only is supportable.

⁴ Copilot CLI (plugin targets 1.0.80) runs custom agents as subagents, but its
Agent Client Protocol server exposes no subagent lifecycle, no child session,
and only the turn-wide `session/cancel`.

⁵ Cursor (cursor-agent 2026.07.23) over ACP emits a subagent as a plain
`Task: …` tool call plus a `cursor/task` notification without child transcript,
so a tile is possible but a child session is not; the running count enables a
confirmation, while ACP's turn-wide `session/cancel` rules out partial stops.

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

⁹ DeepSeek's published adapter 0.1.4 over dsh 0.1.1-rc.2 is the managed target
and minimum accepted runtime. ACP uses native subtree stop for the named scope
and every independently resident descendant root, while ordered input cancel,
exact-child authority, lifecycle, tiles, and child catalogs remain native-backed.
Released clients retain their own child fanout; final phone/desktop E2E remains outstanding.

¹⁰ Grok Build (1.0.5, probed 2026-09-03) sends `subagent_spawned`/`subagent_progress`/
`subagent_finished` with parent and child session ids as
`_x.ai/session_notification` extension notifications, streams child updates
under the child id, and exposes `_x.ai/subagent/cancel` per child. A root
`session/cancel` cancels background children too, so main-agent-only is not
supported.

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
ACP seam, and Antigravity has no Sesori effort variants, so for both there is
nothing to order.

¹⁸ DeepSeek model ids are deliberately opaque tokens with no vendor signal, so
its models keep DeepSeek's catalog order; its efforts are ordered.
