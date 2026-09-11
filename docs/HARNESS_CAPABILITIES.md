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
| Sesori-managed runtime installed on request | 🚫 | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | 🚫 |
| Superseded managed runtime upgraded automatically on bridge start | 🚫 | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | 🚫 |

Antigravity can explicitly download Google's proprietary official runtime pair directly from `dl.google.com`. Before
choosing Install, review [Google's terms](https://antigravity.google/terms) and
[Antigravity documentation](https://antigravity.google/docs/). Sesori independently pins and verifies the five
published archives: macOS arm64, Linux x64/arm64, and Windows x64/arm64. Google publishes no macOS x64 archive, so
managed installation is unavailable there. Every archive keeps the server and local harness as siblings, uses a
conservative two-minute bound for each archive listing/extraction command, and must pass the isolated initialize-only
identity check before placement. A configured `--antigravity-bin` remains authoritative and removes Install. Native
managed-pipeline correctness has run on macOS arm64; Linux and Windows native correctness remains unverified.
Linux requires Info-ZIP `unzip` with ZipInfo support, checked before download.
The [Antigravity operator guide](ANTIGRAVITY.md) covers the exact pair, manual setup, remote personal login and
retained-history behavior. Implemented marks here do not claim completed authenticated end-to-end verification.

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

| Capability | OpenCode |
|---|---|
| Metadata-only import before harness startup | ✅ |

OpenCode can read a safely identified local SQLite database as a coherent,
read-only snapshot. The reader consumes the pinned v1.18.19 project,
project-directory, and session schema and safely falls back to live import when
that contract is absent or invalid. Other harnesses retain their existing
plugin-backed import; no pre-start capability claim is made for them.
All harnesses cold-started only by import fallback use the shared five-minute
import-only idle residency cap.

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
| Antigravity | Implemented: automatic personal Google browser OAuth on mobile and desktop | No copy/paste fallback; current client required. |

Codex and Antigravity implement `InteractivePluginAuthenticationDescriptor.authenticate`.
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

## Command limitations

Pi 0.84.4 advertises its bundled `/llama` command over RPC, but the handler
supports only the interactive TUI. Sesori excludes this bundled command source,
including numbered invocation aliases, while preserving user commands with the
same name. This command is **not supported** through Pi RPC; ordinary extension,
prompt, and skill commands remain available.

## Sub-agents

| Capability | Claude | OpenCode | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|
| Sub-agents rendered as inline subtask tiles | ✅ | ✅ | ✅³ | 🚫⁴ | ⬜⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅¹⁰ |
| Sub-agent transcripts exposed as child sessions | ✅ | ✅ | ✅³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅¹⁰ |
| Scoped stop: confirmation while sub-agents run, `stop` cancels them all | ✅ | ✅ | ✅ (snapshot)³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅ (snapshot)¹⁰ |
| Stop the sub-agents only while the main agent is idle (`stop`) | ✅ | ✅ | ✅³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅¹⁰ |
| Stop the main agent only while it runs, keeping its sub-agents | 🚫¹ | 🚫² | ✅³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | 🚫¹⁰ |

ACP plugins declare one closed scoped-stop capability: `unsupported`, planned `rootSessionCancel` (Cursor's
safe Task subset), `perChildSnapshot` (Grok), or `completeNativeAtomic` (DeepSeek). Plugins that report a
scoped-stop rejection declare whether "main agent only" is honored through `mainAgentOnlySupported`; the app offers
that action only when it is true.

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
not `cursor/task`, so completed foreground tiles are planned without a child
session. Pending/in-progress calls lack presentation facts and `isBackground`, so their
mode is unknown and they remain generic; cancelled foreground calls also remain
generic cancelled cards because no `cursor/task` follows cancellation. Standard
`session/cancel` authoritatively cancels an active root prompt. The planned safe
Task subset may provide side-effect-free confirmation with the exact observed
active Task count and named-root stop when no unresolved background observation
exists. Explicit stop must await authoritative prompt settlement and re-check
unresolved background before acceptance; a Task that resolves as background in
that window yields failure after root cancellation may already have happened,
never aborted success. A launched background Task survives root cancel, so the
overall “`stop` cancels them all” capability is **not supported**. While such an
observation remains unresolved, `confirm`, `keep`, and `stop` must all fail
before root/input cancellation because bridge-internal `workKept` cannot qualify
a success omitted from the client wire. The observation may keep only
ACP process work state busy until session deletion/process reset; root
`end_turn` and root UI idle remain honest root-turn completion, never a
background completion or tile claim.

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

⁹ DeepSeek's published adapter 0.1.5 over dsh 0.1.5-rc.2 is the managed target
and minimum accepted runtime. ACP uses native subtree stop for the named scope
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
user choice. This 0.1.4 evidence does not requalify the current 0.1.5 managed target.
The native model catalog includes `deepseek-flash` (DeepSeek V4.1 Flash) with
image input and reasoning controls. Refresh rereads the installed harness's
configured catalog; it does not upgrade that harness or fetch a live provider catalog.
Native `web_search` and `web_fetch` tools are enabled: outbound requests occur
when invoked, without a Web BFF, HTTP listener, extra process, or telemetry exporter.

¹⁰ Grok Build (1.0.5, probed 2026-09-03 and 2026-09-10) sends
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
earlier passing run. Unchanged configuration emitted no live permission request,
so live permission behavior remains unexecuted and no question support is
claimed. Source phone build and relay connection were healthy, but UI automation
failed to start before any visible case; all phone behavior remains blocked and
unexecuted, including stop, history, read-only child, notification, and push QA.

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
