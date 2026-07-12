# Session Pull Request Monitoring - Master Plan

> Living document. This file owns the product decisions, architecture,
> implementation sequence, current pointer, verification, risks, and findings
> for bridge-to-client pull request monitoring. It is unrelated to the
> `opencode-pr-monitor` development tool configured under `.opencode/`.
>
> Keep this plan accurate in every implementation PR. Git history is the source
> of truth when this file and merged work disagree.

## Current Pointer

- **Last completed step:** Step 0 - execution plan written and architecture-reviewed
- **Next up:** PR 1 - additive shared contracts
- **Runtime behavior:** existing request-driven `PrSyncService`; no new monitoring behavior has shipped
- **Planning branch:** `git-pr-monitor-upgrade`, synchronized with `main` through `a7923438`
- **Implementation branch rule:** one feature branch and one reviewable PR per unchecked row unless the user explicitly requests stacking

### Tracking Rule

Every implementation PR updates these surfaces in the same diff:

1. Move the **Current Pointer** to the completed PR and the next unchecked row.
2. Change that PR's status in the **PR Status Index** from `[ ]` to `[x]`.
3. Record shipped behavior and deviations in **Findings and Plan Deltas**.
4. Update the owning acceptance criteria, regression guide, decision, or risk if implementation evidence changed it.

Before starting the next PR:

1. Reconcile this plan against merged PRs on `main`.
2. Read prior findings and plan deltas.
3. Select the first unchecked status row whose prerequisites are complete.
4. Write the PR-level implementation plan and run `aristotle-plan-review`.
5. Implement only that row by default.
6. Run `aristotle-impl-review` before opening the PR.

## 1. Goal and Scope

Give a session a durable pull request timeline that follows the branches
actually visited at the session's directory:

- keep the latest pull request for the current branch prominent;
- retain pull requests from previously visited branches as collapsed history;
- update GitHub state near real time while a phone is viewing the project;
- stop network work when no phone needs it;
- preserve branch history even while no phone is connected; and
- make session archive terminal for branch and pull request tracking, with one
  non-blocking best-effort final refresh.

The feature remains plugin-agnostic. Git and GitHub behavior belongs to the
bridge, below `BridgePluginApi`; no OpenCode, Codex, Cursor, or future backend
detail enters shared models or clients.

### Non-Goals

- GitHub review comments, individual check runs, labels, assignees, or commits.
- Background polling when no phone views the project.
- Push notifications for pull request changes.
- Treating pull request changes as session conversation unseen activity.
- Cross-host GitHub synchronization or auth outside the existing `gh` CLI.
- Restoring monitoring after a session has entered the terminal archive state.
- Changing or removing the existing unarchive product behavior.
- Offline client caching.
- Modifying the separate OpenCode `pr_monitor` agent tool.

## 2. Re-Audit Findings

The implementation was rechecked after fast-forwarding to `main` at
`0de55787`.

- `PrSyncService` is invoked by `GetSessionsHandler`, debounces refreshes for 30
  seconds, and has no scheduled background poller.
- `GhCliApi.listOpenPrs` invokes `gh pr list --state open --limit 100` without
  `--author @me`; a request may wait up to the handler's five-second PR-data
  budget.
- Pull requests are cached by `(projectId, prNumber)`. Session attribution joins
  the pull request branch to the session row's single stored `branchName`.
- `branchName` is creation/worktree metadata. It does not follow live `HEAD`.
- `GitCliApi` already runs `git rev-parse --abbrev-ref HEAD` for worktree safety,
  but no component continuously observes a session directory.
- `FilesystemApi` is the existing Layer 1 host-filesystem boundary and can
  expose a dumb directory-watch stream.
- `SessionRepository` currently depends on peer `PullRequestRepository` for PR
  enrichment. Work in this plan removes that touched same-layer dependency.
- `SessionViewTracker`, `RelaySessionView`, `SessionViewingService`, and the
  lifecycle/reconnect tests provide a proven connection-scoped view pattern.
  They remain dedicated to session-seen semantics.
- There is no project-view signal. The bridge cannot currently tell which
  project's session list or detail is visible on a phone.
- `SessionUnseenService` and `SessionUnseenTracker` own conversation unseen
  state. Pull request status never enters their timestamp calculation.
- `SessionArchiveService` uses the legacy `SessionPersistenceService` for
  archive writes. The PR archive work replaces that touched dependency with a
  repository-owned transaction.
- `Session.pullRequest` carries one optional headline PR. There is no history
  field or collapsed history presentation.
- `SesoriSseEvent.sessionsUpdated(projectID)` already causes the client to
  re-fetch a project's session list and is sufficient for PR cache changes.
- The current Drift schema is version 10. The implementation must allocate the
  next version present on `main` when its migration starts because the parallel
  plugin work may land another schema migration first.

## 3. Locked Decisions

| # | Decision |
|---|---|
| 1 | Record every named branch observed at each non-terminal session's directory. |
| 2 | Persist each root session's exact reported directory. Existing rows backfill from their stored worktree path or owning project's persisted live path; a missing row/relation never infers location from an unknown session id. |
| 3 | Sessions sharing one checkout intentionally observe the same live branch and may associate the same pull requests. |
| 4 | Detached `HEAD` has no current branch and creates no history entry. Existing branch history remains intact. |
| 5 | Current PR is the highest-numbered associated PR on the current named branch, regardless of open, merged, or closed state. A branch with no PR has no headline. |
| 6 | History contains every other associated PR, newest PR number first. Branch history is internal association data, not a new branch-history UI. |
| 7 | GitHub discovery is restricted to same-repository PRs authored by the authenticated `gh` user via `--author @me`. |
| 8 | Local branch observation runs for every session whose PR tracking has not terminally stopped, independent of phone presence. |
| 9 | GitHub network polling runs only while at least one phone connection views that project's session list or a session detail inside it. |
| 10 | Project activation and a newly recorded branch trigger an all-state authored-PR backfill. Steady polling lists authored open PRs and finalizes previously known open PRs that disappear. |
| 11 | Poll at 15 seconds while the viewed repository has any open PR authored by `@me`, otherwise at 90 seconds. Failures use bounded backoff capped near five minutes. |
| 12 | Every persisted current-branch change invalidates the affected project's session list immediately, independent of GitHub cache changes. While viewed it also triggers an immediate refresh; while not viewed the next activation backfills it. |
| 13 | Session-list and session-detail screens both count as viewing the project. Any connected phone keeps the project active. |
| 14 | Archive synchronously resolves the latest local `HEAD`, returns after an immediate cached snapshot, and starts one asynchronous final attempt. That job resolves the then-active GitHub login, clears a cached snapshot bound to another login, and performs all-state reconciliation for the frozen branches. Success atomically replaces the snapshot; failure retains the same-login snapshot or the cleared empty state and never retries. |
| 15 | Archive permanently stops PR branch tracking. Unarchive clears the existing session archive state but never clears the PR stop marker or restarts PR polling. |
| 16 | PR changes reuse `sessionsUpdated` and never affect conversation unseen state. |
| 17 | New clients render cached session data immediately. The existing `waitForPrData` request remains supported as a one-shot compatibility path for shipped clients. |
| 18 | New PR-monitoring tables and the global PR cache carry `owner_identity = "local"` in their durable keys. Each live PR cache row also carries its verified GitHub author login and is readable only when it matches the project's active PR-cache login; GitHub identity is never inferred from Sesori ownership. |
| 19 | While a project remains continuously viewed, force an all-state authored reconciliation at least every ten minutes in addition to open-PR polling, so a PR opened and completed between polls eventually enters history without requiring navigation away and back. |

