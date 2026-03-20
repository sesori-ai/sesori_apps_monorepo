# Fix Real-Time Activity Tracking + Session Activity Indicators

## TL;DR

> **Quick Summary**: Fix the bug where project activity indicators don't refresh in real-time (orchestrator sends empty signal instead of data payload), and add session-level activity indicators in the session list screen by enriching the existing `ProjectActivitySummary` with active session IDs.
>
> **Deliverables**:
> - Real-time project activity updates work without pull-to-refresh
> - Session list shows which sessions are currently running (green dot + "Running" label)
> - Same SSE event (`projects.summary`) carries both project and session activity data
>
> **Estimated Effort**: Medium
> **Parallel Execution**: YES — 4 waves
> **Critical Path**: T1 → T2/T3/T4 → T5 → T7

---

## Context

### Original Request
Active project indicators don't refresh in real-time — UI shows stale "active" state until pull-to-refresh. Additionally, the session list screen should show which sessions are currently running, similar to how the project list shows active project indicators.

### Interview Summary
**Key Discussions**:
- User confirmed the same SSE response should carry both project and session activity data
- Tests after implementation strategy agreed

**Research Findings**:
- **Root cause identified**: When session status changes, bridge emits `BridgeSseProjectUpdated()` (empty signal) → orchestrator maps to `SesoriSseEvent.projectUpdated()` (still empty) → mobile `SseEventRepository` only handles `SesoriProjectsSummary` (with data) → update silently dropped
- **Initial load works** because orchestrator explicitly builds full `projectsSummary` on SSE subscribe (orchestrator.dart:447-458)
- **`ActiveSessionTracker`** already tracks session IDs internally via `_sessionStatuses` map — just needs to expose them in `buildSummary()`
- **`PluginProjectActivitySummary`** (bridge interface) must stay in sync with shared `ProjectActivitySummary`
- **Dual emission source**: `BridgeSseProjectUpdated` is emitted both from activity changes AND `SseProjectUpdated` mapping — converting both to `projectsSummary` is correct since mobile ignores `projectUpdated` anyway

### Metis Review
**Identified Gaps** (addressed):
- **Build order**: Codegen must run in dependency order: `shared/sesori_shared` → `bridge/` → `mobile/`
- **Change detection gap**: `_mapsEqual` compares counts only — if session A→idle and session B→busy simultaneously, count unchanged, no event. Accepted for V1
- **No orchestrator tests**: Mapping layer is currently untested — should add tests as part of this work
- **Dual `BridgeSseProjectUpdated` semantic**: Converting all to `projectsSummary` loses the "project metadata changed" semantic. Documented in code comment — no mobile consumer needs it

---

## Work Objectives

### Core Objective
Fix the real-time project activity bug and add session-level activity indicators to the session list, using the same `projects.summary` SSE event.

### Concrete Deliverables
- `ProjectActivitySummary` model enriched with `activeSessionIds: List<String>`
- Orchestrator sends full `projectsSummary` event on activity changes (instead of empty `projectUpdated`)
- Session list UI shows green dot + "Running" label for active sessions
- Updated tests for `ActiveSessionTracker.buildSummary()` and new `SseEventRepository` session activity

### Definition of Done
- [ ] `dart analyze` passes in all workspaces: `shared/sesori_shared`, `bridge/` (all modules), `mobile/` (all modules)
- [ ] `make test` from `bridge/` passes
- [ ] `dart test` from `mobile/module_core` passes
- [ ] Active project indicators refresh in real-time when sessions start/stop (no pull-to-refresh needed)
- [ ] Session list shows running indicator for busy sessions

### Must Have
- Follow the exact mapping pattern from orchestrator initial-subscribe handler (lines 447-456)
- Codegen run in dependency order: shared → bridge → mobile

### Must NOT Have (Guardrails)
- Do NOT change `ActiveSessionTracker.handleEvent()` return logic or `_mapsEqual` comparison — count-based change detection is correct for V1
- Do NOT add new `BridgeSseEvent` variants — enrich existing mapping, not event protocol
- Do NOT change `_emitProjectsSummary()` in `opencode_plugin_impl.dart` — it correctly emits `BridgeSseProjectUpdated()` as trigger
- Do NOT add `distinct()` or equality operators to the `BehaviorSubject` in `SseEventRepository`
- Do NOT include session status types (busy/retry) in the payload — only IDs
- Do NOT add animations or complex UI for the indicator — simple green dot + text, matching project list pattern
- Do NOT modify `ActiveSessionTracker._handleEvent` switch cases or `_resolveWorktree` logic

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (dart test, flutter test, existing test files)
- **Automated tests**: Tests-after
- **Framework**: dart test (bridge + mobile/module_core), flutter test (mobile/app)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Model/Shared**: Use Bash (dart test) — Run tests, verify JSON roundtrip
- **Bridge**: Use Bash (dart test + dart analyze) — Run tests, verify mapping
- **Mobile cubit**: Use Bash (dart test) — Run cubit tests
- **Mobile UI**: Use Bash (dart analyze + flutter test) — Verify compilation and analysis

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — models + codegen):
└── Task 1: Shared + bridge interface models [quick]

