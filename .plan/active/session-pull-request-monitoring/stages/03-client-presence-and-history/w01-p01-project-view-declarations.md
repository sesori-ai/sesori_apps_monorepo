# S03-W01-P01: Add Client Project-View Declarations

## 0. Metadata

- **ID:** S03-W01-P01
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Worktree:** one dedicated worker worktree for this PR
- **Base branch:** `main`
- **Branch:** `plan/session-pull-request-monitoring/s03-w01-p01-project-view-declarations`
- **Wave baseline:** pin the assessed current `main` tip after S02-W04 merges
- **Audited reference:** `e766684e0fdc22256419b7b99691021c9f14732d`
- **Contract-affecting:** Yes — new clients begin sending the additive relay
  declaration to both new and old bridges

## 1. Goal and Cohesion

Make mobile session-list and session-detail surfaces declare the one effective
project they are actively viewing. The PR is independently cohesive because the
client API/repository/service pipeline, DI, both cubit claim owners, lifecycle,
reconnect, and cross-version tests activate the already-landed bridge behavior
together without adding presentation.

## 2. Dependencies and Baseline

- S02-W04-P01 is merged: new bridges route `RelayProjectView` and schedule only
  for aggregate viewed projects.
- S01-W01-P01 is merged: old/new relay code can encode/decode the additive union
  variant.
- Assess and pin current `main`, focusing on `ConnectionService`, lifecycle
  adapters, current session-view service, list/detail cubit load/close paths,
  generated DI, and old-bridge unknown-message isolation.
- Preserve current cache-first normal list loads and awaited explicit refresh;
  there is no loading-mode cutover in this PR.

## 3. Scope

### In Scope

- Add generic Layer-0 `RelayControlClient` after `ConnectionService` in the
  existing transport stack. It sends a caller-built `RelayMessage` through the
  current `RelayClient` and owns no feature message shape.
- Migrate `SessionViewApi` off the feature-specific
  `ConnectionService.sendSessionView` seam: both `SessionViewApi` and new
  `ProjectViewApi` construct their own shared union variant and send it through
  `RelayControlClient`.
- Add mandatory thin `ProjectViewRepository`.
- Add singleton `ProjectViewingService` with separate guarded list and detail
  claims, detail precedence, lifecycle visibility, foreground reconnect
  reassertion, serialized sends, and bounded retry of failed connected sends.
- Inject only `ProjectViewRepository`, `LifecycleSource`, and typed
  `Stream<ConnectionStatus>` into the service. Derive the stream from
  `ConnectionService.status` in the DI composition root; do not inject or import
  `ConnectionService` in the service.
- Replace/remove feature-specific `sendSessionView` transport methods from
  `ConnectionService`/`RelayClient` with the generic control-client send path;
  do not add `ConnectionService.sendProjectView`.
- Have `SessionListCubit` claim its project only after the first successful
  session-list render and guard its clear on close.
- Have `SessionDetailCubit` claim its project only after the first successful
  detail render and guard its clear on close.
- Regenerate module-core Injectable output; never edit generated DI by hand.
- Add pure-Dart service/cubit tests and app/desktop downstream verification.

### Non-Goals

- PR-history widgets or changes to `SessionTile`.
- Any bridge scheduling, relay routing, database, or shared model change.
- Combining project presence with `SessionViewingService` or changing mark-seen
  timing.
- Making cubits depend on each other, injecting cubits through DI, or adding
  Flutter to `module_core`.
- Presence claims from project list, desktop shell, background tasks, or any
  surface other than mobile session list/detail.
- Removing request-driven PR refreshes or `PrSyncService` internals.
- Waiting for GitHub during normal session loading.
- Moving lifecycle/reconnect policy into `RelayControlClient`; it remains a dumb
  transport and the two viewing services own reassertion decisions.

## 4. Audited Current Code and Assumptions

- `SessionViewApi` -> `SessionViewRepository` -> `SessionViewingService` is the
  current mandatory client layering precedent, but session view intentionally
  does not reassert itself because it marks conversation content seen.
