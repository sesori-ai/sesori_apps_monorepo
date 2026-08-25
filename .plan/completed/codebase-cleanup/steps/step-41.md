# Step 41 — Plain Reversed Transcript List

## Re-verified evidence

- `session_detail_message_list.dart` remained sole source consumer of `flutter_chat_ui` and `flutter_chat_core`.
- Existing widget suite covered follow/detach, detached snapshots, older-page prepend, prompt transitions, retry/streaming rows, stable keys, timestamp gestures, and inset behavior.
- PR #939 work was not present or imported.

## Change

- Replaced `Chat`, `ChatAnimatedListReversed`, and `InMemoryChatController` mirroring with `ListView.builder(reverse: true, controller: _follow.scrollController)`.
- Kept domain-order row IDs, reversed builder indexing, prompt lifecycle IDs, `ScrollFollowTracker`, `FollowDetachScrollable`, snapshots, pagination in-flight gate, reveal gestures, and row widgets.
- Added reversed stable-row lookup so Flutter preserves row state across ordering changes.
- Made older-page callback gating reset on completion/error, suppress overlap with callback and parent loading state, and log caught failures with stack traces.
- Removed both chat dependencies and regenerated `client/pubspec.lock` with workspace `dart pub get`.
- Updated transcript and history regression documents.

## Verification

- `dart pub get` from `client/`: passed.
- `dart format lib/features/session_detail/widgets/session_detail_message_list.dart test/features/session_detail/widgets/session_detail_message_list_test.dart`: passed.
- Added focused coverage for callback overlap, completion/error retry, parent loading-state suppression, and moved prompt row-state identity.
- `flutter test test/features/session_detail/widgets/session_detail_message_list_test.dart`: passed, 37 tests. Expected pagination-error fixture logs remained observable.
- `dart analyze --fatal-infos` from `client/app`: passed, no issues.
- `git diff --check`: passed.
- `flutter test test/features/session_detail`: passed, 245 tests. Expected fixture error logs and one existing non-fatal hit-test warning remained observable.

## Post-merge follow-up

The replaced package prefetched the older page at 20% from the visual top,
while the landed trigger waited for a scroll to end exactly at the oldest
edge — reported as history scrolling feeling less smooth. A follow-up PR
restores prefetch: older pages now load from scroll updates within ~600px
(about one viewport) of the oldest edge, keeping the scroll-end fallback for
transcripts too short to scroll and all existing request gates.