## 4. Release and Layer Invariants

Every merged PR must leave bridge and client releases viable.

1. **Plugin boundary stays clean.** Branch and GitHub logic never enters a
   plugin implementation or the plugin interface.
2. **Headless bridge stays first-class.** Monitoring needs no desktop control
   channel, GUI process, or Flutter runtime.
3. **Layer direction remains downward.** APIs and DAOs are Layer 1,
   repositories are Layer 2, business decisions are Layer 3, handlers/cubits
   are Layer 4, and only composition roots wire peers.
4. **No repository peers.** `SessionRepository` reads PR/branch DAOs directly
   for enrichment. It does not depend on `PullRequestRepository`,
   `SessionBranchRepository`, or `SessionArchiveRepository`.
5. **One runtime writer per durable concern.** `SessionBranchRepository` writes
   active branch state; `PullRequestRepository` writes the global PR cache;
   `SessionArchiveRepository` writes terminal archive fields and archived PR
   snapshots. A schema migration may seed those tables once before their
   runtime writer exists.
6. **Symmetric triggers.** View activation, scheduled polling, branch changes,
   and archive-final refreshes are separate Listener classes that all delegate
   to `PrRefreshDispatcher`.
7. **Streams, not peer references.** Listeners receive typed streams from the
   composition root. They do not depend on tracker/listener/service instances
   from the same layer.
8. **Polling is bounded to a source without a stream.** GitHub's CLI has no push
   stream; one-shot timers are cancelled with view presence and never overlap.
   Local branch changes use filesystem events instead of periodic Git polling.
9. **Archive remains usable if GitHub is unavailable.** No archive response
   waits for `gh`, network, authentication, or a final PR status.
10. **Shared changes are additive.** Old payloads decode on new clients and old
    clients ignore new fields.
11. **Generated files are generated.** Never hand-edit Freezed, JSON, Drift, or
    DI generated outputs.

## 5. Architecture

### 5.1 Components

| Component | Layer / target directory | Responsibility |
|---|---|---|
| `GitCliApi` additions | Layer 1, existing `bridge/app/lib/src/bridge/api/` | Resolve named `HEAD` and the concrete git `HEAD` path. |
| `FilesystemApi` addition | Layer 1, existing `bridge/app/lib/src/bridge/api/` | Expose raw directory filesystem events. No branch decisions. |
| `GhCliApi` additions | Layer 1, existing `bridge/app/lib/src/bridge/api/` | Resolve the active GitHub login; execute typed `gh pr list` open/all queries with `--author @me`; execute `gh pr view` by number without the list-only author flag; parse each PR author login. |
| branch/archive DAOs and tables | Layer 1, new `bridge/app/lib/src/api/database/` | Raw owner-scoped branch-history, stop-marker, and archived-snapshot persistence. |
| `SessionBranchRepository` | Layer 2, new `bridge/app/lib/src/repositories/` | Only new class that imports session/project DAOs, `GitCliApi`, and `FilesystemApi`; expose typed trackable-session/HEAD streams, resolve/persist active branch state from the stored exact session directory, and emit persisted branch changes. |
| `PrSourceRepository` | Layer 2, existing legacy path | Wrap `GhCliApi`/Git remote checks and return the active GitHub login, typed authored-PR observations, and GitHub-remote eligibility; never write another repository. |
| `PullRequestRepository` | Layer 2, existing legacy path | Sole writer/finalizer of the global pull request cache. |
| `SessionArchiveRepository` | Layer 2, new target directory | From PR 4 onward, atomically archive, stop PR tracking, snapshot only author-verified cached PRs, unarchive without restart, and replace a successful final snapshot. |
| `SessionRepository` changes | Layer 2, existing legacy path | Read PR/branch/archive DAOs and map current/history into shared sessions; never write PR state. |
| PR mappers/models | Layer 2, new target mapper/model directories | Typed API/DAO-to-domain/shared transformations and refresh request/results. |
| `SessionBranchListener` | Layer 4 consumer, new `bridge/app/lib/src/listeners/pr_monitor/` | Own one dynamic filesystem subscription per resolved git `HEAD` watch key, fan transitions out to every mapped session, and delegate resolution/persistence to `SessionBranchRepository`. |
| `ProjectViewTracker` | Layer 3 tracker, new target service directory | Maintain connection-to-project declarations and active project counts. |
| `PrRefreshDispatcher` | Layer 3 dispatcher, new target service directory | Single queued per-project GitHub reconciliation; read live project path/branch scope from `SessionBranchRepository`, check remote eligibility and fetch through `PrSourceRepository`, write global cache through `PullRequestRepository`, and write final archive snapshots through `SessionArchiveRepository`. |
| `ProjectViewPrRefreshListener` | Layer 4 consumer, new `bridge/app/lib/src/listeners/pr_monitor/` | Turn a project 0-to-1 viewed transition into an all-state refresh. No timer. |
| `ScheduledPrRefreshListener` | Layer 4 consumer, new `bridge/app/lib/src/listeners/pr_monitor/` | Own timers, 15/90-second cadence, backoff, cancellation, and scheduled open refreshes. |
| `PrBranchChangeListener` | Layer 4 consumer, new `bridge/app/lib/src/listeners/pr_monitor/` | Refresh a viewed project after branch transitions; persist-only when not viewed. |
| `ArchivePrRefreshListener` | Layer 4 consumer, new `bridge/app/lib/src/listeners/pr_monitor/` | Delegate one archive-final request; log failure and never retry. |
| `SessionMutationDispatcher` changes | Layer 3, existing legacy path | Persist live root session creation and exact directory through `SessionRepository` before unseen/branch consumers observe it. |
| `SessionArchiveService` changes | Layer 3, existing legacy path | Coordinate existing cleanup/plugin behavior with `SessionArchiveRepository`; emit final-refresh requests. |
| `Orchestrator` / runtime wiring | Layers 4/5, existing files | Route `RelayProjectView`, release connections, merge streams, and emit `sessionsUpdated`. |
| `ProjectViewApi` | Client Layer 1, `client/module_core/lib/src/api/` | Send the project-view control declaration through `ConnectionService`. |
| `ProjectViewRepository` | Client Layer 2 | Delegate project-view declarations to the API. |
| `ProjectViewingService` | Client Layer 3 | Own list/detail claims, lifecycle/reconnect behavior, send ordering, and stale-clear protection; depend on `ProjectViewRepository`, `LifecycleSource`, and an injected typed connection-state stream, never `ConnectionService`. |
| session list/detail cubits | Client Layer 4, existing files | Declare and clear project-view claims without depending on each other. |
| PR history presentation | Flutter shell, `client/app/lib/features/session_list/` | Keep the headline prominent and render history collapsed by default. |

