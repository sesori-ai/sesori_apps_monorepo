# S02-W02-P01: Add Authored Identity-Scoped PR Refresh

## 0. Metadata

- **ID:** S02-W02-P01
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Worktree:** one dedicated worker worktree for this PR
- **Base branch:** `main`
- **Branch:** `plan/session-pull-request-monitoring/s02-w02-p01-authored-pr-refresh`
- **Wave baseline:** pin the assessed current `main` tip after S02-W01 merges
- **Audited reference:** `e766684e0fdc22256419b7b99691021c9f14732d`
- **Contract-affecting:** Yes — persisted cache identity and shipped request behavior

## 1. Goal and Cohesion

Replace `PrSyncService`'s request-era discovery internals with one authored,
GitHub-account-safe refresh dispatcher and serve current/history from durable
branch associations. The PR is independently cohesive because it completes the
live request-triggered path—source commands, identity-scoped migration,
repository writers/mappers, dispatcher queue, session enrichment, and SSE—while
deliberately leaving archive snapshots and viewed-project timers for later waves.

## 2. Dependencies and Baseline

- S02-W01-P01 is merged; exact directory/current/history data and
  `SessionBranchChanged` stream exist.
- Fetch `main`, assess all planned paths plus schema drift, and pin the exact
  S02/W02 baseline before branching.
- Read the current schema; allocate exactly `N+1` without rewriting W01.
- Parallel-plugin Stage 2 remains paused.

## 3. Scope

### In Scope

- Export current schema; add owner/login/repository scope to global PR cache and
  project cache metadata, including the project path and normalized Git common
  directory at verification time.
- Add active-login and canonical `nameWithOwner` repository resolution,
  creation-descending open/all authored query modes, 1,001-row truncation
  detection, PR author parsing, exact timeouts, and author-aware single-PR lookup to
  `GhCliApi`/`GhPullRequest`.
- Keep `--author @me` on list commands only; verify `gh pr view` author after
  parsing.
- Evolve `PrSourceRepository` to own cached GitHub-remote eligibility and return
  typed availability/login/query outcomes without writing durable state.
- Make `PullRequestRepository` the sole writer/finalizer of global live PR rows
  and project cache visibility/login/repository/path/Git-common-directory
  metadata.
- Add typed refresh request/result/completion models and
  `PrRefreshDispatcher` in target Layer 3.
- Implement per-project serialization, safe coalescing, complete/truncated
  semantics, all-state replacement, open reconciliation, disappeared-open
  finalization with bounded command fan-out, login/repository capture/recheck,
  cache suspension, request correlation, and change-only completions.
- Route both `GetSessionsHandler` request modes through the dispatcher. Awaited
  all-state retains the five-second budget; non-wait remains fire-and-forget.
- If any project cache login/repository/path/Git-common-directory metadata is
  null or mismatched, upgrade even an open request to all-state and resolve the
  complete repository-bound active branch scope first.
- On that first post-migration verification only, union active scope with
  durable branch-history rows from archived sessions that already carry the
  same non-null Git common directory; never resolve or guess archived paths.
- Remove `SessionRepository -> PullRequestRepository`; inject read-only branch,
  live-PR, and later-compatible archive DAOs/mappers directly.
- Map current headline and descending non-null history for live sessions, hiding
  null/mismatched author rows.
- Subscribe `Orchestrator` independently to branch-change and refresh-completion
  streams and emit `sessionsUpdated` only under their respective change rules.
- Keep request-driven refresh active; do not add project presence or timers.

### Non-Goals

- Terminal stop markers, archive snapshot tables, or final archive refresh.
- Project-view routing, scheduled polling, adaptive cadence, or client sends.
- GitHub comments/check-run detail/PR mutation.
- Full unbounded pagination beyond the supported 1,000 rows.
- Additional pagination to recover older same-repository rows displaced by more
  than 1,000 newer authored fork-head rows; truncation remains explicit and
  non-destructive.
- Deleting `PrSyncService` source in this wave if a thin compatibility facade is
  still needed by existing wiring/tests; dead internals are removed in S03-W02.
- Reusing GitHub login as Sesori owner identity.

## 4. Audited Current Code and Assumptions

- Current `GhCliApi` has `gh --version`, plain auth status, open list limited to
  100, and single view. It does not parse author.
