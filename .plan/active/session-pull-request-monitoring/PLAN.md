# Session Pull Request Monitoring

## 0. Plan Metadata

- **Status:** Approved — ready for delivery on plan PR #436
- **Format version:** 1
- **Generated:** 2026-07-14
- **Plan slug:** `session-pull-request-monitoring`
- **Plan host:** `sesori-ai/sesori_apps_monorepo`
- **Selected implementation base:** `main`
- **Legacy source:** `docs/pr-monitor/PLAN.md` from an earlier commit on the
  existing plan-PR branch. The canonical migration removes that path; it remains
  historical context only, not an implementation baseline or authority.

| Repository | Implementation base | Initial audited tip | Commit date | Latest re-review | Latest audited tip | Commit date |
|---|---|---|---|---|---|---|
| `sesori-ai/sesori_apps_monorepo` | `main` | `2f4adf2dec643f44db231f88d09672499a8a8619` | 2026-07-14T17:20:37+03:00 | 2026-07-14 | `e766684e0fdc22256419b7b99691021c9f14732d` | 2026-07-14T17:59:08+03:00 |

The audited SHA is staleness metadata, not a historical branch point. Each
implementation wave starts from and pins the then-current tip of `main` after
assessing drift from the latest audited tip. Every first-wave PR in this
plan-host repository declares `main` as its base.

## 1. Goal

Give each root session a durable pull-request timeline derived from the named
Git branches actually visited in that session's exact working directory:

- keep the newest associated PR on the current named branch prominent;
- retain PRs from every previously observed named branch as collapsed history;
- refresh authored GitHub state near real time only while a connected client is
  viewing that project;
- continue local branch observation without a connected client so history is
  not lost;
- keep PR status independent from conversation unseen state; and
- make archive terminal for PR tracking while preserving one immutable display
  snapshot and one non-blocking final refresh attempt.

Git and GitHub behavior remains bridge-owned and plugin-agnostic. No OpenCode,
Codex, Cursor, ACP, or future harness detail crosses `BridgePluginApi` into the
shared contract or client.

## 2. Success Criteria

1. A named local `HEAD` transition is persisted from filesystem events, updates
   the session's current branch, preserves prior branch history, and emits a
   project-scoped `sessionsUpdated` invalidation without waiting for GitHub.
2. Detached `HEAD` clears the current branch without creating a fake `HEAD`
   history row; returning to a named branch updates `last_seen_at` rather than
   duplicating it.
3. Sessions sharing one checkout use one normalized git-`HEAD` watcher while
   receiving independent durable history updates.
4. While at least one connected client views a project, GitHub refreshes use a
   15-second tier when the repository has an authored open PR and a 90-second
   tier otherwise. No GitHub timer survives the final viewer leaving.
5. A continuously viewed project completes an all-state authored reconciliation
   at least once every ten minutes; a failed attempt keeps the deadline pending
   and follows bounded backoff.
6. Every `gh pr list` query is restricted to `--author @me` and at most 1,001
   fetched authored rows; accepted observations are additionally restricted to
   the resolved same repository. The first 1,000 pre-filter authored rows are
   supported; row 1,001 marks an observable truncated result that never
   authoritatively deletes absent cached rows.
7. The bridge captures and rechecks active GitHub login plus canonical
   repository identity around every write. Once a refresh observes an unknown
   or changed account/repository, it suspends old cache visibility before
   query/write and emits invalidation. Cache-first reads remain non-blocking, so
   an as-yet-unobserved local `gh auth switch` can remain visible only until the
   next existing request/view trigger detects it.
8. The headline is the highest-numbered associated PR on the current named
   branch, regardless of open/merged/closed state. History is every other
   associated PR, ordered by descending PR number, with no headline duplicate.
9. Archive never waits for `gh`, freezes the latest locally resolvable branch and
   verified cache snapshot, and performs at most one asynchronous final
   all-state attempt. Unarchive never restarts branch or PR tracking.
10. New clients talking to old bridges and old clients talking to new bridges
    continue loading sessions. Missing `pullRequestHistory` decodes to a
    non-null empty list, and both existing `waitForPrData` request modes remain
    supported.
11. PR changes never modify session/project unseen timestamps and never generate
    push notifications.
12. Bridge, shared, module-core, mobile, desktop-core, and desktop-shell
    verification passes at the end of the plan.

## 3. Scope

### In Scope

- Additive shared `RelayProjectView` and `Session.pullRequestHistory` contracts.
- Exact root-session directory persistence and durable named-branch history.
- Filesystem-driven git `HEAD` observation with watcher sharing and recovery.
- Authored, same-repository GitHub discovery through the installed `gh` CLI.
- GitHub-account/repository-scoped global PR cache and project cache identity,
  bound to the project path at verification time.
- Per-project serialized refresh dispatch, open/all reconciliation, truncation
  handling, and identity-switch protection.
- Terminal archive stop state, immutable archived PR snapshots, and one final
  asynchronous refresh attempt.
- Connection-scoped project-view declarations from session-list and
  session-detail client surfaces.
- Adaptive viewed-project scheduling and project-scoped SSE invalidation.
- Mobile collapsed PR-history presentation using Prego tokens.
- Removal of superseded `PrSyncService` internals after all supported triggers
  route through the new dispatcher.