Wave 2 (Core implementation — MAX PARALLEL after Wave 1):
├── Task 2: Bridge tracker + plugin (expose session IDs) [quick]
├── Task 3: Bridge orchestrator fix (projectsSummary mapping) [quick]
└── Task 4: Mobile SseEventRepository (session activity stream) [quick]

Wave 3 (Consumers + bridge tests — parallel after Wave 2):
├── Task 5: Mobile SessionListCubit + state (subscribe to activity) [quick]
└── Task 6: Bridge tests (tracker + orchestrator) [unspecified-high]

Wave 4 (UI + mobile tests — parallel after Wave 3):
├── Task 7: Session list UI (activity indicator) [visual-engineering]
└── Task 8: Mobile tests (repository + cubit) [quick]

Wave FINAL (After ALL tasks — parallel reviews, then user okay):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)
-> Present results -> Get explicit user okay

Critical Path: T1 → T3 → T5 → T7 → F1-F4 → user okay
Parallel Speedup: ~50% faster than sequential
Max Concurrent: 3 (Wave 2)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| T1 | — | T2, T3, T4 |
| T2 | T1 | T6 |
| T3 | T1 | T6 |
| T4 | T1 | T5 |
| T5 | T4 | T7, T8 |
| T6 | T2, T3 | — |
| T7 | T5 | — |
| T8 | T5 | — |

### Agent Dispatch Summary