- The current `SessionViewApi` calls feature-specific
  `ConnectionService.sendSessionView`, which delegates to a feature-specific
  `RelayClient.sendSessionView`. Higher layers may listen to
  `ConnectionService` streams but must use a Layer-0 client for outbound
  transport; this PR replaces that touched seam rather than copying it.
- `SessionViewingService` serializes sends and evaluates current state when each
  queued send executes; project presence needs the same ordering protection but
  different list/detail and resume/reconnect semantics.
- `SessionListCubit.loadSessions()` is started in its constructor and reaches
  `SessionListState.loaded` only after a successful snapshot; normal loads use
  `waitForPrData: false` and explicit refresh uses `true`.
- `SessionDetailCubit` currently declares session view at the successful loaded
  seam and clears it in `close`; project view can use the same render seam
  without participating in its post-refresh mark-seen gating.
- `LifecycleSource` is a pure-Dart `ValueStream<LifecycleState>` and
  `ConnectionService.status` exposes typed `ConnectionStatus` transitions.
- Mobile and desktop shells already register a concrete `LifecycleSource`
  before `configureCoreDependencies`.

## 5. Design and Ownership

### Expected files

New target paths:

- `client/module_core/lib/src/foundation/transport/relay_control_client.dart`
- `client/module_core/lib/src/api/project_view_api.dart`
- `client/module_core/lib/src/repositories/project_view_repository.dart`
- `client/module_core/lib/src/services/project_viewing_service.dart`
- matching pure-Dart tests

Existing paths likely changed:

- `client/module_core/lib/src/capabilities/server_connection/connection_service.dart`
- `client/module_core/lib/src/capabilities/relay/relay_client.dart`
- `client/module_core/lib/src/api/session_view_api.dart`
- `client/module_core/lib/src/cubits/session_list/session_list_cubit.dart`
- `client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart`
- `client/module_core/lib/src/di/injection.dart` and/or an Injectable DI module
- generated `client/module_core/lib/src/di/injection.config.dart`
- affected module-core and app cubit/provider tests

Generated files are outputs only; run generation rather than editing them.

### Layer boundaries

- `RelayControlClient` is a generic Layer-0 transport component ordered after
  `ConnectionService`, parallel to `RelayHttpApiClient`. It stores/uses the
  connection lifecycle component to reach the current raw `RelayClient`, sends
  only an injected `RelayMessage`, and never switches on session/project
  variants or owns feature claims/retries. It reports typed `sent` versus
  `disconnected`; unexpected send failure while the connection still reports
  connected is surfaced to the API/service owner.
- `SessionViewApi` and `ProjectViewApi` are independent Layer-1 peers. Each
  constructs its own `RelayMessage.sessionView` / `RelayMessage.projectView`
  value and calls `RelayControlClient.send`; neither calls `ConnectionService`
  or `RelayClient` directly.
- `ProjectViewRepository` is Layer 2 and only delegates the typed declaration.
- `ProjectViewingService` is Layer 3 because it owns the list/detail precedence,
  visibility/reconnect state machine, and send ordering.
- Cubits are Layer 4 claim owners. They never import `ProjectViewApi` or
  `ConnectionService` for this feature.
- DI alone maps `ConnectionService.status` to the service's typed stream. A DI
  provider may construct the service with already-resolved collaborators; the
  service itself must not accept a pass-through transport dependency.

### Service state and public operations

The service owns:

- nullable current list claim;
- nullable current detail claim;
- visible state (hidden/paused/detached are not visible; resumed/inactive follow
  the existing platform semantics established by `LifecycleSource` tests);
- prior connected state;
- last effective declaration successfully attempted/deduped as needed; and
- one future tail that never remains failed; and
- one generation-guarded retry timer plus consecutive connected-failure count.

Expose intent-specific guarded methods, all with required named arguments:

- `setListProject(projectId)` / `clearListProject(projectId)`;
- `setDetailProject(projectId)` / `clearDetailProject(projectId)`.