- Drift, generated-code, unit, integration, widget, and advisory manual checks.

### Non-Goals

- Review comments, individual check runs, labels, assignees, commits, or PR
  mutation.
- Push notifications or conversation unseen activity for PR changes.
- Polling GitHub when no client views the project.
- Polling git for local branch changes.
- Continuous plugin enumeration, plugin capability changes, or backend-specific
  PR behavior.
- Cross-host GitHub synchronization, GitHub Enterprise support, or credentials
  outside the existing local `gh` CLI.
- More than the newest 1,000 authored PRs returned by repository-wide discovery.
- Restoring PR tracking after a session reaches terminal PR archive state.
- Changing the existing user-visible ability to unarchive a session.
- Offline/local-first client caching.
- Desktop-only PR UI before the shared accessory UI exists.
- The separate OpenCode `pr_monitor` development tool under `.opencode/`.
- Teams, permissions policy, metering, managed-VM trust changes, or speculative
  forge abstractions.

## 4. Audited Baseline

The selected `main` tip was initially fetched and audited at
`2f4adf2dec643f44db231f88d09672499a8a8619`. A pre-delivery drift review at
`e766684e0fdc22256419b7b99691021c9f14732d` found only iOS TestFlight workflow
and Fastfile changes, with no planned path, contract, schema, architecture, or
product-intent impact. The plan branch diverged at
`7e019af01ecb4c658a3e9e6b05e002517ed4910e`; changes from that merge base to the
initial audited tip affect prompt-sheet routing only and do not alter planned PR
paths.

### Current behavior

- `bridge/app/lib/src/bridge/services/pr_sync_service.dart:43-74` accepts only
  request-driven refreshes, deduplicates one active project refresh, and applies
  a 30-second debounce. It owns no viewed-project timer.
- `bridge/app/lib/src/bridge/services/pr_sync_service.dart:103-179` lists open
  PRs, matches them to one stored `branchName`, finalizes disappeared open PRs,
  and emits a project id only when cache data changes.
- `bridge/app/lib/src/bridge/api/gh_cli_api.dart:34-55` runs
  `gh pr list --state open --limit 100` without `--author @me` or PR author
  parsing. `gh pr view` likewise does not parse author identity.
- `bridge/app/lib/src/bridge/api/database/daos/pull_request_dao.dart:24-49`
  associates PRs by joining PR branch to the session row's single
  `branch_name`. The cache key is `(project_id, pr_number)`.
- `bridge/app/lib/src/bridge/repositories/session_repository.dart:519-572`
  depends on peer `PullRequestRepository`, chooses an open PR before a newer
  closed PR, and exposes only one `Session.pullRequest`.
- `bridge/app/lib/src/bridge/persistence/tables/session_table.dart:35-76` stores
  worktree-creation `branch_name` but no exact generic session directory,
  current live branch, branch history, or terminal PR stop marker.
- `bridge/app/lib/src/bridge/api/git_cli_api.dart:168-178` already resolves
  `git rev-parse --abbrev-ref HEAD` for worktree safety, but no component
  observes live `HEAD` changes.
- `bridge/app/lib/src/bridge/api/filesystem_api.dart:9-55` is the existing dumb
  host-filesystem boundary and has no watch operation.
- `bridge/app/lib/src/bridge/routing/get_sessions_handler.dart:67-142` fetches
  and persists plugin sessions, triggers PR refresh for both request modes, and
  gives `waitForPrData: true` a five-second budget. Commit
  `214f000ca88e29ba88dd6facbeed3629f1c77c2c` shipped that compatibility behavior.
- Initial/background client loads already use `waitForPrData: false`; explicit
  pull-to-refresh uses `true`
  (`client/module_core/lib/src/cubits/session_list/session_list_cubit.dart:630-676`,
  `client/app/lib/features/session_list/session_list_content.dart:13-20`). This
  plan preserves rather than reintroduces cache-first loading.
- `SessionMutationDispatcher` currently serializes title/delete mutations only.
  A live `session.created` reaches `SessionUnseenService` after the SSE payload
  is enqueued (`bridge/app/lib/src/bridge/orchestrator.dart:720-739,
  872-883`).
- `SessionViewTracker`, `RelaySessionView`, `SessionViewApi` /
  `SessionViewRepository` / `SessionViewingService`, and detail-cubit tests are
  a proven connection-scoped declaration pattern. They remain dedicated to
  mark-seen semantics and are not reused for project presence.
- `bridge/app/lib/src/bridge/services/session_archive_service.dart:97-133`
  performs cleanup, writes reversible `archived_at` through the legacy
  `SessionPersistenceService`, and notifies the plugin asynchronously. Archived
  PR presentation still reads the mutable global cache.
- `bridge/app/lib/src/bridge/services/session_archive_service.dart:1-10,
  72-95,136-188` also imports cleanup policy upward from `routing/`, initializes
  missing rows through DAO-backed `SessionPersistenceService`, and calls
  `Directory.existsSync` directly. S02-W03 removes those touched boundary
  violations instead of extending them.
- `bridge/app/lib/src/bridge/orchestrator.dart:450-454` is the sole current
  owner of translating PR-cache change streams into `sessionsUpdated` SSE.
