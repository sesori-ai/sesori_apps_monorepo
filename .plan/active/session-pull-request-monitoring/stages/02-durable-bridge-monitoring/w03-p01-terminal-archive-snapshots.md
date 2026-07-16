# S02-W03-P01: Add Terminal Archive Snapshots

## 0. Metadata

- **ID:** S02-W03-P01
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Worktree:** one dedicated worker worktree for this PR
- **Base branch:** `main`
- **Branch:** `plan/session-pull-request-monitoring/s02-w03-p01-terminal-archive-snapshots`
- **Wave baseline:** pin the assessed current `main` tip after S02-W02 merges
- **Audited reference:** `e766684e0fdc22256419b7b99691021c9f14732d`
- **Contract-affecting:** Yes — persisted schema and shipped archive/unarchive behavior

## 1. Goal and Cohesion

Make PR tracking terminal at archive while keeping archive responsive and PR
display immutable. This PR is cohesive because the irreversible stop marker,
snapshot writer/read path, pre-cleanup branch freeze, and exactly-one final
refresh listener land atomically; no release can write terminal state without
being able to serve it.

## 2. Dependencies and Baseline

- S02-W02-P01 is merged; authored identity-scoped cache, dispatcher, branch
  scope, and live history are available.
- Fetch/assess/pin current `main`, including current schema and archive changes.
- Allocate exactly current `N+1`; do not rewrite W01/W02 migrations.
- Parallel-plugin Stage 2 remains paused.

## 3. Scope

### In Scope

- Export current schema; add irreversible `pr_tracking_stopped_at` and
  owner-scoped archived PR snapshot table.
- Migrate already-archived sessions to stopped state and snapshot only cache
  rows already verified against project cache login, canonical repository
  identity, verified project path, and a frozen history row whose own Git common
  directory matches session/project bindings; perform no network work.
- Add raw archive DAO/table, typed archive models, and
  `SessionArchiveRepository` as the sole terminal writer.
- Move touched archive/unarchive persistence from
  `SessionPersistenceService` into `SessionArchiveRepository`.
- Replace `routing/worktree_cleanup.dart` with standalone
  `WorktreeCleanupService`; inject it into `DeleteSessionHandler` and
  `SessionArchiveService`, and move safety-result mapping to the repository
  mapper directory.
- Move archive's missing-row initialization into `SessionRepository` and use a
  repository-backed worktree existence/restore seam; remove routing,
  `SessionPersistenceService`, direct DAO/API, and `dart:io` dependencies from
  `SessionArchiveService`.
- Before cleanup, ask `SessionBranchRepository` to synchronously resolve/persist
  the latest named/detached `HEAD`; log/degrade to last durable branch if local
  resolution fails.
- Archive transaction writes `archived_at`, stop marker, frozen current/history,
  and immediate verified display snapshot.
- Change terminal session enrichment to read immutable archive snapshots
  directly through raw DAO; no repository peer.
- Publish one typed final-refresh request after each newly committed archive.
- Add `ArchivePrRefreshListener`; extend `PrRefreshDispatcher` with
  archive-final target and `SessionArchiveRepository` dependency.
- Implement archive-scope-gated unknown-login/repository clearing, mismatched
  identity clear-before-query, same-identity query-failure retention, identity
  recheck before replacement, typed snapshot-cleared completion, and no retry/
  follow-up.
- Change runtime branch eligibility/recheck from reversible `archived_at` to
  irreversible `pr_tracking_stopped_at`.
- Preserve existing unarchive worktree restoration while never clearing stop
  state or switching terminal reads back to live cache.

### Non-Goals

- Retrying/persisting a pending final refresh, startup recovery, or later live
  cache mutation of archived snapshots.
- Waiting for `gh` in the archive response.
- Restarting PR monitoring on unarchive.
- Changing plugin archive notification best-effort semantics or cleanup conflict
  policy.
