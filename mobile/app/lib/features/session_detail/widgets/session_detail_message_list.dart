import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_chat_core/flutter_chat_core.dart" as chat_core;
import "package:flutter_chat_ui/flutter_chat_ui.dart" as chat_ui;
import "package:sesori_dart_core/logging.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../core/extensions/build_context_x.dart";
import "assistant_message_card.dart";
import "error_message_card.dart";
import "follow_detach_scrollable.dart";
import "jump_to_edge_pill.dart";
import "retry_error_message_card.dart";
import "scroll_follow_tracker.dart";
import "user_message_card.dart";

/// Chat-style message list for the session detail screen, rendered with
/// the flyerhq `flutter_chat_ui` v2 stack (`Chat` +
/// `ChatAnimatedListReversed` + `InMemoryChatController`).
///
/// Integration model:
///
/// - The [chat_core.ChatController] holds **content-stable index
///   entries** only — one `CustomMessage(id, authorId)` per domain
///   message (plus one synthetic entry for the retry-error row). All
///   visible content (message parts, streaming text, tool state) is
///   resolved from the cubit-provided widget props inside the row
///   builders, keyed by message id. Token deltas therefore never
///   round-trip through the controller: `setMessages` diffs (by id +
///   freezed equality) emit operations only when the message *set*
///   changes, and in-place content updates flow through ordinary
///   widget rebuilds.
/// - Every per-row default of the package is replaced: the row wrapper
///   (`chatMessageBuilder` returns the bare child — no bubble, no
///   alignment, no gestures), the composer (the prompt input lives
///   outside this widget), the scroll-to-bottom button and the empty
///   state (both owned by this feature already).
///
/// Scroll behaviour — "follow / detach" (unchanged semantics):
///
/// - The list is reversed, so the newest message renders at the visual
///   bottom (scroll offset `0`).
/// - While **following**, a coalesced post-frame `jumpTo(0)` runs via
///   the [ScrollFollowTracker] — race-free pin-to-edge. The package's
///   own auto-scroll is disabled (`shouldScrollToEndWhenSendingMessage:
///   false`; the at-bottom variant is a no-op for reversed lists).
/// - While **detached** (user dragged / trackpad-scrolled / pan-zoomed
///   away from the bottom), the full set of rendered inputs
///   (`messages`, `streamingText`, `children`, `childStatuses`) is
///   snapshotted AND controller syncing is suspended, so nothing below
///   (or above) the user's viewport can grow, shrink, or reorder under
///   them. Both freezes lift the moment the user reattaches.
///
/// Gesture plumbing and the detached overlay toggle live in
/// [FollowDetachScrollable]; this widget owns message rendering, the
/// detached snapshot, and the follow/chat controller lifecycles.
class SessionDetailMessageList extends StatefulWidget {
  final String? projectId;
  final List<MessageWithParts> messages;
  final Map<String, String> streamingText;
  final List<Session> children;
  final Map<String, SessionStatus> childStatuses;
  final String? retryErrorMessage;

  const SessionDetailMessageList({
    super.key,
    required this.projectId,
    required this.messages,
    required this.streamingText,
    required this.children,
    required this.childStatuses,
    this.retryErrorMessage,
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
  String? retryErrorMessage,
});

class _SessionDetailMessageListState extends State<SessionDetailMessageList> {
  static const _kListViewKey = Key("session-detail-message-list-view");
  static const _kJumpToLatestKey = Key("session-detail-jump-to-latest");

  /// Synthetic controller-entry id for the shimmering retry-error row
  /// pinned at the newest edge. Domain message ids come from the
  /// assistant backend and cannot collide with this.
  static const _kRetryErrorRowId = "session-detail-retry-error-row";

  static const _kUserAuthorId = "user";
  static const _kAgentAuthorId = "agent";

  late final ScrollFollowTracker _follow;
  late final chat_core.InMemoryChatController _chatController;

  /// Snapshot taken at the moment of detach. `null` means "not frozen
  /// — use live `widget.*` props".
  _DetachedSnapshot? _snapshot;

