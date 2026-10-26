# Remove pull request tracking

## Status and scope

- Status: planned 2026-10-25. The user chose to remove all of it (round 1, Q1 A, 2026-10-25), and then asked to
  remove the "which project is open" tracking with it (2026-10-25).
- Scope:
  - the PR mark on session rows;
  - the "Pull request refresh" setting;
  - the bridge's `gh` polling, PR lookup and live branch tracking;
  - the PR table and the PR-only columns;
  - the PR wire models;
  - project-view presence: the client's viewed-project declarations and the bridge's tracker (D7).
- Out of scope:
  - session-view presence, which unseen marks and plugin warm-up use;
  - a dedicated worktree's own branch;
  - the plain git calls.

## Outcome

- Session rows never show a PR.
- Settings has no "Pull request refresh" row.
- The bridge never runs `gh` and never calls GitHub.
- Pull-to-refresh no longer waits for PR data.
- The client no longer reports which project is open, and the bridge no longer tracks it.
- Roughly 11,000 hand-written lines go, about 95% of them deletions.

## Decisions

- **D1 — Remove all of it** (user, Q1 A). Sessions in a dedicated worktree, where the PR was always right, lose
  it too.
- **D2 — Keep what released apps need, inert.**
  - v1.9.1 apps require `BridgeSettingsResponse.pullRequestRefresh`. Without it they fail to load the whole
    bridge-settings card, YOLO and warm-up included.
  - So the bridge keeps:
    - sending that field;
    - accepting `PATCH /settings` with `pullRequestRefreshInterval`;
    - serving `GET /settings/pull-request-refresh` for apps older than v1.8.0;
    - persisting the interval.
  - None of it has any effect any more. Each piece gets a `COMPATIBILITY 2026-10-25 (v1.9.2)` marker. Its
    retiring condition: public apps older than v1.9.2 are unsupported.
  - The shared `BridgeSettingsResponse.pullRequestRefresh` becomes nullable in step 3, following the YOLO
    field's precedent in the same model. The bridge keeps sending it; the new app ignores it, so a later bridge
    can stop sending it without breaking the new app.
  - `waitForPrData` needs no marker. Removing the shared field in step 13 is enough: the bridge's parser ignores
    unknown keys, so a v1.9.1 app's `waitForPrData: true` still parses.
- **D3 — Drop the stored PR data.** Schema v21 drops `pull_requests_table`, `sessions_table.current_branch_name`,
  `sessions_table.current_github_repository_identity` and `projects_table.pr_cache_github_login`. The database is
  local to the bridge, so no wire obligation applies.
- **D4 — `Session.branchName` comes from the stored branch.** It maps from `row.branchName`, the dedicated
  worktree's branch. That matches its shared doc comment and the behaviour before v1.6.1, and v1.9.1 rows keep
  showing a correct branch for dedicated sessions.
- **D5 — Remove the client's pre-v1.8.0 settings fallback.** Its only content was the PR row, so a bridge older
  than v1.8.0 shows the usual "update the bridge" state instead.
- **D6 — The headless setup guide drops its optional `gh` steps.**
- **D7 — Remove project-view presence** (user, 2026-10-25).
  - Once PR polling goes, the voice glossary's warm-up is its only user.
  - The glossary keeps its other trigger. A composer's voice session loads `/project/current` when it opens, and
    that load starts population. The composer is the first place voice can be used, so the glossary is still
    built before the first recording.
  - A first recording made within a few seconds of opening a project's composer may go without the new glossary.
    This was already possible, and transcription works without it.
  - `RelayMessage.projectView` stays in shared, and the bridge ignores it, with a
    `COMPATIBILITY 2026-10-25 (v1.9.2)` marker. Retiring condition: public apps older than v1.9.2 are unsupported.
    Removing it now would log a parse warning for every navigation in a v1.9.1 app.
- **Related, decided separately:** dedicated worktrees start on a detached HEAD (user request 2026-10-25,
  round 2: Q2 B, Q3 A). It ships as its own series, `detached-worktrees`, which removes the generated-branch
  rename together with `SessionDao.replaceGeneratedBranch` and its current-branch guard. Step 12 depends on that
  removal, so it does not rework a guard that is about to go. Under D4, new detached sessions report no
  `branchName`.

## Current behavior (evidence, 2026-10-25, `origin/main` 04f9e375fb)