- Refactoring worktree creation/naming or unrelated delete behavior beyond
  replacing the shared cleanup call site with the same injected policy owner.
- Project-view timers/client behavior.
- Network refresh for sessions archived before this migration.

## 4. Audited Current Code and Assumptions

- `SessionArchiveService` performs cleanup, verifies plugin session, writes
  reversible archive state through `SessionPersistenceService`, then notifies
  plugin asynchronously.
- It currently imports `routing/worktree_cleanup.dart`, calls
  `Directory.existsSync`, and initializes a missing session through the
  DAO-backed `SessionPersistenceService`. Because this wave restructures the
  archive flow, all three upward/data-access violations must be removed here.
- Existing archive tests prove dirty cleanup rejection, force behavior,
  worktree restoration, non-awaited plugin notification, and PR enrichment from
  mutable global cache.
- W01 branch transaction can re-read a session and W02 dispatcher can target
  all-state authored data; this wave adds terminal guards/target only.
- Existing archived rows could only carry old unverified cache data until W02's
  first authored verification. Migration must never guess author or resolve
  archived filesystem paths.

## 5. Design and Ownership

### Expected files

Existing paths likely changed:

- `bridge/app/lib/src/api/database/tables/session_table.dart`
- `bridge/app/lib/src/api/database/database.dart`
- `bridge/app/lib/src/bridge/services/session_archive_service.dart`
- `bridge/app/lib/src/bridge/services/session_persistence_service.dart`
- `bridge/app/lib/src/bridge/routing/delete_session_handler.dart`
- `bridge/app/lib/src/bridge/routing/request_router.dart`
- delete `bridge/app/lib/src/bridge/routing/worktree_cleanup.dart`
- `bridge/app/lib/src/bridge/repositories/session_repository.dart`
- `bridge/app/lib/src/bridge/repositories/worktree_repository.dart`
- `bridge/app/lib/src/bridge/orchestrator.dart`
- S02 target `session_branch_repository.dart`, `pr_refresh_dispatcher.dart`, and
  refresh/archive model files
- archive routing/integration tests

New target paths:

- `bridge/app/lib/src/api/database/tables/archived_session_pull_requests_table.dart`
- `bridge/app/lib/src/api/database/daos/session_archive_dao.dart`
- `bridge/app/lib/src/repositories/session_archive_repository.dart`
- `bridge/app/lib/src/repositories/models/session_archive_models.dart`
- `bridge/app/lib/src/repositories/mappers/worktree_cleanup_mapper.dart`
- `bridge/app/lib/src/services/worktree_cleanup_service.dart`
- `bridge/app/lib/src/listeners/pr_monitor/archive_pr_refresh_listener.dart`
- focused repository/listener/migration tests
- generated schema/Drift/Freezed outputs

### Persistence

`sessions_table.pr_tracking_stopped_at INTEGER NULL` is written once and never
cleared. `archived_session_pull_requests` key is
`(owner_identity, session_id, pr_number)` with:

- non-null owner, session FK/cascade, verified GitHub author login and canonical
  repository identity;
- branch, URL, title, typed state/mergeability/review/check fields;
- original cache creation/check timestamps; and
- non-null `snapshot_at`.

`SessionArchiveRepository` receives raw DAOs/database and owns:

- `archiveAndSnapshot` transaction;
- `unarchiveWithoutRestart` (clears only `archived_at`);
- `validateFinalScope` for a read-only preflight;
- `clearSnapshotIfScopeMatches` returning changed/unchanged/scope-changed;
- `replaceSnapshotIfStillStopped` with expected active login/repository and the
  same immutable archive scope; and
- immutable snapshot reads only if kept there for focused archive operations.

`ArchivePrScopeSnapshot` contains expected owner/session/project ids, persisted
project path, resolved project Git common directory, frozen session Git common
directory, and frozen per-row common-directory/branch identities. Both clear and
replace methods re-read and compare that full scope plus terminal stop inside
their own mutation transaction; a stale final request cannot mutate a snapshot.