  /// Cache for the id → data-source-index map consumed by the row
  /// builder. Keyed on a content signature of `(length, firstId,
  /// lastId)` — NOT list identity. The cubit's `state.messages` getter
  /// is the Freezed-generated `EqualUnmodifiableListView` wrapper which
  /// is recreated on every access, so an `identical(...)` cache would
  /// miss on every emit. The content signature is cheap (three reads)
  /// and correct for every mutation the cubit performs today: append,
  /// remove, and same-order in-place part updates all either change the
  /// signature or preserve the full id ordering. Values are positions,
  /// not message objects, so in-place part updates (which keep the
  /// signature stable) still resolve fresh content from the live list.
  int? _indexSignature;
  Map<String, int> _indexById = const <String, int>{};

  @override
  void initState() {
    super.initState();
    _follow = ScrollFollowTracker(edge: ScrollFollowEdge.min);
    _follow.addListener(_onFollowChanged);
    _chatController = chat_core.InMemoryChatController(
      messages: _chatEntriesFor(
        messages: widget.messages,
        hasRetryError: widget.retryErrorMessage != null,
      ),
    );
  }

  @override
  void dispose() {
    _follow.removeListener(_onFollowChanged);
    _follow.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SessionDetailMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While detached the controller is intentionally left stale so the
    // list structure cannot shift under the reader; `_onFollowChanged`
    // re-syncs on reattach.
    if (_follow.following) {
      _syncChatController();
    }
  }

  void _onFollowChanged() {
    if (!mounted) return;
    setState(() {
      if (_follow.following) {
        _snapshot = null;
        _syncChatController();
      } else {
        _snapshot ??= (
          messages: List<MessageWithParts>.unmodifiable(widget.messages),
          streamingText: Map<String, String>.unmodifiable(widget.streamingText),
          children: List<Session>.unmodifiable(widget.children),
          childStatuses: Map<String, SessionStatus>.unmodifiable(widget.childStatuses),
          retryErrorMessage: widget.retryErrorMessage,
        );
      }
    });
  }

  /// Mirrors the domain transcript into the chat controller. Entries
  /// are value-equal for unchanged messages, so the controller's
  /// diff-based `setMessages` emits insert/remove operations only for
  /// genuine set changes — streaming emits are filtered out by the
  /// cheap id comparison below and never touch the animated list.
  void _syncChatController() {
    final target = _chatEntriesFor(
      messages: widget.messages,
      hasRetryError: widget.retryErrorMessage != null,
    );
    final current = _chatController.messages;
    if (_entriesMatch(current: current, target: target)) return;
    unawaited(
      _chatController.setMessages(target, animated: false).catchError(
        (Object error, StackTrace stack) => loge("Failed to sync chat controller messages", error, stack),
      ),
    );
  }

  bool _entriesMatch({
    required List<chat_core.Message> current,
    required List<chat_core.Message> target,
  }) {
    if (current.length != target.length) return false;
    for (var i = 0; i < target.length; i++) {
      if (current[i].id != target[i].id) return false;
    }
    return true;
  }

  List<chat_core.Message> _chatEntriesFor({
    required List<MessageWithParts> messages,
    required bool hasRetryError,
  }) {
    return <chat_core.Message>[
      for (final message in messages)
        chat_core.Message.custom(
          id: message.info.id,
          authorId: switch (message.info) {
            MessageUser() => _kUserAuthorId,
            MessageAssistant() => _kAgentAuthorId,
            MessageError() => _kAgentAuthorId,
          },
        ),
      if (hasRetryError) const chat_core.Message.custom(id: _kRetryErrorRowId, authorId: _kAgentAuthorId),
    ];
  }

  static Future<chat_core.User?> _resolveUser(String id) async => chat_core.User(id: id);

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final snap = _snapshot;
    final messages = snap?.messages ?? widget.messages;
    final streamingText = snap?.streamingText ?? widget.streamingText;
    final children = snap?.children ?? widget.children;
    final childStatuses = snap?.childStatuses ?? widget.childStatuses;
    final retryErrorMessage = snap?.retryErrorMessage ?? widget.retryErrorMessage;