The effective project while visible is detail claim first, then list claim,
otherwise null. A clear acts only if its project still owns that claim. This
prevents an old cubit closing after cross-project navigation from erasing a
newer claim.

### Data flow

```text
successful SessionListCubit render -> set list claim(project A)
successful SessionDetailCubit render -> set detail claim(project B)
  -> ProjectViewingService recomputes B ?? A
  -> serialized ProjectViewRepository.sendProjectView
  -> ProjectViewApi constructs RelayMessage.projectView
  -> RelayControlClient -> ConnectionService/current RelayClient
```

Closing detail B falls back directly to a still-owned list A declaration; it
does not send a transient null. Closing a same-project detail over a list does
not send a redundant value. Closing the final owner sends null.

### Lifecycle and reconnect behavior

- First transition into hidden/paused/detached enqueues one null transition while
  retaining both intended claims. A failed connected send retries that same
  current null intent until sent, superseded, disconnected, or disposed.
- Repeated hidden -> paused events do not duplicate the clear.
- Resume recomputes and reasserts the effective project immediately; unlike
  session view, project presence has no mark-seen effect and need not await a
  content refresh.
- A transition from any non-connected status to `ConnectionConnected` reasserts
  only while visible and an effective claim exists.
- A reconnect while hidden sends nothing; the later resume performs one current
  reassertion.
- Every queued callback reads current claims/visibility when it executes rather
  than capturing an obsolete project id.
- A surfaced failure while still connected logs once and schedules one-shot
  retry at 1s, 2s, 4s... capped at 30s. Each retry reads the current effective
  declaration and generation, resets on sent success, and cannot resurrect an
  older project/null after navigation or lifecycle change.
- Expected disconnected/no-current-relay sends return typed `disconnected`; the
  service does not retry because bridge connection release clears declarations.
  Foreground reconnect reasserts current visible intent; hidden reconnect stays
  null until resume.
- A failed visible project declaration therefore remains pending without user
  navigation, and a failed hidden null cannot leave indefinite ghost presence
  on an otherwise live connection.
- Service disposal cancels lifecycle/connection subscriptions and retry timer;
  cubit closure remains responsible for releasing its own claim.

### Cubit behavior

- List declares after a successful initial render, not on construction/loading,
  and retains the claim across a failed refresh while the prior list remains
  rendered.
- Detail declares after a successful initial render; its existing session-view
  declaration remains at the same mark-seen seam.
- Both cubits inject `ProjectViewingService` as an already-built collaborator.
- `close()` calls the guarded project-specific clear before `super.close()`.
- The service, not either cubit, owns reconnect/lifecycle declarations.

## 6. Backward Compatibility

- New client -> new bridge activates viewed-project scheduling.
- New client -> old bridge sends an additive unknown union variant. Verify the
  established parser/router isolation keeps the connection and session loading
  alive; request-driven refresh remains the freshness fallback.
- Old client -> new bridge sends no declaration and continues through retained
  request-driven dispatcher paths.
- S01's `pullRequestHistory` default is unchanged.
- No compatibility-only fallback is introduced in this PR, so no new marker is
  expected. Do not mark ordinary guarded state-machine defaults.

## 7. Schema and Generated-Code Work

- No schema/shared Freezed change.
- Regenerate Injectable output from `client/module_core`; do not hand-edit
  `injection.config.dart`.
- If a shared contract change is unexpectedly needed, stop for stale-plan
  re-review rather than broadening the PR.

## 8. Verification

### Automated tests

`ProjectViewApi` / repository:

- construct exact project-view variants for project id/null and send them
  through generic `RelayControlClient`;
- propagate a send failure to the service seam without duplicate logging.

Control transport regression:

- `SessionViewApi` constructs the session-view variant through the same generic
  client and preserves its existing disconnected/race behavior;
- `RelayControlClient` forwards arbitrary caller-built control messages without
  inspecting feature variants, returns typed disconnected without throwing,
  surfaces a failure if the connection remains live, and uses the current relay
  after reconnect;
- no feature-specific session/project send method remains on
  `ConnectionService` or `RelayClient`.

