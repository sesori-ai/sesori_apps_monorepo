# Step 21 — FIFO lanes on `ParallelLock`

## Parent

`27ba00bbb`

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

Final diff: `15 files changed, 358 insertions, 165 deletions`. Reproduce with `git diff --shortstat 27ba00bbb15a9291794fb653ce0382d16c16a9cd..HEAD`.

## Verification

- `dart test` in `bridge/sesori_bridge_foundation`: pass, 77 tests.
- Planned app service/listener matrix: pass, 226 tests (209 activity,
  mutation, unseen, options, event-dispatch, chat-history, and plugin-listener
  tests plus 17 bridge-settings tests).
- `dart analyze --fatal-infos` in `bridge/sesori_bridge_foundation`: pass.
- `dart analyze --fatal-infos` in `bridge/app`: pass.
- `git diff --check`: pass.
- `dart format` formatted eight supported touched Dart files and the dispatcher test with no changes. Formatting `session_options_service.dart` remains blocked by known `dart_style` crash on repository-supported Dart 3.13 primary-constructor syntax; analyzer passes.

## Architecture implementation review

The required review was invoked through a sub-agent, but the
`architecture-implementation-review` skill was unavailable in the tool registry.
No substitute architecture verdict is claimed.