`SessionRepository` receives `SessionArchiveDao` directly for terminal mapping.
It also owns `getOrInitializeStoredSessionForArchive`, which reads the existing
row or uses its already-owned plugin/DAO sources to resolve and insert the
missing root with the exact directory rules established in W01. The service
passes `createdAt`; the repository returns a typed stored row or not-found and
never delegates to `SessionPersistenceService`.

`WorktreeRepository` adds repository-backed `worktreeDirectoryExists` and the
existing resolve/restore operations needed by unarchive, using injected
`FilesystemApi`/`GitCliApi`. `SessionArchiveService` never imports `dart:io`.

`WorktreeCleanupService` receives `SessionRepository` and
`WorktreeRepository`. It owns the existing shared-session check, worktree safety
decision, forced removal/branch deletion sequencing, and typed
success/rejection result. `DeleteSessionHandler` and `SessionArchiveService`
receive the same already-built instance. The pure safety-issue -> shared cleanup
issue conversion moves to `repositories/mappers/worktree_cleanup_mapper.dart`.

The final `SessionArchiveService` constructor contains exactly these
collaborators:

- `SessionRepository` for row initialization/session/plugin operations;
- `SessionBranchRepository` for the final local branch resolve;
- `SessionArchiveRepository` for archive/unarchive/snapshot writes;
- `WorktreeRepository` for existence/base/restore operations; and
- `WorktreeCleanupService` for shared cleanup policy; and
- required `Clock` for deterministic archive timestamps.

It has no `WorktreeService`, `SessionPersistenceService`, routing, DAO, API, or
`dart:io` dependency. The cleanup service does not depend back on the archive
service, so the single allowed Layer-3 coordination edge is acyclic.

### Synchronous archive sequence

1. Load or initialize the stored row through `SessionRepository` and determine
   whether the transition is new.
2. Attempt latest branch resolve/persist before cleanup. On local error, log once
   and continue using last durable branch.
3. Run existing cleanup checks/removal. A conflict prevents archive transaction
   and final request.
4. Verify session existence under existing product behavior.
5. In one repository transaction, re-read session, set `archived_at` and stop
   marker if not already stopped, freeze current/history, and replace immediate
   snapshot with only rows whose author/repository equal non-null project cache
   login/repository, whose verified cache path equals the current project path,
   and whose history row's own Git common directory equals frozen session and
   project cache bindings.
6. Return session enriched from terminal snapshot.
7. Notify plugin best-effort and publish final request only for a newly committed
   archive transition.

### Final async sequence

The typed request carries owner, session/project ids, persisted project path,
frozen session Git common directory and frozen history tuples retaining each
row's Git-common-directory/branch identity, snapshot login, and snapshot
repository identity.
`ArchivePrRefreshListener` delegates once to dispatcher and logs a surfaced
failure once.

Dispatcher behavior:

- Resolve the project path's normalized Git common directory first. If it is
  unavailable or differs from the frozen session binding, retain the immutable
  snapshot, return typed `scopeUnavailable`/`scopeChanged`, and stop.
- Call `SessionArchiveRepository.validateFinalScope`. If persisted project path,
  terminal session binding/state, or frozen per-row scope differs, retain the
  snapshot, return `scopeChanged`, and stop.
- Resolve active login and canonical repository identity. If either is unknown,
  call `clearSnapshotIfScopeMatches`; emit `snapshotCleared` only when that
  transaction revalidates the same scope and mutates. A concurrent scope change
  returns `scopeChanged` and retains the snapshot.
- If snapshot login/repository is non-null and either differs, call the same
  scope-gated clear and publish `snapshotCleared` before any PR query only when
  it mutates; stop without querying if the transaction reports scope change.
  Otherwise continue the same one attempt for the new identity.
- Null snapshot identity may establish the freshly resolved active
  account/repository.