Existing legacy files are modified in place. Every new bridge layer class goes
in the target top-level `api/`, `repositories/`, `services/`, or Layer 4
`listeners/` consumer directory so new imports make layer direction visible.

### 5.2 Branch Flow

```text
SessionBranchRepository typed trackable-session stream
  -> SessionBranchListener groups sessions by resolved git HEAD watch key
  -> one repository-backed OS subscription per watch key
  -> fan each event out to every mapped session
  -> SessionBranchRepository resolves symbolic HEAD through GitCliApi
  -> current branch + idempotent branch history transaction
  -> SessionBranchRepository emits Stream<SessionBranchChanged>
  -> Orchestrator emits sessionsUpdated for each persisted current change
  -> PrBranchChangeListener independently subscribes to the repository stream
     and dispatches refresh only when currently viewed
```

The listener never imports a DAO, `FilesystemApi`, or `GitCliApi`. It asks
`SessionBranchRepository` for typed trackable-session and HEAD-event streams,
then invokes the repository's resolve-and-persist operation. The repository's
filesystem source watches the parent directory containing the resolved git
`HEAD` file so atomic replacement is observed. The listener normalizes that
resolved watch key, owns only one OS subscription per unique key, and maintains
the set of sessions to update for each event. It performs an initial resolve
when a session enters the trackable set. A named branch return updates
`lastSeenAt` without duplicating the history row.

The orchestrator consumes the typed branch-change stream separately from PR
refresh completions and emits `sessionsUpdated` whenever
`current_branch_name` actually changes. A skipped/no-op GitHub refresh therefore
cannot leave a visible list on the old branch. Duplicate events and branch
returns that only update `lastSeenAt` do not invalidate the list.

`SessionBranchRepository.resolveAndPersist` performs its current/history write
in one transaction that re-reads the session row. Once PR 4 adds terminal state,
the transaction inserts/updates only while `pr_tracking_stopped_at IS NULL` and
emits no change otherwise. Database transaction serialization guarantees an
in-flight callback either commits before archive (so the archive transaction
freezes it) or observes the committed stop marker and becomes a no-op.

For live creation, the orchestrator first gives a root `SesoriSessionCreated` to
`SessionMutationDispatcher`, which persists identity/project/plugin/directory
through `SessionRepository`; it then routes the event to unseen tracking. The
session DAO stream can therefore enroll the exact directory before any later
branch event, without a phone request.

### 5.3 Presence Flow

```text
SessionListCubit / SessionDetailCubit
  -> ProjectViewingService
  -> ProjectViewRepository
  -> ProjectViewApi
  -> ConnectionService / RelayClient
  -> RelayProjectView(projectId?)
  -> Orchestrator
  -> ProjectViewTracker
  -> Stream<ProjectViewChange>
```

`ProjectViewingService` owns separate list and detail claims. Detail takes
precedence; clearing detail falls back to a still-mounted list claim. Paused or
hidden sends null while retaining intended claims. Resume and reconnect
reassert the current claim because project presence has no mark-seen side
effect, but reconnect reassertion is gated on the service's current foreground/
visible lifecycle state. A reconnect while paused/hidden keeps the claim dormant
until resume. The DI composition root injects a typed connection-state stream
derived from `ConnectionService`; the service does not import the transport
class. Sends are serialized through `ProjectViewRepository` and always read
current state at execution time.

### 5.4 GitHub Refresh Flow

```text
ProjectViewPrRefreshListener
ScheduledPrRefreshListener
PrBranchChangeListener
ArchivePrRefreshListener
legacy GetSessionsHandler wait request
  -> PrRefreshDispatcher
  -> SessionBranchRepository (live project path + branch scope reads)
  -> PrSourceRepository -> GhCliApi (GitHub fetch only)
  -> PullRequestRepository (global cache writes only)
  -> SessionArchiveRepository (archived-final snapshot writes only)
  -> Stream<PrRefreshCompletion>
  -> Orchestrator -> SesoriSseEvent.sessionsUpdated(projectID)
  -> SessionListCubit re-fetch
```

The dispatcher has required `SessionBranchRepository`, `PrSourceRepository`,
`PullRequestRepository`, and `SessionArchiveRepository` dependencies. For live
requests it reads the path and branch set from `SessionBranchRepository`; an
archived-final request carries its already-frozen path and branches.
`PrSourceRepository` owns the cached GitHub-remote eligibility check and returns
the active GitHub login with typed observations; it never writes another
repository. The dispatcher skips every `gh pr` command when that repository
reports an ineligible remote. Each request captures the active login, accepts
list/view results only for that author, and rechecks the active login before its
write transaction. An identity change discards the stale result and returns a
typed `identityChanged` completion; the dispatcher never autonomously queues a
follow-up. The originating request handler/listener may issue at most one
all-state follow-up after rechecking its own eligibility. View/scheduled/branch
listeners require the project to remain viewed, request handlers remain eligible
for their one request, and `ArchivePrRefreshListener` never follows up because
archive-final is exactly one attempt. The dispatcher serializes requests per
project. An all-state or archived-final request is never dropped behind an
in-flight open refresh. Compatible requests may coalesce, but every caller that
awaits a result receives the result of a refresh at least as strong as it
requested.