- `PrSyncService` currently owns capability/remote caches, 30-second debounce,
  active-project suppression, matching, writes, and completion events.
- `PullRequestsTable` key is `(project_id, pr_number)` and has no author/owner.
- `PullRequestDao.getPrsBySessionIds` joins one legacy session branch; W01's
  branch history is now the correct association source.
- `SessionRepository` depends on peer `PullRequestRepository` and prefers open
  state over a higher PR number; both violate the locked final architecture.
- `GetSessionsHandler` triggers both wait modes and already handles timeout by
  returning current data while later SSE supplies freshness.
- The GitHub CLI manual confirms `--state all`, `--author @me`, finite `--limit`,
  advanced `--search` syntax, and required JSON fields; a live command check
  confirms `sort:created-desc` produces creation-descending results.

## 5. Design and Ownership

### Expected files

Existing paths likely changed:

- `bridge/app/lib/src/bridge/api/gh_cli_api.dart`
- `bridge/app/lib/src/bridge/api/gh_pull_request.dart`
- `bridge/app/lib/src/bridge/repositories/pr_source_repository.dart`
- `bridge/app/lib/src/bridge/repositories/pull_request_repository.dart`
- `bridge/app/lib/src/bridge/repositories/session_repository.dart`
- `bridge/app/lib/src/bridge/api/database/tables/pull_requests_table.dart`
- `bridge/app/lib/src/bridge/api/database/daos/pull_request_dao.dart`
- `bridge/app/lib/src/bridge/persistence/tables/projects_table.dart`
- `bridge/app/lib/src/bridge/persistence/daos/projects_dao.dart`
- `bridge/app/lib/src/bridge/persistence/database.dart`
- `bridge/app/lib/src/bridge/routing/get_sessions_handler.dart`
- `bridge/app/lib/src/bridge/routing/request_router.dart`
- `bridge/app/lib/src/bridge/services/pr_sync_service.dart` (thin transition or removal if no caller remains)
- `bridge/app/lib/src/bridge/orchestrator.dart`

New target paths:

- `bridge/app/lib/src/services/pr_refresh_dispatcher.dart`
- `bridge/app/lib/src/repositories/models/pr_refresh_models.dart`
- `bridge/app/lib/src/repositories/mappers/pr_cache_mapper.dart` if mapping is
  not already owned by `pull_request_mapper.dart`
- focused API/repository/service/integration tests
- generated Drift/Freezed/schema/migration outputs

Do not add `*Like` interfaces; Dart fakes implement concrete classes.
`Orchestrator.compose` constructs and shares every source/repository/dispatcher
instance introduced here. `BridgeRuntime` remains the lifecycle-only consumer
established in W01 and is not a second wiring site.

### Exact API commands

```text
gh --version
gh api user --hostname github.com --jq .login
gh repo view --json nameWithOwner --jq .nameWithOwner
gh pr list --state open --author @me --search sort:created-desc --json number,url,title,state,headRefName,isCrossRepository,mergeable,reviewDecision,statusCheckRollup,author --limit 1001
gh pr list --state all --author @me --search sort:created-desc --json number,url,title,state,headRefName,isCrossRepository,mergeable,reviewDecision,statusCheckRollup,author --limit 1001
gh pr view <number> --json number,url,title,state,headRefName,isCrossRepository,mergeable,reviewDecision,statusCheckRollup,author
```

- Login/repository/view timeout: 15 seconds.
- List timeout: 30 seconds.
- A non-zero exit, malformed login/JSON, missing author, or timeout throws from
  API; repository/dispatcher maps it to typed non-success rather than `[]`.
- `sort:created-desc` makes the finite window explicit. Exactly 1,001 list rows
  means truncated; expose the first/newest 1,000 plus the flag.
- The 1,001 bound applies before `isCrossRepository` rejection because `gh pr
  list` has no same-repository pre-limit filter.

### Persistence

`pull_requests_table` gains:

- `owner_identity TEXT NOT NULL`, backfilled `local`;
- `github_author_login TEXT NULL`, backfilled null;
- `github_repository_identity TEXT NULL`, canonical lowercase `owner/name`,
  backfilled null; and
- primary key `(owner_identity, project_id, pr_number)`.

`projects_table` gains nullable `pr_cache_github_login`,
`pr_cache_repository_identity`, `pr_cache_project_path`, and normalized
`pr_cache_git_common_directory`.