The inventory is in `/tmp` notes from 2026-10-25, re-checked on 04f9e375fb. Schema version 20 is the same as at
v1.9.1.

- **Client.**
  - The row mark is `pr_status_row.dart`, shown from `session_tile.dart`.
  - The setting row is `bridge_settings_section.dart`. Its state is in `BridgeSettingsCubit`, `BridgeSettingsReady`
    and the PR-only `ReadyLegacyPartial`, with the legacy fallback in `BridgeSettingsRepository`.
  - `SessionListService` keeps PR data across `session.updated` events.
  - `sessions.updated` is consumed by `SessionListCubit`, `RecentSessionInventoryService`, `SseEventTracker`
    (`sse_event_tracker.dart:140`) and `SessionDetailCubit`'s event filters.
  - `ProjectViewingService` (349 lines) declares the viewed project through `ViewDeclarationRepository`,
    `ConnectionService.sendProjectView` and `RelayClient.sendProjectView`. Session detail claims it
    (`claimProjectView`), wired through `cubit_composition.dart`, `session_scope.dart`, both routers and the
    desktop cockpit shell.
- **Bridge, polling.**
  - `PrSyncService` and `ViewedProjectPrRefreshListener` (interval timer) poll `gh` through `GhCliApi` and
    `PrSourceRepository`.
  - Results are stored by `PullRequestRepository` and `PullRequestDao`.
  - The orchestrator turns PR changes into `sessions.updated`, the event's only producer.
  - `ProjectViewTracker` feeds `ViewedProjectPrRefreshListener` and `ViewedProjectGlossaryListener`.
    `CurrentProjectGlossaryListener` triggers glossary population from `CurrentProjectService.loadedProjectIds`.
- **Bridge, routes.**
  - `POST /sessions` enriches with PR data within a 5 s budget, and waits when `waitForPrData: true`, which v1.9.1
    apps send on pull-to-refresh. `POST /session/detail` enriches too.
  - The settings routes carry the interval.
- **Plugins** pass `pullRequest: null` only because the shared field is required.
- **Already dead:** `GitCliApi.hasGitHubRemote` has no caller.

## Ownership and contracts

- **Shared, removed in the last step.**
  - `PullRequestInfo` and `pr_enums.dart`.
  - `Session.pullRequest` and `Session.pullRequestHistory`.
  - `SessionListRequest.waitForPrData`.
  - `SesoriSseEvent.sessionsUpdated`.
  - Every in-repository consumer, plugins included, updates in the same step.
- **Shared, kept** with D2 and D7 markers:
  - `BridgeSettingsResponse.pullRequestRefresh`;
  - `BridgeSettingUpdate.pullRequestRefreshInterval` and its rejection;
  - `PullRequestRefreshSettingsResponse`;
  - `RelayMessage.projectView`.
- **Bridge.**
  - **Deleted:**
    - `PrSyncService`, `ViewedProjectPrRefreshListener`, `PrSourceRepository`;
    - `GhCliApi` (with its models) and `GitCliApi.hasGitHubRemote`;
    - `PullRequestRepository` (with `pull_request_target.dart` and `pull_request_selection.dart`);
    - `pull_request_mapper`, `VerifiedGithubLogin`, `PullRequestDao` and `PullRequestsTable`;
    - `ProjectViewTracker` and `ViewedProjectGlossaryListener`.
  - **Also edited:** the benchmarks in `bridge/app/tool/benchmarks/`, which CI analyzes, in the step that breaks
    each of them.
  - **Kept, inert:** the settings repository and service keep reading and writing the interval, now with no
    effect. The orchestrator's `RelayProjectView` case becomes a marked no-op.
  - **Kept:** `CurrentProjectGlossaryListener`, `SessionViewTracker` and `getRemoteUrl`, which have other users.
  - **`GitCliApi.getCurrentBranch`** goes once both of its users are gone: `PrSourceRepository` (step 9) and the
    generated-branch rename (`detached-worktrees`). Whichever lands second deletes it, with
    `WorktreeRepository.getCurrentBranchName` and `GitCurrentBranchResult`.
- **Client.**
  - The settings cubit and state lose the PR interval and the legacy partial state.
  - The YOLO and warm-up rows lose their PR-mutation checks.
  - `ProjectViewingService`, its claims and `sendProjectView` are deleted. `sendSessionView` stays.