- `client/app/lib/features/session_list/session_tile.dart:113-148` renders one
  prominent `PrStatusRow`; there is no history UI.
- `shared/sesori_shared/lib/src/models/sesori/session.dart:34-56` has only the
  optional headline PR. `shared/sesori_shared/lib/src/protocol/messages.dart`
  has `RelaySessionView` but no project-view declaration.
- The declared bridge/mobile version is `1.5.0`
  (`bridge/app/pubspec.yaml`, `bridge/app/lib/src/version.dart`, and
  `client/app/pubspec.yaml`). Compatibility markers introduced by this plan use
  the implementation date and this repository-declared version unless the
  version changes before that PR begins.
- The audited Drift schema is version 10. Every schema-owning PR must inspect
  the current `main` version and allocate the next version; it must never rewrite
  a merged snapshot or migration.

### History evidence

- `da32bf71196326a5acf0c8c1668427d8c2d25f5c` introduced the current
  Aristotle-layered PR-awareness implementation and schema v4.
- `214f000ca88e29ba88dd6facbeed3629f1c77c2c` made PR waiting configurable and
  limited waiting to explicit pull-to-refresh.
- `1bf31620ea91c693a269e96dcf90ed12db6dcd26` introduced connection-scoped
  session viewing and unseen behavior that project presence must not disturb.
- `366fd4e939eeb8f7c6fd97909f84a7290ed6ec41` reduced recurring session sync
  battery work and strengthened current PR capability/debounce tests.

### External references

The 2026-07-14 GitHub CLI manuals confirm that `gh pr list` supports
`--author`, `--state {open|closed|merged|all}`, finite `--limit`, and JSON fields
including `author`, `isCrossRepository`, `reviewDecision`, and
`statusCheckRollup`; `gh pr view` supports the same JSON fields but no author
filter. These command contracts are pinned in the PR-step verification rather
than inferred at implementation time.

## 5. Architecture and Data Flow

### Boundaries and dependency direction

All new code follows Foundation -> API -> Repository -> Service -> Consumer.
Existing legacy files are modified in place only where they own the current
behavior; new classes live in visible top-level layer directories.

| Component | Layer / path | Ownership |
|---|---|---|
| `GitCliApi` additions | Layer 1, existing `bridge/app/lib/src/bridge/api/git_cli_api.dart` | Resolve current named branch and absolute git `HEAD` path. No retries or branch decisions. |
| `FilesystemApi` addition | Layer 1, existing `bridge/app/lib/src/bridge/api/filesystem_api.dart` | Expose raw directory watch events. |
| `GhCliApi` / `GhPullRequest` additions | Layer 1, existing legacy paths | Execute exact `gh` commands, parse author/login/canonical repository identity and typed PR DTO fields, and throw on failures/truncation parsing errors. |
| New branch/archive tables and DAOs | Layer 1, `bridge/app/lib/src/api/database/` | Raw owner-scoped queries and transactions inputs; no selection policy. |
| `SessionBranchRepository` | Layer 2, `bridge/app/lib/src/repositories/` | Resolve stored exact directories to normalized watch targets; map raw watch events to typed signals; atomically persist current/history state; emit `SessionBranchChanged`. |
| `PrSourceRepository` | Layer 2, existing legacy path | Wrap GitHub CLI availability, active-login/repository resolution, authored PR reads, and cached GitHub-remote eligibility. Never write another repository. |
| `PullRequestRepository` | Layer 2, existing legacy path | Sole runtime writer/finalizer of the live global PR cache and project cache visibility/login/repository/path metadata. |
| `SessionArchiveRepository` | Layer 2, `bridge/app/lib/src/repositories/` | Sole runtime writer of terminal stop state and immutable archived PR snapshots. |
| `SessionRepository` | Layer 2, existing legacy path | Persist exact observed root-session directory; read branch/PR/archive DAOs; map headline/history into shared sessions. It has no repository peer dependency. |
| `WorktreeRepository` additions | Layer 2, existing legacy path | Expose repository-backed worktree existence/restore operations over `FilesystemApi`/`GitCliApi`; services never call `dart:io` directly. |
| Mappers and typed models | Layer 2, `bridge/app/lib/src/repositories/{mappers,models}/` | Pure API/DAO/domain/shared transformations only. |
| `ProjectViewTracker` | Layer 3 state collaborator, `bridge/app/lib/src/services/` | Maintain connection -> project declarations, aggregate counts, and typed 0->1 / 1->0 changes. |
| `PrRefreshDispatcher` | Layer 3, `bridge/app/lib/src/services/` | Own per-project request serialization, request-strength coalescing, identity recheck, live/final write coordination, and typed completions. |
| `WorktreeCleanupService` | Layer 3, `bridge/app/lib/src/services/` | Own the existing multi-caller shared-worktree/safety/delete policy using `SessionRepository` and `WorktreeRepository`; replace the routing-layer free function. |
| `SessionArchiveService` changes | Layer 3, existing legacy path | Coordinate injected cleanup collaborator, branch freeze, archive repository transaction, repository-backed worktree restoration, plugin notification, and final-refresh request publication. It imports no routing, DAO, API, or `dart:io` type. |
| `SessionMutationDispatcher` changes | Layer 3, existing legacy path | Preserve ordered session-mutation invariants and persist live root-session identity/directory before unseen handling. |
| PR-monitor listeners | Layer 4, `bridge/app/lib/src/listeners/pr_monitor/` | One trigger lifecycle per class: filesystem branch events, project activation, scheduled refresh, branch refresh, or archive-final refresh. Listeners receive typed streams and never depend on listener peers. |
| `Orchestrator` | Layer 5 / sole bridge composer | Construct and wire every new/touched API, repository, service, tracker, listener, and typed stream; route relay declarations; release connection state; and remain the only SSE owner. |
| `BridgeRuntime` | Bridge lifecycle holder | Receive an already-composed `Orchestrator`, start/stop its session, and delegate debug/disposal lifecycle. It constructs no layered collaborator. |
| `RelayControlClient` | Client Layer 0, `module_core/lib/src/foundation/transport/` | Send a caller-built generic `RelayMessage` through the currently connected relay. It owns no session/project message shape or view policy. |
| `ProjectViewApi` | Client Layer 1 | Construct `RelayProjectView` and send it through `RelayControlClient`; migrate `SessionViewApi` to the same generic control transport. |
| `ProjectViewRepository` | Client Layer 2 | Mandatory thin repository boundary over the API. |
| `ProjectViewingService` | Client Layer 3 | Own list/detail claims, lifecycle/reconnect state, send serialization, stale-clear protection, and bounded retry of failed connected declarations. |
| Session list/detail cubits | Client Layer 4 | Declare/clear project claims after successful render; never depend on each other. |
| `PrHistorySection` / `SessionTile` | Flutter consumer | Render collapsed history with stable per-session expansion state and Prego tokens. |