- **Wave 1**: **1** — T1 → `quick`
- **Wave 2**: **3** — T2 → `quick`, T3 → `quick`, T4 → `quick`
- **Wave 3**: **2** — T5 → `quick`, T6 → `unspecified-high`
- **Wave 4**: **2** — T7 → `visual-engineering`, T8 → `quick`
- **FINAL**: **4** — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [ ] 1. Add `activeSessionIds` to shared and bridge interface models + codegen

  **What to do**:
  - In `shared/sesori_shared/lib/src/models/sesori/project_activity_summary.dart`:
    - Add field `@Default([]) List<String> activeSessionIds` to `ProjectActivitySummary`
  - In `bridge/sesori_plugin_interface/lib/src/models/plugin_project_activity_summary.dart`:
    - Add field `@Default([]) List<String> activeSessionIds` to `PluginProjectActivitySummary`
  - Run codegen in dependency order:
    1. `cd shared/sesori_shared && dart run build_runner build --delete-conflicting-outputs`
    2. `cd bridge && make codegen`
    3. `cd mobile && dart run build_runner build --delete-conflicting-outputs` (from each module that imports sesori_shared)
  - Verify `dart analyze` passes in `shared/sesori_shared` and `bridge/sesori_plugin_interface`

  **Must NOT do**:
  - Do NOT change `@Freezed(fromJson: true, toJson: true)` annotation on `ProjectActivitySummary`
  - Do NOT change `PluginProjectActivitySummary`'s existing `@freezed` annotation (note: lowercase, no JSON)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Two small model file edits + codegen commands. Mechanical changes.
  - **Skills**: []
    - No special skills needed — standard Dart/Freezed model editing.

  **Parallelization**:
  - **Can Run In Parallel**: NO (foundation task)
  - **Parallel Group**: Wave 1 (solo)
  - **Blocks**: T2, T3, T4
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `shared/sesori_shared/lib/src/models/sesori/project_activity_summary.dart` — Current model. Has `@Default(0) int activeSessions`. Add `activeSessionIds` with same `@Default` pattern.
  - `bridge/sesori_plugin_interface/lib/src/models/plugin_project_activity_summary.dart` — Plugin-side mirror. Currently has `required String worktree, required int activeSessions`. Add `activeSessionIds` here too.

  **External References**:
  - Freezed docs: `@Default([])` syntax for default values on collection fields.

  **WHY Each Reference Matters**:
  - The shared model is a Freezed class with `fromJson`/`toJson`. Adding the field here makes it available in the SSE event payload.
  - The plugin interface model is also Freezed but WITHOUT JSON serialization — used only in-process between plugin and orchestrator.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: JSON roundtrip preserves activeSessionIds
    Tool: Bash (dart test)
    Preconditions: Codegen completed in shared/sesori_shared
    Steps:
      1. Run: cd shared/sesori_shared && dart analyze
      2. Verify output: "No issues found"
    Expected Result: dart analyze exits with code 0, no issues
    Failure Indicators: Any analysis error mentioning project_activity_summary
    Evidence: .sisyphus/evidence/task-1-analyze-shared.txt

  Scenario: Bridge interface analysis passes
    Tool: Bash (dart analyze)
    Preconditions: Codegen completed in bridge workspace
    Steps:
      1. Run: cd bridge && make analyze
      2. Verify output includes no errors
    Expected Result: Analysis passes for all bridge modules
    Failure Indicators: Error in plugin_project_activity_summary
    Evidence: .sisyphus/evidence/task-1-analyze-bridge.txt
  ```

  **Commit**: YES (group 1)
  - Message: `feat(shared): add activeSessionIds to ProjectActivitySummary`
  - Files: `shared/sesori_shared/lib/src/models/sesori/project_activity_summary.dart`, `shared/sesori_shared/lib/src/models/sesori/project_activity_summary.freezed.dart`, `shared/sesori_shared/lib/src/models/sesori/project_activity_summary.g.dart`, `bridge/sesori_plugin_interface/lib/src/models/plugin_project_activity_summary.dart`, `bridge/sesori_plugin_interface/lib/src/models/plugin_project_activity_summary.freezed.dart`
  - Pre-commit: `cd shared/sesori_shared && dart analyze && cd ../../bridge && make analyze`

- [ ] 2. Expose active session IDs from `ActiveSessionTracker.buildSummary()` and plugin mapping

  **What to do**:
  - In `bridge/sesori_plugin_opencode/lib/src/active_session_tracker.dart`:
    - Modify `buildSummary()` to include `activeSessionIds` per worktree. The data is already available: iterate `_sessionStatuses` entries, group session IDs by their worktree (via `_sessionWorktrees`), and include in `ProjectActivitySummary`.
    - The existing `activeSessions` map already computes per-worktree counts from `_sessionStatuses` — the session IDs can be collected alongside the counts.
  - In `bridge/sesori_plugin_opencode/lib/src/opencode_plugin_impl.dart`:
    - Update `getActiveSessionsSummary()` (line 476-486) to map `activeSessionIds` from `ProjectActivitySummary` to `PluginProjectActivitySummary`.
  - Run `make codegen` from `bridge/` if any Freezed changes needed (likely not — just logic changes).

  **Must NOT do**:
  - Do NOT modify `handleEvent()` or `_mapsEqual()` — change detection stays count-based
  - Do NOT modify `_emitProjectsSummary()` in `opencode_plugin_impl.dart`
  - Do NOT change `activeSessions` getter logic — only modify `buildSummary()`

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Two files, small logic changes. The data structures are already in place.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with T3, T4)
  - **Blocks**: T6
  - **Blocked By**: T1

  **References**:

  **Pattern References**:
  - `bridge/sesori_plugin_opencode/lib/src/active_session_tracker.dart:88-94` — Current `buildSummary()`. Maps `activeSessions` entries to `ProjectActivitySummary`. Extend to include session IDs per worktree.
  - `bridge/sesori_plugin_opencode/lib/src/active_session_tracker.dart:96-104` — `activeSessions` getter. Shows how `_sessionStatuses` entries are grouped by worktree via `_sessionWorktrees`. Same grouping logic applies for collecting session IDs.
  - `bridge/sesori_plugin_opencode/lib/src/active_session_tracker.dart:10-13` — Internal maps: `_sessionWorktrees` (sessionID → worktree), `_sessionStatuses` (sessionID → status). These contain all needed data.
  - `bridge/sesori_plugin_opencode/lib/src/opencode_plugin_impl.dart:475-486` — Current `getActiveSessionsSummary()`. Maps `ProjectActivitySummary` → `PluginProjectActivitySummary`. Add `activeSessionIds` to the mapping.

  **Test References**:
  - `bridge/sesori_plugin_opencode/test/active_session_tracker_test.dart:16-26` — Existing test pattern: cold start tracker, send events, assert `activeSessions` map. New tests should assert `buildSummary()` includes correct session IDs.
  - `bridge/sesori_plugin_opencode/test/active_session_tracker_test.dart:288-308` — Test helpers: `_fakeRepository()`, `_coldStartedTracker()`. Use these for new test cases.

  **WHY Each Reference Matters**:
  - `buildSummary()` is the single point where activity data is packaged for external consumption. The session IDs must be added HERE.
  - The `activeSessions` getter shows the grouping pattern (iterate `_sessionStatuses`, resolve worktree via `_sessionWorktrees`). The same iteration should collect IDs.
  - `getActiveSessionsSummary()` is the plugin-to-orchestrator bridge. The new field must flow through this mapping.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: buildSummary includes session IDs for active sessions
    Tool: Bash (dart test)
    Preconditions: T1 completed (models updated)
    Steps:
      1. Run: cd bridge/sesori_plugin_opencode && dart test test/active_session_tracker_test.dart
      2. Verify all existing tests still pass
      3. Verify new test: cold-start tracker with 2 busy sessions in same project → buildSummary() returns entry with activeSessionIds containing both session IDs
    Expected Result: All tests pass, buildSummary includes correct IDs
    Failure Indicators: buildSummary returns empty activeSessionIds
    Evidence: .sisyphus/evidence/task-2-tracker-test.txt

  Scenario: Plugin mapping preserves activeSessionIds
    Tool: Bash (dart analyze)
    Preconditions: T1 completed
    Steps:
      1. Run: cd bridge && make analyze
      2. Verify no analysis errors
    Expected Result: dart analyze passes for all bridge modules
    Failure Indicators: Type error in getActiveSessionsSummary mapping
    Evidence: .sisyphus/evidence/task-2-analyze-bridge.txt
  ```

  **Commit**: YES (group 2, with T3)
  - Message: `fix(bridge): send projectsSummary on activity change and expose session IDs`
  - Files: `bridge/sesori_plugin_opencode/lib/src/active_session_tracker.dart`, `bridge/sesori_plugin_opencode/lib/src/opencode_plugin_impl.dart`
  - Pre-commit: `cd bridge && make analyze`

