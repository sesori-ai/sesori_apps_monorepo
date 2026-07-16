# S02-W01-P01: Add Durable Branch Observation

## 0. Metadata

- **ID:** S02-W01-P01
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Worktree:** one dedicated worker worktree for this PR
- **Base branch:** `main`
- **Branch:** `plan/session-pull-request-monitoring/s02-w01-p01-durable-branch-observation`
- **Wave baseline:** pin the assessed current `main` tip in `TRACKER.md` before branch creation
- **Audited reference:** `e766684e0fdc22256419b7b99691021c9f14732d`
- **Contract-affecting:** Yes — persisted schema and shipped branch state

## 1. Goal and Cohesion

Persist every root session's exact reported directory and observe named branch
transitions through one filesystem subscription per normalized git `HEAD`
target. This PR is cohesive because it establishes a complete local-only branch
truth pipeline—session persistence, migration, watcher lifecycle, current/history
writes, and typed changes—without introducing GitHub/network behavior.

## 2. Dependencies and Baseline

- S01-W01-P01 is merged to `main`.
- Parallel-plugin Stage 2 remains paused.
- Assess drift in session schema/DAO/repository, session creation/list/event
  persistence, `GitCliApi`, `FilesystemApi`, Orchestrator/runtime composition
  ownership, and migration history.
- Read the current schema version after pinning. Allocate exactly `N+1`; v11 is
  only the expected number if audited v10 remains current.

## 3. Scope

### In Scope

- Export the current Drift schema before source changes.
- Add/reuse non-null root-session `directory`, nullable normalized
  `git_common_directory`, nullable `current_branch_name`, and owner-scoped
  `session_branch_history` whose identity includes a non-null normalized Git
  common directory plus branch and first/last-seen timestamps.
- Backfill directory from stored worktree path, otherwise FK-joined persisted
  project path. Backfill current branch from a non-empty legacy `branch_name`,
  but do not invent a repository binding or seed unverified history.
- Extend `SessionRepository` to persist exact directories from successful root
  session lists and live root `session.created`; remove the touched bulk-list
  persistence responsibility from `SessionPersistenceService` rather than
  extending its direct DAO bypass. A changed exact directory clears the prior
  current branch and Git common directory in the same transaction until branch
  observation verifies the new location, then emits one typed change after commit.
- Extend `SessionMutationDispatcher` with the ordered live-root persistence
  operation; call it before unseen handling for `SesoriSessionCreated`.
- Add `GitCliApi` operations for named `HEAD`, git `HEAD` path, and Git common
  directory.
- Add a dumb `FilesystemApi` directory-watch operation.
- Add raw branch DAO/table queries, typed repository models,
  `SessionBranchRepository`, and `SessionBranchListener` in target layer paths.
- Watch the parent of normalized absolute git `HEAD`; group all mapped sessions
  by watch key and fan events out independently.
- Perform initial resolve, idempotent transition/return/detach persistence,
  dynamic enrollment/removal, retry failed setup, and full disposal.
- Expose broadcast `Stream<SessionBranchChanged>` for later independent
  consumers from both repository mutation owners; `Orchestrator` merges them
  into one downstream change path. Do not emit SSE below Orchestrator or call
  GitHub in this PR.
- Exclude currently archived rows from runtime observation until the irreversible
  stop marker lands in S02-W03.
- Establish `Orchestrator.compose` as the sole constructor/wiring owner for
  bridge APIs, repositories, services, trackers, listeners, and typed streams.
  Move existing layer construction out of `BridgeRuntime.create`; make
  `BridgeRuntime` receive/delegate to an already-composed orchestrator and own
  only run/debug/disposal lifecycle.

### Non-Goals

- Modifying legacy `branch_name` worktree-creation/cleanup semantics.
- GitHub queries, PR-cache changes, project presence, timers, or PR history
  mapping into `Session`.
- Terminal archive marker/snapshot behavior.
- Child-session branch tracking.
- Polling git or one watcher per session when targets are shared.
- Moving every existing legacy bridge file into target directories.
- Changing existing bridge behavior while relocating composition ownership;
  shared instances, debug-server identity, startup, restart, and teardown remain
  equivalent.

## 4. Audited Current Code and Assumptions

- `SessionTable` has schema v10 fields through `title`, with no generic exact
  directory/current branch/history.