No listener emits SSE or transport messages. No handler/cubit imports a Layer 1
type. No repository depends on a repository peer. `Orchestrator` is the only
bridge class that constructs/wires across layers; `BridgeRuntime` owns lifecycle
only. `BridgePluginApi` remains a Layer 1 source for session data and is absent
from all PR-monitor services and client contracts.

### Root-session persistence and branch flow

```text
plugin root session.created OR successful root-session list
  -> SessionMutationDispatcher / GetSessionsHandler
  -> SessionRepository persists identity, plugin, project, exact directory
  -> SessionBranchDao watch emits the trackable root set
  -> SessionBranchListener groups by normalized absolute git HEAD watch key
  -> one SessionBranchRepository-backed OS subscription per key
  -> repository resolves `git symbolic-ref --short -q HEAD`
  -> transaction rechecks trackability and writes current/history
  -> Stream<SessionBranchChanged>
     -> Orchestrator emits sessionsUpdated for a real current-branch change
     -> PrBranchChangeListener refreshes only if the project is viewed
```

The API resolves the git `HEAD` path with `git rev-parse --git-path HEAD`; the
repository converts a relative result to an absolute normalized path. The raw
filesystem source watches its parent so atomic replacement is observed. The
listener performs an initial branch resolve, shares subscriptions by watch key,
and retries failed watch setup with bounded jittered backoff only while a
session remains trackable. This is failure recovery, not periodic git polling.

`SessionBranchRepository.resolveAndPersist` re-reads the session inside its
transaction. Before terminal state exists it requires `archived_at IS NULL`;
after S02-W03 it requires `pr_tracking_stopped_at IS NULL`. An archive race
therefore either commits before the archive transaction freezes it or observes
the terminal marker and emits nothing.

### Project-presence flow

```text
SessionListCubit / SessionDetailCubit
  -> ProjectViewingService
  -> ProjectViewRepository
  -> ProjectViewApi
  -> RelayControlClient -> ConnectionService -> RelayClient
  -> RelayProjectView(projectId?)
  -> Orchestrator
  -> ProjectViewTracker
  -> Stream<ProjectViewChange>
  -> activation/scheduled/branch listeners
```

The client service owns separate list and detail claims; detail wins in split
or nested navigation, and clearing detail falls back to a still-mounted list
claim. Hidden/paused/detached lifecycle enqueues one null transition and retains
intended claims; a failed connected clear retries the latest null generation.
Because project presence has no mark-seen effect, resume and a foreground
reconnect reassert the effective project. A reconnect while hidden remains
dormant until resume. Every queued send reads current state when it executes.
Unexpected send failure while the relay remains connected retries the latest
project/null intent at bounded one-shot backoff; navigation, disconnect, or
dispose supersedes/cancels that generation.

### GitHub refresh flow

```text
GetSessionsHandler compatibility trigger
ProjectViewPrRefreshListener
ScheduledPrRefreshListener
PrBranchChangeListener
ArchivePrRefreshListener
  -> PrRefreshDispatcher
     -> SessionBranchRepository (live scope/path)
     -> PrSourceRepository -> GhCliApi
     -> PullRequestRepository (live cache only)
     -> SessionArchiveRepository (terminal snapshot only)
  -> Stream<PrRefreshCompletion>
  -> Orchestrator -> sessionsUpdated(projectId) only for rendered changes
```

