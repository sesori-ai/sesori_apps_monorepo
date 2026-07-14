# S01-W01-P01: Add Additive PR-Monitor Contracts

## 0. Metadata

- **ID:** S01-W01-P01
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Worktree:** one dedicated worker worktree for this PR
- **Base branch:** `main`
- **Branch:** `plan/session-pull-request-monitoring/s01-w01-p01-additive-pr-monitor-contracts`
- **Wave baseline:** pin the assessed current `main` tip in `TRACKER.md` before branch creation
- **Audited reference:** `e766684e0fdc22256419b7b99691021c9f14732d`
- **Contract-affecting:** Yes — shared JSON and relay union

## 1. Goal and Cohesion

Add only the shared wire/model vocabulary required by later bridge and client
PRs: a connection-scoped project-view declaration and a non-null PR-history
list. The PR is independently cohesive because every consumer can decode and
compile the additive contract while production behavior remains unchanged.

## 2. Dependencies and Baseline

- No implementation PR dependency beyond the approved plan.
- Re-read `shared/sesori_shared/AGENTS.md`, bridge/client AGENTS files, and the
  declared bridge/mobile version after pinning the baseline.
- Assess drift in the exact shared model/protocol files and every generated
  consumer before editing.
- Same-wave sibling baseline reuse is not applicable; this wave has one PR.

## 3. Scope

### In Scope

- Add `RelayMessage.projectView({required String? projectId})` with wire union
  value `project_view`.
- Add `@Default(<PullRequestInfo>[]) List<PullRequestInfo>
  pullRequestHistory` to `Session` while retaining `pullRequest` unchanged.
- Put the required compatibility marker immediately above the history default,
  using the actual implementation date/version and exact cleanup from PLAN
  section 7.
- Regenerate Freezed/JSON artifacts from source annotations.
- Add old/new JSON omission and round-trip tests.
- Add relay round-trip tests for string and null project ids.
- Update any exhaustive source switches revealed by generation/analyze with an
  explicit no-op only where behavior intentionally waits for later stages.
- Compile/test every shared consumer: bridge, module_core, mobile,
  module_desktop_core, and desktop shell.

### Non-Goals

- Routing `RelayProjectView` in the bridge.
- Sending project presence from the client.
- Adding branch/PR persistence, GitHub calls, timers, or UI.
- Changing `Session.pullRequest`, `RelaySessionView`, unseen behavior, or
  session request semantics.
- Hand-editing any generated file.

## 4. Audited Current Code and Assumptions

- `shared/sesori_shared/lib/src/protocol/messages.dart` has
  `RelaySessionView` as the only view declaration.
- `shared/sesori_shared/lib/src/models/sesori/session.dart` has one required
  nullable `pullRequest` and no history.
- Shared `build.yaml` omits null JSON keys; a list default is serialized by new
  peers and old payload omission decodes through Freezed's default.
- Bridge relay parsing catches an unknown union at
  `bridge/app/lib/src/bridge/orchestrator.dart:1214-1223` and drops only that
  message, so an old bridge does not disconnect a new client.
- No desktop source directly switches on `RelayMessage`; downstream validation
  is still required because shared generated APIs are consumed there.

## 5. Design and Ownership

### Workspaces and files

Expected source/test files:

- `shared/sesori_shared/lib/src/protocol/messages.dart`
- `shared/sesori_shared/lib/src/models/sesori/session.dart`
- `shared/sesori_shared/test/protocol/relay_project_view_test.dart` (new)
- `shared/sesori_shared/test/models/pull_request_history_compatibility_test.dart` (new)
- any existing shared session/protocol tests that centralize round trips
- generated `messages.freezed.dart`, `messages.g.dart`,
  `session.freezed.dart`, and `session.g.dart`
- only source switches/tests in bridge/client that fail exhaustive analysis
  after the new variant; do not add behavior wiring

### Classes, layers, and collaborators

