# Current-Branch Pull Request Monitoring

## Status

- **Plan slug:** `session-pull-request-monitoring`
- **Status:** Approved — Step 1/9 merged; Step 2.a/9 PR [#662](https://github.com/sesori-ai/sesori_apps_monorepo/pull/662) open
- **Plan revision date:** 2026-08-01
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main`
- **Latest audited tip:** `edff10828f17a45c40ba5bc02db109977a856411`
- **Existing contract baseline:** [#457](https://github.com/sesori-ai/sesori_apps_monorepo/pull/457) shipped additive
  `RelayProjectView` and `Session.pullRequestHistory` contracts.
- **Delivery:** one plan PR, nine sequential implementation PRs, and
  one plan-retirement PR.

This document and `TRACKER.md` are the sole current implementation authority.

## Goal

Show one useful GitHub pull request beside each root session:

1. resolve the root session directory's current named Git branch;
2. find same-repository PRs whose head branch exactly matches it;
3. show the newest open PR, including drafts; otherwise show the newest merged
   or closed PR; and
4. keep that branch and PR fresh while any connected client device views the
   project.

Dedicated and non-dedicated sessions follow the same rule. A branch switch
immediately changes association scope. If the new branch has no matching PR,
the session shows no PR; it never falls back to one from a prior branch.

Git and GitHub behavior remains headless-bridge-owned and plugin-agnostic. No
OpenCode, Codex, Cursor, ACP, or future backend behavior crosses
`BridgePluginApi` for this feature.

## Success Criteria

1. Every root session response displays the most recently resolved named branch
   from its exact persisted `directory`; child sessions have no independent PR
   association.
2. Detached `HEAD`, a missing/non-git directory, a non-GitHub remote, or a
   branch with no matching PR produces no PR and never reuses a prior branch's
   PR.
3. For an exact lowercase GitHub repository identity plus case-sensitive head
   branch, selection is newest open PR first, then newest merged/closed PR,
   ordered by GitHub `createdAt DESC` and PR number descending.
4. PR author is irrelevant. A same-repository coworker PR is eligible; a
   fork-head/cross-repository PR is not.
5. One GraphQL request can batch several active repository/branch targets and
   returns repository, branch, state, mergeability, review decision, and latest
   check-rollup state through the installed authenticated `gh` CLI.
6. Normal session loads remain cache-first. Project activation, each configured
   refresh cycle, branch changes discovered by that cycle, and explicit
   pull-to-refresh resolve local branch state before GitHub selection.
7. One device connection declares at most one viewed project. The bridge unions
   declarations across devices, refreshes different viewed projects together,
   deduplicates shared targets, and releases only the disconnected/backgrounded
   device's claim.
8. One bridge-wide refresh interval defaults to 30 seconds. The JSON setting is
   read at startup; a successful client settings mutation persists it and
   updates the running timer without a file watcher.
9. PR/branch changes reuse project-scoped `sessionsUpdated`; they never mutate
   conversation unseen state and never send push notifications.
10. Archive has no PR-specific behavior: no stop marker, snapshot, final
    attempt, pause, or resume path is introduced.
11. `Session.pullRequestHistory` remains empty. No multiple-PR/history UI or
    desktop-shell-specific implementation is added.
12. Every implementation PR is independently releasable, preserves old/new
    client-bridge compatibility, and passes directly relevant analysis/tests.

## Locked Product Decisions

### Session and branch scope

- Root sessions only. Child tasks do not duplicate their root's PR status.
- Resolve `SessionTable.directory` for dedicated and non-dedicated roots alike.
- Sessions sharing one directory intentionally share its current branch and
  selected PR.
- Resolve on activation, every scheduled cycle, and explicit refresh. Do not
  add filesystem watchers or retain visited branches.
- A named branch is the only associable state. Detached/unknown has no branch
  and no PR.
- The persisted creation/cleanup `branch_name` remains untouched. A separate
  internal current-branch field owns observed display state.

### PR selection

- GitHub.com only, through the user's installed/authenticated `gh` CLI.
- Match canonical base-repository identity and exact head branch.
- Accept any author in that repository; reject `isCrossRepository == true`.
- Select and retain at most one newest open or terminal PR per target. Query
  ordered candidate pages only as far as needed to skip ineligible fork heads;
  those transient candidates are not persisted as PR history.
- Draft PRs are open and eligible.
- “Most recent” means GitHub creation time, with PR number as a deterministic
  tie-breaker.
- Cache only the selected current-target projection. Successful complete
  refreshes remove rows outside the project's current target set.

### Presence and cadence

- Session-list and session-detail screens both count as viewing the project.
- One connection has one effective project. Multiple connections/devices may
  view different projects simultaneously.
- Presence is connection-scoped, not account-global. Background/disconnect
  clears only that connection; foreground reconnect reasserts it.
- One bridge listener owns one non-overlapping timer for the union of viewed
  projects. It batches their unique repository/branch targets rather than
  creating a timer per project.
- Use a fixed interval, not the old 15/90-second adaptive state machine.
- Default to 30 seconds. Persist a custom integer in seconds per bridge. The
  implementation validates a conservative 15–3,600 second range.
- A client settings PATCH updates the running listener immediately. Manual
  edits to `~/.config/sesori/config.json` require bridge restart because no file
  watcher is added.
- Explicit pull-to-refresh retains the existing five-second bounded wait.

### Presentation and lifecycle

- Continue using the existing `Session.pullRequest` and `PrStatusRow`.
- `Session.branchName` becomes the bridge's best current named-branch
  presentation. Older bridges continue supplying the creation branch as
  graceful degraded behavior; database cleanup still uses its separate stored
  creation field.
- No previous-branch fallback, history disclosure, PR detail route, mutation,
  comments, or check-run detail.
- The product client UI is shared by mobile and the eventual full desktop
  client. Do not add feature code to the current `client/desktop` bridge-control
  shell; validate it only as a downstream consumer of shared/module-core code.
- Archive is ordinary session metadata and does not participate in PR logic.
- PR changes affect neither unseen timestamps nor notifications.

## Non-Goals

- PRs from a coworker's fork or another head repository.
- More than one selected PR per root session.
- Branch or PR history, visited-branch retention, archive snapshots, or final
  archive refreshes.
- Always-on branch observation or GitHub work while no client views a project.
- GitHub Enterprise, GitLab, other forges, direct token storage, or GitHub web
  API credentials outside local `gh`.
- Review comments, individual checks, labels, assignees, commits, or PR
  mutations.
- Push notifications, unseen activity, or client-side offline caching.
- Backend-plugin capability or behavior changes.
- A new analytics event or warehouse model.

## Current Repository Baseline

The audited `main` tip is
`10c7afb9ff55d7fe91d15a48e1ef8ba08e7a3484` (2026-07-31). Parallel plugins are
complete through PR #497. Current implementation constraints are:

- Drift is schema v12, not v10
  (`bridge/app/lib/src/api/database/database.dart`).
- `SessionTable` already has stable Sesori/backend/plugin identity, parent/root
  hierarchy, and non-null exact `directory`. Its nullable `branchName` remains
  dedicated-worktree creation/cleanup metadata.
- Project/root/detail/child reads are database-only. Catalog import updates
  projection-owned fields without overwriting worktree state.
- `SessionLifecycleService` now owns archive/cleanup orchestration; no
  PR-specific archive work is required.
- `PrSyncService` remains request-driven, per-project, 30-second debounced, and
  lists only open PRs. It matches the project cache to stored creation branch.
- `GhCliApi` still runs repository-scoped `gh pr list`/`gh pr view`; it does not
  expose GraphQL batches or GitHub creation timestamps.
- `PullRequestsTable` is keyed by `(project_id, pr_number)` and has no canonical
  repository/login scope. `PullRequestDao` joins it to `SessionTable.branchName`.
- `SessionRepository` still prefers open PRs then highest number and maps only
  `Session.pullRequest`. `pullRequestHistory` decodes but remains empty.
- `RelayProjectView` is shipped in shared code but is ignored by the bridge and
  never sent by clients.
- `SessionViewTracker` proves connection-scoped declaration/release behavior,
  but it is mark-seen-specific and must remain separate.
- The session tile already renders `session.branchName` and
  `session.pullRequest` through `PrStatusRow`; no new PR display widget is
  required.
- `BridgeSettingsRepository` persists
  `~/.config/sesori/config.json`; `PluginLifecycleService` demonstrates
  client-driven live settings mutation but its private mutation tail does not
  serialize another settings domain.
- PR #647 has merged and consolidates Harness management into
  `harnesses_settings_screen.dart`. Step 8 uses that merged numeric-bottom-sheet
  pattern where useful but keeps PR cadence in a separate bridge settings row.

### External GitHub evidence

The 2026-07-31 GitHub CLI/API contracts were checked against installed
`gh 2.97.0` and current official documentation:

- `gh search prs --repo A --repo B` returns the union of repositories, but its
  JSON fields omit `headRefName`, mergeability, review decision, and check
  rollup, so it is not the production data source.
- GraphQL `Repository.pullRequests` accepts `headRefName`, `states`, `first`,
  and `orderBy`.
- One GraphQL document can alias several repository/branch targets and return
  rich PR fields in one `gh api graphql` invocation.
- GitHub search's 1,000-result window is irrelevant to the final exact-target
  query. Each target uses its repository connection and paginates only when
  newer fork-head candidates obscure an eligible same-repository PR.

Implementation must recheck the CLI schema at Step 3 rather than assume an
unversioned hosted API never changes.

## Final Architecture

Dependencies continue to flow Foundation -> API -> Repository -> Service ->
Consumer. Existing legacy files may be modified in place; new production
classes use current top-level layer directories.

### Local target resolution

```text
active project ids or explicit project id
  -> SessionDao reads root rows only
  -> PrSourceRepository deduplicates exact session directories
  -> GitCliApi resolves symbolic current HEAD + preferred remote URL
  -> GitRemoteIdentityParser produces host + canonical slug
  -> github.com + named branch targets only
  -> local transaction persists current branch/repository scope
     and invalidates stale selected rows before network work
```

`GitCliApi` is a dumb command wrapper. `PrSourceRepository` maps command results
to typed target variants such as named GitHub target, detached, unsupported,
missing, or failed. It does not write another repository.

The local phase commits even when `gh` is missing or slow. A branch/repository
change can therefore clear a stale prior PR and emit `sessionsUpdated` without
waiting for GitHub.

### Batched GitHub selection

`GhCliApi` builds one variable-bound GraphQL document for a bounded batch of
unique lowercase-repository/case-sensitive-branch targets. Each initial alias
requests a bounded page and cursor metadata for both state groups:

```graphql
open: pullRequests(
  headRefName: $branch
  states: [OPEN]
  first: 10
  orderBy: {field: CREATED_AT, direction: DESC}
)
terminal: pullRequests(
  headRefName: $branch
  states: [MERGED, CLOSED]
  first: 10
  orderBy: {field: CREATED_AT, direction: DESC}
)
```

The shared fragment includes number, URL, title, `createdAt`, state,
`headRefName`, `isCrossRepository`, mergeability, review decision, the latest
commit's aggregate check-rollup state, and typed `pageInfo`. The API parses
generated typed DTOs; it does not pass raw JSON maps through layers.

The source filters each ordered page before selection. When a page contains
only ineligible fork heads, it follows that connection's cursor until it finds
an eligible same-repository candidate or exhausts the connection. It also reads
through an equal-`createdAt` page boundary before applying PR-number tie-breaks.
Open pagination completes before terminal fallback. Follow-up cursors for
different targets are coalesced into the same bounded command where possible;
candidate pages exist only in memory and never become stored history.

The production batch bound is 20 unique targets per command. Larger active
sets are sorted and split into deterministic chunks inside one refresh cycle.
Every chunk reports the authenticated viewer login; all initial/paginated
chunks and one final identity recheck must agree before cache writes.
Cross-repository candidates are discarded. The repository selects open first,
otherwise terminal, and verifies the returned repository/branch against the
requested target.

### Persistence and read flow

One Drift migration allocates the next schema version on then-current `main`:

- `sessions_table.current_branch_name TEXT NULL` — latest resolved named branch;
- `sessions_table.current_github_repository_identity TEXT NULL` — lowercase
  `owner/repo` for the exact session directory;
- `projects_table.pr_cache_github_login TEXT NULL` — non-null only while rows
  are visible under a freshly verified active login; and
- `pull_requests_table.github_repository_identity TEXT NOT NULL` plus
  `github_login TEXT NOT NULL`, with primary key
  `(project_id, github_repository_identity, pr_number)`.

The migration cannot honestly infer current branches, repository identities, or
active GitHub login. It leaves new session/project scope null and rebuilds the
ephemeral PR cache empty. The first request/view refresh repopulates it. It does
not alter `sessions_table.branch_name`.

`PullRequestRepository` remains the sole PR-cache writer. It uses raw DAOs in a
transaction to:

1. compare the captured current root-session directory/project scope;
2. apply local current branch/repository updates and delete no-longer-matching
   selected rows;
3. suspend project visibility when GitHub login changes or becomes unknown;
4. replace only the complete requested project's current selected target rows;
   and
5. return project ids whose rendered branch or PR changed.

`SessionRepository` reads DAOs directly and has no repository peer dependency.
Every handler path that can map a cached PR first asks `PrSyncService` for a
fresh typed `gh` identity result, without waiting for branch or GraphQL work.
The handler passes the verified login (or explicit absence) into required
nullable parameters on the repository's PR-bearing reads. Live mapping joins
project id, current repository, current branch, project cache login, row login,
and that read-scoped verified login. Unknown/failed verification yields the
session and branch without a PR; it can never default to the last persisted
login. This keeps reads cache-first while preventing an out-of-band
`gh auth switch` from exposing the prior account's private metadata.

The join can produce only current-target candidates; its defensive selector
orders open first, then GitHub creation time/number. Shared
`Session.branchName` maps from `current_branch_name`; the stored creation branch
continues to serve cleanup code only.

`Session.pullRequestHistory` is never populated by this plan.

### Refresh and multi-device scheduling

```text
GetSessionsHandler wait/non-wait compatibility requests
ProjectViewTracker active-set transitions
ViewedProjectPrRefreshListener one-shot timer
  -> PrSyncService one serialized batched refresh
  -> local target commit
  -> GraphQL target chunks
  -> selected-cache commit
  -> renderedChanges stream
  -> Orchestrator -> sessionsUpdated(projectId)
```

`PrSyncService` evolves in place into the single refresh owner; do not add a
parallel dispatcher plus facade. It accepts a set of project ids and exposes
typed completion/rendered-change results. One cycle runs at a time. Before local
target resolution begins, the service seals that cycle's per-project request
generations. A later request advances its project's generation and enters one
coalesced pending set even when the same project is already in flight. Completion
atomically drains pending generations into one immediate follow-up cycle, so a
newly viewed project or a same-project branch switch cannot be dropped and no
cycles overlap. Explicit waiters complete only after a cycle whose sealed
generation covers their request. The listener's next interval starts from the
final drained completion.

`ProjectViewTracker` owns `connectionId -> projectId?`, per-project counts, and
typed active-set changes. `Orchestrator` routes `RelayProjectView`, releases one
connection on disconnect, clears all on relay loss, and remains the only SSE
owner.

`ViewedProjectPrRefreshListener` owns exactly one timer for the aggregate active
set. A 0->nonzero transition or newly added project requests an immediate cycle.
The final viewer leaving cancels future work; an already-running cycle may
finish. Interval changes cancel/rearm the pending timer without spawning a
second loop.

### Bridge settings

`BridgeSettings` adds root JSON key `pullRequestRefreshIntervalSeconds`, default
30. Missing uses the default. Non-integer/out-of-range manual values warn and
repair to 30 at startup. No file watcher is added.

`BridgeSettingsRepository` gains one callback-scoped serialized mutation seam
used by plugin and PR settings writers so concurrent devices/settings domains
cannot lose each other's fields. Successful writes publish the in-memory
settings stream.

New shared request/response models back GET/PATCH
`/settings/pull-request-refresh`. A focused bridge settings service validates
15–3,600 seconds, persists through the repository, and returns the committed
value. The listener consumes the repository/service stream and updates live.

### Shared client behavior

`ProjectViewApi -> ProjectViewRepository -> ProjectViewingService -> cubits`
uses the shipped `RelayProjectView` contract. The service owns separate list and
detail claim records with explicit visibility, one effective visible project,
send ordering, lifecycle, reconnect, and late-clear protection. Unlike session
viewing, project presence has no mark-seen side effect, so a foreground
reconnect/resume reasserts only the currently visible effective claim. The
service consumes the existing pure-Dart `RouteSource`; the thin adaptive shell
reports only whether the wide list pane is actually mounted.

- `SessionListCubit` records its project only after a successful list snapshot.
  The service treats the direct sessions route as visible and the list claim as
  visible on child routes only while the shell reports the wide left pane.
  Covered narrow routes such as new-session therefore clear the list claim
  without waiting for cubit disposal.
- `SessionDetailCubit` records its loaded root project's id. The service treats
  only the direct session-detail route as detail-visible; while that claim loads,
  it retains the same-project ready list claim as a transition handoff so
  list -> detail sends no false null. A child diffs route hides the detail claim
  even while the provider remains mounted. Child detail uses its root/project
  association; it does not create child PR state.
- Cubit close remains final cleanup, but route/pane transitions drive visibility
  first. List/detail claims for one navigation stack cannot transiently clear the
  same visible project; detail precedence falls back only to a currently visible
  list pane or the same-project direct-detail transition handoff.
- Old bridges ignore the additive control message; both existing request refresh
  paths remain as fallback.

Client settings use a focused API, repository, service, and cubit. The current
settings screen adds one bridge section row and Prego numeric bottom sheet; it
does not add another route. A successful PATCH updates the displayed committed
value. Older bridges returning 404 are rendered as unsupported rather than an
app failure.

## Compatibility, Security, and Failure Behavior

### Client/bridge version skew

- `Session.pullRequest` and `Session.branchName` keep their wire shapes.
- Modern bridges send current `branchName`; old bridges continue sending the
  creation branch. Add a dated compatibility comment at the mapping/model seam
  explaining this degraded old-bridge behavior.
- `pullRequestHistory` keeps its shipped empty default and remains empty.
- `RelayProjectView` is already additive. Old bridges ignore it and continue
  request-driven refresh.
- Keep `waitForPrData: false` as a non-blocking refresh trigger for old clients
  that never declare presence. Keep `waitForPrData: true` as explicit refresh
  with its existing five-second budget. Add the exact dated compatibility marker
  only to the non-wait legacy trigger.
- New settings APIs return 404 on old bridges; clients show unsupported.

### Identity and source privacy

- Tokens remain owned by local `gh`; the bridge stores no GitHub token and sends
  no GitHub login to clients.
- Repository identity is canonical lowercase `owner/repo`; branch names remain
  case-sensitive and are never logged at normal levels or reported to analytics.
- Every GraphQL chunk carries one authenticated login. A mismatch/unknown login
  suspends visibility before another account's data can be written or exposed.
- Before any session response can include cached PR metadata, a fresh typed
  identity check gates the repository join. Unknown, failed, or switched login
  omits PR metadata immediately without deleting another account's cache.
- A newly resolved branch/repository invalidates the previous selected PR before
  network work, preventing same-name branches in a moved project from reusing
  stale metadata.
- Same-repository enforcement uses both requested base repository and
  `isCrossRepository == false`.
- Logs never contain source paths, branch names, repository slugs, PR titles,
  URLs, raw GraphQL payloads, or raw errors that may embed those values.

### Failure behavior

- Missing `gh`, unauthenticated GitHub, unsupported remote, detached HEAD, and
  command/query failure are distinct typed outcomes, not successful empty data.
- Local branch changes commit and invalidate stale PRs even if GitHub fails.
- A transient GitHub query failure under the same freshly verified identity may
  retain the same current-target cached PR; identity/repository/branch change
  never does.
- A failed read-time identity check fails closed for PR presentation while
  still returning non-sensitive session and current-branch data.
- A complete successful target with no candidate clears that target's selected
  row.
- Recovered failures log once at the recovering service/listener with typed,
  privacy-safe context. Explicit failures returned to callers are not double
  logged.
- Timer failures wait the configured fixed interval; no adaptive backoff or
  zero-delay retry state is added.

## Analytics Decision

No product analytics event is added. PR association is passive rendering, not a
confirmed user action, and branch/repository/PR context is prohibited. The
interval setting mutation alone does not yet drive a defined product or
investor decision that justifies a warehouse/reporting surface. Existing
settings screen analytics continue unchanged.

## Cleanup Assessment

- Step 2 replaces the unscoped ephemeral PR-cache key instead of carrying
  unusable rows or compatibility columns forward; migration rebuilds that cache
  empty because no valid repository/login backfill exists.
- Step 3 removes the repository-wide open-list/per-disappeared-PR source path
  and its directly obsolete tests, fakes, and comments once every consumer uses
  exact-target GraphQL selection.
- Keep `sessions_table.branch_name`: it still owns worktree cleanup and is not
  made obsolete by the separate current-branch display field.
- Keep the empty `Session.pullRequestHistory` wire field for released
  client/bridge compatibility; no producer, storage, or UI is added for it.
- No other data, generator, watcher, setting, or presentation path becomes
  obsolete under the current scope.

## Delivery Rules

- The series has nine top-level steps, with Step 2 delivered through ordered
  2.a–2.c PRs. Every title uses the fixed denominator and substep form below.
- Step 1 raises this complete plan and updates the repository, Plan Maker, and
  Plan Worker PR communication rules. It changes `.plan/**`, root `AGENTS.md`,
  and the two agent definitions only, so it runs documentation/config validation
  rather than Dart/Flutter suites.
- Every PR body states complexity, what, why, risk/test focus, and expected
  user-visible/data/internal results; an absent impact is explicit rather than
  omitted.
- Step 9 contains no production change. It records completion and moves
  `.plan/active/session-pull-request-monitoring/` to
  `.plan/completed/session-pull-request-monitoring/`.
- Steps merge in numeric order. Each implementation branch starts from current
  `main` after its predecessor merges and re-audits declared paths/schema/open
  overlapping PRs.
- Target no more than 1,500 additions plus deletions per implementation PR,
  including generated code and tests. Do not combine adjacent steps because one
  is small.
- Step 1 necessarily exceeds the soft cap because it consolidates the active
  plan into three top-level documents while deleting several thousand lines of
  redundant stage files in the same atomic change. Splitting those files would
  leave more than one implementation authority during review.
- Step 2.b is expected to exceed 1,500 because one Drift table rekey, generated
  schema/steps, migration callback, transactional writer adaptation, and
  migration tests must ship together. Its 9,800–10,800 target reflects the
  current generator's required v12 and v13 migration helper classes plus the v13
  snapshot and application outputs. Splitting the v12 helper into an earlier PR
  would ship thousands of lines of unused test support without an independently
  valid behavior or verification outcome. Record actual generated size and seek
  another coherent split if production/test logic—not generated migration
  output—causes extra overage.
- Step 3 is expected to exceed 1,500 because the typed GraphQL response model
  generates roughly 700 Freezed/JSON lines and the coherent source replacement
  deletes roughly 900 lines of obsolete repository-wide list/view tests and
  fakes. Splitting before integration would either ship unused GraphQL machinery
  or retain both source paths, so the evidence-based target is 3,100–3,500
  changed lines including generated output and deletions.
- Step 4 is expected to exceed 1,500 because current-branch persistence and the
  request-generation drain must replace the old creation-branch/per-project
  refresh state machine atomically: shipping only local resolution would retain
  the known same-project post-seal request drop while presenting the result as
  current. Roughly 1,000 changed lines delete obsolete service tests/fakes and
  roughly 700 replace persistence/service coverage around the new invariants.
  Review hardening added exact directory and checkout-race fences, explicit
  refresh policy, isolated batched-write failures, and their regressions, so the
  later review hardening also bounded refresh/fallback work and coalesced
  background requests, so the final evidence-based target is 4,000–4,200
  changed lines including deletions.
- Never hand-edit generated files. Internal Dart contracts update every
  in-repository consumer in lockstep.
- Run `aristotle-impl-review` for Steps 2.a–8 because they alter production
  persistence, APIs, ownership, lifecycle, public/wire contracts, or cross-layer
  flow. Do not run it for documentation-only Steps 1 or 9.

## Fixed PR Series

| Step | Branch | Exact PR title | Complexity rationale | Changed-line target | Outcome |
|---|---|---|---|---:|---|
| 1/9 | `plan/session-pull-request-monitoring/replan-current-pr-only` | `🌿 [session-pull-request-monitoring] docs: plan current PR monitoring [step 1/9]` | Documentation/instruction/agent-definition changes only, with no runtime behavior. | 4,000–7,000 | Publish this reviewed plan/tracker and the reusable PR communication/cleanup rules. |
| 2.a/9 | `session-pull-request-monitoring-scoped-source` | `⚙️ [session-pull-request-monitoring] feat(bridge): scope GitHub PR queries [step 2.a/9]` | Typed identity/repository evidence and deterministic repository-pinned CLI queries. | 500–900 | Make the existing request-driven source verify its active login and canonical repository before querying that repository explicitly. |
| 2.b/9 | `session-pull-request-monitoring-scoped-pr-persistence` | `🚧 [session-pull-request-monitoring] feat(bridge): persist scoped PR selections [step 2.b/9]` | Drift migration, generated artifacts, transactional writer ownership, and scoped cache joins. | 9,800–10,800 | Migrate current branch/repository/login scope and the repository-keyed ephemeral PR cache while preserving request-driven behavior. |
| 2.c/9 | `session-pull-request-monitoring-scoped-pr-reads` | `🚧 [session-pull-request-monitoring] feat(bridge): gate scoped PR reads [step 2.c/9]` | Fresh request identity gating, list/detail failure behavior, and privacy-sensitive regressions. | 1,200–1,700 | Require fresh login evidence for every PR-bearing read and fail closed without blocking session/catalog data. |
| 3/9 | `session-pull-request-monitoring-graphql-selection` | `🚧 [session-pull-request-monitoring] feat(bridge): batch exact PR selection [step 3/9]` | Typed dynamic GraphQL batching/pagination, identity fencing, and deterministic selection. | 3,100–3,500 | Replace repository-wide open-list CLI reads with typed exact-target GraphQL batching and open/terminal selection. |
| 4/9 | `session-pull-request-monitoring-current-branch-refresh` | `🚧 [session-pull-request-monitoring] feat(bridge): refresh current session branches [step 4/9]` | Git/process resolution, persisted scope, cache races, and cross-layer rendering. | 4,000–4,200 | Resolve every root's current branch/repository on each request refresh, scope selected cache, and map the live branch. |
| 5/9 | `session-pull-request-monitoring-view-scheduler` | `🚧 [session-pull-request-monitoring] feat(bridge): schedule viewed-project PR refresh [step 5/9]` | Multi-device connection lifecycle and serialized add-during-flight scheduling. | 900–1,400 | Route per-connection project presence and run one fixed 30-second aggregate scheduler. |
| 6/9 | `session-pull-request-monitoring-bridge-settings` | `⚙️ [session-pull-request-monitoring] feat(bridge): configure PR refresh cadence [step 6/9]` | Localized persisted settings flow with concurrent writes and live timer updates. | 1,000–1,500 | Persist/validate interval settings, expose GET/PATCH, serialize settings writes, and rearm the live timer. |
| 7/9 | `session-pull-request-monitoring-client-presence` | `🚧 [session-pull-request-monitoring] feat(client): declare viewed projects [step 7/9]` | Shared list/detail lifecycle, reconnect ordering, and multi-device bridge behavior. | 1,000–1,500 | Add layered client project presence with list/detail, lifecycle, reconnect, and multi-device-safe bridge behavior. |
| 8/9 | `session-pull-request-monitoring-client-settings` | `🚧 [session-pull-request-monitoring] feat(client): configure PR refresh cadence [step 8/9]` | Shared settings layers, compatibility UI, and end-to-end bridge/client regression coverage. | 1,000–1,500 | Add shared client interval settings, compatibility UI, final integration verification, and current-branch/PR regressions. |
| 9/9 | `session-pull-request-monitoring-retire-plan` | `🌱 [session-pull-request-monitoring] docs: retire current PR monitoring plan [step 9/9]` | Mechanical documentation state/move after implementation completion. | 50–200 | Record completion and move the plan directory from active to completed. |

## Implementation Steps

### Step 1/9 — Durable plan and PR guidance

Scope:

- Publish the current-branch architecture and tracker as one plan authority.
- Consolidate execution guidance into the top-level plan files.
- Record the fixed top-level sequence and emoji-prefixed titles, line budgets, existing PR #457
  contract baseline, current code baseline, open-PR drift, and final retirement
  step.
- Update root repository guidance, Plan Maker, and Plan Worker with the reusable
  complexity scale and required PR summaries; add feature cleanup
  assessment/execution rules to the planning agents.
- Run `aristotle-plan-review` against the complete production plan.

Verification:

- `git diff --check`
- cross-check every title/step total/branch in `PLAN.md` and `TRACKER.md`
- confirm only this plan directory, root `AGENTS.md`, and the two requested
  agent definitions changed

### Step 2.a/9 — Scoped GitHub source queries

Scope:

- Pin current `main` and record drift from the merged plan baseline.
- Add typed active-login verification and canonical lowercase GitHub
  `owner/repo` resolution at the API/repository boundary.
- Require the existing request-driven writer to obtain both pieces of evidence
  before GitHub work and pass canonical `owner/repo` through every repository
  layer.
- Pin repository-wide `gh pr list` and `gh pr view` calls with `--repo` so
  `GH_REPO` or another CLI default cannot redirect data under the wrong scope.
- Keep the existing unscoped database shape and read behavior unchanged; Steps
  2.b and 2.c own persistence and fresh read gating respectively.

Acceptance:

- Identity verification failure skips source refresh without claiming the user
  is signed out.
- Non-GitHub, malformed, or unavailable remotes cannot start a PR query.
- Every PR list/view command targets the canonical repository explicitly.
- No database, wire, client, timer, or settings behavior changes.

Verification:

- `GhCliApi`, canonical remote, and `PrSyncService` source-scope tests
- bridge fatal-info analysis and focused/full tests as warranted
- `git diff --check` and changed-line count

### Step 2.b/9 — Scoped PR persistence

Scope:

- Pin current `main`; export the current Drift schema before source edits and
  allocate exactly one next migration.
- Add internal current branch/repository fields, project cache login, and
  repository/login-scoped PR rows/key.
- Rebuild legacy cache empty because no valid repository/login backfill exists.
- Keep creation `branch_name` unchanged.
- Adapt the Step 2.a request-driven writer to populate the required row scope in
  one repository-owned transaction before the GraphQL source lands.
- Join cached rows to persisted project login and session repository/branch
  scope without adding fresh request-time identity gating yet.
- Preserve established PR scope when catalog publication updates project or
  session rows.
- Add schema verifier, old-row, key/FK/cascade, and cache-empty migration tests.

Acceptance:

- Existing project/session/catalog identities and cleanup metadata survive.
- Old unscoped PR rows cannot become visible after migration.
- Request-driven refresh can repopulate scoped rows on the next request.
- No project presence, timer, or client behavior ships.

Verification:

- Drift schema/code generation and migration tests
- focused DAO/repository/session mapping tests
- bridge analyze/tests for changed modules
- generated-line count and overage rationale recorded in tracker

### Step 2.c/9 — Fresh scoped PR reads

Scope:

- Thread the Step 2.a repository-produced `VerifiedGithubLogin` evidence into
  every PR-bearing `SessionRepository` read explicitly.
- Have list/detail handlers verify identity freshly before mapping cached PR
  metadata; explicit absence returns the session and branch without a PR.
- Add the read-scoped login to persisted project/row/repository/branch joins.
- Treat scoped cache selection as authoritative during enrichment, clearing
  incoming PR/history data before applying a freshly selected row.
- Propagate refresh failure to waited list handling so timeout/source/query
  failures return sessions without cached PR metadata.

Acceptance:

- Switching or invalidating `gh` identity between two session reads prevents
  the second response from exposing the first login's cached PR metadata.
- Failed or timed-out waited refreshes preserve session/catalog data while
  stripping PR metadata.
- Catalog reads remain database-owned; only privacy-sensitive PR enrichment
  depends on fresh identity evidence.
- No project presence, timer, settings, client, or wire behavior ships.

Verification:

- session mapping tests for same/switched/unknown/failed identity
- list/detail read-gate and waited-refresh failure tests
- bridge fatal-info analysis and focused/full tests as warranted
- `git diff --check` and changed-line count

### Step 3/9 — Exact GraphQL selection

Scope:

- Add generated typed GraphQL response DTOs and `createdAt` mapping.
- Add bounded variable/alias query construction to `GhCliApi`; no manual raw-map
  business parsing.
- Query bounded ordered open and terminal candidate pages per exact target,
  include viewer identity, and paginate past cross-repository/mismatched results
  only until an eligible winner or exhaustion.
- Extend `PrSourceRepository` with typed batch targets/outcomes.
- Evolve request-driven `PrSyncService` to use the final batch API and replace
  current selected rows; remove the repository-wide open-list and
  per-disappeared-PR finalization paths plus their directly obsolete tests,
  fakes, and comments.
- Preserve the current `/sessions` trigger behavior.

Acceptance:

- A coworker-authored same-repository PR is selected.
- Newest open wins; absent open falls back to newest merged/closed.
- A fork-head PR, wrong repository, wrong branch, or older candidate cannot win.
- A newer fork-head candidate cannot hide an older eligible same-repository PR.
- Multiple repo/branch targets use one command up to the batch bound.
- Complete no-match clears; typed query failure does not masquerade as empty.

Verification:

- exact initial/cursor query/variables, fork-only page, equal-time boundary, and
  20-target split tests
- DTO enum/check-rollup/null/error tests
- source/repository/service selection and identity tests
- bridge fatal-info analysis and focused/full tests

### Step 4/9 — Current-branch request refresh

Scope:

- Add `GitCliApi` named-current-branch resolution and repository mapping for
  each exact root-session directory.
- Read root sessions only, dedupe shared directories/targets, and persist local
  current branch/repository scope before GitHub work.
- Make one `PrSyncService` call accept a set of project ids and serialize its
  local/network/write phases.
- Seal per-project request generations before local target resolution; queue
  requests arriving after that seal for one coalesced follow-up even when their
  project is already in the active cycle.
- Gate joins on project id + repository + branch + project cache login + fresh
  read-scoped verified login; replace only complete current-target selections.
- Map shared `Session.branchName` from the current field and keep cleanup paths
  on creation `branch_name`.
- Remove prior-branch fallback and emit rendered changes from local and network
  phases.

Acceptance:

- Dedicated and non-dedicated roots behave identically by exact directory.
- Shared-directory roots share branch/PR; children have none.
- Branch A -> branch B with no PR immediately shows B and no PR.
- Detached/non-git produces no branch/PR; a named branch with a non-GitHub or
  missing remote still displays its branch while producing no PR.
- Same branch with a transient same-identity GitHub failure may retain its
  selected row; changed branch/repo/login cannot.
- Normal and explicit session loads preserve cache-first/five-second behavior.
- An explicit refresh arriving after its project's cycle generation was sealed
  waits for the follow-up generation and can observe a branch switch made during
  the first cycle.

Verification:

- root/child/shared-directory/dedicated/detached/missing/path-move tests
- request false/true timeout, same-project post-seal branch-switch, generation
  coalescing, and SSE change-only tests
- account/repository/branch race and privacy-safe logging tests
- bridge fatal-info analysis and focused/full tests

### Step 5/9 — Multi-device view scheduling

Scope:

- Add `ProjectViewTracker` with connection -> project ownership, counts, active
  set changes, release-one, and clear-all.
- Route the shipped `RelayProjectView` in `Orchestrator`.
- Add one `ViewedProjectPrRefreshListener` with immediate activation and one
  completion-based fixed 30-second timer for the active union.
- Batch different devices' projects through the same `PrSyncService` cycle.
- Feed projects added during an in-flight cycle into the service's pending
  generation drain before rearming the interval.
- Cancel future work when the active set empties; integrate disposal.
- Keep request-driven old-client triggers.

Acceptance:

- Devices A/B viewing projects X/Y keep both active; disconnecting A removes X
  only when no other connection claims it.
- Duplicate viewers/targets do not duplicate GraphQL aliases.
- Relay drop clears all timers; foreground reassertion can activate again.
- No timer runs with an empty active set and cycles never overlap.
- A project first viewed during another project's cycle is covered by the
  immediate follow-up rather than waiting one full interval.
- PR changes still do not touch unseen or push subsystems.

Verification:

- tracker multi-connection and late-clear tests
- deterministic fake-clock activation/add-during-flight/timer/completion/
  disposal tests
- orchestrator routing/drop/SSE tests
- bridge fatal-info analysis and focused/full tests

### Step 6/9 — Bridge cadence settings

Scope:

- Add `pullRequestRefreshIntervalSeconds` to `BridgeSettings`, default 30, with
  startup repair/validation for 15–3,600.
- Add one callback-scoped serialized settings mutation seam and migrate touched
  plugin settings writers to it to prevent cross-domain lost updates.
- Add shared GET/PATCH request/response models and bridge handlers/service for
  `/settings/pull-request-refresh`.
- Publish successful in-process settings changes and make the listener
  cancel/rearm its pending timer with the committed interval.
- Do not watch the JSON file.

Acceptance:

- Missing key uses/writes 30; invalid manual value warns and repairs at startup.
- Concurrent plugin and PR interval mutations preserve both values.
- PATCH persists and changes the running timer without restart.
- Manual file edit alone has no live effect and takes effect after restart.
- Values outside 15–3,600 receive a typed 400 response.

Verification:

- settings parse/repair/round-trip/concurrent-mutation tests
- handler/service range and persistence tests
- fake-clock live timer rearm tests
- shared codegen/round-trip tests
- bridge/shared fatal-info analysis and tests

### Step 7/9 — Shared client project presence

Scope:

- Add `ProjectViewApi`, `ProjectViewRepository`, and singleton
  `ProjectViewingService` in module-core.
- Add the minimal Layer-0/connection send seam for caller-built project view
  declarations; do not couple it to session mark-seen state.
- Own list/detail claim precedence, one effective project, serialized sends,
  background null, resume/reconnect reassertion, and stale-clear protection.
- Integrate `SessionListCubit` after successful list render and
  `SessionDetailCubit` after loaded session/project resolution, with both claims
  carrying readiness and generation ownership.
- Inject the existing pure-Dart `RouteSource` into `ProjectViewingService` for
  covered-route transitions. Add a thin app-shell signal for actual wide
  split-list-pane presence; the service composes route, pane presence, and ready
  claim records into one effective project.
- Regenerate DI. Do not add `client/desktop` feature code.

Acceptance:

- List and detail each activate the project; list -> detail -> list does not
  send a false null.
- Narrow list -> new-session clears the claim and returning reasserts it; a wide
  split list remains claimed while its left pane is actually visible.
- Detail -> diffs hides the detail claim despite the mounted provider; a visible
  wide list may remain effective. Resume/reconnect under a covered route cannot
  reassert a hidden claim.
- Same-project list -> detail preserves one effective claim while detail data
  loads; failed/cancelled detail routing then recomputes from the current route
  and pane rather than retaining a stale handoff.
- Cross-project navigation and late clear cannot erase the new claim.
- Background clears once; foreground reconnect/resume reasserts.
- Each physical device sends its own declaration; bridge tests from Step 5 prove
  their union.
- Old bridge ignore behavior leaves request-driven refresh working.

Verification:

- API/repository/service lifecycle/reconnect/send-order tests
- list/detail direct navigation, narrow covered-route, wide split-pane,
  detail/diffs, resume-under-cover, load failure, close, and race tests
- module-core codegen, fatal-info analysis, and tests
- mobile and desktop downstream analysis/tests required by shared changes

### Step 8/9 — Shared client settings and final integration

Scope:

- Re-audit current settings ownership before editing, using merged PR #647's
  consolidated Harness screen only as a proven input/mutation pattern.
- Add module-core settings API/repository/service/cubit for GET/PATCH, numeric
  planning, unsupported old bridge, mutation uncertainty, and committed value.
- Add one localized Prego settings row/bottom sheet in the product client's
  existing settings owner; custom integer seconds, default display 30, range
  15–3,600.
- Keep current session row/`PrStatusRow` presentation; add no history UI.
- Complete fake Git/GitHub/relay integration for view -> branch -> batch ->
  selected cache -> `sessionsUpdated` -> refetch -> shared row.
- Run final bridge/shared/client/mobile/desktop verification.

Acceptance:

- Successful update displays and applies the bridge-committed value live.
- Invalid input dispatches nothing; disconnected/unsupported/failure states are
  clear and retryable; an uncertain sent mutation refreshes before another send.
- Branch changes never show a previous branch's PR.
- Current open then newest terminal selection renders through existing status
  UI on supported widths/themes/text scales.
- No history, archive special case, unseen change, push, or analytics event is
  introduced.

Verification:

- module-core API/repository/service/cubit tests
- settings widget/localization/accessibility tests
- session row current branch/PR/no-match/detached tests
- bridge fake-source end-to-end and old/new compatibility tests
- full relevant bridge/shared/client workspace matrix

### Step 9/9 — Retire plan

Scope:

- Confirm Steps 2.a–8 merged and required verification/findings are recorded.
- Mark the tracker complete.
- Move the entire directory unchanged except final state from
  `.plan/active/session-pull-request-monitoring/` to
  `.plan/completed/session-pull-request-monitoring/`.
- Make no production/test/config change.

Verification:

- `git diff --check`
- confirm no active plan directory remains and completed plan retains history
- confirm only `.plan/**` changed

## Risk Register

| Risk | Decision / mitigation |
|---|---|
| Current branch overwrites cleanup branch | Separate internal current fields; creation `branch_name` remains the only cleanup value. |
| Same-name branch after project/repository move | Bind session and PR rows to canonical repository identity; invalidate local scope before GitHub. |
| Coworker PR is missed | No author filter; exact same-repository head branch is authoritative. |
| Fork PR collides by branch name | Reject cross-repository heads and page past newer fork candidates until an eligible same-repository PR or exhaustion; fork support is deferred. |
| Multiple devices view different projects | Per-connection tracker plus one active-set scheduler; batch/dedupe targets. |
| Mounted but covered client routes keep polling | Claims carry explicit visibility from `RouteSource` plus actual split-pane presence; resume reasserts visible claims only. |
| Refresh/timer/config races or duplicate work | Per-project request generations sealed before local resolution, one serialized drain with a coalesced pending set, one completion-based timer, and callback-scoped settings mutation. |
| `gh auth switch` exposes prior private metadata | Fresh read-scoped identity gating, login-gated rows, per-chunk identity, final recheck, and fail-closed visibility suspension. |
| GraphQL query becomes too large | Deterministic 20-target chunks in one refresh cycle; no per-project timers. |
| GraphQL/`gh` is unavailable | Local branch still commits; cache-first sessions continue without PR metadata when identity is unverifiable; typed failure never becomes empty success. |
| Old clients never declare project view | Preserve both request-driven refresh modes and exact compatibility cleanup marker. |
| Old bridges ignore project view/settings | Request refresh remains; settings UI reports unsupported 404. |
| Settings paths continue evolving | Step 8 starts from current `main`; merged #647 is evidence, not a frozen path assumption. |
| Plan PR exceeds line cap | Atomic consolidation into the three authoritative plan files avoids competing active guidance during review. |
| Schema PR exceeds line cap | Generated migration/table-rekey output stays with source, callback, and migration proof; split non-generated behavior first if needed. |

## Completion Conditions

The feature is complete only when:

- every titled PR in the fixed top-level/substep sequence merges in order;
- the current session branch and one selected same-repository PR obey the locked
  rules for dedicated/non-dedicated/shared/detached cases;
- multi-device project presence and one configured bridge timer are proven;
- client settings update the bridge live and manual JSON edits require restart;
- compatibility, identity privacy, no-unseen/no-push/no-history invariants pass;
  and
- Step 9 moves this directory to `.plan/completed/`.
