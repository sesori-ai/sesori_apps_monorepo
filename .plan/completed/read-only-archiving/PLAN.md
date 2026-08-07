# Read-Only Archiving

## Status

- **Plan slug:** `read-only-archiving`
- **Status:** Completed — all implementation steps merged; retired 2026-08-07
- **Plan date:** 2026-08-06
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Base:** `main` at `232974e1`
- **Relationship:** prerequisite of `internal-chat-history`, now satisfied. The
  chat-history archive export/purge builds on the permanence guarantee
  established here.
- **As-built deltas:** see `TRACKER.md`. Notably, `ArchivedSessionValidator`
  checks only the session the caller named — the family/ancestor checks two
  review rounds asked for were tried and deliberately reverted.

## Goal

Archiving becomes a final, permanent action. An archived session can never be
unarchived, prompted, or mutated again — it is audit-only. Remove the entire
unarchive capability (bridge, wire behavior, client UI) and make archived
session detail read-only in the app.

## Current Behavior

- `PATCH /session/update/archive` accepts `archived: false`.
  `SessionLifecycleService._doUnarchive`
  (bridge/app/lib/src/bridge/services/session_lifecycle_service.dart:252)
  clears `archived_at` and, for dedicated sessions whose worktree is gone,
  re-creates it via `WorktreeService.restoreWorktree`.
- `SessionRepository.unarchiveStoredSession` and `SessionDao.clearArchived`
  back that flow.
- The client renders Unarchive in the session tile menu and swipe pill,
  supports undo-of-archive (which unarchives), and archived session detail
  still shows the composer and accepts prompt sends, question replies, and
  permission replies.
- Archiving is described to users as reversible.

## Proposed Changes

### Bridge