- `SessionPersistenceService.persistSessionsForProject` inserts list rows via
  DAOs but drops `Session.directory`; it is a legacy Layer 3 -> Layer 1 bypass.
- `SessionUnseenRepository.ensureRootSessionActivity` can insert a bare root row
  from `session.created`; the orchestrator currently routes unseen only after
  enqueueing the event. The new ordered repository persistence becomes the
  authoritative directory writer before unseen timestamp updates.
- `GitCliApi.inspectWorktreeSafety` already executes
  `git rev-parse --abbrev-ref HEAD`; branch observation needs a detached-safe
  symbolic-ref operation and concrete `HEAD` path.
- `FilesystemApi` is a dumb `dart:io` wrapper but exposes no stream.
- All current session rows are roots; future child schema belongs to the paused
  parallel-plugin plan and requires later stale re-review.

## 5. Design and Ownership

### Expected files

Existing source paths likely changed:

- `bridge/app/lib/src/api/database/tables/session_table.dart`
- `bridge/app/lib/src/api/database/daos/session_dao.dart`
- `bridge/app/lib/src/api/database/database.dart`
- `bridge/app/lib/src/bridge/repositories/session_repository.dart`
- `bridge/app/lib/src/bridge/services/session_mutation_dispatcher.dart`
- `bridge/app/lib/src/bridge/services/session_persistence_service.dart`
- `bridge/app/lib/src/bridge/routing/get_sessions_handler.dart`
- `bridge/app/lib/src/bridge/orchestrator.dart`
- `bridge/app/lib/src/bridge/runtime/bridge_runtime.dart`
- `bridge/app/lib/src/bridge/api/git_cli_api.dart`
- `bridge/app/lib/src/bridge/api/filesystem_api.dart`

New target-layer paths:

- `bridge/app/lib/src/api/database/tables/session_branch_history_table.dart`
- `bridge/app/lib/src/api/database/daos/session_branch_dao.dart`
- `bridge/app/lib/src/repositories/session_branch_repository.dart`
- `bridge/app/lib/src/repositories/models/session_branch_models.dart`
- `bridge/app/lib/src/listeners/pr_monitor/session_branch_listener.dart`
- focused tests under matching `test/api`, `test/repositories`, and
  `test/listeners/pr_monitor` paths
- generated Drift/Freezed/schema/migration files produced by tools

Use current repository naming if the baseline already establishes an equivalent
target path; do not create duplicate tables/DAOs/models.

### Classes, layers, and collaborators

- `FilesystemApi.watchDirectory({required String path})` returns raw
  `Stream<FileSystemEvent>` and makes no retry/classification decision.
- `GitCliApi.resolveNamedHead` executes
  `git symbolic-ref --short -q HEAD`; exit 1/empty maps at the repository
  boundary to detached-null, while unexpected process failures throw.
- `GitCliApi.resolveGitHeadPath` executes
  `git rev-parse --git-path HEAD` in the stored session directory and returns
  the raw path. `SessionBranchRepository` resolves a relative result against
  that exact stored directory before absolute normalization; it never resolves
  against the bridge process working directory.
- `GitCliApi.resolveGitCommonDirectory` executes
  `git rev-parse --git-common-dir` and returns the raw path. The repository uses
  the same directory-relative normalization; main and linked-worktree sessions
  share one value, while unrelated checkouts do not.
- `SessionBranchDao` exposes raw Drift watch/read/write operations with required
  owner/session/project inputs. Selection and branch semantics stay out of DAO.
- `SessionBranchRepository` receives the DAOs, `GitCliApi`, and
  `FilesystemApi`; no service/handler is constructed inside it.
- `SessionRepository` is the sole exact-directory writer and owns only the
  derived current-branch/Git-common-directory -> null invalidation when that
  directory changes. `SessionBranchRepository` owns only successful git
  verification to a non-null binding plus observed current/history writes.
  Neither repository calls the other.
- `SessionBranchListener` receives an already-built repository and its typed
  trackable-session stream. It owns subscription maps, retry timers, and
  teardown; it imports no DAO/API or raw `dart:io` event type.
- `SessionMutationDispatcher` continues to own ordered session mutations and
  delegates exact writes to `SessionRepository`; it does not construct or call
  the branch listener.
- `Orchestrator.compose` constructs all existing and new layered collaborators,
  injects one shared instance into every consumer/debug path, and wires typed
  streams. Its normal constructor/factory still creates `OrchestratorSession`.