Live reads require row `owner_identity = local`; non-null row/project login and
repository identity with pairwise equality;
`projects.pr_cache_project_path = projects.path`; and the session's non-null
`git_common_directory = projects.pr_cache_git_common_directory`. Legacy or
unverified rows and sessions from a prior path/repository/account are retained
physically but hidden until verified replacement.

### Repository responsibilities

- `PrSourceRepository` returns active login, canonical lowercase GitHub
  repository identity, authored observations, truncation, and GitHub-remote
  eligibility. Its remote cache keeps the existing ten-minute TTL;
  capability/login/repository failures remain explicit.
- `PullRequestRepository` receives raw PR/project DAOs and owns transactionally
  suspending visibility (null project cache login), replacing/upserting rows,
  and project cache login/repository/path/Git-common-directory metadata. Complete
  all-state results may delete absent branch-matched rows; truncated results may
  not. It also receives raw session/branch DAOs so the cache-write transaction
  can re-read and compare the complete captured `PrBranchScopeSnapshot`; it does
  not call `SessionBranchRepository` or decide how to refresh after mismatch.
- `SessionRepository` receives raw read-only DAOs and pure mapper(s). Live
  association joins only history rows whose own Git common directory equals
  both the session's current non-null binding and project cache metadata and
  whose `branch_name` equals the PR row's `branch_name`, then chooses the
  highest-numbered PR on current branch as headline and every other associated
  PR descending as history. It never infers a historical row's repository from
  only the session's current location or associates by repository binding alone.
- No repository imports or calls another repository.

### Dispatcher and data flow

Typed requests identify:

- opaque request id;
- project id;
- mode `open` or `all` (archive-final lands W03);
- typed origin (`sessionRequest`, later listener origins); and
- whether the caller still owns one identity-change follow-up.

`PrBranchScopeSnapshot` is a typed Layer-2 value containing expected project id,
persisted project path, resolved project Git common directory, and the complete
ordered set of relevant session ids with each persisted directory/common-
directory/current state plus every history row's own common-directory/branch
identity. It includes unbound active rows so a newly added, moved, or
not-yet-verified session changes the snapshot instead of being silently omitted.
All-state first verification also includes already-bound archived-only history
rows under its existing rule.

`dispatch` returns a ticket containing that request id and a future result.
Broadcast execution completions contain an execution id plus all satisfied
request ids/origins after coalescing, so Orchestrator emits once per execution
and later listeners can ignore unrelated results.

Dispatcher flow:

1. Serialize requests by project. Let an active/queued all-state request satisfy
   compatible live open waiters; never let an open request discard queued all.
2. Read persisted live project path and repository-bound branch scope from
   `SessionBranchRepository`. Before all-state, synchronously resolve/persist
   every active session branch/common-directory value, resolve the project
   path's common directory, and include only sessions with the same non-null
   binding so listener enrollment races cannot commit an incomplete baseline.
3. Resolve eligibility, canonical repository identity, and active login through
   `PrSourceRepository`.
4. Compare current path/Git-common-directory/repository/login with project cache
   metadata. If any value cannot be verified or changed, atomically suspend
   cache visibility before continuing/returning and publish rendered change if
   previously visible. Rows remain physically retained. Path/common-directory
   mismatch is already hidden by the read predicate before preflight runs.
5. Execute open/all query. Reject cross-repository and any row whose
   `author.login` differs from captured login.
6. Match a PR only when both its head-ref/`branch_name` equals a history row's
   `branch_name` and that row's binding equals captured project/session bindings.
   For first null-cache-login verification, include only already-bound archived-
   only persisted history.
7. For a complete open result with exactly one absent cached open row, finalize
   it through author-verified `gh pr view`. If more than one is absent, upgrade
   the same serialized execution to one all-state list instead of issuing
   unbounded per-row commands. For truncated results, absence proves nothing.
8. Re-resolve active login, repository identity, and project path Git common
   directory immediately before the write transaction. If any differs or cannot
   be confirmed, suspend visibility, discard observations, and return typed
   `identityChanged`/failure.