`ProjectViewingService`:

- list-only claim, detail-only direct navigation, detail-over-list precedence,
  detail clear fallback, and final null;
- same-project list/detail creates no false null or redundant transition;
- late old-project list/detail clear cannot erase a newer project;
- serialized rapid A -> B -> clear transmits current execution-time state and
  ends at the correct declaration;
- hidden/paused/detached clear once, retained claims, resume reassert, inactive
  behavior matching platform contract;
- foreground reconnect reassert, hidden reconnect no send, resume after hidden
  reconnect one reassert;
- connected visible-send failure retries current project without navigation;
  connected hidden-clear failure retries null; 1/2/4/30-second cap, success
  reset, generation supersession, disconnect cancellation, and no overlap;
- disconnected outcome does not retry and reconnect/resume rules reassert only
  when appropriate;
- send failure does not poison later tail; subscription/timer cancellation and
  no post-disposal sends.

Cubits/integration:

- list initial success claims; initial failure/waiting never claims; close
  clears only its own project; refresh failure preserves a rendered claim;
- detail success claims independently of list; initial failure/waiting never
  claims; close clears both project and existing session view correctly;
- list A -> detail A -> list sends no null; list A -> direct detail B -> close
  falls back to A without a stale-clear race;
- session view still reasserts only after successful fresh detail content while
  project view reasserts on visible reconnect/resume without changing unseen;
- generated DI resolves one singleton service in both mobile and desktop core
  composition and receives the typed status stream;
- encoded project-view to an old-bridge unknown-message fixture does not break
  the relay/session request path.

### Manual verification

Deferred to S03-W03-M01 so presence can be observed together with real GitHub
cadence and final UI.

### Exact commands

```text
# workdir: client
dart pub get

# workdir: client/module_core
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart test

# workdir: client/app
dart analyze --fatal-infos
flutter test

# workdir: client/module_desktop_core
dart analyze --fatal-infos
dart test

# workdir: client/desktop
dart analyze --fatal-infos
flutter test
```

### Regression guide

- Initial/background session-list fetch remains cache-first and explicit
  pull-to-refresh retains the five-second awaited bridge budget.
- Opening detail still marks conversation seen only after successful content
  rendering; project presence itself never changes unseen state.
- Existing reconnect/staleness subscriptions and session SSE re-fetch behavior
  remain intact.
- Mobile and desktop shells resolve core DI; no desktop-only UI is introduced.
- New client with an old bridge can still list/open sessions after declaration.

## 9. Risks

- Separate cubits can clear out of order; project-specific guarded claims prevent
  an old owner from clearing a replacement.
- Queued sends can overtake navigation intent; one tail reading current state at
  execution prevents stale captures.
- A failed declaration can otherwise persist forever while the user remains on
  one surface; bounded generation-guarded retry repairs live-connection failures
  without polling or retrying after disconnect.
- Session-view and project-view resume semantics differ intentionally; keeping
  separate services avoids accidental mark-seen reassertion.
- A raw `ConnectionService` injection would leak transport into Layer 3; DI must
  provide only its typed status stream. Outbound Layer-1 APIs use the generic
  `RelayControlClient`, never `ConnectionService` transport methods.

## 10. Acceptance Criteria

- Either successfully rendered mobile surface activates its effective project.
- Detail precedence and guarded fallback work without transient null.
- Hidden/background and relay disconnect cannot leave ghost presence; visible
  resume/reconnect reasserts current intent.
- Connected declaration failures retry the latest intent with bounded backoff
  and do not poison future ordered sends.
- Session unseen and loading behavior remain unchanged.
- New/old bridge-client pairings retain session functionality.

## 11. Definition of Done

- API/repository/service/cubit/DI implementation and focused tests are complete.
- Generated DI is regenerated, never hand-edited.
- Exact module-core, app, desktop-core, and desktop commands pass.
- `aristotle-impl-review` approves before PR opening.
- PR targets `main`; tracker records baseline/branch/URL/check state.
- S03-W02 starts only after merge.
