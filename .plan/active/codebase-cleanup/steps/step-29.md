# Step 29 Evidence

## Re-verification

- `AcpStdioClient`, `CodexStdioAppServerClient`, `ClaudeStreamClient`, and `PiRpcClient` still independently owned line framing, pending correlation, timeout removal, process-exit failure, attach fencing, and teardown.
- Codex WebSocket transport remains separate and unchanged.
- Pi still requires LF-only byte framing, startup buffering before listener attachment, bounded/redacted stderr-tail diagnostics, and exit-time stdout/stderr draining. Adopting decoded-line `NdjsonProcessClient` would remove those behaviors or duplicate them around the shared client, increasing code.
- Claude correlation is inseparable from `ClaudeStreamMessage.parse`: `request_id`, success subtype, payload, and error mapping are resolved by `ClaudeControlResponseMessage` inside one exhaustive message switch. Correlating first in `NdjsonProcessClient` would duplicate Claude frame-shape parsing and split protocol classification across transport and plugin. Lifecycle-only adoption leaves both subscriptions and process-frame parsing local, so it is net addition rather than consolidation.

## Actual scope and deltas

- Added exported `NdjsonProcessClient`, `NdjsonProcessHandle`, attach token, explicit malformed/non-object/stderr policies, explicit malformed-log content policy, opaque correlation callback, plugin-typed process-exit error callback, request/dispatch/send APIs, generation fencing, serialized reset/dispose, and close-stdin/graceful/force teardown.
- Runtime transport preserves original synchronous write failures, removes timed-out correlation before late responses, rejects/reaps superseded attaches, fences stdout/stderr/exit callbacks, validates object string keys without throwing casts, fails all pending requests on configured frame/stream/exit failures, and continues cleanup after stage failures.
- Migrated Codex stdio and ACP stdio correlation, timeout, framing, attach, process-exit, and teardown. Protocol envelopes, notifications/server requests, and typed RPC error mapping remain plugin-local. Codex malformed JSON still fails all pending; non-object frames remain discard-only; stderr content remains discarded. ACP malformed/non-object frames remain discard-only; stderr remains forwarded.
- ACP teardown intentionally now closes stdin before termination.
- Claude and Pi remain local for concrete incompatibilities above. Codex WebSocket remains local.
- Updated runtime export, ACP runtime dependency, bridge module-order description, and lifecycle regression documentation.

## Verification results

- `dart analyze --fatal-infos && dart test` in `bridge/sesori_plugin_runtime`: pass; 166 tests.
- `dart analyze --fatal-infos && dart test test/codex_stdio_app_server_client_test.dart` in `bridge/sesori_plugin_codex`: pass; 7 tests.
- `dart test` in `bridge/sesori_plugin_codex`: pass; 380 tests.
- `dart analyze --fatal-infos && dart test test/acp_stdio_client_test.dart` in `bridge/sesori_plugin_acp`: pass; 12 tests.
- First full ACP run exposed `AcpBridgePlugin start rolls back as soon as the start is aborted during a hanging handshake` at 5.023 seconds and then hit the 120-second command timeout. Shared teardown was corrected to close stdin, signal graceful immediately, then wait before force-kill.
- `dart test test/acp_bridge_plugin_test.dart test/acp_stdio_client_test.dart` after that correction: pass; 14 tests.
- `dart test` in unchanged `bridge/sesori_plugin_claude`: pass; 254 tests. `dart analyze --fatal-infos`: pass.
- `dart analyze --fatal-infos && dart test test/pi_rpc_client_test.dart` in unchanged `bridge/sesori_plugin_pi`: pass; 34 tests.
- Final `dart test` rerun in `bridge/sesori_plugin_acp`: pass; 263 tests.
- Architecture implementation review: approved with no findings.
- Correctness review findings were applied: ACP malformed-frame logs now retain
  metadata only, and reset/dispose complete the detached process's captured
  exit future without allowing stale callbacks to affect a replacement.
- After merging Step 28 review fixes forward, final analyzers and full suites
  passed for runtime (166), ACP (263), and Codex (380).
- `git diff --check`: passed.