- [ ] 3. Fix orchestrator to send `projectsSummary` instead of empty `projectUpdated`

  **What to do**:
  - In `bridge/app/lib/src/bridge/orchestrator.dart`:
    - Modify `_mapBridgeToSesoriEvent()` (line 587-588): Instead of returning `const SesoriSseEvent.projectUpdated()` for `BridgeSseProjectUpdated`, build and return a full `SesoriSseEvent.projectsSummary(...)` using `_plugin.getActiveSessionsSummary()`.
    - Follow the EXACT same mapping pattern used in the initial-subscribe handler (lines 447-456): call `_plugin.getActiveSessionsSummary()`, map each `PluginProjectActivitySummary` to `ProjectActivitySummary`, return as `projectsSummary` event.
    - Add a code comment at the mapping site explaining that `BridgeSseProjectUpdated` is emitted both from activity changes AND project metadata changes, and converting both to `projectsSummary` is intentional since mobile doesn't handle `projectUpdated`.
  - This is the **critical bug fix** — after this change, the mobile `SseEventRepository` will receive `projectsSummary` events on every activity change, updating the UI in real-time.

  **Must NOT do**:
  - Do NOT add new `BridgeSseEvent` variants
  - Do NOT change the `RelaySseSubscribe` handler (lines 443-462) — it already works correctly
  - Do NOT modify any other case in `_mapBridgeToSesoriEvent` — only the `BridgeSseProjectUpdated` case

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file, single method, ~10 lines of change. The pattern to follow already exists in the same file.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with T2, T4)
  - **Blocks**: T6
  - **Blocked By**: T1

  **References**:

  **Pattern References**:
  - `bridge/app/lib/src/bridge/orchestrator.dart:443-458` — Initial-subscribe handler. This is the EXACT pattern to replicate: calls `_plugin.getActiveSessionsSummary()`, maps each `PluginProjectActivitySummary` → `ProjectActivitySummary`, wraps in `SesoriSseEvent.projectsSummary(...)`. Copy this logic.
  - `bridge/app/lib/src/bridge/orchestrator.dart:587-588` — The broken mapping: `case BridgeSseProjectUpdated(): return const SesoriSseEvent.projectUpdated();`. Replace this entire case.
  - `bridge/app/lib/src/bridge/orchestrator.dart:91-99` — Event stream subscription. Shows how `_mapBridgeToSesoriEvent` is called and its return value is enqueued. The mapping function must return a non-null `SesoriSseEvent`.

  **API/Type References**:
  - `bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart` — `getActiveSessionsSummary()` returns `List<PluginProjectActivitySummary>`. Called on `_plugin`.
  - `shared/sesori_shared/lib/src/models/sesori/project_activity_summary.dart` — `ProjectActivitySummary(worktree:, activeSessions:, activeSessionIds:)`. Target model.
  - `shared/sesori_shared/lib/src/models/sesori/sesori_sse_event.dart:229-232` — `SesoriSseEvent.projectsSummary(projects: List<ProjectActivitySummary>)`. The event to return.

  **WHY Each Reference Matters**:
  - Lines 447-456 are the gold standard — the initial subscribe handler already does exactly what we need. The fix is literally copying this pattern into the `_mapBridgeToSesoriEvent` case for `BridgeSseProjectUpdated`.
  - Lines 587-588 are the bug — the empty `projectUpdated()` that mobile silently drops.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Orchestrator maps BridgeSseProjectUpdated to projectsSummary
    Tool: Bash (dart analyze)
    Preconditions: T1 completed (models updated)
    Steps:
      1. Run: cd bridge/app && dart analyze
      2. Verify no analysis errors in orchestrator.dart
    Expected Result: dart analyze passes
    Failure Indicators: Type error in _mapBridgeToSesoriEvent
    Evidence: .sisyphus/evidence/task-3-analyze-orchestrator.txt

  Scenario: Full bridge analysis and test suite passes
    Tool: Bash (make analyze && make test)
    Preconditions: T1 and T2 completed
    Steps:
      1. Run: cd bridge && make analyze && make test
      2. Verify all pass
    Expected Result: Zero analysis errors, all tests pass
    Failure Indicators: Any failure in orchestrator or SSE-related tests
    Evidence: .sisyphus/evidence/task-3-bridge-full.txt
  ```

  **Commit**: YES (group 2, with T2)
  - Message: `fix(bridge): send projectsSummary on activity change and expose session IDs`
  - Files: `bridge/app/lib/src/bridge/orchestrator.dart`
  - Pre-commit: `cd bridge && make analyze`

- [ ] 4. Expose session-level activity from `SseEventRepository`

  **What to do**:
  - In `mobile/module_core/lib/src/capabilities/sse/sse_event_repository.dart`:
    - Add a new `BehaviorSubject<Map<String, Set<String>>>` for session activity: maps worktree → set of active session IDs.
    - In `_handleEvent`, when receiving `SesoriProjectsSummary`, also extract `activeSessionIds` from each `ProjectActivitySummary` and update the new subject.
    - Expose the new stream as `ValueStream<Map<String, Set<String>>> get sessionActivity`.
    - Expose synchronous accessor `Map<String, Set<String>> get currentSessionActivity`.
    - Close the new subject in `onDispose()`.
  - The existing `_projectActivity` (`Map<String, int>`) stays unchanged — it continues to serve `ProjectListCubit`.

  **Must NOT do**:
  - Do NOT modify the existing `_projectActivity` BehaviorSubject type or behavior
  - Do NOT add `distinct()` or equality operators
  - Do NOT change how `SesoriProjectsSummary` is parsed for the project-level data

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file, extending existing pattern. Add a parallel BehaviorSubject alongside the existing one.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with T2, T3)
  - **Blocks**: T5
  - **Blocked By**: T1

  **References**:

  **Pattern References**:
  - `mobile/module_core/lib/src/capabilities/sse/sse_event_repository.dart:16` — Existing `_projectActivity` BehaviorSubject. Follow the same pattern for session activity.
  - `mobile/module_core/lib/src/capabilities/sse/sse_event_repository.dart:26-29` — Existing stream + synchronous accessor pattern. Replicate for session activity.
  - `mobile/module_core/lib/src/capabilities/sse/sse_event_repository.dart:31-41` — `_handleEvent` method. Extend the `SesoriProjectsSummary` case to also extract `activeSessionIds`.

  **API/Type References**:
  - `shared/sesori_shared/lib/src/models/sesori/project_activity_summary.dart` — `ProjectActivitySummary.activeSessionIds` (after T1) — the field to extract.

  **WHY Each Reference Matters**:
  - The existing `_projectActivity` is the exact template. The new `_sessionActivity` follows the same BehaviorSubject pattern with a different data shape (`Set<String>` per worktree instead of `int`).
  - `_handleEvent` already destructures `SesoriProjectsSummary` — extending the existing case is trivial.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: SseEventRepository exposes session activity stream
    Tool: Bash (dart analyze)
    Preconditions: T1 completed
    Steps:
      1. Run: cd mobile/module_core && dart analyze
      2. Verify no analysis errors in sse_event_repository.dart
    Expected Result: dart analyze passes
    Failure Indicators: Type errors related to new BehaviorSubject or missing imports
    Evidence: .sisyphus/evidence/task-4-analyze-mobile.txt

  Scenario: Session activity correctly defaults to empty
    Tool: Bash (dart analyze)
    Preconditions: T1 completed
    Steps:
      1. Verify currentSessionActivity returns empty map when no events received
      2. Run: cd mobile/module_core && dart analyze
    Expected Result: Compiles and analyzes cleanly
    Failure Indicators: Null reference or uninitialized BehaviorSubject
    Evidence: .sisyphus/evidence/task-4-default-value.txt
  ```

  **Commit**: YES (group 3, with T5)
  - Message: `feat(mobile): add session-level activity tracking to cubit and repository`
  - Files: `mobile/module_core/lib/src/capabilities/sse/sse_event_repository.dart`
  - Pre-commit: `cd mobile/module_core && dart analyze`