## Compatibility

- **v1.9.1 app on a new bridge.**
  - Rows lose their PR mark, and pull-to-refresh returns at once (`waitForPrData` is accepted and ignored).
  - The settings card still loads, and its PR refresh row still saves, with no effect.
  - The branch shows only for dedicated-worktree sessions.
  - Its `project_view` messages parse and are ignored (D7).
- **New app on a v1.9.1 bridge.**
  - The app no longer sends `project_view`, so that bridge stops its viewed-project polling and its view-based
    glossary warm-up. Its current-project glossary trigger still runs. Its list-read enrichment may still call
    `gh`.
  - The app ignores the PR fields.
  - Once the shared event is removed, a `sessions.updated` event is logged as an unknown event type.
- **New app on a bridge older than v1.8.0:** the settings card shows "update the bridge" (D5).

## Complexity budget

- **New state:** none.
- **New files:** none, except the v21 migration's generated schema files.
- **Not added:**
  - a replacement branch tracker;
  - any GitHub integration;
  - a feature flag;
  - a replacement glossary warm-up trigger.

## Cleanup

Everything listed under Ownership is removed, along with:
- `docs/regression/pull-request-monitoring.md` and its README link;
- the PR lines in `projects-and-sessions.md`, `diffs-and-source-control.md`, `bridge/AGENTS.md`,
  `bridge/ARCHITECTURE.md`, the root `README.md` and `docs/SETUP_HEADLESS_VM.md`;
- the active-view trigger in `voice-input.md`;
- the PR strings in `app_en.arb`.

`.plan/active/session-refresh-reconnects/PLAN.md` describes `sessions.updated` producers. Step 13 corrects that
text.

## Steps

The series has 13 steps. Each step updates the regression documents it touches, and deletes in the same step
any code, fixture or comment that the step makes obsolete.

| Step | Title | Estimate (changed lines, hand-written) | Depends on |
|---|---|---|---|
| 1 | 🌱 [pr-tracking-removal] Publish the plan [step 1/13] | 350 | — |
| 2 | 🌿 [pr-tracking-removal] Remove the PR mark from session rows [step 2/13] | 550 | 1 |
| 3 | 🌿 [pr-tracking-removal] Remove the pull request refresh setting [step 3/13] | 1,450 | 1 |
| 4 | 🌿 [pr-tracking-removal] Stop declaring the open project [step 4/13] | 1,200 | 1 |
| 5 | 🌿 [pr-tracking-removal] Session reads stop carrying PR data [step 5/13] | 1,700 | 1 |
| 6 | 🌿 [pr-tracking-removal] Stop polling pull requests [step 6/13] | 700 | 5 |
| 7 | 🌿 [pr-tracking-removal] Stop tracking the open project on the bridge [step 7/13] | 550 | 6 |
| 8 | 🌿 [pr-tracking-removal] Remove the PR sync service [step 8/13] | 1,650 | 7 |
| 9 | 🌿 [pr-tracking-removal] Remove the PR source lookup [step 9/13] | 1,000 | 8 |
| 10 | 🌿 [pr-tracking-removal] Remove the pull request repository [step 10/13] | 1,450 | 9 |
| 11 | 🌿 [pr-tracking-removal] Remove the gh client [step 11/13] | 1,300 | 9 |
| 12 | ⚙️ [pr-tracking-removal] Drop the stored PR data in schema v21 [step 12/13] | 1,300 + gen. | 5, 10, DW |
| 13 | 🌿 [pr-tracking-removal] Remove the PR wire models and retire the plan [step 13/13] | 550 | 2, 3, 4, 11, 12 |

- DW: `detached-worktrees` step 2, which removes the generated-branch rename.
- Client steps 2, 3 and 4 and bridge step 5 are independent. Bridge steps 5–12 are a chain over shared files.
- Steps 9–11 follow the imports:
  - `PrSourceRepository` and `PullRequestRepository` share the target, selection and `VerifiedGithubLogin`
    models, which step 10 deletes, so step 9 goes first;
  - after step 8, `PrSourceRepository` is the last user of `GhCliApi`, so step 11 needs only step 9.
- Step 13 must come last: the table uses `textEnum<PrState>`, and the client mark reads `PullRequestInfo`.
- With its dependencies merged, every step compiles on its own and keeps the D2 and D7 contracts.
- Steps 3, 5, 8 and 12 sit near the soft cap. If one measures well over it, split it as noted in its section.
  Splits are pre-approved.