- `RelayMessage` remains a Layer 0 shared transport union.
- `Session` remains a shared transport/domain response model.
- No new service, repository, interface, helper, or wrapper is introduced.

### Data flow

```text
old Session JSON without pullRequestHistory
  -> Session.fromJson
  -> @Default([])
  -> modern non-null empty history

RelayProjectView JSON
  <-> RelayMessage.fromJson/toJson
```

### Error, lifecycle, concurrency

- Invalid relay union bodies continue to be isolated by existing parser error
  handling; this PR does not add a second parser or fallback branch.
- The variant is stateless and fire-and-forget; lifecycle ownership lands in
  S02/S03.
- No concurrency or cancellation behavior changes.

## 6. Backward Compatibility

### Old bridge -> new client

Old session payloads omit `pullRequestHistory`; new shared decode returns an
empty non-null list. The compatibility source marker identifies bridges before
history support and the cleanup: remove `@Default`, make the field required, and
remove the omission fixture after every supported bridge sends the field.

### New bridge -> old client

Old clients ignore the additive JSON field and continue using `pullRequest`.

### New client -> old bridge

No client sends `RelayProjectView` in this PR. S03 tests the existing old-bridge
parse isolation before activating sends.

### Marker location

Immediately above `Session.pullRequestHistory` in
`shared/sesori_shared/lib/src/models/sesori/session.dart`, exactly as specified
in PLAN section 7 with the implementation date and currently declared version.

## 7. Generated-Code Work

- Run build_runner from `shared/sesori_shared` after source/test edits.
- Review generated diffs for only the new union variant and history field.
- Never hand-edit `*.freezed.dart` or `*.g.dart`.
- No Drift generation or migration occurs.

## 8. Verification

### Automated tests

- Session JSON with omitted history -> empty non-null list.
- Session JSON with empty and populated history -> exact round trip.
- Existing headline PR round trip remains unchanged.
- Relay project-view round trip with a project id and null.
- Existing `RelaySessionView` round trip/behavior remains unchanged.
- Invalid/unknown control union remains connection-safe in bridge parsing tests
  if no existing test already proves it.
- All downstream consumers compile against generated shared output.

### Manual verification

None; the behavior is deterministic and fully automatable.

### Exact commands

```text
# workdir: shared/sesori_shared
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze
dart test

# workdir: bridge
dart pub get
make analyze
make test

# workdir: bridge/app
dart analyze --fatal-infos

# workdir: client
dart pub get

# workdir: client/module_core
dart analyze
dart test

# workdir: client/app
dart analyze
flutter test

# workdir: client/module_desktop_core
dart analyze
dart test

# workdir: client/desktop
dart analyze
flutter test
```

### Regression guide

- Session list serialization still exposes `pullRequest` exactly as before.
- Existing session-view declarations still own mark-seen semantics only.
- Relay request/response/SSE/key-exchange/resume variants round-trip unchanged.
- Mobile and desktop shells launch tests without new DI registrations.

## 9. Risks

- A nullable history field would leak compatibility state into modern APIs;
  prevent this with the locked empty default and omission test.
- Generated output can create a broad diff; regenerate only from the shared
  module and reject unrelated formatting/regeneration.
- An eager no-op route could accidentally claim behavior support; keep routing
  and sending out of this PR.

## 10. Acceptance Criteria

- New shared code can construct, serialize, and deserialize both additions.
- Old session JSON produces `pullRequestHistory.isEmpty` without caller
  normalization.
- `pullRequest` remains source/wire compatible.
- No production sender, listener, timer, schema, or UI behavior changes.
- All command groups pass.

## 11. Definition of Done

- Scope, tests, generated outputs, and regression checks are complete.
- `aristotle-impl-review` approves the changed implementation before PR opening.
- Only intended files are committed; branch is pushed and PR targets `main`.
- `TRACKER.md` records pinned baseline, branch, PR URL, and checked state on the
  implementation branch. S02 does not start until this PR merges.
