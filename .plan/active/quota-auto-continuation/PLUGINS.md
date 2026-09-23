# Plugin implementation map

Supplement to [IMPLEMENTATION.md](IMPLEMENTATION.md). Paths below are relative
to the named plugin's `lib/src/`. Existing owners keep their current role;
new files/classes are explicitly marked. No plugin advertises support until
its pinned runtime passes the parser, terminal-reporting and readiness checks.

## Claude Code — `bridge/sesori_plugin_claude`

- **API:** `api/models/claude_stream_message.dart` / `ClaudeRateLimitMessage`
  gains typed reset/status fields, replacing raw rate-limit payload access.
  `api/claude_stream_client.dart` remains the transport owner. API parsing has
  no repository, service or bridge-core dependency.
- **Repository mapping:** new
  `repositories/mappers/claude_quota_interruption_mapper.dart` /
  `ClaudeQuotaInterruptionMapper` maps typed rejected-limit data and the narrowly
  recognized tagged error fallback into `PluginQuotaInterruption`. It is
  stateless: named inputs supply the stable error ID, original observation time,
  and typed provider data. Time-zone parsing remains inside this plugin.
- **Turn lifecycle:** `services/claude_session_service.dart` /
  `ClaudeSessionService` alone invokes the mapper from its existing process-event
  handling, retains at most one candidate in its turn state, and releases it
  after terminal settlement. Inject the stateless mapper into that service.
  Before quota mapping, ignore forwarded assistant/user/stream frames whose
  parentToolUseId is non-null, including when the child identity is not yet
  known. Claude sub-agent sessions are read-only; their quota errors must not
  arm the root session. A process-level rate-limit status without message
  attribution is only supporting evidence: release requires a terminal error
  belonging to the root turn, with that root error's stable message ID.
  Reuse the stable message-ID mapping used by live/history error projection.
  `claude_event_dispatcher.dart` / `ClaudeEventDispatcher` continues presentation
  mapping only; no candidate must cross between these peer owners. The service
  emits the result through its existing event path, without another stream.
- **Readiness:** `ClaudeSessionService` owns the named-session decision using
  its existing `ClaudeSessionProcessRepository`, `ClaudeApprovalRegistry`, clock
  and turn/queue state. Add data-only named-session process queries to
  `repositories/claude_session_process_repository.dart` as needed. A pending
  approval, native wakeup, retry, turn or queue blocks idle readiness. A missing
  resident-map entry alone never proves idle; prove normal startup/process
  ownership for non-resident sessions, otherwise return unknown.
- **Boundary/composition:** `claude_plugin_impl.dart` / `ClaudePlugin` delegates
  readiness to its existing session service and wires its mapper dependency. The descriptor
  in `runtime/claude_plugin_descriptor.dart` declares conditional reporting.
  No raw provider fields or Claude identifiers leave the plugin contract.

## Pi — `bridge/sesori_plugin_pi`

- **API:** `api/models/pi_event.dart` and `pi_rpc_state_dto.dart` retain the typed
  terminal error, original timestamp and native state fields received through
  `api/pi_rpc_client.dart`. No provider retry headers are assumed to survive RPC.
- **Repository mapping:** new
  `repositories/mappers/pi_quota_interruption_mapper.dart` /
  `PiQuotaInterruptionMapper` is stateless, taking named error ID, original time,
  provider and terminal error inputs. It recognizes the evidenced `openai-codex`
  duration format and returns known/unknown reset. Existing
  `pi_history_mapper.dart` and `pi_message_identity_builder.dart` remain the
  error/history identity authorities; history parsing never emits quota events.
- **Turn lifecycle:** `services/pi_session_service.dart` / `PiSessionService`
  alone invokes the injected stateless mapper in its existing _handleFrame
  lifecycle path. It keeps at most one candidate in existing turn state until
  native retry settles, discards it on successful recovery, and emits only a
  remaining terminal quota interruption through its existing event path.
  `services/pi_event_dispatcher.dart` / `PiEventDispatcher` continues presentation
  mapping; its immediately emitted mapped events carry no quota candidate.
  No candidate handoff, second event stream or second retry owner is introduced.
