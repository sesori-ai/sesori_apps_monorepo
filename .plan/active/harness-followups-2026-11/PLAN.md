# Harness follow-ups 2026-11

## Goal

Ship the follow-ups the owner picked from the November harness refresh
(review page `harness-refresh-2026-11`, 2026-11-12). Phase 1 holds the
valuable, not-too-hard items, grouped by plugin seam into PRs that can run in
parallel. Phase 2 lists bigger items that each become their own plan.

The `harness-refresh-2026-11` plan stays open; its step 4 still waits on the
DeepSeek adapter release.

## Owner decisions (2026-11-12)

- **Do now:** Q3 hide empty untitled OMP sessions and move OMP to 18.19.0,
  Q4 file the leftover-session issue upstream (public issue approved), Q6 OMP
  tool name, Q7 `--opencode-no-password` fails clearly on v2, Q8 OpenCode agent
  refresh on a partial list, Q12 Codex sub-agent model and effort, Q13 Codex
  stale approval cards, Q14 Codex provider rejection on resume, Q15 Hermes
  duplicate failure notice, Q17 Hermes unrecognised failure messages, Q18 Claude
  error codes, Q19 Copilot version probe with auto-update off, Q20 Copilot
  withdrawn permission cards, Q25 `FORCE_COLOR=0`.
- **Q5 OMP compaction status:** its own PR immediately after the OMP PR,
  without waiting to be asked.
- **Do now, but phase 2 (each becomes its own plan):** Q9 OpenCode archive
  sync, Q11 OpenCode MCP OAuth code paste, Q21 Pi Windows exit wait, Q22 Cursor
  Windows managed install, Q24 Antigravity `agy acp`.
- **Later (not planned):** Q16 Hermes effort/service-tier/edit-policy pickers,
  Q23 Grok paged-history probe.
- **No change:** Q2 the DeepSeek read-before-edit guard stays off.
- **Pending owner answers, not in this plan:** Q10 OpenCode stop only the main
  session; Q1 the DeepSeek adapter release (`sesori-deepseek-acp` #24 is not
  merged and no tag is pushed).

## Phase 1

Every PR updates its own `docs/HARNESS_CAPABILITIES.md` rows and the
regression rows it changes; step 9 reconciles what is left. Shared ACP files
(`acp_plugin.dart`, `acp_event_mapper.dart`) are touched by steps 2, 4 and 5 in
separate regions; whichever lands later merges `main` in.

### Step 2 — OMP: hide empty sessions, target 18.19.0, tool name, upstream issue

**Current behaviour.**
- OMP uses the shared ACP `session/list` (`OmpPlugin extends AcpPlugin`,
  `bridge/sesori_plugin_omp/lib/src/omp_plugin_impl.dart`). All listing paths
  pass through `_listSessionPages` in `bridge/sesori_plugin_acp/lib/src/acp_plugin.dart`
  (`infos.addAll(result.sessions)`).
- OMP sends `title` and `_meta: {messageCount, size}` per session, and
  `AcpSessionInfo` already parses `_meta` (`acp_protocol.dart`). The 18.18.9+
  deletion leftover has no title and zero messages.
- `session/new` writes an empty untitled session file at once (probed on
  `18.18.8` and `18.19.0`), so the filter also hides never-prompted sessions
  from import. One Sesori created keeps its bridge row (the import only
  upserts what the listing returns).
- Tool cards are named by `AcpContentMapper.toolName`
  (`acp_content_mapper.dart`): `kind`, then `title`. OMP's `mapToolKind` sends
  `other` for task, wait and ask, so those cards read "Other". OMP 18.18.8
  already sends a top-level `name` on `tool_call`.

**Change.**
- Add an overridable `includeListedSession(AcpSessionInfo)` hook (default true)
  next to `sessionParentId` and apply it in `_listSessionPages`. OMP hides an
  entry with `_meta.messageCount == 0` and no title; a missing or non-int count
  keeps the entry.
- Move the OMP target to 18.19.0: `omp_runtime_manifest.dart` (version, the
  hold comment, 8 hashes) and its test. Download every asset and check it
  against `SHA256SUMS.txt` and the GitHub digests; never copy hashes.