### 5.5 Client Read Flow

```text
POST /sessions
  -> SessionRepository reads plugin sessions + stored enrichment data
  -> current branch and associated PR rows
  -> current headline + history mapping
  -> Session.pullRequest + Session.pullRequestHistory
  -> SessionListCubit
  -> SessionTile / collapsed history
```

`SessionRepository` receives `PullRequestDao`, `SessionBranchDao`, and
`ArchivedSessionPullRequestDao` as read-only Layer 1 dependencies. Live sessions
read the global PR cache joined through durable branch history. Terminal
sessions read `archived_session_pull_requests` directly through its DAO, never
through `SessionArchiveRepository`, so no repository peer dependency is
introduced. Later refreshes for another session on the same branch therefore
cannot mutate archived presentation.

## 6. Persistence Design

PRs 2, 3, and 4 each allocate the next schema version present on `main` for
their own cohesive persistence change. They never rewrite or combine a migration
already merged by the parallel plugin work or an earlier PR in this plan.

### Session Fields

- `directory TEXT NOT NULL`: exact session working directory. Reuse the field if
  parallel-plugin work lands it first; otherwise PR 2 adds it and backfills from
  `worktree_path ?? owning projects_table.path` through the known FK relation.
- `current_branch_name TEXT NULL`: live named branch; null on detached HEAD or
  before the first successful observation.
- `pr_tracking_stopped_at INTEGER NULL`: terminal PR-monitoring stop marker.
  Unlike `archived_at`, this is never cleared by unarchive.

The existing `branch_name` remains worktree-creation and cleanup metadata. It is
not repurposed as live HEAD.

### Session Branch History

`session_branch_history`:

| Column | Meaning |
|---|---|
| `owner_identity` | durable owner, currently `local` |
| `session_id` | FK to session, cascade delete |
| `branch_name` | observed named branch |
| `first_seen_at` | first bridge observation |
| `last_seen_at` | latest return to the branch |

Primary key: `(owner_identity, session_id, branch_name)`.

### Global PR Cache Additions

The existing `pull_requests_table` gains:

- `owner_identity TEXT NOT NULL`, backfilled to `local` and included in the
  `(owner_identity, project_id, pr_number)` durable key; and
- `github_author_login TEXT NULL`, backfilled to null. Only a successful
  authored list/view observation writes a non-null login.

`projects_table` gains nullable `pr_cache_github_login`. A successful refresh
atomically writes this login with the corresponding cache replacement. Live
session enrichment includes only rows whose non-null `github_author_login`
equals the owning project's non-null `pr_cache_github_login`; pre-migration and
in-flight stale-account rows are therefore never rendered.

Sesori owner identity and GitHub authorship are intentionally separate. A
machine-local `gh auth switch` does not change the Sesori owner. Detection of a
different active login upgrades the refresh to all-state and atomically replaces
branch-matched rows plus project cache-login metadata for the new account.

### Archived Session PR Snapshot

`archived_session_pull_requests` stores the complete display snapshot keyed by
`(owner_identity, session_id, pr_number)`:

- owner identity;
- verified GitHub author login;
- branch name, URL, title, state;
- mergeability, review decision, check status;
- original/cache creation time, last checked time, and snapshot time.

`SessionArchiveRepository` is the sole runtime writer. The archive transaction
updates `archived_at`, sets `pr_tracking_stopped_at`, reads the frozen
current/history branches, and writes only cached rows already verified as
authored by the project's active `gh` login. Unverified or stale-login rows are
never made terminal snapshots.

### Migration Rules

- PR 2 backfills exact session `directory` from a stored worktree path or the
  owning project's persisted path through the existing FK, then seeds one
  branch-history row and `current_branch_name` from a non-empty stored
  `branch_name`, with `owner_identity = "local"`.
- PR 3 backfills `owner_identity = "local"` on the PR cache, includes owner in
  its durable key, and sets every pre-migration PR row's
  `github_author_login` plus every project's `pr_cache_github_login` to null.
- PR 4 sets `pr_tracking_stopped_at = archived_at` for sessions already
  archived and snapshots only cache rows whose non-null author login matches the
  project's non-null cache login. Rows from the old unfiltered cache never enter
  terminal snapshots.
- Never derive a live directory from `project_id` during migration. Branch
  observation starts only after the repository resolves the session's stored
  worktree path or its owning project's non-null live `path`; missing/corrupt
  relationships fail validation instead of inventing a location.
- `SessionArchiveRepository` becomes the only runtime writer of
  `archived_session_pull_requests` and the terminal fields in PR 4; no second
  writer is introduced.
- Preserve existing pull request cache rows. The first all-state authored
  backfill transaction replaces branch-matched live cache data and removes
  pre-upgrade non-author-scoped matches.
- Test both structure and data integrity from the prior schema.

## 7. Polling and Reconciliation Policy

### Activation Backfill

On project view 0-to-1 and on a newly recorded branch while viewed:

1. Check cached `gh` availability, authentication, and GitHub remote eligibility.
2. Ask `SessionBranchRepository` to synchronously resolve/persist the current
   named branch for every active session in scope, then read the complete branch
   set. Do not commit project cache-login metadata if resolution fails or is
   incomplete.
3. Run an all-state authored query, paged/bounded high enough to cover normal
   repository history.
4. Match same-repository PR head branches against the union of active recorded
   branches for the project.
5. Recheck that the active GitHub login still equals the request's captured
   login; discard and return `identityChanged` if it changed. The still-eligible
   origin may issue its single all-state follow-up.
6. Replace matched live cache rows and the project's cache-login metadata in one
   transaction without deleting unrelated project data.
7. Emit `sessionsUpdated` only when rendered PR data changed.

### Steady Open Refresh

1. List open PRs authored by `@me` for the repository.
2. Compute the fast/idle tier from the complete open authored result before
   branch matching.
3. Upsert matching open PRs with their verified author login.
4. For a previously cached open PR absent from the result, call `gh pr view` to
   record its final merged/closed state only when the returned author equals the
   request's captured active login.
5. Recheck the active login before commit; an account change discards the result
   and returns `identityChanged`. The dispatcher queues nothing; the origin
   rechecks eligibility before issuing at most one all-state follow-up.
6. Preserve terminal history rows for the matching login.
7. Schedule the next one-shot timer after completion, never from start time.

### Continuous-View History Reconciliation