### Step 2 — Remove the PR mark from session rows (🌿)

- **Changes.**
  - Delete `pr_status_row.dart` and its export.
  - Edit `session_tile.dart`.
  - Remove the `prLabel`, `prState*`, `prReview*`, `prChecks*` and `prConflicting` strings, and regenerate l10n.
  - Remove `SessionListService`'s PR carry-over.
  - Drop `waitForPrData: false` from `project_api.dart`.
- **Tests:** the row tests. **Docs:** the row text in `projects-and-sessions.md`.
- **PR body:** before and after row screenshots, using fixture data.

### Step 3 — Remove the pull request refresh setting (🌿)

- **Changes.**
  - Simplify the bridge-settings cubit, state, result, repository and API:
    - remove `BridgeSettingsService.updatePullRequestRefresh` (`bridge_settings_service.dart:63`);
    - remove the PR-only `validationBounds` from `BridgeSettingsFailure`, `BridgeSettingsReady` and the cubit.
  - Remove `ReadyLegacyPartial` and the `/settings/pull-request-refresh` fallback (D5).
  - Remove the setting row, its interval sheet, the YOLO and warm-up PR checks, and the
    `settingsPullRequestRefresh*` strings, then regenerate l10n.
  - Make the shared `BridgeSettingsResponse.pullRequestRefresh` nullable, with a
    `COMPATIBILITY 2026-10-25 (v1.9.2)` marker directly above it (D2).
- **Tests:**
  - phone and desktop settings tests, including "a 404 on `/settings` shows unsupported";
  - a client test that a `/settings` response without `pullRequestRefresh` loads.
- **Split if needed:** client first, then the shared nullability with its test.
- **PR body:** before and after Settings screenshots.

### Step 4 — Stop declaring the open project (🌿)

- **Changes.**
  - Delete `ProjectViewingService`, its claim types and its DI registration.
  - Remove the session-detail claim: `claimProjectView` in `SessionDetailCubit`, `cubit_composition.dart`,
    `session_detail_screen.dart` and `desktop_session_detail_screen.dart`.
  - Remove `AllSessionsCubit`'s list claim and wide-pane claim (`_ListClaim`, `beginListClaim`,
    `beginWideListPaneClaim`, `setWideListPaneVisible` and their releases), and whatever reports the pane's
    visibility to it.
  - Remove the `projectViewingService` wiring in `session_scope.dart`, `app_router.dart`, `desktop_router.dart`
    and `desktop_cockpit_shell.dart`.
  - Delete `sendProjectView` from `ViewDeclarationRepository`, its API, `ConnectionService` and `RelayClient`.
    `sendSessionView` stays.
  - Fixtures: `MockProjectViewingService`, `stubbedProjectViewingService` and the claim fallback values in
    `module_core/lib/src/testing/test_helpers.dart`, and the `claimProjectView` and `projectViewingService`
    arguments in the session-detail, all-sessions, desktop cockpit shell and view-declaration tests.
- **Tests:** `project_viewing_service_test.dart` goes; the remaining tests compile and pass.
- **Docs:** remove the active-view trigger from `voice-input.md`, keeping the current-project trigger.
- No user-visible change, so no screenshots.

### Step 5 — Session reads stop carrying PR data (🌿)

- **Changes.**
  - `get_sessions_handler` drops its `PrSyncService` dependency: the `verifyGithubIdentity` calls, the
    `enrichSessions` passes and `triggerRefresh`. It stops waiting on `waitForPrData`; the field stays in the
    shared request until step 13 and needs no marker (D2).
  - Remove PR enrichment from `get_session_handler` and `SessionRepository`, and the orchestrator wiring for
    those handlers.
  - Delete `pull_request_mapper`, `SessionRepository`'s `pullRequestDao` dependency and the `pullRequest:`
    parameter of `SessionCatalogMapper.map`.
  - Fixtures: the enrichment fakes and `pullRequestDao:` arguments in `routing_test_helpers.dart`.
  - Benchmarks: `pullRequestDao:` in `catalog_import_event_soak.dart:145`, `live_list_baseline.dart:434` and
    `event_projection_benchmark.dart:86` and `:332`.
  - Delete `pull-request-monitoring.md` and its index link.
  - Edit `diffs-and-source-control.md` and the root `README.md`.
