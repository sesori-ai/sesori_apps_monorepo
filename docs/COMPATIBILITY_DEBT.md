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