`ScheduledPrRefreshListener` records the last successful all-state refresh for
each viewed project. If ten minutes elapse without another activation/new-branch
backfill, the next scheduled trigger upgrades itself from open to all-state.
When scheduling, it caps the next one-shot delay at the remaining time to that
deadline instead of allowing a 15/90-second tier interval to cross it. This uses
the existing timer and dispatcher queue rather than adding a second timer or
overlapping command. A successful all-state refresh resets the deadline;
failures follow the normal jittered backoff.

### Failure Behavior

- Availability/auth/no-GitHub-remote results are explicit non-success outcomes,
  not empty successful PR lists.
- Recovering listeners log failures with attached errors and continue safely.
- Backoff grows only while the project remains viewed, applies randomized
  jitter independently at every retry step, and caps near five minutes.
- A success resets failure backoff and restores the 15/90-second tier.
- Leaving the viewed set cancels future timers. An already-running command may
  finish and commit its result, but no new command starts.

## 8. Archive Semantics

Archive is a two-step terminal operation:

1. **Synchronous durable step:** before any cleanup can delete a worktree or
   branch, synchronously resolve/persist the session directory's latest named
   `HEAD` (or detached-null). Then run the existing cleanup validation/destructive
   operation. On success, one database transaction writes `archived_at`, writes
   `pr_tracking_stopped_at`, freezes branch membership/current branch, and
   snapshots cached PR display data together with the project's persisted
   verified `pr_cache_github_login`. It does not run `gh` during the synchronous
   archive path. A local branch-resolution failure logs and freezes the last
   durable branch so archive itself remains available. The archive response then
   returns.
2. **Asynchronous final step:** `SessionArchiveService` publishes a typed request
   containing project path, session id, frozen branches, and the verified
   snapshot GitHub login.
   `ArchivePrRefreshListener` only receives that request, delegates it to
   `PrRefreshDispatcher`, and logs failure. The dispatcher resolves the
   then-active `gh` login through `PrSourceRepository`. If it differs from a
   non-null snapshot login, the dispatcher asks `SessionArchiveRepository` to
   clear that stale-account snapshot and returns a typed `snapshotCleared`
   completion before attempting more GitHub work. The orchestrator consumes that
   completion and emits `sessionsUpdated`; a later lookup/query failure can
   therefore not leave clients rendering the cleared PR. A null snapshot login
   is allowed to establish the active account asynchronously. The dispatcher
   performs one all-state authored reconciliation for the active login. Success
   atomically replaces the archived snapshot only after rechecking that login,
   then returns another change completion for orchestrator delivery when rendered
   data changes. If active-login resolution itself fails, the dispatcher
   instructs `SessionArchiveRepository` to clear any non-empty terminal snapshot
   and returns `snapshotCleared` when the repository reports a mutation, because
   no fresh same-login check exists to justify retaining it. If login resolution
   succeeds and confirms the snapshot account but the later PR query fails, the
   dispatcher reports failure and retains that same-login snapshot. The listener
   logs the failure, and either failure is terminal.

There is no retry, persisted pending sentinel, startup recovery, or later
project-poll mutation. Unarchive continues restoring the worktree/session as it
does today, but PR monitoring remains stopped and the snapshot remains the only
PR read source.

## 9. Compatibility and Rollout

- `Session.pullRequestHistory` is nullable and omitted from JSON when null. New
  clients normalize null to an empty history; new bridges send a non-null list.
- `Session.pullRequest` remains the headline field, preserving existing clients.
- `RelayProjectView` is additive. Bridge decoding lands before any mobile sender.
  Version-skew tests must prove an unsupported/invalid control declaration is
  isolated and does not disconnect normal relay traffic; an older bridge simply
  falls back to request-driven PR refresh.
- `waitForPrData` remains accepted. PR 3 routes it through the dispatcher as a
  one-shot all-state refresh for old clients that do not declare project view,
  while preserving the handler's existing five-second PR-data timeout before it
  returns current cached/enriched sessions.
- The existing `waitForPrData: false` path remains a fire-and-forget dispatcher
  trigger for all supported client versions, including after project presence
  ships. Presence and request triggers coalesce in the same dispatcher; removal
  requires a documented minimum-client-version decision, not completion of this
  plan.
- New mobile code requests cached sessions immediately; view activation and SSE
  provide freshness without blocking list rendering on `gh`.
- No compatibility branch is persisted solely to distinguish hypothetical
  backends. Any temporary wire fallback added during implementation must be
  recorded in `docs/COMPATIBILITY_DEBT.md` with a removal target.

## 10. PR Status Index

Legend: `[ ]` pending, `[x]` completed.

| Status | PR | Deliverable | Primary verification |
|---|---|---|---|
| [x] | 0 | Approved tracked execution plan | `aristotle-plan-review`; plan consistency |
| [ ] | 1 | Additive shared project-view and PR-history contracts | shared round trips; bridge/client compile compatibility |
| [ ] | 2 | Durable live branch observation | Drift migration; repository/listener/watch-sharing tests |
| [ ] | 3 | Authored PR dispatcher, identity-scoped cache, and live history | API/repository/dispatcher tests; legacy request path |
| [ ] | 4 | Terminal archive snapshot and one-shot final refresh | migration/archive/final-refresh tests |
| [ ] | 5 | Project presence and adaptive bridge listeners | multi-phone/timer/orchestrator tests |
| [ ] | 6 | Mobile project-view declarations and cache-first session loading | service lifecycle/reconnect and cubit tests |
| [ ] | 7 | Collapsed PR history UI, integration pass, and old sync cleanup | widget tests; full bridge/shared/client verification |

## 11. Step-by-Step PR Plan

### PR 1 - Additive Shared Contracts

Scope:

- Add `RelayMessage.projectView({required String? projectId})`.
- Add nullable `List<PullRequestInfo>? pullRequestHistory` to `Session` while
  retaining `pullRequest` unchanged.
- Export/regenerate shared Freezed and JSON artifacts.
- Update exhaustive relay-message switches in bridge/client with no-op handling
  where production behavior is not wired yet.
- Add old/new JSON and relay round-trip tests.

Acceptance:

- Missing history decodes as null and callers can normalize it to empty.
- Null fields remain omitted from shared JSON.
- Existing session and relay behavior is unchanged.
- Bridge, module_core, mobile, desktop consumers, and shared analysis compile.

Regression guide:

- Session list serialization still carries the existing headline PR.
- Existing `RelaySessionView` still marks only session content seen.
- Unknown/invalid control-message handling remains connection-safe.