- **Tests:** handler tests. `waitForPrData: true` returns without waiting.
- **Split if needed:** the handlers and their fixtures first, then the repository, mapper and benchmarks.

### Step 6 — Stop polling pull requests (🌿)

- **Changes.**
  - Delete `ViewedProjectPrRefreshListener` and the PR change → `sessions.updated` forwarding.
  - Delete `PullRequestRefreshSettingsService.changes` and `currentSettings`, which only the listener used.
  - Add D2 markers to the kept settings field, PATCH case, legacy route and settings service.
- **Tests:** settings handler tests show the field is still served and the PATCH still accepted.

### Step 7 — Stop tracking the open project on the bridge (🌿)

- **Changes.**
  - Delete `ProjectViewTracker` and `ViewedProjectGlossaryListener`, with their tests.
  - Remove their orchestrator construction, start, dispose, `clearAll` and `releaseConnection` calls, and the
    tracker's dispose step in `bridge_runtime.dart`.
  - The `RelayProjectView` case becomes a no-op with a `COMPATIBILITY 2026-10-25 (v1.9.2)` marker. Mark
    `RelayMessage.projectView` in shared the same way (D7).
- **Tests:** `project_glossary_listeners_test.dart` keeps the current-project cases; an orchestrator test shows a
  `project_view` message is accepted and changes nothing.

### Step 8 — Remove the PR sync service (🌿)

- **Changes.**
  - Delete `PrSyncService` and its test, and its orchestrator construction and drain.
  - Delete what only it used:
    - `SessionRepository.getStoredSessionsByProjectId` (`session_repository.dart:1301`);
    - the orchestrator's `PullRequestRepository` construction;
    - the imports left stale.
  - Fixtures: `FakePrSyncService` (`routing_test_helpers.dart:223`).
  - Map `Session.branchName` from `row.branchName` (D4), and remove the `COMPATIBILITY 2026-08-02 (v1.6.1)`
    comment in `session_catalog_mapper.dart` that explained the live-branch mapping.
- **Tests:** the session catalog mapper test covers the branch mapping.
- **Split if needed:** the branch mapping first, then the service removal.

### Step 9 — Remove the PR source lookup (🌿)

- **Changes.**
  - Delete `PrSourceRepository` and its test.
  - Fixtures: `_AlwaysReadyPrSource` (`routing_test_helpers.dart:276`).
  - If the `detached-worktrees` rename removal has merged, delete `GitCliApi.getCurrentBranch`,
    `WorktreeRepository.getCurrentBranchName` and `GitCurrentBranchResult`.
- `pull_request_target.dart` and `pull_request_selection.dart` stay until step 10, because
  `PullRequestRepository` still uses them.

### Step 10 — Remove the pull request repository (🌿)

- **Changes.**
  - Delete `PullRequestRepository`, `pull_request_target.dart`, `pull_request_selection.dart`,
    `VerifiedGithubLogin` and the FK regression test.
  - Remove `updatePullRequestScopes` and `setPrCacheGithubLogin`.
  - Fixtures:
    - `_NoopPullRequestRepository` (`routing_test_helpers.dart:301`);
    - `FakePullRequestRepository` (`fake_repository_fakes.dart:27`);
    - every `VerifiedGithubLogin` use.

### Step 11 — Remove the gh client (🌿)

- **Changes.**
  - Delete `GhCliApi`, the `gh_*` models and their tests, and the dead `GitCliApi.hasGitHubRemote` with its test
    file `test/bridge/api/git_remote_api_test.dart`.
  - Update `docs/SETUP_HEADLESS_VM.md` (D6) and `bridge/ARCHITECTURE.md`.
  - `bridge/AGENTS.md:104` and `:137` use `GhCliApi` as an example. Switch them to `GitCliApi` or
    `SesoriServerApi`.
  - `.agents/skills/architecture-plan-review/SKILL.md` and
    `.agents/skills/architecture-implementation-review/SKILL.md` use `GhCliApi` as an example. Switch them the
    same way.

### Step 12 — Drop the stored PR data in schema v21 (⚙️)