- OMP's event mapper names tool cards from a non-empty top-level `name`
  before `kind`, through an adapter tool-name hook shared by live mapping and
  replay (other ACP harnesses keep `kind`). Only OMP sends
  it in practice (Grok's lives under `_meta`). File-mutation detection reads
  `kind` and is unaffected.
- File the public upstream issue on `can1357/oh-my-pi` describing the
  persisted replacement session after ACP `/session delete` (#18665), with the
  sandboxed probe steps and no user data. Link it from the OMP docs.
- Docs: the OMP rows in `HARNESS_CAPABILITIES.md` (tool title row, form row,
  Windows ARM64 row), the hold text in `docs/regression/plugin-setup-and-lifecycle.md`,
  the OMP section of `.agents/skills/update-backend-runtimes/references/harnesses.md`,
  and hold H1 in `.plan/completed/harness-refresh-2026-11/PLAN.md` (lifted).

**Not handled.** Leftovers already imported from a PATH 18.18.9+ binary stay in
the bridge database; the filter only stops new imports. Low damage, accepted.

**Verification.** ACP listing test plus OMP plugin tests; manifest test. Live,
sandboxed, no credentials: rerun the deletion probe on 18.19.0 and capture the
raw `session/list` entry to confirm `messageCount: 0` and no title, then
confirm the managed install of 18.19.0.

**Estimate.** `🌿`, about 200 lines including tests and docs.

### Step 3 — OMP compaction status (right after step 2)

**Current behaviour.** OMP sends `_omp/compaction/start {sessionId, reason,
action}` and `_omp/compaction/end {sessionId, action, aborted, willRetry,
skipped, errorMessage, tokensBefore}`, for auto compaction only. The shared
mapper sends non-`session/update` notifications to `mapExtension`, which
returns nothing (`acp_event_mapper.dart`). The shared contract
`PluginMessagePart.compaction` / `PluginCompactionState` already serves Claude,
OpenCode, Pi, Codex and DeepSeek; OMP is ⬜ in `HARNESS_CAPABILITIES.md`.

**Change.** Follow the DeepSeek pattern (`deepseek_event_mapper.dart`,
`deepseek_compaction_tracker.dart`): an `OmpEventMapper extends AcpEventMapper`
overriding `mapExtension` and `shouldBufferDuringPromptWrite`, plus an
`OmpCompactionTracker` using `host.clock`, wired in `omp_plugin_impl.dart` and
`omp_plugin_descriptor.dart`. Mapping: start → running; `willRetry` is ignored
(the 18.19.0 source sets it only on a successful compaction, meaning OMP
re-sends the overflowed turn); `aborted` → failed (`cancelled`); `errorMessage` → failed, with
the raw error logged locally; `skipped` → the same state the other plugins use
for "nothing to compact"; otherwise completed with trigger `auto` and
`BridgeSseSessionCompacted`. No summary or freed-token count exists.

**Not handled.** Manual `/compact` sends no ACP signal; history replay shows
OMP's stored summary as OMP sends it. Record both as limits.

**Verification.** Mapper and tracker unit tests. A live auto-compaction needs
credentials (see the open question on live checks).

**Docs.** OMP compaction row in `HARNESS_CAPABILITIES.md`, the compaction
entries in `docs/regression/tools-and-file-changes.md`, the OMP section of
`harnesses.md`.

**Estimate.** `⚙️`, about 270 lines.

### Step 4 — Hermes: one notice per failed turn, remaining failure copy

**Current behaviour.**
- Hermes 0.22+ sends its failure text as the final agent message, then fails
  `session/prompt` with JSON-RPC error `admitted_turn_failed`
  (`acp_adapter/gateway_server.py`). The shared ACP plugin maps the failure text
  to a `<turn>-halt` notice (`HermesEventMapper.classifyHaltNotice`), then maps
  the prompt error to a second `<turn>-error` notice named `ACP prompt failed`
  (`acp_plugin.dart` prompt catch → `mapPromptError` in `acp_event_mapper.dart`).
  #2499's history merge does not touch it (different id and kind).
- When the model streamed part of a reply before failing, Hermes sends no
  failure text and the only live notice is the raw `admitted_turn_failed`.
- Still plain replies: `launch_credentials_unavailable`, `pending_tool_result`
  (two variants), the replayed content-refused row, `cron_session_read_only` and
  `workspace_unavailable` (Hermes 0.23.1 `agent/turn_failure_copy.py`,
  `agent/turn_finalizer.py`, `locales/en.yaml`).

**Change.**
- Shared ACP: skip `mapPromptError` when the mapper already showed a halt
  notice for the turn (the `-halt` id is in `_startedParts` until `beginTurn`);
  keep `_finishTurn(failed: true)` and the session error event.
- Hermes: when no halt notice was shown and the prompt error is
  `admitted_turn_failed`, show Hermes's own `FAILED_TURN_NOTICE` text with kind
  `hermes_failed_turn`, so the history store merges it with the replayed row.
- Hermes copy: add the English templates; a language-independent match on the
  `Details: launch_credentials_unavailable` paragraph; the content-refused row
  as an exact-text saved row of kind `hermes_failed_turn`. Other locales without
  a details line stay plain replies (accepted).
- Fix the stale `end_turn` comment in `hermes_event_mapper.dart` and the ⚠️ note
  in the Hermes failure-copy row, which says the partial-reply case shows no
  live notice.

**Verification.** ACP fake-transport test proving the halt notice is mapped
before the prompt error is handled; Hermes mapper and copy tests; a
`chat_history_capture_test.dart` reload case. Live without credentials: a
Hermes turn with a deliberately invalid API key shows one notice.

**Docs.** Hermes failure-copy row in `HARNESS_CAPABILITIES.md`;
`docs/regression/session-history-and-recovery.md` (already lists "shows two
notices" as a failure).

**Estimate.** `🌿`, about 150 lines.

### Step 5 — Retire requests the harness withdrew (Codex and ACP)

One seam for Q13 and Q20 instead of two per-plugin fixes.

**Current behaviour.** The shared `PendingPermissionRegistry`
(`bridge/sesori_plugin_interface/lib/src/pending_permission_registry.dart`)
retires entries only through a reply, `cancelForSession` (which answers the
harness) or disposal. Codex ignores `serverRequest/resolved`
(`approval_registry.dart` `_handleNotification`), so a card answered elsewhere
or abandoned by an interrupted turn stays until stop, close, delete or archive,
and answering it replies to a dead request. ACP drops `$/cancel_request`
(`mapExtension` default), with the same result.

**Change.**
- Shared registry: `withdrawWhere(matches)` removes matching entries and emits
  their existing cancellation events without answering the harness.
- Codex: handle `serverRequest/resolved` by matching the stored `codexId`
  (int or string, compared exactly) and clearing the native turn mapping.
- ACP: intercept `$/cancel_request` in `handleAgentNotification`, withdraw the
  pending entry by `acpId`, drop it from the prompt-write buffer, and answer the
  original request with error `-32800` as the ACP cancellation RFD requires.
- First confirm the wire: dump the Codex 0.167.2 schema
  (`codex app-server generate-json-schema`) for the `serverRequest/resolved`
  params, and grep the published `@github/copilot` 1.0.109 bundle for
  `$/cancel_request`. If Copilot never sends it, drop the ACP half and record
  that in `HARNESS_CAPABILITIES.md` instead.

**Verification.** Shared registry, Codex registry and ACP approval-registry
unit tests with fake frames. A live interrupted approval needs credentials.

**Docs.** `docs/regression/questions-and-permissions.md` (what retires a card),
Codex and Copilot rows in `HARNESS_CAPABILITIES.md`.

**Estimate.** `⚙️`, about 300 lines.

### Step 6 — Codex: sub-agent model and effort, clear provider-mismatch error

**Current behaviour.**
- Live messages always carry `variant: null` and fall back to the configured
  model when a thread's model is unknown (`codex_event_mapper.dart`); a child
  sub-agent's model is read in `handleSubAgentStarted` but never reaches the
  mapper. History replay already sets model and effort from `turn_context`
  (`codex_message_repository.dart`). The sub-agent item DTO decodes only
  `subAgentActivity`; `collabAgentToolCall` falls to `unknown`.
- Both RPC transports drop JSON-RPC `error.data`
  (`codex_app_server_client.dart`, `codex_stdio_app_server_client.dart`); the
  thread repository wraps every error in `CodexThreadRequestException`, and the
  router answers HTTP 500 with a raw string. A resumed thread started on
  another provider therefore fails as a generic send error.

**Change.**
- Confirm field locations with the 0.167.2 schema dump, then decode
  `collabAgentToolCall` (`receiverThreadIds`, `model`, `reasoningEffort`) and
  any thread-level `model`/`reasoningEffort`; keep a per-thread effort next to
  the existing per-thread model in the event mapper and set `variant` from it.
  No interface change: `PluginMessage.assistant` already has `modelID` and
  `variant`.
- Keep `data` on `CodexRpcException`; map `modelProviderMismatch`,
  `modelProviderNotConfigured` and `modelProviderPolicyConflict` to a typed
  exception carrying both provider names (keeping the original as `cause`), and
  surface a `PluginOperationException` with a 4xx status and a short message
  naming both providers and the fix.

**As built.** The 0.167 schema puts the resolved `model` and `reasoningEffort`
on the started `subAgentActivity` itself (and on `Thread`), so
`collabAgentToolCall` stays undecoded. The live probe (0.167.1) puts the
mismatch on `thread/resume`: code `-32600`, `data` `{type, modelProvider,
currentModelProvider}`. The app shows its generic "Couldn't send" for any 4xx
prompt rejection, so the provider message reaches logs, not the screen.

**Verification.** Fixture tests for both. Live without credentials: with an
isolated `CODEX_HOME`, start a thread under provider A, switch to B, resume and
send, and record whether the error lands on `thread/resume` or `turn/start` and
its exact `data`.

**Docs.** Sub-agents table and the "Reopening a session whose model is gone"
section of `HARNESS_CAPABILITIES.md`; `docs/regression/session-history-and-recovery.md`.

**Estimate.** `⚙️`, about 350 lines plus generated code.

### Step 7 — OpenCode: clear no-password failure, catalog refresh

**Current behaviour.**
- `--opencode-no-password` is validated statically, without a version. With the
  OpenCode 2 shared service it is silently ignored. A private v2 server started
  without a password invents one, so the health probe gets 401 for 30 s per
  attempt and the dynamic-port loop retries up to 5 ports: about 150 s, then
  "unable to start runtime on an available dynamic port". In attach mode the
  warning says "cannot reach OpenCode".
- Agents are read from `/api/agent` on every request
  (`opencode_v2_repository.dart`) and reported as complete, but OpenCode 2.2.7
  may return a partial list on a cold location and announces changes with
  `agent.updated` / `command.updated` (empty data), which the plugin does not
  subscribe to (`tool/opencode_events_v2.json`).

**Change.**
- Private managed start with the flag: probe the resolved binary's version
  first (existing `RuntimeVersionValidator.probe`) and fail with a clear
  `PluginStartException` on major version 2+. Shared mode: log once that the
  flag is ignored because the shared service brings its own password (see open
  question). Attach mode: name `--opencode-password` in the warning. CLI help
  says v1 only.
- Add `agent.updated` and `command.updated` to the v2 event manifest,
  regenerate `v2_event.g.dart`, and map both to the existing
  `BridgeSseCommandCatalogUpdated`, which already refreshes cached projects'
  options. No debounce: the options service coalesces per key.

**Verification.** Descriptor tests (v1 fake keeps working, v2 rejection,
shared-mode log); parser and mapper tests. Live without model calls: `opencode
serve` 2.2.7 with a password on a temp project, edit `.opencode/agent/*.md`,
confirm `agent.updated` frames.

**Docs.** `bridge/app/README.md`, `docs/HOW_IT_WORKS.md`, `docs/SECURITY.md`,
one sentence in `docs/regression/plugin-setup-and-lifecycle.md`, the catalog
bullet in `docs/regression/session-creation-and-options.md`.

**Estimate.** `🌿`, about 300 lines, under half handwritten.

### Step 8 — Small runtime fixes: Claude error codes, Copilot probe, FORCE_COLOR

**Current behaviour.**
- Claude 2.1.322 adds `account_on_hold`, `verification_required` and
  `cloud_credential_error`; `ClaudeAssistantError.parse` sends them to `unknown`
  (`claude_stream_message.dart`). They already show as notices with Claude's
  text.
- The shared version probe runs `--version`
  (`sesori_plugin_runtime/lib/src/provisioning/runtime_version_validator.dart`);
  Copilot launches with `--no-auto-update` but probes without it, so a cached
  newer package could answer for the pin.
- `terminal_color_validator.dart` treats any non-empty `FORCE_COLOR` as on, and
  so do `install.sh`, `install.ps1` and the npm wrapper's `ui.js`. Node treats
  `0` and `false` as off.

**Change.**
- Claude: add the three values; route `cloud_credential_error` to
  `PluginAuthenticationRequiredException` with external-configuration recovery,
  like the custom base URL case (a Sesori login cannot fix cloud credentials).
  The other two stay notices.
- Runtime: `RuntimeManifest.versionProbeArguments` (default `["--version"]`),
  used throughout the validator; Copilot overrides it with
  `["--no-auto-update", "--version"]`. Confirm first that Copilot 1.0.78 (floor)
  and 1.0.109 accept it and exit 0.
- `FORCE_COLOR` `0` or `false` turns colour off in all four implementations.

**Verification.** Unit tests in each package, installer and npm wrapper tests.
No live run.

**Docs.** `docs/regression/plugin-runtime-installation.md` (version probe), a
Claude note near "Failed-turn notices sent as text" in `HARNESS_CAPABILITIES.md`.

**Estimate.** `🌿`, about 150 lines.

## Phase 2 (each becomes its own plan)

- **OpenCode native archive sync (Q9):** archive in OpenCode too on 2.1.0+, so
  OpenCode's own clients agree with Sesori. Plugin-side outbound only at first;
  inbound sync needs bridge-core work.
- **OpenCode MCP OAuth code paste (Q11):** use 2.2.7's paste completion route so
  OAuth works when the loopback callback cannot reach the bridge machine. The
  wire already carries the pasted URL; mostly plugin, maybe client copy.
- **Windows (Q21 Pi exit wait, Q22 Cursor managed install):** need a Windows host
  to verify; Pi loses an in-flight login refresh when killed early, and Cursor
  Windows packages exist but are unmanaged.
- **Antigravity `agy acp` (Q24):** move to Google's ACP entry point; large,
  touches launch, auth and the exact-pair gate.

## Verification matrix (final step)

Coverage level: L2 for each touched feature document, through the plugin
boundary with unit and fake-transport tests, plus these cells.

| Cell | Platform | Credentials |
|---|---|---|
| OMP 18.19.0 managed install and deletion probe; deleted session absent from the list | macOS bridge + headless iOS simulator | none |
| OMP task/ask card shows the OMP tool name | headless iOS simulator | needed (open question) |
| OMP auto-compaction card | headless iOS simulator | needed (open question) |
| Hermes failed turn (invalid key) shows one notice, live and after reload | headless iOS simulator | none |
| Codex provider mismatch shows the clear error | headless iOS simulator | none |
| Codex sub-agent messages show model and effort; withdrawn approval card disappears | headless iOS simulator | needed (open question) |
| Copilot withdrawn permission card disappears (if step 5 keeps the ACP half) | headless iOS simulator | needed (open question) |
| OpenCode agent edit refreshes the agent picker; v2 no-password start fails clearly | headless iOS simulator | none |
| Claude, Copilot probe, FORCE_COLOR | unit tests only | none |

Phase 2 Windows items carry their own Windows cells in their own plans.

## Open questions (asked on a review page)

- **Live checks with credentials:** may the final matrix use the owner's
  harness accounts for the cells marked "needed"? Without them those behaviours
  are proven only through unit and fake-transport tests, which needs explicit
  acceptance before retirement.
- **`--opencode-no-password` with the OpenCode 2 shared service:** log and
  ignore (recommended; the setup works and auth is stronger), or fail the
  start as for a private server.

## Complexity budget

New mutable state: OMP compaction tracker (per-session running state, as
DeepSeek); Codex per-thread effort map next to the existing model map. Nothing
else. Deliberately not added: pruning already-imported OMP leftovers, a
debounce for catalog events, per-locale Hermes copy, a client UI state for the
provider mismatch, a cross-package fatal health-probe flag.

## Risks

- OMP filter hides a session with zero messages and no title: the deletion
  leftover or a never-prompted session from another client, neither of which
  has anything to show.
- Copilot may never send `$/cancel_request`; step 5 checks before building.
- Codex field locations are inferred from binary strings until the schema dump.

## Steps

See `TRACKER.md`. Steps 2, 4, 5, 6, 7 and 8 can run in parallel; step 3 follows
step 2. Step 9 reconciles `docs/regression/`; step 10 runs the matrix above and
retires the plan.
