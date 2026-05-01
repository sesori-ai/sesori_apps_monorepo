import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../core/extensions/build_context_x.dart";
import "assistant_message_card.dart";
import "error_message_card.dart";
import "follow_detach_scrollable.dart";
import "jump_to_edge_pill.dart";
import "scroll_follow_tracker.dart";
import "user_message_card.dart";

/// Chat-style message list for the session detail screen.
///
/// Scroll behaviour — "follow / detach":
///
/// - Uses a `reverse: true` `ListView.builder` so the newest message
///   renders at the visual bottom (scroll offset `0`).
/// - While **following**, a coalesced post-frame `jumpTo(0)` runs via
///   the [ScrollFollowTracker] — race-free pin-to-edge, never a
///   delta-based compensation.
/// - While **detached** (user dragged / trackpad-scrolled / pan-zoomed
///   away from the bottom), the full set of rendered inputs
///   (`messages`, `streamingText`, `children`, `childStatuses`) is
///   snapshotted and rendered in place of the live values. New data
///   still arrives in the background but nothing below (or above) the
///   user's viewport can grow, shrink, or reorder under them. The
///   snapshot is cleared the moment the user reattaches.
/// - `findChildIndexCallback` is mandatory: every append shifts every
///   existing item's builder index by 1 (we append to the data list
///   then flip with `messages.length - 1 - index`), so without it
///   `SliverChildBuilderDelegate` loses child identity and preserved
///   element state.
///
/// Gesture plumbing and the detached overlay toggle live in
/// [FollowDetachScrollable]; this widget only owns message rendering,
/// the detached snapshot, and the follow controller lifecycle.
class SessionDetailMessageList extends StatefulWidget {
  final String? projectId;
  final List<MessageWithParts> messages;
  final Map<String, String> streamingText;
  final List<Session> children;
  final Map<String, SessionStatus> childStatuses;

  const SessionDetailMessageList({
    super.key,
    required this.projectId,
    required this.messages,
    required this.streamingText,
    required this.children,
    required this.childStatuses,
  });

  @override
  State<SessionDetailMessageList> createState() => _SessionDetailMessageListState();
}

/// Immutable snapshot of the rendered inputs taken the moment the user
/// detaches. Rendered in place of live widget props while detached so
/// the viewport stays pinned to what the user was reading.
typedef _DetachedSnapshot = ({
  List<MessageWithParts> messages,
  Map<String, String> streamingText,
  List<Session> children,
  Map<String, SessionStatus> childStatuses,
});

class _SessionDetailMessageListState extends State<SessionDetailMessageList> {
  static const _kListViewKey = Key("session-detail-message-list-view");
  static const _kJumpToLatestKey = Key("session-detail-jump-to-latest");

  late final ScrollFollowTracker _follow;

  /// Snapshot taken at the moment of detach. `null` means "not frozen
  /// — use live `widget.*` props".
  _DetachedSnapshot? _snapshot;

  /// Cache for the id → builder-index map consumed by
  /// `findChildIndexCallback`. Keyed on a content signature of
  /// `(length, firstId, lastId)` — NOT list identity. The cubit's
  /// `state.messages` getter is the Freezed-generated
  /// `EqualUnmodifiableListView` wrapper which is recreated on every
  /// access, so an `identical(...)` cache would miss on every emit.
  /// The content signature is cheap (three reads) and correct for
  /// every mutation the cubit performs today: append, remove, and
  /// same-order part updates all either change the signature or
  /// preserve the full id ordering. `null` means "cache empty".
  int? _indexSignature;
  Map<String, int> _indexById = const <String, int>{};

  @override
  void initState() {
    super.initState();
    _follow = ScrollFollowTracker(edge: ScrollFollowEdge.min);
    _follow.addListener(_syncSnapshot);
  }

  @override
  void dispose() {
    _follow.removeListener(_syncSnapshot);
    _follow.dispose();
    super.dispose();
  }

  void _syncSnapshot() {
    if (!mounted) return;
    setState(() {
      if (_follow.following) {
        _snapshot = null;
      } else {
        _snapshot ??= (
          messages: List<MessageWithParts>.unmodifiable(widget.messages),
          streamingText: Map<String, String>.unmodifiable(widget.streamingText),
          children: List<Session>.unmodifiable(widget.children),
          childStatuses: Map<String, SessionStatus>.unmodifiable(widget.childStatuses),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final snap = _snapshot;
    final messages = snap?.messages ?? widget.messages;
    final streamingText = snap?.streamingText ?? widget.streamingText;
    final children = snap?.children ?? widget.children;
    final childStatuses = snap?.childStatuses ?? widget.childStatuses;

    // Map message id → data-source index. Consulted by
    // `findChildIndexCallback` so the reversed builder keeps stable
    // element identity across appends that shift every existing index.
    // Recomputed only when the content signature changes — skips the
    // O(N) rebuild on every streaming-text emit.
    final indexById = _indexByIdFor(messages: messages);

    // Coalesced post-frame pin-to-edge while following. The scheduler
    // collapses repeated calls within a frame and the jump is skipped
    // when `position.pixels` is already at the edge. Completely
    // different from the old delta-compensation logic — there are no
    // stale captures and the target is always `0`.
    _follow.scheduleJumpToEdge();

    return FollowDetachScrollable(
      tracker: _follow,
      detachedOverlayBuilder: (ctx) => JumpToEdgePill(
        tapTargetKey: _kJumpToLatestKey,
        label: loc.sessionDetailJumpToLatest,
        onTap: () => _follow.animateToEdge(),
      ),
      child: ListView.builder(
        key: _kListViewKey,
        controller: _follow.scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: messages.length,
        findChildIndexCallback: (key) => _findChildIndex(
          key: key,
          indexById: indexById,
          totalCount: messages.length,
        ),
        itemBuilder: (context, index) {
          final message = messages[messages.length - 1 - index];
          return KeyedSubtree(
            key: ValueKey(message.info.id),
            child: _buildCard(
              message: message,
              streamingText: streamingText,
              children: children,
              childStatuses: childStatuses,
            ),
          );
        },
      ),
    );
  }

  Map<String, int> _indexByIdFor({required List<MessageWithParts> messages}) {
    final signature = _signatureOf(messages: messages);
    if (signature == _indexSignature) return _indexById;
    _indexSignature = signature;
    return _indexById = <String, int>{
      for (var i = 0; i < messages.length; i++) messages[i].info.id: i,
    };
  }

  int _signatureOf({required List<MessageWithParts> messages}) {
    if (messages.isEmpty) return 0;
    return Object.hash(messages.length, messages.first.info.id, messages.last.info.id);
  }

  int? _findChildIndex({
    required Key key,
    required Map<String, int> indexById,
    required int totalCount,
  }) {
    if (key is! ValueKey<String>) return null;
    final sourceIndex = indexById[key.value];
    if (sourceIndex == null) return null;
    return totalCount - 1 - sourceIndex;
  }

  Widget _buildCard({
    required MessageWithParts message,
    required Map<String, String> streamingText,
    required List<Session> children,
    required Map<String, SessionStatus> childStatuses,
  }) {
    return switch (message.info) {
      MessageUser() => UserMessageCard(message: message),
      MessageAssistant() => AssistantMessageCard(
        projectId: widget.projectId,
        message: message,
        streamingText: streamingText,
        children: children,
        childStatuses: childStatuses,
      ),
      final MessageError messageError => ErrorMessageCard(message: messageError),
    };
  }
}