The dispatcher serializes by project. Every request has an opaque id and typed
origin; one execution completion carries all satisfied ids/origins after
coalescing. Live open requests may coalesce; a queued
live all-state request supersedes weaker queued open work. Archive-final
requests are never dropped or merged into live requests. Every waiter receives
a result at least as strong as requested for the same target. The dispatcher
never autonomously retries `identityChanged`; a still-eligible originating
handler/listener may issue one all-state follow-up.

### Session read flow

```text
POST /sessions
  -> SessionRepository obtains plugin/catalog session payload
  -> read-only SessionBranchDao + PullRequestDao + ArchivedSessionPullRequestDao
  -> live rows: current branch + complete branch associations + verified cache
  -> terminal rows: immutable archived snapshot only
  -> current headline + descending history mapper
  -> Session.pullRequest + non-null Session.pullRequestHistory
  -> SessionListCubit -> SessionTile -> PrHistorySection
```

## 6. Locked Decisions

1. Implementation uses `main`; first-wave branches do not start from the
   legacy plan branch.
2. This seven-PR plan completes before parallel-plugin Stage 2 begins. The
   parallel-plugin plan must receive explicit stale-plan re-review afterward;
   the workstreams do not interleave.
3. Record every named branch observed at each root session whose PR tracking has
   not terminally stopped.
4. Persist the exact reported root-session directory. Migration may backfill
   from non-null stored `worktree_path`, otherwise the owning project's persisted
   `path` through its FK; it never treats an unknown id as a filesystem path.
5. Sessions sharing a checkout intentionally observe the same live branch and
   may associate the same PRs.
6. Detached `HEAD` has no current branch and creates no history row; existing
   history remains.
7. The headline is the highest-numbered associated PR on the current named
   branch regardless of state. History is every other associated PR, newest PR
   number first.
8. GitHub discovery is same-repository and authored by the active `gh` account.
   Fork-head/cross-repository PRs are excluded.
9. Repository-wide open/all discovery supports the newest 1,000 authored rows
   before cross-repository rejection. Commands request 1,001 so truncation is
   explicit; incomplete results never delete cache rows merely because they are
   absent. Pagination to recover same-repository rows displaced by more than
   1,000 newer fork-head rows is explicitly deferred.
10. Local branch observation runs for every nonterminal root session,
    independent of phone presence. GitHub network scheduling runs only while at
    least one connection views the project.
11. Project activation and a newly recorded branch while viewed request
    all-state reconciliation. Steady scheduling requests open reconciliation;
    a successful all-state run is forced at least every ten minutes.
12. Poll at 15 seconds when the complete supported open result contains any PR
    authored by `@me`, otherwise at 90 seconds. Failure backoff starts at the
    greater of the normal tier and 30 seconds, doubles with fresh +/-20% jitter,
    and caps at five minutes.
13. Every persisted current-branch change invalidates the affected project
    immediately even if GitHub is unavailable or cache data is unchanged.
14. Session-list and session-detail surfaces both count as viewing the project;
    any connected client keeps it active.
15. Archive synchronously resolves the latest local `HEAD`, performs existing
    cleanup checks, commits terminal state plus an immediate verified snapshot,
    returns, and then publishes exactly one final async request.
16. Unknown active GitHub identity clears a non-empty terminal snapshot. A PR
    query failure retains a snapshot only after the same final job freshly
    confirmed the same login. Archive-final never follows identity change and
    never retries.
17. Unarchive retains existing worktree/session restoration but never clears
    the PR stop marker, restarts branch observation, or switches reads away from
    the terminal snapshot.
18. PR changes reuse `sessionsUpdated` and never affect unseen state.
19. `Session.pullRequestHistory` uses an honest empty transport default and is
    non-null throughout modern bridge/client APIs.
20. Both existing `waitForPrData` paths remain. The awaited path keeps the
    five-second response budget; the non-wait path remains a compatibility
    fire-and-forget trigger for clients that never declare project view.
21. New PR tables/cache keys carry `owner_identity = "local"`; Sesori ownership
    and GitHub login remain separate. GitHub login is never sent to clients.
22. One runtime writer owns each concern: `SessionRepository` exact directory,
    `SessionBranchRepository` current/history branch state,
    `PullRequestRepository` live PR cache/login, and
    `SessionArchiveRepository` terminal stop/snapshot state.
23. Branch/refresh/archive triggers are peer Layer 4 listeners over typed
    streams. `Orchestrator` wires them; peers never reference each other.
24. Visible live PR rows must match the active project cache's GitHub login,
    canonical lowercase `owner/name` repository identity, and verified project
    path. Moving a stable project id to another path hides old rows immediately.
25. Account/repository changes are detected by existing refresh triggers rather
    than a blocking check on every cache-first read. Detection atomically nulls
    project cache login before query, retains rows physically, and emits rendered
    change; fresh verification is required to re-expose them.
26. A complete open refresh finalizes at most one disappeared row with `gh pr
    view`; two or more disappearances upgrade the same execution to one bounded
    all-state list.
27. Coalesced dispatcher completions carry satisfied request ids/origins.
    Scheduled polling rearms only from activation-origin or its own request-id
    completions, and an unsuccessful overdue all-state waits bounded backoff
    instead of zero-delay deadline retries.
28. Project-view sends distinguish disconnected from failed-connected outcomes.
    Disconnected relies on bridge connection release/reconnect reassertion;
    failed-connected sends retry the latest generation at 1s, 2s, 4s... capped
    at 30s so visible activation and hidden null cannot remain lost indefinitely.