- [ ] 5. Add active session tracking to `SessionListCubit` and state

  **What to do**:
  - In `mobile/module_core/lib/src/cubits/session_list/session_list_state.dart`:
    - Add field `@Default({}) Set<String> activeSessionIds` to `SessionListLoaded` variant. This holds the set of session IDs that are currently active (busy/retry) for this project.
  - In `mobile/module_core/lib/src/cubits/session_list/session_list_cubit.dart`:
    - Accept `SseEventRepository` as a new constructor parameter (same as `ProjectListCubit` does).
    - Subscribe to `sseEventRepository.sessionActivity` stream in the constructor.
    - In the listener callback, extract the active session IDs for `_worktree` from the `Map<String, Set<String>>` and emit updated state with the new `activeSessionIds`.
    - In `_emitFiltered()`, include `currentSessionActivity` from the repository as the initial value.
    - Run codegen in `mobile/module_core` after changing the Freezed state.
  - Update the `SessionListScreen` widget in `mobile/app/lib/features/session_list/session_list_screen.dart`:
    - Pass `getIt<SseEventRepository>()` to the `SessionListCubit` constructor.

  **Must NOT do**:
  - Do NOT subscribe to `ConnectionService.events` for status events — use the `SseEventRepository` stream instead (single source of truth)
  - Do NOT add session status types (busy/retry) to the state — only the set of active session IDs

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Three files — state model (add field), cubit (add subscription + listener), screen (pass DI dependency). Follows existing patterns.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with T6)
  - **Blocks**: T7, T8
  - **Blocked By**: T4

  **References**:

  **Pattern References**:
  - `mobile/module_core/lib/src/cubits/project_list/project_list_cubit.dart:20-31` — `ProjectListCubit` constructor. Shows how to accept `SseEventRepository` and subscribe to its stream. **Copy this pattern exactly** for `SessionListCubit`.
  - `mobile/module_core/lib/src/cubits/project_list/project_list_cubit.dart:38-47` — `_onActivityUpdated()` handler. Shows how to merge activity data into existing state. Replicate for session activity.
  - `mobile/module_core/lib/src/cubits/project_list/project_list_state.dart:11-14` — `ProjectListLoaded` with `activityByWorktree`. Model for extending `SessionListLoaded`.
  - `mobile/module_core/lib/src/cubits/session_list/session_list_cubit.dart:27-39` — Current constructor. Add `SseEventRepository` parameter after `ConnectionService`.
  - `mobile/module_core/lib/src/cubits/session_list/session_list_state.dart:11-14` — Current `SessionListLoaded`. Add `activeSessionIds` field.
  - `mobile/app/lib/features/session_list/session_list_screen.dart:27-35` — `BlocProvider.create`. Add `getIt<SseEventRepository>()` to cubit constructor.

  **WHY Each Reference Matters**:
  - `ProjectListCubit` is the exact template — it already subscribes to `SseEventRepository.projectActivity`. The session-level version is structurally identical but uses `sessionActivity` and filters by worktree.
  - The screen's `BlocProvider.create` is where DI dependencies are injected. Adding `SseEventRepository` follows the same `getIt<>()` pattern.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: SessionListCubit accepts SseEventRepository
    Tool: Bash (dart analyze)
    Preconditions: T4 completed, codegen run in mobile/module_core
    Steps:
      1. Run: cd mobile/module_core && dart run build_runner build --delete-conflicting-outputs
      2. Run: cd mobile/module_core && dart analyze
      3. Run: cd mobile/app && dart analyze
    Expected Result: All analysis passes — no type errors in cubit, state, or screen
    Failure Indicators: Missing parameter error in SessionListScreen or type mismatch
    Evidence: .sisyphus/evidence/task-5-analyze-cubit.txt

  Scenario: SessionListState.loaded includes activeSessionIds
    Tool: Bash (dart analyze)
    Preconditions: Codegen completed
    Steps:
      1. Verify SessionListLoaded has activeSessionIds field with @Default({})
      2. Run: cd mobile/module_core && dart analyze
    Expected Result: State model compiles with default empty set
    Failure Indicators: Missing field or wrong default value
    Evidence: .sisyphus/evidence/task-5-state-model.txt
  ```

  **Commit**: YES (group 3, with T4)
  - Message: `feat(mobile): add session-level activity tracking to cubit and repository`
  - Files: `mobile/module_core/lib/src/cubits/session_list/session_list_cubit.dart`, `mobile/module_core/lib/src/cubits/session_list/session_list_state.dart`, `mobile/module_core/lib/src/cubits/session_list/session_list_state.freezed.dart`, `mobile/app/lib/features/session_list/session_list_screen.dart`
  - Pre-commit: `cd mobile/module_core && dart analyze && cd ../../mobile/app && dart analyze`

- [ ] 6. Add bridge tests for `buildSummary` session IDs and orchestrator mapping

  **What to do**:
  - In `bridge/sesori_plugin_opencode/test/active_session_tracker_test.dart`:
    - Add test: "buildSummary includes activeSessionIds for busy sessions" — cold-start tracker with 2 busy sessions in same project → assert `buildSummary()` returns entry with `activeSessionIds` containing both session IDs.
    - Add test: "buildSummary excludes idle sessions from activeSessionIds" — start with 2 busy sessions, then idle one → assert only remaining session ID is in list.
    - Add test: "buildSummary groups session IDs by worktree correctly" — 2 projects, 1 busy session each → assert each summary entry has correct session ID.
  - Optionally add orchestrator mapping test if test infrastructure exists for it (check for existing orchestrator test files). If no orchestrator test file exists, document the gap in a code comment.

  **Must NOT do**:
  - Do NOT modify existing test helpers or test cases
  - Do NOT add tests for unrelated orchestrator mappings — only `BridgeSseProjectUpdated`

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Writing tests requires careful setup of test fixtures and understanding of existing test patterns.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with T5)
  - **Blocks**: —
  - **Blocked By**: T2, T3

  **References**:

  **Pattern References**:
  - `bridge/sesori_plugin_opencode/test/active_session_tracker_test.dart:16-26` — Existing test pattern: `_coldStartedTracker(projects: [...])`, send events via `handleEvent()`, assert results. Follow this pattern exactly.
  - `bridge/sesori_plugin_opencode/test/active_session_tracker_test.dart:280-286` — `_sessionBusy()` helper. Creates `SseSessionStatus` with `SessionStatus.busy()`.
  - `bridge/sesori_plugin_opencode/test/active_session_tracker_test.dart:288-308` — `_fakeRepository()` and `_coldStartedTracker()` helpers. Use these for new tests.
  - `bridge/sesori_plugin_opencode/test/active_session_tracker_test.dart:310-350` — `_FakeApi` class. Shows how to mock the API layer.

  **WHY Each Reference Matters**:
  - All existing test infrastructure is already in place — `_coldStartedTracker`, `_sessionBusy`, `_sessionCreated`, `_fakeRepository`. New tests just use these helpers.
  - The test pattern is: create tracker → send SSE events → assert `buildSummary()` / `activeSessions`. New tests add assertions on `activeSessionIds` field.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All bridge tests pass including new buildSummary tests
    Tool: Bash (make test)
    Preconditions: T2 and T3 completed
    Steps:
      1. Run: cd bridge && make test
      2. Verify all tests pass, including new activeSessionIds tests
    Expected Result: All tests pass (0 failures)
    Failure Indicators: Any test failure in active_session_tracker_test.dart
    Evidence: .sisyphus/evidence/task-6-bridge-tests.txt

  Scenario: New tests actually verify session IDs, not just counts
    Tool: Bash (dart test)
    Preconditions: T2 completed
    Steps:
      1. Run: cd bridge/sesori_plugin_opencode && dart test test/active_session_tracker_test.dart -r expanded
      2. Verify test names include "activeSessionIds" or "session IDs"
    Expected Result: At least 3 new tests visible in output
    Failure Indicators: No new tests appear
    Evidence: .sisyphus/evidence/task-6-new-tests.txt
  ```

  **Commit**: YES (group 4)
  - Message: `test(bridge): add tests for buildSummary session IDs`
  - Files: `bridge/sesori_plugin_opencode/test/active_session_tracker_test.dart`
  - Pre-commit: `cd bridge && make test`