### PR 2 - Durable Branch Observation

Scope:

- Export the current Drift schema before changes and allocate the next version.
- Add/reuse exact session `directory`, add `current_branch_name` and owner-scoped
  `session_branch_history`; keep terminal archive fields/snapshots out of this
  PR.
- Add `GitCliApi` named-HEAD and git-HEAD-path operations plus the raw
  `FilesystemApi` directory-watch operation.
- Add `SessionBranchRepository` and `SessionBranchListener` in target layer
  directories. The listener imports no Layer 1 type.
- Group sessions by normalized resolved git `HEAD` watch key, own one OS
  subscription per key, and fan each event to every mapped session.
- Perform initial reads, persist named transitions, handle duplicate/return/
  detached cases, and stop subscriptions when the last mapped session leaves.
- Extend the existing `SessionMutationDispatcher`/`SessionRepository` mutation
  path so the orchestrator persists each live root `session.created` identity,
  project, plugin, and exact reported directory before routing the same event to
  unseen tracking. The DAO stream then enrolls laptop-created sessions without
  waiting for a phone list request; child sessions remain excluded.
- Until terminal semantics ship in PR 4, exclude `archived_at != null` rows from
  the trackable set; unarchive retains the existing reversible behavior.
- Wire listener lifecycle at the bridge composition root, but do not trigger
  GitHub refreshes yet.

Acceptance:

- Existing sessions migrate without identity or worktree metadata loss.
- A laptop-created root is durably stored with its exact directory before the
  branch watcher can miss a later switch, even when no phone has loaded it.
- Named branch switches persist current/history; detached HEAD clears current
  without adding `HEAD` as a branch.
- Two sessions sharing a checkout receive independent history updates through
  one filesystem subscription for that resolved `HEAD` key.
- Archive/delete/bridge shutdown removes mappings and cancels a subscription
  when its final session leaves.

Regression guide:

- Session creation and worktree cleanup continue using stored `branchName`.
- Existing unseen creation stamps remain intact; on `session.created`, dispatcher
  persistence precedes the unseen stamp and its existing insert-if-missing
  fallback remains idempotent.
- No periodic Git process or per-session duplicate watcher is introduced.
- Missing, moved, or permission-denied paths log/degrade without crashing the
  bridge or inventing a location.

### PR 3 - Authored PR Dispatcher and Live History

Scope:

- Export the then-current schema and add owner/login metadata to the global PR
  cache and project rows as specified in section 6.
- Backfill owner identity to `local`; leave legacy PR author/project-cache login
  metadata null so those rows stop rendering until verified.
- Resolve/capture/recheck the active GitHub login; add open/all authored queries
  and author mapping. Keep `--author @me` on `gh pr list` only.
- Evolve `PrSourceRepository` and make `PullRequestRepository` the sole global
  PR-cache writer.
- Add typed refresh request/result/completion models and
  `PrRefreshDispatcher` with explicit `SessionBranchRepository`,
  `PrSourceRepository`, and `PullRequestRepository` dependencies, per-project
  serialization, and request-strength coalescing.
- Implement all-state backfill, open reconciliation, disappeared-open
  finalization, same-repository filtering, captured-login revalidation,
  typed identity-change completion, and change-only completion events. The
  dispatcher never starts a follow-up itself.
- Upgrade a requested open refresh to all-state when the project has no
  `pr_cache_github_login` (the post-migration/unverified state), so the first
  ordinary `waitForPrData: false` load re-verifies terminal as well as open PRs.
- Before any all-state query, synchronously resolve/persist the complete active
  branch scope; do not set `pr_cache_github_login` from an empty/incomplete
  initial listener race.
- For the first post-migration all-state upgrade while
  `pr_cache_github_login` is null, union that active scope with durable branch
  history from archived sessions in the project. Never resolve archived
  filesystem paths; persisted history lets PR 3 verify archived-only legacy rows
  before PR 4 snapshots them.
- Route `waitForPrData: true` through one awaited all-state request inside the
  existing five-second PR-data timeout, and preserve `waitForPrData: false` as a
  fire-and-forget open refresh.
- On `identityChanged`, `GetSessionsHandler` may issue one all-state follow-up
  for its still-current request trigger; the dispatcher itself never loops.
- Route persisted current-branch changes to the orchestrator's independent
  `sessionsUpdated` invalidation path, even when the subsequent GitHub refresh
  produces no cache changes.
- Remove `SessionRepository -> PullRequestRepository`; inject read-only DAOs and
  mappers, hide null/mismatched author rows, and enrich live sessions with the
  current branch headline plus ordered history.
- Keep existing archive behavior and request-driven refresh; no timers or phone
  presence yet.

Acceptance:

- Every GitHub list query uses `--author @me`; `gh pr view` results are accepted
  only when their author matches the captured login.
- Current selection and history ordering obey Decisions 5 and 6.
- Full backfill discovers merged/closed PRs missed while idle; disappeared open
  PRs retain their final state.
- After migration hides unverified legacy rows, the first ordinary non-wait
  session load restores authored open/merged/closed headlines via an automatic
  all-state upgrade over a synchronously complete branch scope.
- Awaited legacy loads retain the five-second response budget and fall back to
  current cached/enriched sessions when a paged all-state query exceeds it.
- Changing or detaching `HEAD` updates visible headline/history even when GitHub
  data is unchanged or unavailable.
- A `gh auth switch` during a command cannot commit/render the old account's
  result; an eligible originating request/listener may issue at most one
  all-state follow-up for the new login.
- The first compatibility backfill verifies PRs on archived-only durable
  branches as well as active branches before setting project cache-login state.
- Concurrent open/all requests do not overlap or drop the stronger request.
- Identity-change follow-ups are bounded to one and remain owned by the
  originating eligible consumer, never the dispatcher.
- Both shipped request modes remain fresh and existing clients receive the
  correct `pullRequest` headline.

Regression guide:

- Non-GitHub projects and unauthenticated/missing `gh` still return session
  lists.
- A GitHub failure is not interpreted as an empty authoritative result.
- Session list pagination, archive behavior, and unseen enrichment are unchanged.

### PR 4 - Terminal Archive and Final Refresh

Scope:

- Export the then-current schema; add `pr_tracking_stopped_at`, owner-scoped
  `archived_session_pull_requests`, and migration coverage.
- For sessions already archived when this PR lands, set the stop marker and
  snapshot only global cache rows matching the project's verified GitHub login;
  do not perform network refreshes for pre-feature archive actions.
