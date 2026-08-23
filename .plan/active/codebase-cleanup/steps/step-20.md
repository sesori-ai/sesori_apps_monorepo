# Step 20 evidence

## Context

- Branch: `codebase-cleanup/step-20-session-repositories`
- Parent commit: `f5fc700ba`
- All committed Step 19 review fixes are preserved.

## Implementation decisions

- Consolidated session binding/runtime/directory priming in `_useSessionPlugin`, PromptModel conversion, chunked session-ID reads, generated session IDs, and hidden placeholder `ProjectDto` construction.
- Reduced `enrichSessions` to visible-PR enrichment over already-mapped catalog sessions. Removed row rereads, `plugin_session_mapper.dart`, derived-plugin ownership wiring, and stale row-rederivation expectations while retaining visible-PR selection coverage.
- `GetSessionHandler` now reads one catalog session and enriches that DTO. Removed production-dead `findProjectIdForSession` and `getSessionForProject`; tests and benchmark use `getCatalogSession` directly.
- Added same-layer `PendingInteractionSupport` owning shared binding, visibility, tombstone mutation checks, and bridge-ID mapping. Question and permission repositories depend on support, not each other; mapper imports stay with support.
- Replaced bridge-local `ProjectActivity` with shared `ProjectTime` across repositories, service, and tests. Retained only distinct `ProjectActivityChange` and `StoredProjectActivity` models.
- `PullRequestTargetSelected` now carries `GhPullRequest` plus target; repository and tests consume DTO fields directly.
- Moved `preservePullRequestScope` decision from `SessionDao` to `SessionRepository`. DAO receives explicit policy; schema unchanged.
- Replaced direct HOME/USERPROFILE reads with `resolveUserHomeDirectory` and added local warning with error/stack for aggregate session-status failures.
- Wire contracts, database schema, and plugin boundaries unchanged.

## Generation-fence conclusion

Inner repository generation checks retained. `_beginStart` bumps generation at `plugin_runtime.dart:1228-1233` without first awaiting `_waitForDurableCommits`; waits exist on graceful stop/dispose/failure cleanup (`plugin_runtime.dart:901`, `983`, `1101`, `1476`), but no universal await boundary gates every generation bump. Removing inner checks is not proven safe.

## Diff size

The final staged diff covers 56 files with 602 insertions and 743 deletions. The
broad file count comes from explicit `preservePullRequestScope` argument updates
across direct DAO callers.

## Verification

- Focused Step 20 repository, runtime, routing, activity, PR-selection, and DAO
  matrix: PASS, 330 tests.
- Direct message/delete routing coverage for the final plugin-use consolidation:
  PASS, 25 tests.
- `dart analyze --fatal-infos` from `bridge/app`: PASS, no issues.
- Supported touched Dart files formatted. `session_repository.dart` and `orchestrator.dart` remain excluded because pinned `dart_style` crashes on existing enhanced-enum syntax; analyzer parses both successfully.
- `git diff --check`: PASS.

## Intentionally retained

- Inner generation checks retained for concrete runtime boundary reason above.

## Architecture implementation review

The required review was invoked through a sub-agent, but the
`architecture-implementation-review` skill was unavailable in the tool registry.
No substitute architecture verdict is claimed.