    final indexById = _indexByIdFor(messages: messages);

    // Coalesced post-frame pin-to-edge while following. The scheduler
    // collapses repeated calls within a frame and the jump is skipped
    // when `position.pixels` is already at the edge.
    _follow.scheduleJumpToEdge();

    return FollowDetachScrollable(
      tracker: _follow,
      detachedOverlayBuilder: (ctx) => JumpToEdgePill(
        tapTargetKey: _kJumpToLatestKey,
        label: loc.sessionDetailJumpToLatest,
        onTap: () => _follow.animateToEdge(),
      ),
      child: chat_ui.Chat(
        key: _kListViewKey,
        currentUserId: _kUserAuthorId,
        resolveUser: _resolveUser,
        chatController: _chatController,
        theme: chat_core.ChatTheme.fromThemeData(Theme.of(context)),
        backgroundColor: Colors.transparent,
        builders: chat_core.Builders(
          // Full-row control: drop the package's bubble/alignment/
          // gesture wrapper and render our cards bare, exactly as the
          // previous ListView did.
          chatMessageBuilder:
              (
                context,
                message,
                index,
                animation,
                child, {
                bool? isRemoved,
                required bool isSentByMe,
                chat_core.MessageGroupStatus? groupStatus,
              }) => child,
          customMessageBuilder:
              (
                context,
                message,
                index, {
                required bool isSentByMe,
                chat_core.MessageGroupStatus? groupStatus,
              }) => _buildRow(
                entry: message,
                messages: messages,
                indexById: indexById,
                streamingText: streamingText,
                children: children,
                childStatuses: childStatuses,
                retryErrorMessage: retryErrorMessage,
              ),
          // The prompt input, queued bubbles and tasks bar live outside
          // this widget; reserve no composer space inside the list.
          composerBuilder: (context) => const SizedBox.shrink(),
          // Follow/detach owns the jump affordance via the overlay pill.
          scrollToBottomBuilder: (context, animation, onPressed) => const SizedBox.shrink(),
          // The loaded view renders its own empty state before this
          // widget is ever mounted.
          emptyChatListBuilder: (context) => const SizedBox.shrink(),
          chatAnimatedListBuilder: (context, itemBuilder) => chat_ui.ChatAnimatedListReversed(
            itemBuilder: itemBuilder,
            scrollController: _follow.scrollController,
            insertAnimationDuration: Duration.zero,
            removeAnimationDuration: Duration.zero,
            shouldScrollToEndWhenSendingMessage: false,
            topPadding: 8,
            bottomPadding: 8,
            handleSafeArea: false,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            // Always allow overscroll/bounce, even when the transcript is
            // shorter than the viewport, so the list never feels locked.
            physics: const AlwaysScrollableScrollPhysics(),
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required chat_core.CustomMessage entry,
    required List<MessageWithParts> messages,
    required Map<String, int> indexById,
    required Map<String, String> streamingText,
    required List<Session> children,
    required Map<String, SessionStatus> childStatuses,
    required String? retryErrorMessage,
  }) {
    if (entry.id == _kRetryErrorRowId) {
      if (retryErrorMessage == null) return const SizedBox.shrink();
      return RetryErrorMessageCard(message: retryErrorMessage);
    }
    final index = indexById[entry.id];
    if (index == null || index >= messages.length) return const SizedBox.shrink();
    final message = messages[index];
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

  Map<String, int> _indexByIdFor({required List<MessageWithParts> messages}) {
    final signature = _signatureOf(messages: messages);
    if (signature == _indexSignature) return _indexById;
    _indexSignature = signature;
    return _indexById = <String, int>{
      for (var i = 0; i < messages.length; i++) messages[i].info.id: i,
    };
  }

  int _signatureOf({required List<MessageWithParts> messages}) {
    // Hash every id so the cache invalidates on any structural change —
    // including a middle insert/delete/replace that preserves length and the
    // first/last ids. Cheap for chat-sized transcripts and bounded by maxLines
    // at the render layer.
    return Object.hashAll(messages.map((m) => m.info.id));
  }
}