- Add `SessionArchiveRepository` and move touched archive/unarchive persistence
  out of `SessionPersistenceService`. Archive atomically writes `archived_at`,
  stop marker, frozen branches, and the immediate verified snapshot; unarchive
  never clears terminal PR state.
- At the start of archive, before cleanup can delete a worktree or branch,
  synchronously resolve/persist the latest local named `HEAD` (or detached-null)
  through `SessionBranchRepository`, so a just-visited branch cannot be lost.
- Add `ArchivePrRefreshListener`, extend `PrRefreshDispatcher` with its
  `SessionArchiveRepository` dependency/final mode, and emit one final request
  after each newly committed archive transaction. The request carries the
  verified project-cache GitHub login captured by that transaction. The listener
  only delegates and logs failure. `PrRefreshDispatcher` resolves the active
  login through `PrSourceRepository`: it clears a mismatched cached snapshot,
  allows a null cached login to establish the active account, and replaces only
  after rechecking the active login at commit.
- Return a typed `snapshotCleared` completion immediately whenever mismatch
  handling clears a snapshot, before the final query can fail; the orchestrator
  emits `sessionsUpdated`. Return another change completion only if successful
  replacement changes rendered data. Archive-final never retries or follows an
  identity-change completion.
- Fail closed when the final job cannot resolve the active GitHub login: the
  dispatcher asks `SessionArchiveRepository` to clear any non-empty snapshot;
  the repository returns only changed/unchanged, and the dispatcher returns
  `snapshotCleared` on change. Retain a snapshot on PR query failure only after
  that job freshly confirmed the same login.
- Switch terminal enrichment to archived snapshots in the same PR.
- Change branch tracking eligibility from `archived_at == null` to
  `pr_tracking_stopped_at == null`.
- Extend `SessionBranchRepository.resolveAndPersist` so its branch-history/
  current-branch transaction atomically rechecks the stop marker before writing.
  A callback already in flight when archive commits must no-op and emit nothing.

Acceptance:

- No build can write a terminal stop marker without also having immutable reads
  and the final-refresh listener available.
- Archive response never awaits GitHub; final refresh succeeds once or fails
  once without retry.
- Existing archived sessions get only verified cached data; new archives get
  the synchronous snapshot plus one final all-state attempt.
- Archive freezes the latest synchronously resolved branch, never runs `gh`
  before responding, and the final attempt can populate an initially null-login
  snapshot or clear/replace a stale-account snapshot without cross-account data.
- Clearing a stale-account snapshot invalidates clients even if the subsequent
  final query fails.
- Active-login lookup failure clears the terminal snapshot; a later query
  failure may retain it only after a fresh same-login check.
- Another session's later global-cache refresh cannot mutate archived display.
- A branch callback racing archive either commits before the frozen snapshot or
  is rejected by the terminal marker; it cannot mutate branch state afterward.
- Unarchive does not restart PR monitoring.

Regression guide:

- Existing archive cleanup conflicts still prevent the archive transaction.
- Plugin archive notification remains best-effort and observable on failure.
- Existing already-archived sessions do not trigger surprise network traffic.

### PR 5 - Project Presence and Adaptive Bridge Polling

Scope:

- Add `ProjectViewTracker` and route `RelayProjectView` in the orchestrator.
- Release presence per connection disconnect and clear all presence on relay
  drop.
- Add the remaining peer listeners: view activation, scheduled polling, and
  branch change. Inject streams from composition, never peer classes.
- Implement 15/90-second one-shot scheduling, cancellation, randomized bounded
  failure backoff, and an all-state reconciliation at least every ten minutes
  while continuously viewed.
- On `identityChanged`, each listener rechecks that its project is still viewed
  before issuing its single all-state follow-up; a timer whose final viewer left
  cannot restart GitHub work.

Acceptance:

- One or many phone connections produce correct project 0-to-1 and 1-to-0
  transitions.
- Only viewed projects schedule GitHub work; branch observation continues for
  unviewed projects.
- Any authored open PR selects 15 seconds; none selects 90 seconds; a short-lived
  PR missed by open polls enters history within ten minutes while still viewed,
  because no tier interval may schedule past the all-state deadline.
- Relay loss leaves no ghost project viewers or timers, and commands never
  overlap.

Regression guide:

- Session unseen view counts remain independent.
- Legacy request-driven refreshes remain available for clients without project
  presence.

### PR 6 - Mobile Project Presence

Scope:

- Add `ProjectViewApi`, `ProjectViewRepository`, and singleton
  `ProjectViewingService` in module_core.
- Give the service required `ProjectViewRepository`, `LifecycleSource`, and
  typed `Stream<ConnectionStatus>` dependencies. The DI composition root derives
  the stream from `ConnectionService`; the service never imports transport.
- Own serialized sends, list/detail claims, detail precedence, fallback to list,
  stale-clear guards, pause/hidden clear, and resume/reconnect reassertion.
  Reconnect reasserts only while lifecycle state is foreground/visible; a
  paused/hidden claim remains dormant until resume.
- Have `SessionListCubit` declare after a successful initial render and clear on
  close.
- Have `SessionDetailCubit` declare for direct-detail navigation and clear on
  close without depending on the list cubit.
- Switch new-client session loading to cache-first instead of waiting for `gh`.
- Regenerate module_core DI.

Acceptance:

- Entering either screen activates the correct project.
- Navigating list -> detail -> list does not emit a false null declaration.
- Cross-project navigation cannot let a late clear erase the new project.
- Background sends null once; a background reconnect sends nothing; resume or a
  foreground reconnect reasserts the visible project.
- Disconnect send failures do not poison future serialized sends.

Regression guide:

- Opening session detail still marks conversation content seen only after its
  existing successful refresh rule.
- Session loading errors do not claim a project that was never rendered.
- Existing connection reconnect and lifecycle tests remain green.

### PR 7 - Collapsed History UI and Integration Cleanup

Scope:

- Normalize nullable history to empty in module_core presentation state.
- Keep `PrStatusRow` as the prominent headline presentation.
- Add a focused, localized history section that appears only when history is
  non-empty, is collapsed by default, and uses Prego design tokens.
- Preserve expansion state across `sessionsUpdated` re-fetches where widget
  identity remains stable.
- Add compact layouts for phone and wider/adaptive session lists.
- Remove dead `PrSyncService` internals and obsolete debounce state after all
  triggers use the dispatcher, but retain both `GetSessionsHandler` wait/non-wait
  dispatcher paths for supported older clients.