- Query all authored state only for frozen history rows whose own binding equals
  the frozen session/project common directory, using W02's bound/truncation
  contract. A truncated archive-final result returns before any post-query live-
  cache or terminal writer call, performs no upsert/replace or truncation-caused
  clear, and retains the same-identity immediate snapshot unchanged. Any earlier
  scope-gated clear required by an identity mismatch remains authoritative.
- Recheck login, repository, project path, and Git common directory immediately
  before replacement. Identity/binding change returns `identityChanged` and
  ends; archive origin never follows up.
- Call `SessionArchiveRepository.replaceSnapshotIfStillStopped` with all captured
  expectations. In the snapshot-replacement transaction it re-reads the session
  and project, requires terminal stop, expected session/project ids, unchanged
  project path, unchanged frozen session Git common directory, equality of
  expected project/session common directories, and exact frozen per-row scope
  before replacing. Any mismatch returns typed `scopeChanged` with zero snapshot
  writes.
- Complete all-state success atomically replaces the full snapshot and publishes
  rendered change when content differs.
- A PR query failure retains snapshot only when login/repository were freshly
  confirmed equal in this job. No retry exists.

### Concurrency, lifecycle, and races

- Branch resolve transaction and archive transaction serialize through DB. An
  in-flight branch callback either commits before archive freezes it or re-reads
  non-null stop state and no-ops afterward.
- Final listener is constructed at composition and subscribed before archive
  requests can publish; teardown cancels its one subscription.
- `Orchestrator` constructs the repositories, cleanup/archive services, final
  listener, and shared instances. `BridgeRuntime` receives the already-composed
  orchestrator and performs lifecycle only.
- Archive-final requests never coalesce into live requests or disappear behind
  open work; dispatcher serializes by project while retaining final target.
- Re-archiving an already stopped session emits no second final request.
- Later live project refreshes cannot write archive table.

## 6. Backward Compatibility

- Existing archived sessions get terminal stop state at migration and only
  already verified cache rows; no surprise network traffic.
- Existing unarchive remains user-visible and restores worktrees as before, but
  PR state intentionally remains terminal. This is an approved shipped-behavior
  extension, not a silent compatibility fallback.
- Old clients continue reading `pullRequest`; new clients can read history.
- Snapshot login/repository null exists only where no honest verified legacy
  author/source can be inferred. It is normalized to empty terminal display and
  resolved only by the one final job for newly archived sessions.
- No compatibility repair is added for rows no released producer could write.
- The persisted stop marker and snapshot schema are retained until an explicit
  future cleanup/migration; no temporary compatibility marker is required.

## 7. Schema and Generated-Code Workflow

1. Export current schema before source edits.
2. Allocate current `N+1` and add stop/snapshot source definitions.
3. Generate migrations; implement predecessor -> new callback only.
4. Backfill stop from existing non-null archive timestamp.
5. Snapshot only author/repository/path/Git-common-directory-verified rows
   matching project cache metadata; leave other archived snapshots empty.
6. Generate code and add structural/data/FK/cascade tests.
7. Preserve W01/W02 schema snapshots and migration callbacks unchanged.

## 8. Verification

### Automated tests

- Migration structure, already-active vs already-archived stop backfill,
  verified/mismatched/null cache snapshot, FK/cascade, data preservation.
- Archive latest named branch and detached branch before cleanup; local branch
  failure logs/degrades without blocking archive.
- Cleanup conflict prevents transaction/final request; force semantics remain.
- Delete and archive use one `WorktreeCleanupService` instance with identical
  shared-worktree/safety/force behavior; neither imports routing cleanup code.
- Missing-row archive initialization writes through `SessionRepository` with an
  exact persisted directory; not-found/initialization errors remain typed.
- Unarchive existence/base/restore checks use `WorktreeRepository`; no service
  performs direct filesystem or DAO access.
- Archive response completes while `gh` never completes and while plugin notify
  never completes.