- `BridgeRuntime` receives the fully composed `Orchestrator`, starts/stops its
  session, and delegates debug/disposal hooks exposed by that orchestrator. It
  imports/constructs no API, repository, service, tracker, listener, or mapper.
  The runner may call the one `Orchestrator.compose` factory but never assembles
  individual layers.

### Persistence and data flow

`session_branch_history` columns:

- `owner_identity TEXT NOT NULL`
- `session_id TEXT NOT NULL` FK/cascade
- `git_common_directory TEXT NOT NULL`
- `branch_name TEXT NOT NULL`
- `first_seen_at INTEGER NOT NULL`
- `last_seen_at INTEGER NOT NULL`
- primary key
  `(owner_identity, session_id, git_common_directory, branch_name)`

Repository enrollment records contain only required plain values: `sessionId`,
`projectId`, `directory`. Watch targets contain normalized absolute
`headPath`/`watchKey`; repository watch signals are `Stream<void>`, so the
listener never receives Layer 1 filesystem types. The nullable persisted Git
common directory is honest unverified state for migrated rows or failed git
resolution, not a fallback identity.

On each initial/event resolve:

1. Run detached-safe named-branch and Git-common-directory resolution in the
   exact stored directory.
2. Start a DB transaction and re-read the session.
3. No-op if missing or archived (later: terminally stopped).
4. Persist the normalized Git common directory on the session.
5. If named, upsert history under the freshly verified Git common directory,
   preserving first-seen and advancing last-seen only for that bound row.
6. Set `current_branch_name` to named/null.
7. Emit `SessionBranchChanged` when current branch or Git common directory
   changed; a same-branch duplicate or return that changes only `last_seen_at`
   emits no invalidation.

`SessionRepository` independently emits the same typed event exactly once after
its directory-change transaction commits clear-to-null current branch/binding.
The repository does not wait for branch re-resolution, so a failed subsequent
git command still invalidates prior PR association. `Orchestrator` merges that source with
`SessionBranchRepository.changes` into one typed stream; W02 wires that merged
stream once to SSE, and W04 adds viewed-project refresh fan-out to the same path.

### Concurrency, cancellation, lifecycle, and errors

- The session-table watch drives dynamic add/remove/update enrollment.
- Resolve `HEAD` target before subscribing; group normalized targets and create
  one lazy OS subscription when the first session joins.
- Fan one event to every currently mapped session. Serialize
  resolve-and-persist per watch key so event bursts cannot reorder transitions.
- Cancelling/remapping one session does not cancel a shared watch until its final
  mapped session leaves.
- A failed path/permission/watch setup logs with error/stack and schedules
  cancellable retry at 1s, 2s, 4s... with fresh +/-20% jitter capped at five
  minutes. Success resets retry state. Removal/archive/shutdown cancels retry.
- A watch stream error follows the same recovery; it is never silently treated
  as a stable branch and never invents another directory.
- Use `CompositeSubscription` when a class owns multiple long-lived streams.

## 6. Backward Compatibility

- The migration preserves `session_id`, project FK, plugin id, worktree path,
  legacy `branch_name`, archive, title, prompt defaults, and unseen timestamps.
- Existing branch/worktree cleanup keeps reading legacy `branch_name`.
- Existing rows receive a deterministic exact directory from only persisted
  location evidence; no hypothetical repair or unknown-id path inference.
- Existing archived rows retain last-known `current_branch_name` when available
  but get no history row because migration cannot verify their Git repository;
  they remain unobserved in this PR and fail closed for PR association.
- No shared wire field changes beyond already-merged S01.
- No compatibility-only runtime fallback is added; migration backfill is normal
  schema transition and does not require a `COMPATIBILITY` source marker.

## 7. Schema and Generated-Code Workflow

1. From `bridge/app`, run `dart run drift_dev make-migrations` before edits.
2. Inspect current `schemaVersion = N`; add exactly one `fromNToN+1` migration.
3. Modify source table/DAO/database registration.
4. Run `dart run drift_dev make-migrations` again.
5. Implement generated callback body only; do not hand-edit schema JSON or other
   generated sections.
6. From `bridge`, run `make codegen`.
7. Add structural and data-integrity tests from version N.

## 8. Verification

### Automated tests