- Update this plan's pointer/index/findings and any compatibility debt.

Acceptance:

- Current PR remains immediately visible.
- History is ordered newest first and never duplicates the headline.
- Sessions with no history render exactly the current compact layout.
- Archived sessions render their immutable snapshot.
- End-to-end project presence -> refresh -> SSE -> re-fetch -> UI is covered by
  an integration test with fake Git/GitHub sources.

Regression guide:

- Existing PR status colors, review/check indicators, activity row, unseen dot,
  archive swipe, and adaptive selection remain functional.
- Session tiles do not overflow at supported phone text scales and desktop-width
  adaptive layouts.
- Old clients can still use `waitForPrData` after old internal sync code is
  removed.

## 12. Verification Matrix

Every PR runs generated-code checks, fatal-info analysis, and tests for each
changed workspace.

| Area | Required coverage |
|---|---|
| Shared contracts | Old/new JSON, nullable omission, relay round trips, exhaustive switches |
| Drift migration | `SchemaVerifier.migrateAndValidate`, old-row fixtures, archived snapshot, branch seeding, FKs/cascades |
| Git/filesystem | normal branch, return, duplicate event, detached HEAD, worktree gitdir, missing path, permission failure, one watcher for shared HEAD key, fan-out, archive-before-watch race, in-flight callback vs terminal transaction, disposal |
| GitHub API | active-login lookup, exact list-only `--author @me` and state arguments, no author flag on `pr view`, author JSON mapping, remote eligibility, command failure/timeout, same-repository filter |
| Repositories | writer ownership, owner/login-scoped reads, null/mismatched-row hiding, active plus archived-only compatibility scope, current/history selection, all-state replacement, final-state preservation, archived immutability |
| Dispatcher | per-project serialization, mode coalescing, synchronous all-state branch scope, null-cache-login upgrade, open disappearance, typed identity-change completion without autonomous retry, no false empty success |
| Presence/listeners | multi-connection counts, activation/cancel, 15/90 tiers, ten-minute all-state deadline, branch immediate trigger, identity-change eligibility recheck, failure backoff, no overlap |
| Archive | existing-archive verified migration, pre-cleanup latest-HEAD freeze, null/stale snapshot-login establishment, clear-before-failure invalidation, login-lookup fail-closed, same-login query failure retention, immediate response, transaction rollback, final success, final failure/no retry, unarchive remains terminal for PRs |
| Mobile service | list/detail claims, navigation races, foreground-gated reconnect, lifecycle, serialized-send recovery |
| Cubits/UI | cache-first load, SSE re-fetch, collapsed/default state, ordering, archived history, no-history parity, overflow |

Final integration verification:

```sh
cd bridge && dart pub get && make codegen && make analyze && make test
cd shared/sesori_shared && dart pub get && dart analyze && dart test
cd client && dart pub get
cd client/module_core && dart analyze && dart test
cd client/app && dart analyze && flutter test
cd client/module_desktop_core && dart analyze && dart test
cd client/desktop && dart analyze && flutter test
```

Use the current workspace command shape rather than literal `cd` chaining when
executing through automation. Desktop checks are required because shared and
module_core contracts are consumed by the desktop product even though this plan
adds no desktop-only PR-monitor behavior.

## 13. Risk Register

| Risk | Status | Mitigation / owning PR |
|---|---|---|
| Concurrent parallel-plugin migration takes the next Drift version | OPEN | Each schema-owning PR allocates from current `main`; never rewrite a merged migration (PR 2-4) |
| Filesystem watch misses atomic HEAD replacement or duplicates shared-checkout watches | OPEN | Watch resolved HEAD parent once per normalized key, fan out to mapped sessions, initial read, worktree/platform tests (PR 2) |
| Large authored PR history exceeds list bound | OPEN | Use paged/high bounded all-state query; record observed limits and add fixture (PR 3) |
| `gh` process is slow or hangs | OPEN | Process timeout, one in-flight project refresh, completion-based schedule, backoff (PR 3-5) |
| GitHub CLI account switch leaves old authored cache rows | OPEN | Store row/project GitHub login, hide mismatches, capture and recheck login around each refresh, and let only a still-eligible origin follow `identityChanged` with one all-state replacement; relay/Sesori identity remains independent (PR 3) |
| Multiple triggers drop an archive-final or periodic all-state refresh | OPEN | Per-project queue; final/all mode outranks open and is never coalesced away (PR 3-5) |
| Short-lived PR opens and completes between open polls | OPEN | Force all-state at least every ten minutes while continuously viewed (PR 5) |
| Shared checkout associates one PR with several sessions | ACCEPTED | Explicit Decision 3; test and document rather than infer ownership |
| Laptop-created root switches branch before any phone list fetch | OPEN | Persist root identity and exact event directory before unseen handling; DAO stream enrolls watcher (PR 2) |
| New app talks to an older bridge without project-view support | OPEN | Bridge decoder lands first; connection-safe failure and request-driven fallback tests (PR 1, 6) |
| Supported old client never sends project presence | OPEN | Keep non-wait `/sessions` as a dispatcher trigger until a documented minimum-client-version removal (PR 3-7) |
| Archived snapshot changes through shared global PR cache | OPEN | Snapshot table and terminal-only read path land atomically with terminal behavior (PR 4) |
| Archive cache login is null/stale after `gh auth switch` | OPEN | Async final establishes active login, clears mismatched snapshot, rechecks before replacement, no retry (PR 4) |
| Unarchive accidentally restarts monitoring | OPEN | Independent non-null stop marker; archive repository never clears it (PR 4) |
| PR updates accidentally mark conversation unseen | OPEN | No dependency on unseen service/tracker; regression tests (all) |
| Timer survives lost phone presence | OPEN | Per-connection counts, relay-drop clear, one owner for timer cancellation (PR 5) |
| Plan drifts from merged implementation | OPEN | Same-PR pointer/index/findings/risk updates (all) |

## 14. Findings and Plan Deltas

Record newest findings first. A plan delta names the changed decision or section
and updates the owning acceptance/risk text in the same PR.

- **Step 0:** Fast-forwarded `git-pr-monitor-upgrade` to `main` at `0de55787`.
  Re-audited current PR sync, branch persistence, session-view lifecycle,
  archive, shared session model, and mobile PR presentation. The architecture
  plan was approved after splitting equivalent refresh triggers into peer
  listeners, replacing same-layer references with injected streams, assigning
  one repository writer per durable concern, and making the archive transaction
  ownership explicit. No production behavior has changed.