1. **Single read-only validator.** New Layer-3 `ArchivedSessionValidator`
   (`bridge/app/lib/src/bridge/services/`, dep:
   `{required SessionRepository sessionRepository}`) exposing one check that
   throws a typed `SessionArchivedReadOnlyException` when the target session
   is archived. It is the **only** archive-permanence rule in the bridge —
   every archived-mutation rejection uses this one exception type:
   - `SessionLifecycleService._updateArchiveStatusAlreadyReserved` consults
     it when `archived: false` targets an archived session (idempotent no-op
     remains for `archived: false` on a non-archived session, matching
     today's unchanged-result path). No separate exception type. The request
     shape keeps accepting `archived: false` because published apps send it:
     `// COMPATIBILITY 2026-08-06 (v<current>): published apps render
     Unarchive from time.archived alone; remove tolerance when out of
     support.`
   - `SessionPromptService.sendPrompt` and
     `PendingInteractionService.replyToPermission` / `replyToQuestion` /
     `rejectQuestion` consult it inside the body dispatched through
     `SessionOperationDispatcher` (so the check cannot race a concurrent
     archive on the same family lane; archive itself reserves that lane).
     The legacy sessionless question-rejection path
     (pending_interaction_service.dart:76-105) has no session to check and
     is exempt.
   - Handlers only translate the typed exception to the wire error; no
     per-handler duplication.
2. **Wire error shape.** A new freezed `SessionArchivedRejection` model in
   `shared/sesori_shared/lib/src/models/sesori/` (fields: `sessionId`,
   closed `reason` enum, initially one value `archivedReadOnly`) is the 409
   body for every archived-mutation rejection. This **is** a new shared wire
   model (a deliberate exception to "no new wire fields"). Published-client
   behavior per path, verified against current client code:
   - `SessionApi.unarchiveSession` (client/module_core/lib/src/api/session_api.dart:149)
     does not parse 409 bodies; the call fails and the published client's
     optimistic unarchive rolls back with its generic failure log/snackbar.
     Acceptable explicit failure.
   - `archiveSession`/`deleteSession` run `_throwIfCleanupRejected`
     (session_api.dart:192-206), which parses `SessionCleanupRejection`
     bodies. The new body's JSON shape shares no required keys with
     `SessionCleanupRejection`, so parsing fails and the generic error path
     runs — no bogus cleanup/force dialog. Pinned by a step-2 test.
   - Prompt/question/permission routes surface the generic send-failure
     path on published clients.
3. **Delete the unarchive machinery** (whole vertical, no orphans):
   `SessionLifecycleService._doUnarchive` and `_resolveRestoreBaseBranch`,
   `SessionRepository.unarchiveStoredSession`, `SessionDao.clearArchived`,
   `WorktreeService.restoreWorktree` and
   `WorktreeService.resolveBaseBranchAndCommit` (only production caller is
   `_resolveRestoreBaseBranch`; `createWorktree` uses the repository method
   directly), `WorktreeRepository.restoreWorktree`,
   `GitCliApi.restoreWorktree`, `SessionInitializationException` and its
   `on SessionInitializationException` branch in
   `UpdateSessionArchiveStatusHandler`, and all their tests.

### Client

1. Remove `unarchiveSession` from `SessionApi`, `SessionRepository`,
   `SessionService`, and `SessionListCubit`; remove the Unarchive tile-menu
   entry and swipe-pill state; remove the related l10n strings; update
   affected tests.
2. **Undo machinery fate, explicitly:** `undoLastArchiveAction` and
   `clearLastActionUndo` are deleted from `SessionListCubit` (with archive
   one-way and unarchive gone, no user-facing undo remains).
   `_rollbackLastAction` **survives** — it is still required for
   optimistic-archive failure rollback (session_list_cubit.dart:408/419) —
   and therefore the snapshot it reads survives too: `_undoSnapshot` is
   renamed to `_lastActionSnapshot` (still written by the archive path at
   session_list_cubit.dart:383) since its remaining purpose is failure
   rollback, not undo. `_showUndoSnackBar` in
   `client/app/lib/features/session_list/session_list_actions.dart:95-125`
   is deleted; the archive success path shows a plain confirmation snackbar
   without an undo action.
3. Archive confirmation copy changes from reversible to permanent (the user
   must understand the action is final before committing).
4. **Archived session detail read-only — split stated explicitly:** the
   refusal decision lives in `module_core`: `SessionDetailCubit.sendMessage`,
   `replyToQuestion`, `rejectQuestion`, `replyToPermission`, and
   `_drainQueuedMessages` no-op with a logged reason when
   `SessionDetailLoaded.isArchived`
   (client/module_core/lib/src/cubits/session_detail/session_detail_state.dart:34)
   is true. The `client/app` session-detail widgets only branch on that same
   flag for presentation: composer hidden, question/permission interaction
   widgets rendered disabled, mutating actions hidden, and a clear archived
   state surfaced. No decision logic in the Flutter shell. Bridge-side, the
   validator above enforces the same rule for old or misbehaving clients.

## Wire Compatibility

- `archived: false` from a published app → explicit 409 carrying the new
  `SessionArchivedRejection` body. The published client does not parse that
  body (see Bridge item 2 for the per-path behavior); the operation fails
  explicitly and the optimistic UI rolls back. Deliberate one-way behavior
  change, not silent breakage.
- Prompt/question/permission sends to archived sessions from a published app →
  same 409 body, generic send-failure surface. Deliberate behavior change;
  the archived state is user-visible in the session list, keeping the
  failure understandable.
- One new shared wire model (`SessionArchivedRejection`); no new routes. New
  clients parse it for precise messaging; old clients degrade to generic
  errors. Internal Dart contracts update in lockstep.

## Cleanup Assessment

Included in the feature PRs (directly caused):

- The full unarchive vertical listed in Bridge item 3, and tests (step 2).
- Client unarchive UI, undo-of-archive machinery per Client item 2, l10n
  strings, and tests (step 3).

Kept: `archived_at` column and `idx_sessions_archive` (archived listing);
`notifySessionArchived` best-effort backend call; the archive action itself.

## Evidence And Proportionality

- The permanence decision is an explicit product decision by the user, not a
  defensive safeguard.
- `ArchivedSessionValidator` addresses an ordinary reachable flow (old
  clients or stale UI sending to an archived session) with a single coarse
  check — no per-resource machinery.
- No locks, registries, or lifecycle machinery added.

## PR Series

| Step | Exact PR title | Boundary |
|---|---|---|
| 1/4 | `🌱 [read-only-archiving] Raise plan [step 1/4]` | This plan and tracker. |
| 2/4 | `⚙️ [read-only-archiving] Reject unarchive and delete restore machinery [step 2/4]` | `ArchivedSessionValidator` + `SessionArchivedRejection` shared model, lifecycle-service consultation, handler mapping, full unarchive-vertical deletion, mis-parse pin test. |
| 3/4 | `⚙️ [read-only-archiving] Enforce read-only archived sessions [step 3/4]` | Prompt/question/permission enforcement via the validator (bridge), client unarchive-UI and undo removal, permanent-archive copy, read-only archived detail (cubit refusal + widget presentation), l10n, tests. |
| 4/4 | `🌱 [read-only-archiving] Retire plan [step 4/4]` | Move plan to `.plan/completed/`. |

Step 3 spans bridge and client; if it trends past the 1,500-line soft cap it
splits at the bridge/client boundary (gate PR, then client PR) and the series
total is restated before opening the first affected PR.

## Verification

- Step 2: service tests — `archived: false` on an archived session throws
  `SessionArchivedReadOnlyException` and maps to 409 with the
  `SessionArchivedRejection` body; on a non-archived session remains a no-op;
  archive path unaffected. Mis-parse pin: the new body does not decode as
  `SessionCleanupRejection`. Deleted-code references gone (`dart analyze`).
- Step 3: validator tests (prompt, permission reply, question reply, question
  reject each rejected on archived sessions inside the dispatched operation,
  allowed otherwise); cubit refusal tests for archived sessions; client
  widget tests for removed affordances and read-only detail; l10n
  completeness.
- Per-PR: owning-package tests + analyzer; CI runs the matrix.

## Risks

- Published apps still render Unarchive until they update; they now receive
  an explicit error. Accepted and intended.
- A user archiving by mistake has no recovery. Mitigated by permanent-action
  confirmation copy; accepted by product decision.

## Plan Review Record

- 2026-08-06 — `architecture-plan-review` (sub-agent) rejected the first
  draft with nine findings: dual rejection structures/exception types,
  `rejectQuestion` omitted from the gated set, incomplete deletion vertical
  (worktree repository/API, `resolveBaseBranchAndCommit`,
  `SessionInitializationException`), unspecified dispatcher ordering,
  misnamed collaborators, forbidden `Gate` suffix, undefined 409 body
  contract and incorrect client-rendering claim, unnamed client classes for
  read-only detail, and half-removed undo machinery. All findings were
  applied directly in this document; the corrected plan was not re-reviewed
  merely for approval.
