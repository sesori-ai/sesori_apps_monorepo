# Step 45 — YOLO per session

## Part a: the bridge stores a per-session override

### What changed

- Sessions carry a nullable `approvalOverride` (`SessionApprovalMode.ask` or
  `yolo`). Null follows the bridge-wide YOLO setting. The bridge stores it in a
  new nullable `sessions_table.approval_override` column (schema 19, no
  backfill: null is what every session did before).
- `PATCH /session/approval-override` with
  `SetSessionApprovalOverrideRequest{sessionId, approvalOverride}` sets or
  clears the override and returns the enriched `Session`. An unknown session
  answers 404 with `SessionApprovalOverrideErrorResponse{code: sessionNotFound}`.
- `SessionMutationDispatcher` owns the write and announces it as a
  `session.updated` event, so other surfaces see the change.
- `PermissionAutoApprovalService.isYolo` owns the effective mode:
  the nearest override on the session or its ancestors, else the bridge
  setting. Live approval, the pending sweep and snapshot resolution approve
  only sessions that are effectively YOLO. The sweep runs when the bridge
  setting turns on and when a session is switched to YOLO.
- `YoloSettingsResponse.supportsSessionOverride` (default false) lets a client
  tell a bridge that predates overrides from one whose sessions all follow the
  bridge setting.

### Deviations

- Child sessions inherit their nearest ancestor's override, because sub-agent
  permission requests carry the child session id.
- Setting an override does not change the session's `updatedAt`, so it does
  not reorder session lists.
- No harness needs changes. Plugins only pass `approvalOverride: null` where
  they build a `Session`; `docs/HARNESS_CAPABILITIES.md` is unchanged.

### Verification

- `dart analyze --fatal-infos` is clean in `sesori_shared`, bridge `app`,
  `sesori_plugin_acp`, `sesori_plugin_codex`, and the client packages whose
  tests build a `Session`.
- `dart test` passes in `sesori_shared`, bridge `app`, `sesori_plugin_acp` and
  `sesori_plugin_codex`, including the v18 to v19 migration test, the handler
  test, override scoping in `pending_interaction_service_test.dart`, and the
  shared round-trip tests with the missing-field default.

## Part b: the composer picks YOLO per session

Pending.
