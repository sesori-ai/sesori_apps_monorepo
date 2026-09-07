# Antigravity Persistent ACP Composition

## Status and supported behavior

Internal, unregistered Step 8.b composition only. Inputs are an already-validated official runtime pair and prepared
isolated profile, not ambient credentials. Descriptor/setup/exit supervision are Step 8.c; activation is Step 9.
No database/wire migration, analytics event, managed installation, OAuth attempt or Google history deletion lands here.

- One existing ACP lifecycle owns live processes, turn lanes, pending input and replay clients. Composition injects
  required peers; options use the actual connection's configuration repository per call. No scratch session is used.
- Fresh options expose one primary agent and no models. Real new sessions establish the account default; load/resume
  do not redefine it. Explicit models use advertised IDs; every applied turn uses mode `default`. Reset clears catalog
  and default together. Commands use the existing notification snapshot.
- Metadata recovery runs on import/cold attribution, not ordinary DB catalog reads. DB/live bindings override recovery
  regardless of arrival order. Live residency prefers advertised resume, otherwise load; replay always uses load.
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

Wrong cwd, replay leaking into live state, lost models/defaults, invented approvals, lost original failure stacks,
secret log output, auth gates accumulating image lines, or deletion touching Google files are regressions.

- **L1/L2:** `antigravity_plugin_test.dart`: inert options; personal handshake/new/default-mode/model writes;
  both residency paths; cold metadata and DB precedence; 121-message replay/two sessions; native output parity.
- **L3/L4:** same composed tests cover exact questions, active cancellation/delete isolation, crash/reset/reconnect,
  global interruption, idempotent dispose, late-spawn reaping, enterprise rejection and live/replay stale-auth privacy.
  `antigravity_output_composer_test.dart` covers all auth-line splits and large valid image-bearing JSON;
  `acp_output_interceptor_test.dart` covers EOF/CRLF/UTF-8, bounded matched lines, cancellation and 25MiB streaming
  before newline. `ndjson_process_client_test.dart` verifies caught-stack and explicit-reset-stack behavior.
- **L5 Full:** native supported targets, real authorized authentication, descriptor host supervision and bridge import/
  tombstone end-to-end remain later gates. Missing infrastructure is Blocked, not replaced by these synthetic tests.