9. Call `PullRequestRepository.applyRefresh` with the captured scope. Inside the
   same transaction that would mutate cache rows/metadata, re-read project path
   plus the complete active and eligible archived session/common-directory/
   current state and each history row's bound common-directory/branch identity;
   require exact equality. On mismatch, write nothing
   and return typed `scopeChanged`; the dispatcher discards observations and
   never retries autonomously. Origin/listener behavior remains governed by its
   existing request eligibility and later typed branch/location triggers.
10. Publish one broadcast execution completion with satisfied request
    ids/origins, effective mode, complete/truncated, authored-open count, and
    rendered-change flag.

The dispatcher never queues an identity follow-up. `GetSessionsHandler` may
recheck that its request is still live and issue at most one all-state follow-up.

### Request behavior

- `waitForPrData: true`: request all-state, await no more than existing five
  seconds, re-enrich already-fetched sessions on success, otherwise return
  current cached data and let later completion SSE refresh clients.
- `waitForPrData: false`: fire-and-forget open request. Null/mismatched project
  cache login/repository/path metadata upgrades it to all-state. Add the exact
  compatibility marker above this trigger because old clients rely on it after
  project presence ships.
- A timeout does not cancel the dispatcher process or lose its eventual write;
  it only releases the HTTP response budget.
- Cache-first reads intentionally do not run `gh` or git synchronously. A local
  account or remote change that has not yet been observed can remain visible
  until the next request/view trigger; a project-path change fails the persisted
  path/common-directory predicate immediately. Once observed, old visibility is
  suspended before any query/write and cannot reappear without fresh
  verification.

### Concurrency, cancellation, lifecycle, and errors

- Project queues are independent; one slow repository does not block another.
- Shutdown rejects new requests, lets owned process futures settle/cancel under
  existing process timeout, completes all waiters exactly once, and closes the
  completion stream.
- Failures surfaced as typed results are logged once by the recovering origin,
  not pre-logged by dispatcher. Unexpected catch-all recovery includes context
  and attached stack.
- Branch changes always publish their independent project invalidation even if
  the subsequent request is skipped, truncated, or fails.

## 6. Backward Compatibility

- Old clients/new bridge: both request modes still trigger dispatcher work.
  Non-wait trigger receives the source marker and exact cleanup condition from
  PLAN section 7.
- New clients/old bridge: not active until S03; the old request-driven path
  remains compatible.
- Existing `pullRequest` is populated from the new headline rule; history is
  additive and non-null from S01.
- Legacy cache rows are preserved but hidden because no released producer
  recorded verified author. The first complete authored all-state result
  verifies/replaces them; no speculative repair guesses an author.
- A first all-state verification includes archived-only durable branches so W03
  can snapshot genuine legacy associations without touching archived paths.
- Compatibility marker location: immediately above the non-wait dispatcher
  trigger in `GetSessionsHandler`; use implementation date/current declared
  version and cleanup text from PLAN section 7.

## 7. Schema and Generated-Code Workflow

1. Run pre-edit schema export from `bridge/app`.
2. Allocate current `N+1`; rebuild key/table as required by Drift while
   preserving all existing rows and FKs.
3. Backfill owner to `local`; row author/repository and project
   login/repository/path/Git-common-directory metadata to null.
4. Run migration generation and implement callback body only.
5. Run bridge-wide codegen.
6. Add structural/data tests for key, row preservation, hidden unverified rows,
   project cascade, and migration from immediate predecessor.

## 8. Verification

### Automated tests

- Exact command arguments including `--search sort:created-desc`, working
  directory, timeout, canonical repository identity, author JSON, login parsing,
  state mapping, malformed output, non-zero, and timeout.
- 1,000 rows complete; 1,001 rows truncated; truncated results expose first
  1,000 and never trigger absent-row deletion/finalization.
- Cross-repository rows are rejected after the cap; fixtures prove they can
  consume supported slots, truncation remains visible, and displaced older
  same-repository rows are not falsely deleted or claimed complete.
- Remote eligibility/capability caching and non-GitHub/missing-gh outcomes.
- Migration preserves cache rows, adds local owner key, nulls
  login/repository/path/Git-common-directory metadata, and keeps
  project/session/PR cascades valid.
- SessionRepository hides null/mismatched login, repository, project path, or
  history-row/session/project Git-common-directory rows and maps headline/history
  for current branch, previous branch, duplicate branch associations, detached
  current branch, and repository-bound archived-only first-verification scope.
- Two sessions/history rows in one Git common directory but on different branch
  names see only PR rows with their own names; repository equality alone never
  associates a PR.