## 7. Backward Compatibility and Migration

### Shared contract compatibility

`Session.pullRequest` remains unchanged. S01-W01 adds:

```dart
// COMPATIBILITY <implementation-date> (v1.5.0): Bridges before PR-history support omit pullRequestHistory, which means no legacy history beyond pullRequest. Remove @Default and make the field required after the minimum supported bridge always sends pullRequestHistory.
@Default(<PullRequestInfo>[]) List<PullRequestInfo> pullRequestHistory,
```

The worker substitutes the actual implementation date and re-reads the declared
application version immediately before implementation. New bridges always emit
the list; new clients receive empty history from old bridges. Old clients ignore
the additive JSON key.

`RelayProjectView` is additive. Old bridges already isolate an unknown union
variant at relay-message parsing and keep the connection alive; new clients
therefore fall back to the existing request-driven refresh behavior. S01 lands
decode support before S03 sends the variant.

S02-W02 adds this source marker immediately above the non-wait request trigger,
and S03-W02 audits/preserves it when deleting the old sync facade:

```dart
// COMPATIBILITY <implementation-date> (v1.5.0): Clients before project-view declarations rely on non-wait /sessions requests to start PR refresh. Remove this fire-and-forget trigger after the minimum supported client always declares project view; keep the awaited explicit-refresh path.
```

The awaited explicit pull-to-refresh remains a current product behavior and is
not marked compatibility-only.

### Drift workflow

S02-W01, S02-W02, and S02-W03 each own one cohesive migration. At the audited
tip the schema is v10, so absent intervening migrations they become v11, v12,
and v13. Each step instead reads current `main` and allocates `N+1` at execution.

For every migration:

1. Pin the wave baseline and run `dart run drift_dev make-migrations` from
   `bridge/app/` before table edits to preserve the current schema export.
2. Modify source tables/DAOs and increment `schemaVersion` exactly once.
3. Run `dart run drift_dev make-migrations` again.
4. Implement only generated migration callback bodies; never hand-edit schema
   JSON or other generated content.
5. Run bridge-wide code generation.
6. Add `SchemaVerifier.migrateAndValidate` plus old-row data-integrity, FK,
   cascade, key, and rollback tests.
7. Preserve every schema version already merged to `main`; conflicts move this
   plan's pending migration forward rather than rewriting history.

### Persistence migrations

- **S02-W01:** add non-null session `directory`, nullable
  `current_branch_name`, and owner-scoped `session_branch_history`. Backfill
  directory from stored worktree or FK-joined project path. Seed one history row
  and current branch from a non-empty legacy `branch_name`, including archived
  rows, while only unarchived rows enter runtime observation.
- **S02-W02:** rebuild/extend the global PR cache with non-null
  `owner_identity = "local"`, nullable verified `github_author_login`, nullable
  canonical `github_repository_identity`, and key
  `(owner_identity, project_id, pr_number)`. Add nullable project cache login,
  repository identity, and verified project path. Legacy verification fields
  remain null and are hidden until an authored all-state refresh verifies them.
- **S02-W03:** add nullable `pr_tracking_stopped_at` and owner-scoped
  `archived_session_pull_requests`. Existing archived sessions receive
  `pr_tracking_stopped_at = archived_at`; migration snapshots only rows whose
  non-null author/repository match project cache identity and whose verified
  cache path equals current project path. It performs no network work.

Rollback before new terminal/random state is written may use the previous
binary against additive columns only if its Drift compatibility is verified.
Once terminal snapshots/stop markers exist, rollback requires a binary that
understands those fields; release notes identify that minimum version.

## 8. Rollout and Verification

### Release-safe ordering

1. S01 lands additive shared decode/model support with no behavior change.
2. S02-W01 records branch state but does not start GitHub scheduling.
3. S02-W02 replaces request-driven PR internals while retaining both shipped
   request triggers.
4. S02-W03 atomically lands terminal writes and immutable reads; no build can
   write a stop marker without snapshot support.
5. S02-W04 routes project-view declarations on the bridge and adds scheduling
   before any client sends them.
6. S03-W01 adds client declarations; older bridges safely ignore them.
7. S03-W02 adds presentation and removes only dead `PrSyncService` internals.

Every merged PR leaves standalone/headless bridge and mobile release paths
viable. No feature flag, desktop supervisor, plugin capability, or relay/auth
server deployment is required.

### Global verification strategy

- Unit-test each API command shape, parser, mapper, repository writer, state
  machine, timer, identity race, and lifecycle path with deterministic clocks
  and fake process/filesystem streams.
- Migration-test structure and representative old data at each new schema
  version; never rely only on current-schema tests.
- Integration-test branch event -> durable state -> dispatcher -> cache -> SSE
  -> client re-fetch with fake Git/GitHub sources.
- Widget-test headline prominence, collapsed/default history, expansion
  stability, archived snapshot, no-history parity, text scale, and adaptive
  widths.
- Run fatal-info analysis for changed Dart modules and downstream desktop
  consumers of shared/module-core contracts.