- **Changes.**
  - Delete `PullRequestDao` and `PullRequestsTable`.
  - Add the v20 → v21 step:
    - `DROP TABLE pull_requests_table` (and its index);
    - `TableMigration` rebuilds that drop the three columns, as earlier steps do (`Migrator.dropColumn`
      also works, on Drift 2.35.3 with SQLite 3.35 or newer);
    - then `PRAGMA foreign_key_check`.
  - Remove the column references:
    - `preservePullRequestScope` (`session_repository.dart:260`, `session_dao.dart:188` and `:233-234`,
      `test_database.dart:43`);
    - `SessionRepository._projectPlaceholder` (`session_repository.dart:1701`);
    - catalog import and project activity.
  - The current-branch guard in `replaceGeneratedBranch` is already gone with the `detached-worktrees` rename
    removal.
  - Benchmarks: the removed columns and `preservePullRequestScope` in `tool/benchmarks/`.
  - Regenerate the Drift schema files.
- **Tests.**
  - Rewrite the PR-column cases in `test/drift/default/migration_test.dart` (lines 184, 370, 759–803, 1528,
    1547 and 1780–1827) against the versioned schema classes or raw SQL.
  - Fixtures: `pullRequestInfoFromDto` (`routing_test_helpers.dart:928`, `:970`).
  - About 370 test lines that use the dropped columns: `session_repository_test` (82), `session_dao_test` (33)
    and `get_sessions_handler_test` (28), with the rest spread over smaller files.
  - A new migration test from a populated v20 database:
    - a project with sessions and worktrees, including a parent and a child session;
    - PR rows and stored branches;
    - sessions, projects, worktrees, the parent link and stored branches survive;
    - `PRAGMA foreign_key_check` returns nothing.
- **Split if needed:** the test-only column cleanups first, then the migration with its schema files.
- **PR body:** report generated versus hand-written churn.

### Step 13 — Remove the PR wire models and retire the plan (🌿)

- **Changes.**
  - Remove the shared PR models, `waitForPrData` and `sessionsUpdated`.
  - Update every consumer in the same step:
    - the plugins;
    - the client switches, including `SseEventTracker` and `SessionDetailCubit`'s event filters;
    - the `sessionsUpdated` consumers in `SessionListCubit` and `RecentSessionInventoryService`;
    - the test helpers, the `pullRequest: null` test lines and the benchmarks' `pullRequest: null`.
  - Correct the `sessions.updated` text in `session-refresh-reconnects/PLAN.md`.
- **Tests:** a `POST /sessions` body with `waitForPrData: true` parses and returns at once.
- **Then:** run the matrix below, record it in `TRACKER.md`, and move the plan to `.plan/completed/`.

## Verification and regression matrix

- **Highest level: L2 Routine**, plus a mixed-version release check. It deletes a feature and migrates the local
  database, but adds nothing new.
- **Unit and Drift tests:** each step's tests above, plus the v21 migration test against a v20 fixture.
- **Live dev bridge and a headless iOS simulator**, after step 13:
  - rows show no PR mark;
  - Settings has no PR row;
  - pull-to-refresh returns promptly;
  - the bridge log shows no `gh` call while a project is open;
  - opening a session's composer populates that project's glossary, and voice input then uses it;
  - an existing v20 data directory migrates, and its sessions, worktrees and archives still open.
- **Mixed versions.**
  - **A v1.9.1 app on the new bridge:**
    - the settings card loads with YOLO and warm-up;
    - saving the PR row is accepted;
    - pull-to-refresh returns;
    - a dedicated session shows its branch;
    - navigating logs no relay parse warning.
  - **The new app on a v1.9.1 bridge:** lists load, the bridge-settings card works, and voice input still gets
    the glossary.
- **Reductions.** Any reduction needs explicit user acceptance, recorded here before retirement. Accepted on
  2026-10-26: voice input using the glossary (A4 and C6). Headless simulators have no microphone; the glossary
  publication and key issuance before it passed.

## Risks and accepted behavior

- **Dedicated-worktree sessions lose their PR mark** (D1, accepted).
- **The v21 migration rebuilds `sessions_table` and `projects_table`.** A rebuild mistake could lose sessions,
  which is why step 12 tests a populated v20 database and checks foreign keys.
- **Inert settings and `project_view` stay in the wire contract** until released apps no longer use them (D2, D7,
  accepted).
- **A very early first recording may miss the glossary** (D7, accepted). Transcription works without it.
- **Older bridges may still call `gh`** on list reads while a new app is connected (accepted). They are released
  peers.