- A stable project id moved from repository/path A to B cannot attach B's PR to
  an A-bound history row with the same branch name; moving a session preserves A
  rows under their original key while new B rows are distinct, and a linked-
  worktree history row whose common directory matches B remains eligible.
- Highest current-branch number wins regardless of state; history is descending
  and excludes headline.
- Complete all-state replacement, complete open upsert/finalization, truncated
  non-destructive behavior, query failure non-empty semantics, and rendered
  change detection.
- A branch, session directory/common-directory, enrollment, archive state, or
  project path mutation during the GitHub query makes the transactional scope
  comparison fail with zero PR/cache writes; unchanged scope commits once.
- One disappeared open row uses one author-verified view; two or more upgrade to
  one bounded all-state list with no per-row fan-out.
- Per-project serialization, stronger queued request preservation, compatible
  waiter coalescing, independent project concurrency, shutdown, and no overlap.
- Request ids/origins survive coalescing and each waiter completes once; one
  execution completion carries every satisfied id/origin.
- Login/repository/path/Git-common-directory changes and failures before query,
  during query, and before commit suspend prior visibility and emit change;
  retained rows cannot reappear without fresh matching verification. Handler
  follow-up is at most one; dispatcher follow-up is zero.
- Null/mismatched cache identity/path/common-directory open upgrade synchronously
  resolves active repository-bound branch scope.
- `waitForPrData` true keeps five-second budget and re-enriches on success;
  false fires and returns; both retain existing response behavior.
- Branch current change emits `sessionsUpdated` even with no PR cache change;
  cache completion emits only on rendered change.
- Unseen timestamps are unchanged by every refresh mode.

### Manual verification

Deferred to S03-W03-M01; API and identity races are deterministic with fake
process outputs here.

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
dart test test/bridge/api/gh_cli_api_test.dart
dart test test/bridge/routing/get_sessions_handler_test.dart
```

### Regression guide

- Non-GitHub, unavailable `gh`, or unauthenticated `gh` still returns sessions.
- A failure is not an authoritative empty PR result.
- Session list pagination/persistence, worktree metadata, archive behavior, and
  unseen enrichment remain unchanged.
- Explicit pull-to-refresh remains bounded; normal load remains non-blocking.
- Old clients still receive the correct one-field headline.
- Bridge stays plugin-agnostic and headless.

## 9. Risks

- Account switch can race every async gap; capture/recheck login and verify each
  author before transaction, suspending old visibility when detected.
- A stable project id can move to another path/repository; bind visible rows to
  canonical repository identity, verified project path/common directory, and
  only sessions carrying that same common-directory binding.
- Per-row finalization can monopolize the dispatcher; allow at most one
  `gh pr view`, then use one all-state list for larger disappearance sets.
- All-state query may exceed response budget; handler timeout must not cancel
  eventual dispatcher completion.
- Truncated results can falsely close/delete absent PRs; absence is never used
  when truncated.
- Same-layer dependencies can return through convenience calls; inject DAOs
  directly into each repository and repositories only into dispatcher.
- Migration key rebuild may lose rows/FKs; require old-row fixtures and foreign
  key validation.

## 10. Acceptance Criteria

- Every list query uses `--author @me --search sort:created-desc`; every accepted
  row/view matches captured active login and canonical same-repository identity.
- 1,001st row produces explicit non-destructive truncation.
- Live sessions render verified current/history under locked ordering.
- No `SessionRepository -> PullRequestRepository` dependency remains.
- Requests serialize/coalesce without dropping all-state work or looping on
  identity change; completions preserve request/origin correlation.
- Every cache mutation transaction revalidates the complete captured session
  branch/binding scope and fails closed on any concurrent scope change.
- Detected account/repository/path/Git-common-directory changes suspend old
  cache visibility before any new query result can be rendered, and old-session
  branches cannot match a moved project's new repository.
- Both shipped request paths and five-second wait behavior remain.
- Branch and PR invalidations are independent and unseen-neutral.

## 11. Definition of Done

- Migration, codegen, tests, fatal analysis, and regression pass are complete.
- Compatibility marker has exact date/version/scenario/cleanup.
- `aristotle-impl-review` approves before PR opening.
- PR targets `main`; tracker records baseline/branch/URL/check state.
- S02-W03 starts only after merge.