- **Readiness:** `PiSessionService` uses its existing process/catalog
  repositories, event dispatcher, `PiExtensionUiService`, clock and native
  turn/queue state. `repositories/pi_session_process_repository.dart` exposes
  typed named-session process/RPC facts; its existing API clients perform I/O.
  Pending extension input, retry, compaction or queued work cannot report idle.
  Confirm non-resident process ownership, or return unknown without guessing.
- **Boundary/composition:** `pi_plugin_impl.dart` / `PiPlugin` delegates to its
  session service and supplies the mapper to PiEventDispatcher.
  `runtime/pi_plugin_descriptor.dart`
  declares conditional reporting only for verified error/provider shapes.

## Codex candidate — `bridge/sesori_plugin_codex`

- **API:** extend `api/codex_app_server_api.dart` / `CodexAppServerApi` with a
  typed account-rate-limit read. New `api/models/codex_rate_limits_dto.dart` /
  `CodexRateLimitsDto` decodes the driven wire shape. Existing thread DTO/API
  reads also expose native thread readiness data; API code does no bucket policy.
- **Repository mapping:** new `repositories/codex_quota_repository.dart` /
  `CodexQuotaRepository` takes the existing `CodexAppServerApi`, maps its typed
  response and attributes exhausted windows to the failed request. Its named
  inputs include the original error ID/time and selected provider/model. It
  returns unknown if attribution or a required reset is missing. No account
  cache, timer or polling loop is added.
- **Turn lifecycle:** `codex_event_mapper.dart` / `CodexEventMapper` recognizes
  the terminal usage-limit event. `codex_plugin_impl.dart` / `CodexPlugin`
  preserves existing turn identity and generation handling, then delegates the
  failure-triggered quota lookup to `services/codex_session_service.dart` /
  `CodexSessionService`. Inject `CodexQuotaRepository` into that service; publish
  the normalized result through the plugin's current event path.
- **Readiness:** `CodexSessionService` alone derives readiness. It gains
  `CodexThreadRepository` for a typed named-thread read; that repository already
  depends on `CodexAppServerApi`. New immutable
  `repositories/models/codex_local_session_facts.dart` / `CodexLocalSessionFacts`
  carries observed native status, active turn ID, pending-input/request facts
  and queued-work facts copied from existing owners. `CodexPlugin` passes that
  snapshot as a named input without interpreting it as readiness. The service
  combines those facts with native thread evidence and returns the enum. There
  is no reverse callback or dependency on CodexPlugin. Extend existing thread
  DTO/domain mappings as needed; missing/uncertain facts cannot imply idle.
  No activity map or child traversal is added.
- **Boundary/composition:** `CodexPlugin` exposes the readiness operation and
  wires the new dependencies in existing construction.
  `runtime/codex_plugin_descriptor.dart` remains unavailable until failed-turn
  bucket attribution is verified, then may declare conditional reporting.

## Other registered harnesses

OpenCode, GitHub Copilot, Cursor, Hermes Agent, Oh My Pi, DeepSeek, Grok Build and
Antigravity remain **unverified**, not unsupported. Step 2 inspects their actual
driven error/reset payloads before deciding whether to add reporting. The initial
internal-contract update does not invent quota parsers for them:

- `bridge/sesori_plugin_opencode/lib/src/opencode_plugin_impl.dart` /
  `OpenCodePlugin` implements unavailable readiness while reporting is unverified.
- `bridge/sesori_plugin_acp/lib/src/acp_plugin.dart` / `AcpPlugin` supplies the
  same unavailable contract to its concrete adapters. No generic ACP reset
  parser is assumed. Pi RPC evidence cannot enable Oh My Pi's ACP adapter.
- Each concrete descriptor keeps reporting unavailable until verified; this is
  a declared implementation limit, not a claim that its harness is incapable.
  All in-repository test fakes implement the required internal API in lockstep.
- If inspection establishes another usable provider/reset seam, add its exact
  API/repository/service mapping to this document before implementing support,
  following the same plugin-local ownership and tests. Update the harness matrix
  with the actual evidence. A considerable architecture change gets plan review;
  uncertainty alone does not authorize new shared abstractions.

## Required plugin checks

Every advertised plugin needs sanitized real-payload parser tests, terminal-only
reporting, live/history error-ID agreement, native retry exhaustion, pending-input
and queued-work readiness, and restart/non-resident coverage. Unverified or
unknown readiness must produce no send. Keep tests beside the mapped owners;
wire/API DTO changes regenerate their source-controlled serializers.