- Execute the advisory manual checkpoint in S03-W03 when credentials and a
  disposable GitHub repository are available; record separate User and Worker
  evidence in `TRACKER.md`.

### Observability

- Every recovered filesystem, git, `gh`, timer, final-refresh, or disposal
  failure logs context with the error/stack argument and explains why
  continuation is safe.
- Typed failures returned to an originating listener/handler are not logged in
  the dispatcher first; the recovering origin logs once.
- Unsupported/non-GitHub projects, missing `gh`, unauthenticated `gh`, identity
  change, command timeout, and truncated query are distinct outcomes rather
  than empty authoritative PR lists.
- Cache suspension logs the detected account/repository/path reason and whether
  rendered data changed; retained rows are not reported as deleted.
- Truncation logs project/repository, mode, and the supported 1,000-row bound.
  It preserves absent cache rows and remains visible in tests; no new telemetry
  subsystem is built.
- `Orchestrator` remains the only SSE owner and emits only when rendered branch
  or PR data changed.

### Security

- GitHub credentials remain inside the local `gh` CLI; the bridge stores no
  token and sends no GitHub login to clients.
- Active-login/repository capture and recheck plus row/project/path verification
  prevent detected account or repository changes from leaving prior cache
  visible. Normal reads stay cache-first and detection occurs at the next
  existing refresh trigger rather than by blocking every response on `gh`.
- Only canonical same-repository authored PRs are accepted;
  cross-repository/fork-head observations are rejected before writes.
- Relay encryption, local zero-knowledge posture, managed-mode separation, and
  per-bridge addressing remain unchanged.

## 9. Risks and Deferrals

| Risk | Decision / mitigation |
|---|---|
| Parallel-plugin schema/session rewrites conflict | Finish this plan first without interleaving; explicitly stale-re-review the parallel-plugin plan afterward. |
| Filesystem watch misses atomic replacement | Resolve absolute git `HEAD`, watch its parent, perform initial read, dedupe events, and test worktree gitdir paths. |
| Watch setup fails for missing/permission-denied path | Log and use cancellable jittered retry while the row remains trackable; never infer another path. |
| More than 1,000 authored PRs, including fork heads | Fetch 1,001 before same-repository rejection, mark truncation, retain the newest 1,000 pre-filter rows, preserve absent cache rows, and report that older same-repository rows may be displaced. Full pagination is deferred. |
| `gh` hangs or is slow | Explicit process timeouts, one per-project dispatcher, five-second legacy wait budget, completion-based timers, bounded retry, and at most one per-row finalization before all-state upgrade. |
| `gh auth switch` races writes | Capture login, verify every returned author, recheck before transaction, suspend old visibility when detected, discard stale results, and allow one origin-owned follow-up. Cache-first reads intentionally detect at the next trigger. |
| Stable project id moves to another repository | Bind visible rows to canonical repository identity and verified project path; path mismatch hides immediately and refresh suspends on source mismatch. |
| Short-lived PR opens and closes between open polls | Successful all-state reconciliation at least every ten minutes while viewed. |
| Same checkout links one PR to multiple sessions | Explicitly accepted; share the watcher but persist/session-map independently. |
| Laptop-created root switches before phone fetch | Persist exact `session.created` root through the mutation dispatcher before unseen handling; DAO watch enrolls it. |
| Old client never declares project presence | Keep request-driven compatibility triggers with exact marker and cleanup condition. |
| Archived display mutates from live cache | Snapshot table and terminal-only read path land atomically with the stop marker. |
| Unknown/stale GitHub identity on archive final | Fail closed on unknown login/repository; clear mismatch before query; retain only after fresh same-identity confirmation. |
| Timer/viewer leak after disconnect | Per-connection tracker, explicit release, relay-drop clear, listener cancellation tests. |
| Client declaration send fails while relay stays live | Keep the latest project/null generation pending and retry with capped one-shot backoff; cancel on superseding intent, disconnect, or disposal. |
| PR status changes conversation unseen | No dependency on unseen repository/service/tracker; regression tests across all stages. |
| Desktop lacks this UI | Deferred until shared accessory UI exists; desktop compiles against additive contracts now. |
| Forge-neutral abstraction | Deferred until comments/check actions create a concrete second forge need; current scope uses existing local GitHub CLI. |

## 10. Stage Map

| Stage | Outcome | Waves |
|---|---|---|
| S01 — Additive contracts | New bridge/client code can decode project presence and non-null history without behavior changes. | W01: S01-W01-P01 |
| S02 — Durable bridge monitoring | Branch history, authored PR cache, terminal snapshots, viewed-project scheduling, and SSE invalidation are complete on the bridge. | W01: S02-W01-P01; W02: S02-W02-P01; W03: S02-W03-P01; W04: S02-W04-P01 |
| S03 — Client presence and history | Mobile declares project presence, renders collapsed history, removes dead sync code, and completes integration verification. | W01: S03-W01-P01; W02: S03-W02-P01; W03 advisory: S03-W03-M01 |

Waves are strict merge barriers. No stacked PRs are planned. Every PR in a wave
must merge to `main` before the next wave begins. The sole manual checkpoint is
advisory and does not block plan closure or any later wave.

## 11. Plan-Specific Detail

### Exact GitHub command contract

`GhCliApi` executes these shapes through the existing injected `ProcessRunner`:

```text
gh --version
gh api user --hostname github.com --jq .login
gh repo view --json nameWithOwner --jq .nameWithOwner
gh pr list --state open --author @me --json number,url,title,state,headRefName,isCrossRepository,mergeable,reviewDecision,statusCheckRollup,author --limit 1001
gh pr list --state all --author @me --json number,url,title,state,headRefName,isCrossRepository,mergeable,reviewDecision,statusCheckRollup,author --limit 1001
gh pr view <number> --json number,url,title,state,headRefName,isCrossRepository,mergeable,reviewDecision,statusCheckRollup,author
```

Commands run in the project's persisted live path. Login, repository, and
single-PR commands use a 15-second timeout; list commands use 30 seconds. The
repository identity is normalized to lowercase `owner/name`. A `gh pr view` call never
receives the list-only `--author` flag, so its parsed `author.login` must equal
the request's captured active login before acceptance.

The list DTO reports `truncated = rows.length == 1001` and exposes only the
first 1,000 rows. A complete result may replace branch-matched rows for the
captured login. A truncated result may upsert returned rows and finalize a
specifically queried known PR, but it does not delete rows absent from the
partial result or claim complete history.

### Refresh policies

Activation/all-state:

1. Resolve GitHub availability, active login, canonical repository identity,
   and cached GitHub-remote eligibility.
2. Resolve/persist every active root session's current named branch and read the
   complete durable branch union. On the first post-migration verification,
   include archived-only durable branch history without touching archived paths.
3. Before query, suspend old visibility if cached path/repository/login differs;
   if current identity cannot be verified, suspend and stop.
4. Query all states with the 1,001-row contract; reject cross-repository or
   mismatched-author rows.
5. Recheck active login/repository. On difference or failure, suspend old
   visibility, discard observations, and return typed identity failure.
6. Atomically upsert/replace supported branch matches and project cache
   login/repository/path metadata. Only a complete result deletes absent
   branch-matched rows.
7. Publish a rendered-change completion only when headline/history output can
   differ.

Steady open refresh:

1. Query authored open PRs and derive the 15/90 tier from the complete supported
   result before branch matching.
2. Upsert matching open rows.
3. If exactly one previously cached open row is absent from a complete result,
   run one `gh pr view`; if two or more are absent, upgrade to one all-state list
   in the same serialized execution. Accept only same-author/repository results.
4. A truncated open result does not treat absence as closure.
5. Recheck login/repository before one transaction and apply the same
   suspension/identity-change rule.
6. Schedule the next one-shot timer from completion time, never start time.

Continuous-view all-state deadline:

- Each viewed project tracks its last successful all-state completion.
- The scheduled listener caps the next delay at the remaining ten-minute
  deadline and upgrades that trigger to all-state when due.
- Failed, unavailable, identity-changed, or truncated all-state attempts do not
  consume the deadline. New signals remain independently eligible.
- If the deadline is already overdue and the due all-state attempt is
  unsuccessful, bounded failure backoff temporarily overrides the zero deadline
  remainder; the next timer remains all-state and cannot spin immediately.

### Persistence shape

`sessions_table` additions:

- `directory TEXT NOT NULL` — exact root-session working directory;
- `current_branch_name TEXT NULL` — current named branch or null; and
- `pr_tracking_stopped_at INTEGER NULL` — irreversible PR terminal marker.

`session_branch_history`:

- key `(owner_identity, session_id, branch_name)`;
- non-null `owner_identity`, `first_seen_at`, and `last_seen_at`;
- FK session delete cascade.

`pull_requests_table` additions/rekey:

- key `(owner_identity, project_id, pr_number)`;
- non-null `owner_identity`;
- nullable `github_author_login` and `github_repository_identity`, hidden until
  both match non-null project cache metadata and the cache's verified path equals
  current `projects.path`.

`projects_table` cache metadata:

- nullable `pr_cache_github_login`;
- nullable canonical `pr_cache_repository_identity`; and
- nullable `pr_cache_project_path`.

`archived_session_pull_requests`:

- key `(owner_identity, session_id, pr_number)`;
- verified author login and repository identity, branch, URL, title, typed
  status fields, original creation/check times, and non-null snapshot time;
- FK session delete cascade.

### Terminal archive sequence

1. Synchronously attempt `SessionBranchRepository.resolveAndPersist` before any
   destructive cleanup. A local failure is logged and the last durable branch is
   used so archive remains available.
2. Run existing worktree/branch cleanup validation and operations.
3. In one `SessionArchiveRepository` transaction, write `archived_at`, write the
   irreversible stop marker, freeze current/history branches, and snapshot only
   global-cache rows verified against project cache login/repository and current
   verified project path.
4. Return the archived session from the immutable snapshot read path.
5. Publish an archive-final request containing session id, project id/path,
   frozen branches, captured snapshot login, and repository identity.
6. The archive listener delegates one all-state attempt. Unknown login or
   repository clears a non-empty snapshot. Mismatch clears and emits change
   before querying the new identity. Same-login/repository query failure retains
   the snapshot. Success rechecks both and atomically replaces the full snapshot.
7. No retry, pending sentinel, startup recovery, later project-poll mutation, or
   unarchive restart exists.