- [ ] 7. Add active session indicator to session list UI

  **What to do**:
  - In `mobile/app/lib/features/session_list/session_list_screen.dart`:
    - In `_SessionListBody.build()`, extract `activeSessionIds` from the cubit state (available after T5).
    - Pass `isActive: activeSessionIds.contains(session.id)` to each `_SessionTile`.
    - In `_SessionTile`, add `isActive` parameter. When `true`, display a green dot + "Running" label in the subtitle, following the exact same visual pattern as `_ProjectTile` in `project_list_screen.dart` (lines 119-132):
      ```dart
      if (isActive)
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              loc.sessionListRunning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ```
    - Update `isThreeLine` to account for the new row.
  - In `mobile/app/lib/l10n/app_en.arb`:
    - Add localization string: `"sessionListRunning": "Running"`

  **Must NOT do**:
  - Do NOT add animations or pulsing effects — simple static indicator matching project list
  - Do NOT change the CircleAvatar leading icon — add the indicator in subtitle like projects do
  - Do NOT add any filtering/toggle for active sessions — just visual indicator

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI widget modification with visual indicator. Needs to match existing project list pattern precisely.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T8)
  - **Blocks**: —
  - **Blocked By**: T5

  **References**:

  **Pattern References**:
  - `mobile/app/lib/features/project_list/project_list_screen.dart:92-132` — **THE visual pattern to match**. Shows `isActive` check, green dot `Icon(Icons.circle, size: 8, color: theme.colorScheme.primary)`, `SizedBox(width: 4)`, text with `colorScheme.primary` and `FontWeight.w500`. Copy this styling exactly.
  - `mobile/app/lib/features/session_list/session_list_screen.dart:273-353` — Current `_SessionTile` widget. The subtitle `Column` (lines 324-339) is where the indicator goes, after `updatedAt` and `filesChanged`.
  - `mobile/app/lib/features/session_list/session_list_screen.dart:221-259` — `SessionListLoaded` branch with `ListView.builder`. This is where `activeSessionIds` is extracted from state and passed to each tile.
  - `mobile/app/lib/features/session_list/session_list_screen.dart:246-258` — `itemBuilder`. Add `isActive: state.activeSessionIds.contains(session.id)` to `_SessionTile` constructor.

  **External References**:
  - `mobile/app/lib/l10n/app_en.arb:49-50` — Existing `projectListActiveSessions` localization pattern. The session version is simpler: just "Running" (no count needed since it's per-session).

  **WHY Each Reference Matters**:
  - `project_list_screen.dart:119-132` is the gold standard for the visual indicator. The user explicitly said "same kind of indicator". This must be pixel-identical in style.
  - `session_list_screen.dart` widget structure shows exactly where the new Row should be inserted in the subtitle Column.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Session list UI compiles with active indicator
    Tool: Bash (dart analyze)
    Preconditions: T5 completed
    Steps:
      1. Run: cd mobile/app && dart analyze
      2. Verify no analysis errors in session_list_screen.dart
    Expected Result: dart analyze passes
    Failure Indicators: Type error for isActive parameter or missing localization
    Evidence: .sisyphus/evidence/task-7-analyze-ui.txt

  Scenario: Localization string exists
    Tool: Bash (grep)
    Preconditions: Localization file updated
    Steps:
      1. Verify "sessionListRunning" key exists in mobile/app/lib/l10n/app_en.arb
      2. Run: cd mobile/app && dart analyze
    Expected Result: Localization compiles correctly
    Failure Indicators: Missing localization key causes compile error
    Evidence: .sisyphus/evidence/task-7-localization.txt

  Scenario: _SessionTile accepts isActive parameter
    Tool: Bash (dart analyze)
    Preconditions: Widget updated
    Steps:
      1. Verify _SessionTile constructor includes isActive: bool
      2. Verify all call sites pass the parameter
      3. Run: cd mobile/app && dart analyze
    Expected Result: No missing argument errors
    Failure Indicators: Required parameter not passed at call site
    Evidence: .sisyphus/evidence/task-7-widget-param.txt
  ```

  **Commit**: YES (group 5)
  - Message: `feat(mobile): add active session indicator to session list UI`
  - Files: `mobile/app/lib/features/session_list/session_list_screen.dart`, `mobile/app/lib/l10n/app_en.arb`
  - Pre-commit: `cd mobile/app && dart analyze`

- [ ] 8. Add mobile tests for session activity tracking

  **What to do**:
  - Create or extend test file for `SseEventRepository`:
    - Test: "sessionActivity emits active session IDs from projectsSummary event" — feed a `SesoriProjectsSummary` event with `activeSessionIds: ["s1", "s2"]` → verify `sessionActivity` stream emits `{"/path": {"s1", "s2"}}`.
    - Test: "sessionActivity defaults to empty map" — verify initial value is `{}`.
    - Test: "sessionActivity excludes worktrees with no active sessions" — feed event with `activeSessions: 0, activeSessionIds: []` → verify worktree not in map.
  - Create or extend test file for `SessionListCubit`:
    - Test: "state includes activeSessionIds from SseEventRepository" — mock `SseEventRepository.sessionActivity` stream, emit activity data → verify `SessionListLoaded.activeSessionIds` contains correct IDs.
    - Test: "activeSessionIds updates when activity changes" — emit initial data, then updated data → verify state reflects change.

  **Must NOT do**:
  - Do NOT test UI rendering — only cubit/repository logic
  - Do NOT test the full SSE pipeline end-to-end — test each unit in isolation

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Standard bloc_test / unit test patterns. Follow existing test conventions.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T7)
  - **Blocks**: —
  - **Blocked By**: T5

  **References**:

  **Pattern References**:
  - Check for existing test files in `mobile/module_core/test/` — look for cubit tests or repository tests to follow conventions.
  - `bridge/sesori_plugin_opencode/test/active_session_tracker_test.dart` — General test pattern in this codebase: plain `test()` functions, helpers for test fixtures, assertions on computed values.

  **API/Type References**:
  - `mobile/module_core/lib/src/capabilities/sse/sse_event_repository.dart` — Public API: `sessionActivity`, `currentSessionActivity`. These are what tests assert against.
  - `mobile/module_core/lib/src/cubits/session_list/session_list_state.dart` — `SessionListLoaded.activeSessionIds`. Verify this field in cubit tests.

  **WHY Each Reference Matters**:
  - Existing test patterns in this codebase show the testing style (plain dart test, mocktail for mocks). Following these ensures consistency.
  - The public API of `SseEventRepository` and `SessionListCubit` defines the test contract.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All mobile tests pass
    Tool: Bash (dart test)
    Preconditions: T4 and T5 completed
    Steps:
      1. Run: cd mobile/module_core && dart test
      2. Verify all tests pass including new session activity tests
    Expected Result: All tests pass (0 failures)
    Failure Indicators: Any test failure in new test files
    Evidence: .sisyphus/evidence/task-8-mobile-tests.txt

  Scenario: New tests cover both repository and cubit
    Tool: Bash (dart test)
    Preconditions: Tests written
    Steps:
      1. Run: cd mobile/module_core && dart test -r expanded
      2. Verify test output includes tests for both SseEventRepository and SessionListCubit
    Expected Result: At least 5 new tests visible (3 repository + 2 cubit)
    Failure Indicators: Missing test groups
    Evidence: .sisyphus/evidence/task-8-test-count.txt
  ```

  **Commit**: YES (group 6)
  - Message: `test(mobile): add tests for session activity tracking`
  - Files: `mobile/module_core/test/...` (new or extended test files)
  - Pre-commit: `cd mobile/module_core && dart test`

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read `.sisyphus/plans/fix-activity-tracking.md` end-to-end. For each "Must Have": verify implementation exists. For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in `.sisyphus/evidence/`. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `dart analyze` in `shared/sesori_shared`, `bridge/` (all modules via `make analyze`), `mobile/` (all modules). Run `make test` from `bridge/`, `dart test` from `mobile/module_core`. Review all changed files for: `as any`/`@ts-ignore` equivalents, empty catches, unused imports. Check AI slop: excessive comments, over-abstraction.
  Output: `Analyze [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Verify JSON roundtrip for `ProjectActivitySummary` with `activeSessionIds`. Run `ActiveSessionTracker` test suite. Run mobile cubit tests. Save evidence to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (`git log`/`git diff`). Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | VERDICT`

---

## Commit Strategy

| # | Scope | Message | Files | Pre-commit |
|---|-------|---------|-------|------------|
| 1 | T1 | `feat(shared): add activeSessionIds to ProjectActivitySummary` | `shared/sesori_shared/...`, `bridge/sesori_plugin_interface/...` | `dart analyze` in both |
| 2 | T2+T3 | `fix(bridge): send projectsSummary on activity change and expose session IDs` | `bridge/sesori_plugin_opencode/...`, `bridge/app/...` | `make analyze` from `bridge/` |
| 3 | T4+T5 | `feat(mobile): add session-level activity tracking to cubit and repository` | `mobile/module_core/...` | `dart analyze` in `mobile/module_core` |
| 4 | T6 | `test(bridge): add tests for buildSummary session IDs and orchestrator mapping` | `bridge/sesori_plugin_opencode/test/...` | `make test` from `bridge/` |
| 5 | T7 | `feat(mobile): add active session indicator to session list UI` | `mobile/app/...` | `dart analyze` in `mobile/app` |
| 6 | T8 | `test(mobile): add tests for session activity tracking` | `mobile/module_core/test/...` | `dart test` in `mobile/module_core` |

---

## Success Criteria

### Verification Commands
```bash
cd shared/sesori_shared && dart analyze    # Expected: No issues found
cd bridge && make analyze                  # Expected: No issues found (all modules)
cd bridge && make test                     # Expected: All tests pass
cd mobile/module_core && dart analyze      # Expected: No issues found
cd mobile/module_core && dart test         # Expected: All tests pass
cd mobile/app && dart analyze              # Expected: No issues found
```

### Final Checklist
- [ ] All "Must Have" present (mapping pattern match, codegen order)
- [ ] All "Must NOT Have" absent (no `_mapsEqual` changes, no new BridgeSseEvent variants, no animations)
- [ ] All tests pass across bridge and mobile workspaces
