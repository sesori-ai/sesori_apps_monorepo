# Antigravity Persistent ACP Composition

## Status and supported behavior

Registered local-runtime behavior over the Step 8.b composition. Inputs are an already-validated official runtime pair
and prepared isolated profile, not ambient credentials. Activation adds no database/wire migration, analytics event,
managed installation, OAuth attempt or Google history deletion.

- One existing ACP lifecycle owns live processes, turn lanes, pending input and replay clients. Composition injects
  required peers; one connection-scoped catalog repository wraps standard list/new/resume requests. The options service
  owns coalescing, reserved-session identity, catalog state and reset fencing; the plugin owns live-client composition
  and final session filtering. No second process or parallel API/service stack is used.
- Fresh options create or recover one retained no-prompt native discovery session in the reserved conversations cwd.
  Reuse is inert and refresh resumes its exact ID. Every matching reserved-cwd session is hidden from enumeration and
  metadata recovery; native files remain because deletion is unavailable. Exact paired High/Medium/Low entries become
  one model with variants; ambiguous shapes remain raw. Selection writes the exact native ID, then mode `default`, while
  normalized model/variant metadata is stamped live and on replay. Reset clears picker state and fences late discovery;
  failed or malformed refresh retains last-good state.
- Metadata recovery runs once per new live connection before it is advertised, not during ordinary enumeration or DB
  catalog reads. Imports consume those warmed hints. DB/live bindings override recovery regardless of arrival order. Live residency prefers advertised resume, otherwise load; replay always uses load.
- Cancellation/deletion settle the target's pending input without altering other sessions. Local deletion never removes
  Google metadata/history. Existing bridge tombstones, not plugin-side history deletion, own reimport exclusion.
- Live/replay receive fresh pre-decoding policies and the same normalizer. The authorization classifier holds only the
  56-byte pinned prefix before ordinary NDJSON streams unchanged. Matching lines allow a 16KiB URL plus prefix/CRLF;
  stderr remains 64KiB. Provider matching stays in the plugin. Default ACP whole-line interception is unchanged.
- Images keep existing limits: 20MiB individually, 50MiB collection, four candidates. Base64 expands a 20MiB image to
  roughly 28 million characters; a whole-line auth gate is inappropriate. Buffering 256MiB additionally
  risks 1–2GiB of general-list slots at 4–8 bytes each. The gate now retains a small prefix, not an entire image line,
  and uses immutable byte views rather than boxed copies. Normal NDJSON decoding still has its existing memory cost.
- Stale auth stops before dispatch without a browser launch or secret URL logging. Typed authentication failures retain
  the interception wrapper and original source stack through initialization, transport reset and live failure caching.
  Ordinary errors keep their identity. Existing client cleanup forwards cancellation and reaps late spawn results;
  this does not claim that uninterruptible OS spawning can be cancelled instantly.

## Failure signals and coverage

Wrong discovery cwd, duplicate routine discovery artifacts, a prompt sent to the reserved session, reserved-session
catalog/recovery leakage, replay leaking into live state, normalized native dispatch, stale model/variant acceptance,
invented approvals, lost original failure stacks, secret log output, auth gates accumulating image lines, or deletion
touching Google files are regressions.

- **L1/L2:** `antigravity_session_options_service_test.dart` covers grouping ambiguity, exact variant dispatch,
  coalescing/reuse/refresh/recovery, failure retention and reset fencing. `antigravity_plugin_test.dart` covers hidden
  no-prompt cold discovery, exact refresh reuse, personal handshake/new/mode/model writes, normalized live/replay
  metadata, once-per-connection recovery and DB precedence, both residency paths, and 121-message replay/two sessions.
- **L3/L4:** same composed tests cover exact questions, active cancellation/delete isolation, crash/reset/reconnect,
  global interruption, idempotent dispose, late-spawn reaping, enterprise rejection and live/replay stale-auth privacy.
  `antigravity_output_composer_test.dart` covers all auth-line splits and large valid image-bearing JSON;
  `acp_output_interceptor_test.dart` covers EOF/CRLF/UTF-8, bounded matched lines, cancellation and 25MiB streaming
  before newline. `ndjson_process_client_test.dart` verifies caught-stack and explicit-reset-stack behavior.
- **L5 Full:** native supported targets, real authorized authentication and bridge import/tombstone end-to-end remain
  later gates. Missing infrastructure is Blocked, not replaced by these synthetic tests.
