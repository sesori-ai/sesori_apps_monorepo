# Step 21 — FIFO lanes on `ParallelLock`

## Parent

`e919de274`

## Result

- Added snapshot-semantic `ParallelLock.idle`, composed on the existing foundation `PendingOperations` rather than a second set/`whenComplete`/`Future.wait` copy (Complexity Guardrail: one `PendingOperations`).
- Added public `KeyedParallelLock<K>` with per-key FIFO execution, independent keys, error-safe release, idle snapshots (`idle`, `idleFor`), and automatic entry removal once every accepted user settles.
- Replaced six single FIFO tails and four keyed-tail implementations with foundation locks. Two sites were missed by the plan's audit and found during re-verification: `PluginLifecycleService` settings mutations (single) and `RuntimeFileApi.updateFile` (keyed per file name). Public barrel already exported `parallel_lock.dart`, so no export change was needed.
- Kept `ChatHistoryService._enqueueAll` private. It submits one reservation per unique session lane in a single synchronous burst, waits until every reservation holds its lane, runs the write, then releases them together. Deadlock-freedom comes from that synchronous burst: `use` takes its FIFO position on each lane before returning, so two multi-session writes meet in the same relative order on every lane they share. Sorting the ids is not what protects it (a probe with one `await` between sorted submissions deadlocked), so the code documents the real invariant instead. Single-session writes (`_enqueue`) use the lane directly.
- Kept every `SessionOptionsService` invalidation-epoch check. Invalidations use keyed lanes so unrelated cache keys remain independent, while commits wait only for the named key's invalidation snapshot. Owner did not accept serving a just-invalidated retained snapshot once.
- `SessionEventDispatcher.dispose` rejects new work after disposal begins, drains the accepted snapshot, then closes output; dispatch errors remain stream errors and release the keyed lane for later work.
- Behavior-preserving: every replaced tail already released its lane on failure, and what each caller observes (rethrow, swallow-and-log, or stream error) is unchanged per site. Minor deltas only: `SessionUnseenService` user-initiated writes no longer log in addition to rethrowing (the request-handler base logs the failure with error and stack), the dispatcher no longer keeps one map entry per plugin forever, and a rejected-selection delete starts one microtask later while still being fenced by the synchronous `use` registration.
- No wire, database, or schema changes. `SessionOperationDispatcher` lanes, the orchestrator per-plugin lane, and the three dispatchers remain unchanged by plan.

## Diff

Final diff: `17 files changed, 443 insertions, 231 deletions`. Reproduce with `git diff --shortstat e919de274be00e237d9a76dde69b97a517e0a425..HEAD`.

## Verification

- `dart test` in `bridge/sesori_bridge_foundation`: pass, 78 runtime test
  cases (70 plain `test(` declarations; loop-defined cases account for the
  remaining eight).
- Affected bridge app suites (chat-history, project activity/mutation,
  unseen, session options, event dispatcher, bridge settings, plugin
  lifecycle service and command handler, runtime file API, startup mutex,
  host JSON store, plugin generation factory): pass, 341 tests.
- `dart analyze --fatal-infos` in `bridge/sesori_bridge_foundation`: pass.
- `dart analyze --fatal-infos` in `bridge/app`: pass.
- `git diff --check`: pass.
- `dart format` on the touched Dart files that `dart_style` supports: no
  changes. Formatting `session_options_service.dart` remains blocked by the
  known `dart_style` crash on repository-supported Dart 3.13
  primary-constructor syntax; analyzer passes.
- Review probe (not committed): 200 randomized rounds of mixed single- and
  multi-session operations with interleaved submissions and random failures
  against `KeyedParallelLock` plus a copy of `_enqueueAll` — no deadlock, no
  per-key overlap, per-key execution order equal to submission order.

## Architecture implementation review

Gate status: passed. `architecture-implementation-review` was run through a
sub-agent twice on 2026-08-23: on head `9808fbebc` and again on the updated
branch (`origin/main...HEAD`, including the `PendingOperations` composition and
the `PluginLifecycleService`/`RuntimeFileApi` sites). Both passes: APPROVED,
zero findings. The reviewer also rejected the bot claim that Layer-3 services
importing `sesori_bridge_foundation` skip layers: the no-skip rule governs the
data/transport path (Service -> Repository -> API), `sesori_bridge_foundation`
is the sibling Layer-0 workspace package already consumed by services,
repositories, listeners, and APIs at the merge-base, and a pure in-memory
concurrency primitive has no intermediate layer to bypass.