- Immediate snapshot includes only same-login/repository/path/common-directory
  verified rows and terminal reads never consult live global cache.
- One final success replaces snapshot; one query failure retains only after
  same-login/repository/common-directory confirmation; unknown identity or
  identity mismatch clears only through a transaction that revalidates the full
  archive scope; scope mismatch/unavailability retains; successful clearing
  emits independent invalidation.
- Null snapshot login/repository can establish active identity.
- Identity change before replacement writes nothing and receives no follow-up.
- Project path/common-directory or frozen session-binding change before the
  clear or replacement transaction returns `scopeChanged` and writes nothing.
- A frozen A-bound history row never enters a B-bound final replacement even if
  its branch name is identical.
- Under unchanged identity, truncated archive-final all-state invokes no post-
  query live-cache/snapshot writer and leaves the immediate snapshot byte-for-
  byte unchanged; a prior scope-gated identity-mismatch clear is not reversed.
- Re-archive produces no second final request; archive listener never retries.
- Branch callback vs archive transaction both orderings; no branch write/change
  after stop marker.
- Unarchive clears `archived_at`, restores existing behavior, retains stop and
  immutable snapshot, and never re-enrolls watcher/poller.
- Later another-session live cache changes cannot mutate archived output.
- Plugin archive notification remains best-effort and observable on failure.

### Manual verification

Deferred to S03-W03-M01.

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
dart test test/bridge/routing/update_session_archive_status_handler_test.dart
```

### Regression guide

- Dirty/shared worktree cleanup conflicts still block archive.
- Force, delete-worktree/delete-branch, restore base, plugin notify, and unseen
  archive update behavior remain.
- Delete-session cleanup behavior remains unchanged after the routing free
  function is removed.
- Archive response never waits on GitHub/plugin notification.
- Existing already-archived rows do not produce network calls.
- Delete cascades terminal snapshots and branch history.
- Headless bridge owns listener lifecycle; no desktop dependency appears.

## 9. Risks

- Irreversible marker without immutable read path would corrupt behavior; land
  writer/read/listener together and test migration atomicity.
- Clearing a stale account then failing query could leave clients stale; scope-
  gate the clear transaction and publish `snapshotCleared` immediately through
  dispatcher completion/orchestrator only after an actual mutation.
- A branch callback can race destructive cleanup; resolve before cleanup and
  recheck stop inside every branch transaction.
- Truncated all-state is not a full final snapshot; preserve safe immediate state
  with zero post-query writer calls and report failure rather than freezing or
  upserting an incomplete terminal replacement.
- Retaining the routing cleanup import/direct `dart:io`/legacy persistence seam
  would preserve a touched layer cycle; remove all three in this wave and test
  the final constructor boundary.

## 10. Acceptance Criteria

- Archive is responsive, terminal for PR tracking, and immutable afterward.
- Exactly one final attempt occurs for a new archive and zero for migrated old
  archives/re-archive/unarchive.
- Unknown/mismatched identity or Git common directory cannot leave cross-account
  or cross-repository terminal display.
- Unknown/mismatched identity clears only while the full frozen archive scope
  still matches; unavailable/moved scope retains the immutable snapshot.
- Final clear and replacement transactions each revalidate terminal state,
  project path, expected project common directory, frozen session common
  directory, and per-row scope.
- Same-login query failure retention and clear-before-failure invalidation are
  independently proven.
- Branch writes cannot commit after stop state.
- Existing cleanup/unarchive product flows remain available.
- `SessionArchiveService` has the declared repository/collaborator constructor,
  no upward/data-access bypass, and delete/archive share one cleanup policy.

## 11. Definition of Done

- Migration/codegen/tests/fatal analysis/regressions complete.
- `aristotle-impl-review` approves before PR opening.
- PR targets `main`; tracker records baseline/branch/URL/check state.
- S02-W04 starts only after merge.
