# Compatibility Debt

This document tracks temporary backwards-compatibility fields that are nullable
only to allow older peers time to roll out. Each entry lists the debt, the reason
it exists, and the exact cleanup to perform on the recorded date.

## `Project.time` is nullable

- **Location:** `shared/sesori_shared/lib/src/models/sesori/project.dart`
- **Debt:** `Project.time` is declared as `required ProjectTime? time`.
- **Reason:** Bridges released before the project-timestamp work may send
  `time: null`. Consumers currently fall back to treating the project as having
  no recorded timestamps.
- **Cleanup date:** 2026-10-11
- **Exact cleanup:**
  1. Change `Project.time` from `required ProjectTime? time` to
     `required ProjectTime time`.
  2. Remove every consumer-side fallback path that treats `time == null` as a
     valid baseline (for example, defaulting display timestamps to the current
     time, hiding timestamp columns, or skipping timestamp-based sorting).
  3. Remove any bridge-side code that emits `null` for `time`.
  4. Regenerate shared code and verify bridge + client + desktop round-trips.

## `project.updated` event fields are nullable

- **Location:** `shared/sesori_shared/lib/src/models/sesori/sesori_sse_event.dart`
- **Debt:** `SesoriSseEvent.projectUpdated` currently declares
  `required String? projectID` and `required int? updatedAt`.
- **Reason:** Servers and bridges emitting the `project.updated` event before
  this change send the event with no payload. Requiring the fields while keeping
  them nullable lets new consumers read them when present while still accepting
  older empty payloads.
- **Cleanup date:** 2026-10-11
- **Exact cleanup:**
  1. Change `SesoriSseEvent.projectUpdated` so that `projectID` and `updatedAt`
     are `required String projectID` and `required int updatedAt` (non-nullable).
  2. Update every emission site (bridge SSE mappers / event construction) to
     always provide `projectID` and `updatedAt`.
  3. Update every handler that consumes `projectUpdated` to remove null-safe
     fallbacks and assume the fields are present.
   4. Regenerate shared code and verify event round-trips.

## `Session.pluginId` is nullable

- **Location:** `shared/sesori_shared/lib/src/models/sesori/session.dart`
- **Debt:** `Session.pluginId` is declared as `required String? pluginId`.
- **Reason:** Bridges released before parallel-plugin attribution do not include
  the field. New bridges always stamp their active plugin id, while clients must
  continue accepting older responses during the compatibility window.
- **Cleanup date:** 2027-01-12
- **Exact cleanup:**
  1. Change `Session.pluginId` to `required String pluginId`.
  2. Remove client fallbacks that treat a null session plugin as the bridge
     default.
  3. Remove bridge/plugin fixtures that construct relay-facing sessions with a
     null plugin id; plugin-internal payloads must be attributed before crossing
     the bridge boundary.
  4. Regenerate shared code and verify bridge, mobile, and desktop round-trips.

## `CreateSessionRequest.pluginId` is nullable

- **Location:** `shared/sesori_shared/lib/src/models/sesori/create_session_request.dart`
- **Debt:** `CreateSessionRequest.pluginId` is declared as
  `required String? pluginId`; null selects the bridge's only/default plugin.
- **Reason:** Clients released before explicit plugin selection omit the field.
  Until multi-plugin routing lands, the single-plugin bridge assumes a non-null
  id identifies its active plugin.
- **Cleanup date:** 2027-01-12
- **Exact cleanup:**
  1. Change `CreateSessionRequest.pluginId` to `required String pluginId`.
  2. Remove the bridge's null-to-default selection fallback.
  3. Require every client create-session call to send its selected plugin id.
  4. Regenerate shared code and verify bridge and client request round-trips.

## Composer requests allow a missing plugin id

- **Location:** `shared/sesori_shared/lib/src/models/sesori/project.dart` and
  bridge handlers/repositories for `POST /agent`, `POST /provider`, and
  `POST /command`.
- **Debt:** These composer routes accept `ProjectIdRequest.pluginId == null` and
  use the bridge's only/default plugin.
- **Reason:** Older clients send only `projectId`. `ProjectIdRequest.pluginId`
  remains structurally nullable because non-composer project routes also use
  this generic DTO and do not require plugin selection.
- **Cleanup date:** 2027-01-12
- **Exact cleanup:**
  1. Make the three composer routes reject a null plugin id while leaving the
     shared DTO nullable for non-composer routes.
   2. Remove null-to-default fallback from the composer route handlers.
  3. Require module-core composer calls to send the selected plugin id.
   4. Verify older-client support has ended before removing the fallback.

## Native project rows may store the backend id as their path

- **Location:** `bridge/app/lib/src/bridge/repositories/project_repository.dart`
  and `bridge/app/lib/src/bridge/persistence/daos/projects_dao.dart`.
- **Debt:** Native project listing replaces a persisted `path` only when it is
  still exactly equal to the backend project id.
- **Reason:** Bridges released before `PluginProject.directory` stored the id as
  the default path. New bridges repair that legacy default from the plugin's
  declared directory while preserving any separately recorded moved path.
- **Cleanup date:** 2027-01-12
- **Exact cleanup:**
  1. Remove `ProjectsDao.replacePathIfMatches`.
  2. Remove the native-list reconciliation loop from `ProjectRepository`.
  3. Keep new-row seeding from `PluginProject.directory` unchanged.
  4. Verify every supported bridge version has written explicit native project
     directories before removing the repair.
