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
import "message_timestamp_reveal.dart";
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

class _SessionDetailMessageListState extends State<SessionDetailMessageList> with SingleTickerProviderStateMixin {
  static const _kListViewKey = Key("session-detail-message-list-view");
  static const _kJumpToLatestKey = Key("session-detail-jump-to-latest");

  /// Width of the per-message timestamp gutter revealed by the horizontal
  /// "peek" gesture, and the distance rows slide left at full reveal.
  static const double _kMaxReveal = 76;

  /// Horizontal travel before a drag is treated as a timestamp peek
  /// rather than a scroll. Kept below `kTouchSlop` so the peek engages
  /// promptly, but only when horizontal travel clearly dominates.
  static const double _kRevealEngageSlop = 8;

  /// Synthetic controller-entry id for the shimmering retry-error row
  /// pinned at the newest edge. Domain message ids come from the
  /// assistant backend and cannot collide with this.
  static const _kRetryErrorRowId = "session-detail-retry-error-row";

  static const _kUserAuthorId = "user";
  static const _kAgentAuthorId = "agent";

  late final ScrollFollowTracker _follow;
  late final chat_core.InMemoryChatController _chatController;

  /// Shared 0..1 progress for the horizontal timestamp-reveal "peek".
  /// Set directly while the user drags; springs back to 0 on release.
  /// Every visible row's [MessageTimestampReveal] listens to it, so one
  /// drag moves the whole transcript in lockstep.
  late final AnimationController _revealController;

  /// Pointer-tracking state for the reveal "peek" gesture (see
  /// [_onRevealPointerMove]). `_revealPointer` is the active pointer id;
  /// `_revealEngaged`/`_revealRejected` latch the horizontal-vs-vertical
  /// decision for the duration of one gesture.
  int? _revealPointer;
  Offset _revealStart = Offset.zero;
  bool _revealEngaged = false;
  bool _revealRejected = false;
  bool _revealStartedFollowing = false;

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
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
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
    _revealController.dispose();
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
      _chatController
          .setMessages(target, animated: false)
          .catchError(
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
      // Horizontal "peek" gesture: drag the transcript left to reveal
      // each message's timestamp on the right. Driven by a raw [Listener]
      // rather than a drag GestureDetector on purpose — a competing
      // horizontal drag recognizer would join the gesture arena and stop
      // the list's vertical scroll recognizer from being the sole member,
      // which would break small-drag detach. The Listener never joins the
      // arena, so vertical scrolling is untouched; we disambiguate
      // direction ourselves and only steer the reveal on horizontal-
      // dominant drags. `translucent` so the whole list area is tracked
      // while taps and selection still reach the cards below.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onRevealPointerDown,
        onPointerMove: _onRevealPointerMove,
        onPointerUp: _onRevealPointerUp,
        onPointerCancel: _onRevealPointerCancel,
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
      // Synthetic row: no timestamp, but it still slides with the rest.
      return _revealable(createdAtMs: null, child: RetryErrorMessageCard(message: retryErrorMessage));
    }
    final index = indexById[entry.id];
    if (index == null || index >= messages.length) return const SizedBox.shrink();
    final message = messages[index];
    final card = switch (message.info) {
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
    return _revealable(createdAtMs: message.info.time?.created, child: card);
  }

  /// Wraps a row so the shared horizontal drag reveals its timestamp.
  Widget _revealable({required int? createdAtMs, required Widget child}) {
    return MessageTimestampReveal(
      progress: _revealController,
      maxReveal: _kMaxReveal,
      createdAtMs: createdAtMs,
      child: child,
    );
  }

  void _onRevealPointerDown(PointerDownEvent event) {
    // The first pointer owns the peek for its whole lifetime; ignore
    // secondary touches so a stray second finger can't strand the
    // gesture state (and the detach suppression) on the wrong pointer.
    if (_revealPointer != null) return;
    _revealPointer = event.pointer;
    _revealStart = event.position;
    _revealEngaged = false;
    _revealRejected = false;
    // Remember whether we were following when the gesture began: only
    // then is a detach during this gesture "spurious" and worth undoing.
    _revealStartedFollowing = _follow.following;
  }

  void _onRevealPointerMove(PointerMoveEvent event) {
    if (event.pointer != _revealPointer || _revealRejected) return;

    if (!_revealEngaged) {
      // Disambiguate direction. A vertical or ambiguous drag is left to
      // the scrollable untouched (so its eager small-drag detach still
      // works); only a clear horizontal drag becomes a timestamp peek.
      final dx = event.position.dx - _revealStart.dx;
      final dy = event.position.dy - _revealStart.dy;
      if (dy.abs() >= _kRevealEngageSlop && dy.abs() > dx.abs()) {
        _revealRejected = true;
        return;
      }
      if (dx.abs() < _kRevealEngageSlop || dx.abs() <= dy.abs()) return;
      _revealEngaged = true;
      // The scrollable fires a spurious drag-start as it claims the
      // pointer. Only undo/suppress the resulting detach when we began
      // the gesture following — otherwise the user was deliberately
      // scrolled up reading history, and force-re-attaching here would
      // discard their snapshot and teleport them to the newest edge.
      if (_revealStartedFollowing) {
        _follow.suppressDetach();
      }
    }

    // Dragging left (negative dx) opens the gutter; dragging right closes
    // it. The controller value is the reveal fraction, so normalise the
    // per-move pixel delta by the gutter width and clamp to [0, 1].
    final next = (_revealController.value - event.delta.dx / _kMaxReveal).clamp(0.0, 1.0);
    _revealController.value = next;
  }

  void _onRevealPointerUp(PointerUpEvent event) {
    if (event.pointer != _revealPointer) return;
    _endReveal();
  }

  void _onRevealPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _revealPointer) return;
    _endReveal();
  }

  void _endReveal() {
    _revealPointer = null;
    _revealEngaged = false;
    _revealRejected = false;
    _follow.releaseDetachSuppression();
    if (_revealController.value == 0) return;
    // Spring the gutter shut, honouring the OS reduce-motion preference
    // like the rest of the app's decorative animations.
    if (context.isReducedMotion) {
      _revealController.value = 0;
    } else {
      _revealController.animateTo(0, curve: Curves.easeOut);
    }
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
