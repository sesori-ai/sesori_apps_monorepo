# Step 27/45 — Extract the shared pending-permission registry base

## Re-verification against Step 26

ACP and Codex still duplicated bridge request ID allocation, opaque pending
storage, request-stream lifecycle, pending snapshots and queries, reply/reject
removal, clearing events, session cancellation, and settle-all disposal. Their
request classification, parsing, wire response shapes, permission summaries,
and question builders remain protocol-specific. Claude's registry remains
structurally different and was not migrated.

## Change

- Added `PendingPermissionRegistry<TRequest, TPayload>` to
  `sesori_plugin_interface`. It owns the shared lifecycle and contract state but
  stores protocol payloads opaquely and delegates settlement through typed
  callbacks.
- Migrated ACP and Codex to the shared registry while preserving their local
  parsing, classification, response construction, invalid-answer behavior, and
  remove-before-response settlement semantics.
- Made cancellation and disposal settle every pending entry independently,
  retain recovered failures in local logs, and clear stale client prompts even
  when another backend resolution fails.
- Moved Cursor's `generate_image` and `update_todos` acknowledgement and
  notification reinjection into `CursorApprovalRegistry`, including observable
  reinjection failures that do not break later request routing.
- Kept DeepSeek's DTO mapping and strict answer validation local while routing
  its question registration through the shared engine.
- Documented the pending-input lifecycle contract on `BridgePluginApi` and in
  the questions-and-permissions regression document.
- There is no public wire, persisted-data, database, or intended user-visible
  behavior change.

## Verification

- `dart analyze --fatal-infos` in `bridge/sesori_plugin_interface`: passed.
- Full `dart test` in `bridge/sesori_plugin_interface`: 155 passed.
- Focused shared registry tests: 3 passed.
- `dart analyze --fatal-infos` and full `dart test` in
  `bridge/sesori_plugin_acp`: passed, 261 tests.
- `dart analyze --fatal-infos` and full `dart test` in
  `bridge/sesori_plugin_codex`: passed, 380 tests.
- Cursor analyzer and `cursor_approval_registry_test.dart`: passed.
- DeepSeek analyzer and `deepseek_approval_registry_test.dart`: passed.
- Claude analyzer and unchanged `claude_approval_registry_test.dart`: passed.
- Architecture implementation review: approved with no findings; the shared
  registry remains in `sesori_plugin_interface` as planned.
- `git diff --check`: passed.
