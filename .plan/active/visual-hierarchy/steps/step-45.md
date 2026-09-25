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

### What changed

- `SessionApi`, `SessionRepository` and a new `SessionApprovalService` carry
  `PATCH /session/approval-override`. The service owns the default rule:
  picking the mode the bridge setting gives sends a null override, so the
  session follows later changes to the bridge setting; picking the other mode
  stores it.
- `BridgeSettingsService` publishes the whole `YoloSettingsResponse` instead of
  a bool, so sessions learn `supportsSessionOverride`. A committed YOLO save
  updates only `enabled` and keeps the loaded support flag.
- `SessionDetailLoaded` carries `bridgeYolo` and `isUpdatingApproval`, and its
  `approvalControl` resolves a sealed `SessionApprovalControl`: hidden or a
  read-only bridge-wide YOLO chip on older bridges, or per-session with the
  effective mode and the bridge default. `SessionDetailCubit.setApprovalMode`
  applies the acknowledged session and reports a failure as a notice.
- The composer shows `SessionApprovalChip` on supporting bridges: YOLO is the
  warning-coloured `shield-exclamation` with "YOLO" (glyph only on touch);
  asking is the neutral outline shield, glyph only, named "Ask for approval".
  Its anchored menu lists "Ask for approval" and "Approve everything (YOLO)",
  suffixes the bridge default with "(default)", and tints YOLO with the warning
  colour. Older bridges keep today's `YoloChip` and its explanation.
- `YoloChip.icon` is declared by hand as `IconData(0xF9C6)` because the icon
  generator skips codepoints above U+F8FF. The Settings row picks it up.
- `PregoComposerChip` and `PregoMenuItem` gain a warning tone.

### Deviations

- The chip reads only the session's own override. A child session without one
  shows the bridge default even when the bridge applies an ancestor's override.
  Accepted: the display is informational, and picking on the child sets the
  child's own override.

### Verification

- `dart analyze --fatal-infos` is clean in `module_prego`, `module_core`,
  `module_app_ui`, `app` and `desktop`.
- `dart test` in `module_core` (session detail cubits, services, API);
  `flutter test` for the app's session detail body, model row, routing and
  settings tests, `module_prego` components, `module_app_ui` session detail and
  the desktop sessions and settings tests.