- Migration structure and old-row data preservation, including dedicated and
  non-dedicated directory backfill, null migrated session Git common directory,
  last-known current branch, no unverified history seed, history-binding key,
  FK/cascade, and null legacy branch.
- Successful list persistence and live `session.created` persist exact
  directory before unseen updates; a changed directory clears stale current
  branch/Git common directory in the same transaction, emits one post-commit
  typed change even when re-resolution fails, and child events do not enroll.
- Normal initial branch, switch, duplicate event, branch return, detached HEAD,
  and detach -> named transitions.
- Moving one session from repository A to B preserves A-bound history rows and
  creates distinct B-bound rows; neither row is ever rekeyed to the other common
  directory.
- Main checkout and linked-worktree git `HEAD`/common-directory normalization;
  linked worktrees share the common-directory value while unrelated checkouts
  do not.
- Two unrelated normal checkouts that both return `.git/HEAD` resolve to
  distinct absolute watch keys and cannot share/fan out events.
- Two sessions sharing one checkout create one OS subscription and independent
  history rows.
- Mapping changes, archive/delete, final-session removal, stream error, missing
  path, permission error, retry cancellation/reset, and bridge shutdown.
- Composition regression proves `Orchestrator.compose` shares the same
  repository/service/tracker instances with request routing, listeners, SSE,
  and `DebugServer`; `BridgeRuntime` only starts/stops/delegates them and all
  prior restart/debug lifecycle tests remain green.
- A failed repository write emits no `SessionBranchChanged`; a common-directory
  change with the same branch emits one. Tests subscribe to the Orchestrator's
  merged path and prove one downstream event per committed clear or verification,
  with no duplicate for unchanged state.
- No periodic timer invokes git while a healthy filesystem stream exists.
- Existing unseen, session creation/list persistence, archive, worktree cleanup,
  and PR-sync tests remain green.

### Manual verification

No separate checkpoint; fake filesystem/git streams make lifecycle assertions
deterministic. Real end-to-end checking occurs at S03-W03-M01.

### Exact commands

```text
# workdir: bridge
dart pub get

# workdir: bridge/app — before source table edits
dart run drift_dev make-migrations

# workdir: bridge/app — after schemaVersion/table edits
dart run drift_dev make-migrations

# workdir: bridge
make codegen
make analyze
make test

# workdir: bridge/app
dart analyze --fatal-infos
dart test test/drift/default/migration_test.dart
```

### Regression guide

- Create/list events still persist roots and unseen timestamps correctly.
- Worktree create/archive/delete/restore still use legacy branch metadata.
- Missing filesystem access degrades/logs without crashing relay/plugin flow.
- No client-visible PR behavior changes yet; history remains empty until W02.
- Headless startup/shutdown owns and disposes all new watchers.
- Standalone/supervised runners still create one composed orchestrator; runtime
  owns lifecycle but never becomes a second layer composer.

## 9. Risks

- Atomic `HEAD` replacement can be missed by watching the file itself; watch its
  parent and filter/map through repository signals.
- A shared watch can be accidentally cancelled by one session; reference it by
  mapped-session set and cancel only when empty.
- List/live creation can race; use repository upsert semantics that preserve
  worktree/user/unseen fields while making exact directory authoritative.
- Migration may collide with a newly merged schema; move to current `N+1` and
  preserve all merged snapshots.

## 10. Acceptance Criteria

- Every persisted root has a non-null exact directory backed by real persisted
  evidence; a non-null Git common directory is written only from successful git
  resolution.
- Named current/history state follows filesystem-driven `HEAD` changes without
  periodic git polling.
- Shared checkout watcher count is one per normalized target.
- Detached, failure, retry, mapping, race, and shutdown behavior is tested.
- No GitHub call, timer-based PR refresh, SSE emission, or UI behavior lands.
- Directory clear and successful Git verification have explicit, disjoint
  repository transition ownership and converge on one typed Orchestrator path.
- `Orchestrator` is the sole layer composer and `BridgeRuntime` is lifecycle-only
  without changing existing startup/debug/restart behavior.

## 11. Definition of Done

- Migration and generated output are complete and reviewed.
- All exact commands pass.
- `aristotle-impl-review` approves the complete diff before PR opening.
- PR targets `main`; tracker records baseline/branch/URL/check state.
- W02 starts only after this PR merges.
