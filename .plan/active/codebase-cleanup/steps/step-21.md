# Step 21 — FIFO lanes on `ParallelLock`

## Parent

`e919de274`

## Result

- Added snapshot-semantic `ParallelLock.idle`.
- Added public `KeyedParallelLock<K>` with per-key FIFO execution, independent keys, error-safe release, idle snapshots, and automatic idle entry removal after every accepted user settles.
- Replaced five single FIFO tails and three keyed-tail implementations with foundation locks. Public barrel already exported `parallel_lock.dart`, so no export change was needed.
- Kept `ChatHistoryService._enqueueAll` private. It synchronously submits one reservation to every sorted unique session lane, waits until all reservations hold their lanes, then runs the write and releases them together. This preserves submission-time FIFO on every key and remains deadlock-safe because reservations wait only on one shared release barrier, never on another lane.
- Kept every `SessionOptionsService` invalidation-epoch check. Invalidations use keyed lanes so unrelated cache keys remain independent, while commits wait only for the named key's invalidation snapshot. Owner did not accept serving a just-invalidated retained snapshot once.
- `SessionEventDispatcher.dispose` rejects new work after disposal begins, drains the accepted snapshot, then closes output; dispatch errors remain stream errors and release the keyed lane for later work.
- Intentionally unified lane failure policy: failed operations release their lane and later queued work continues.
- No wire, database, or schema changes. Out-of-scope dispatchers and lanes remain unchanged.

## Diff

Final diff: `15 files changed, 369 insertions, 166 deletions`. Reproduce with `git diff --shortstat e919de274be00e237d9a76dde69b97a517e0a425..HEAD`.

## Verification

- `dart test` in `bridge/sesori_bridge_foundation`: pass, 78 runtime test
  cases. The source contains 70 plain `test(` declarations after this step;
  loop-defined cases account for the remaining eight runtime cases.
- Planned app service/listener matrix: pass, 226 tests (209 activity,
  mutation, unseen, options, event-dispatch, chat-history, and plugin-listener
  tests plus 17 bridge-settings tests).
- `dart analyze --fatal-infos` in `bridge/sesori_bridge_foundation`: pass.
- `dart analyze --fatal-infos` in `bridge/app`: pass.
- `git diff --check`: pass.
- `dart format` formatted eight supported touched Dart files and the dispatcher test with no changes. Formatting `session_options_service.dart` remains blocked by known `dart_style` crash on repository-supported Dart 3.13 primary-constructor syntax; analyzer passes.

## Architecture implementation review

Gate status: blocked. The required review was invoked through a sub-agent, but
the `architecture-implementation-review` skill was unavailable in the tool
registry. The verification above is test/analyzer evidence only; no substitute
architecture verdict or waiver is claimed, so human architecture review remains
required before merge.
