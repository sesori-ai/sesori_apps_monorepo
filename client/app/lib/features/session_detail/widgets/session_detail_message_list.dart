import "dart:async";

import "package:flutter/gestures.dart";
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

  /// Height of the floating composer overlaying the list's bottom edge. Used
  /// both as extra bottom scroll padding — so the newest message rests clear of
  /// the composer while older content scrolls up behind its fade — and to lift
  /// the "jump to latest" pill above the composer. Zero in the read-only
  /// variant, which renders no composer.
  final double bottomInset;

  /// Top inset (status bar + nav bar height) the list scrolls behind. Added as
  /// extra top scroll padding so the oldest message rests clear of the
  /// transparent bar at full scroll, while content in between scrolls up behind
  /// it and dissolves into the bar's fade.
  final double topInset;

  const SessionDetailMessageList({
    super.key,
    required this.projectId,
    required this.messages,
    required this.streamingText,
    required this.children,
    required this.childStatuses,
    this.retryErrorMessage,
    this.bottomInset = 0,
    this.topInset = 0,
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
  /// Wide enough for a dated label this year (e.g. "Jun 14, 9:41 AM");
  /// rarer/longer labels ellipsize in [MessageTimestampReveal].
  static const double _kMaxReveal = 108;

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

  /// Metadata key carrying each entry's domain role. Assistant and error
  /// messages share [_kAgentAuthorId], so without this discriminator a
  /// message flipping from assistant to error mid-stream (same id, same
  /// authorId) would be value-equal to its previous entry — the
  /// controller diff would emit no update and the on-screen row would
  /// stay the stale assistant card until the screen is remounted.
  static const _kRoleMetadataKey = "role";
  static const _kUserRole = "user";
  static const _kAssistantRole = "assistant";
  static const _kErrorRole = "error";

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

  /// True while a trackpad pan-zoom owns the reveal. The pointer-drag and
  /// pan-zoom paths share the engage/reject latches above, so exactly one
  /// may drive the peek at a time: whichever gesture starts first claims
  /// ownership (`_revealPointer` for finger/stylus, this flag for
  /// trackpad) and the other path no-ops until it releases. Guards against
  /// a stray pan on a touchscreen-plus-trackpad device resetting the
  /// latches — or springing the gutter shut — mid touch drag.
  bool _revealPanActive = false;

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

  /// Cache for the chat package theme derived from the app theme. Deriving it
  /// allocates a full style set, and this widget rebuilds on every streaming
  /// flush — recompute only when the underlying [ThemeData] changes.
  (ThemeData, chat_core.ChatTheme)? _chatThemeCache;

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
      // A same-id entry can still change role in place (assistant→error);
      // that must not be filtered out as a streaming-only emit, or the
      // controller never learns the row needs to swap to the error card.
      if (current[i].metadata?[_kRoleMetadataKey] != target[i].metadata?[_kRoleMetadataKey]) return false;
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
          // Role discriminates assistant from error under the shared
          // agent authorId, so a live assistant→error transition on the
          // same message id is no longer value-equal and forces the row
          // to re-render as the error card.
          metadata: <String, String>{
            _kRoleMetadataKey: switch (message.info) {
              MessageUser() => _kUserRole,
              MessageAssistant() => _kAssistantRole,
              MessageError() => _kErrorRole,
            },
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
        // Lift the pill clear of the floating composer overlaid below.
        bottomInset: widget.bottomInset,
      ),
      // Horizontal "peek" gesture: slide the transcript left to reveal
      // each message's timestamp on the right. Driven by a raw [Listener]
      // rather than a drag GestureDetector on purpose — a competing
      // horizontal drag recognizer would join the gesture arena and stop
      // the list's vertical scroll recognizer from being the sole member,
      // which would break small-drag detach. The Listener never joins the
      // arena, so vertical scrolling is untouched; we disambiguate
      // direction ourselves and only steer the reveal on horizontal-
      // dominant gestures. `translucent` so the whole list area is tracked
      // while taps and selection still reach the cards below.
      //
      // Input source is chosen by the pointer's *device kind*, not the
      // OS — so a desktop touchscreen still peeks by finger and an
      // attached mouse on mobile still selects text:
      //
      // - Touch / stylus: a finger drag — pointer down/move/up.
      // - Trackpad: a horizontal two-finger swipe — pointer pan-zoom.
      // - Mouse: a button press-and-drag is left untouched (the pointer
      //   path ignores the mouse kind) so it keeps selecting message
      //   text; hijacking it for the peek would make selection impossible.
      //
      // Both handler sets are always bound; each only fires for its own
      // device kind, so they never compete.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onRevealPointerDown,
        onPointerMove: _onRevealPointerMove,
        onPointerUp: _onRevealPointerUp,
        onPointerCancel: _onRevealPointerCancel,
        onPointerPanZoomStart: _onRevealPanZoomStart,
        onPointerPanZoomUpdate: _onRevealPanZoomUpdate,
        onPointerPanZoomEnd: _onRevealPanZoomEnd,
        child: chat_ui.Chat(
          key: _kListViewKey,
          currentUserId: _kUserAuthorId,
          resolveUser: _resolveUser,
          chatController: _chatController,
          theme: _chatThemeFor(theme: Theme.of(context)),
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
              topPadding: 8 + widget.topInset,
              bottomPadding: 8 + widget.bottomInset,
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
    // A trackpad pan already owns the reveal — don't let a concurrent
    // touch claim the shared latches out from under it.
    if (_revealPanActive) return;
    // A mouse press-and-drag is the text-selection gesture, so never
    // hijack it for the peek — regardless of OS. (A trackpad click also
    // reports as a mouse pointer; its two-finger swipe arrives separately
    // via the pan-zoom path.) Finger and stylus drags drive the peek.
    if (event.kind == PointerDeviceKind.mouse) return;
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
      // Disambiguate direction once the pointer clears the slop. Vertical,
      // ambiguous, and rightward drags are left untouched: the scrollable
      // keeps its eager small-drag detach, and a rightward drag stays free
      // for the system back-swipe and any future gestures. The gutter is
      // on the right, so only a clear leftward drag opens it.
      final dx = event.position.dx - _revealStart.dx;
      final dy = event.position.dy - _revealStart.dy;
      if (dx.abs() < _kRevealEngageSlop && dy.abs() < _kRevealEngageSlop) return;
      if (dy.abs() >= dx.abs() || dx > 0) {
        _revealRejected = true;
        return;
      }
      _revealEngaged = true;
      // Take over any in-flight spring-back so the manual drag doesn't
      // fight the closing animation. (Done here, not on pointer-down, so a
      // vertical scroll that follows a release still springs shut.)
      _revealController.stop();
      // The scrollable fires a spurious drag-start as it claims the
      // pointer. Only undo/suppress the resulting detach when we began
      // the gesture following — otherwise the user was deliberately
      // scrolled up reading history, and force-re-attaching here would
      // discard their snapshot and teleport them to the newest edge.
      if (_revealStartedFollowing) {
        _follow.suppressDetach();
      }
    }

    // Dragging left (negative dx) opens the gutter further; dragging back
    // right closes it. Normalise the per-move pixel delta by the gutter
    // width and clamp to [0, 1].
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

  // ---------------------------------------------------------------------------
  // Trackpad reveal: horizontal two-finger pan-zoom. Mirrors the touch
  // pointer-drag path above (slop, horizontal-dominant gating, detach
  // suppression, spring-back) but reads the cumulative `pan` and
  // per-event `panDelta` from the pan-zoom stream instead of raw pointer
  // positions. Reuses the same engage/reject/started-following latches as
  // the pointer path, so a [_revealPanActive] / `_revealPointer`
  // ownership handshake keeps the two from clobbering each other when a
  // device has both a touchscreen and a trackpad.
  // ---------------------------------------------------------------------------

  void _onRevealPanZoomStart(PointerPanZoomStartEvent event) {
    // A finger/stylus drag already owns the reveal — don't reset its
    // latches from under it (see [_revealPanActive]).
    if (_revealPointer != null) return;
    _revealPanActive = true;
    _revealEngaged = false;
    _revealRejected = false;
    _revealStartedFollowing = _follow.following;
  }

  void _onRevealPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_revealPanActive || _revealRejected) return;

    if (!_revealEngaged) {
      // Same direction disambiguation as the touch path: only a clear
      // leftward pan opens the right-hand gutter; vertical, ambiguous and
      // rightward pans are left for the list's own scroll handling.
      final dx = event.pan.dx;
      final dy = event.pan.dy;
      if (dx.abs() < _kRevealEngageSlop && dy.abs() < _kRevealEngageSlop) return;
      if (dy.abs() >= dx.abs() || dx > 0) {
        _revealRejected = true;
        return;
      }
      _revealEngaged = true;
      _revealController.stop();
      // The list's scroll plumbing detaches on pan-zoom start; undo that
      // for a horizontal peek, but only when we began following (see the
      // touch path for the rationale).
      if (_revealStartedFollowing) {
        _follow.suppressDetach();
      }
    }

    final next = (_revealController.value - event.panDelta.dx / _kMaxReveal).clamp(0.0, 1.0);
    _revealController.value = next;
  }

  void _onRevealPanZoomEnd(PointerPanZoomEndEvent event) {
    // Ignore a pan that never claimed the reveal (a finger drag owned it).
    if (!_revealPanActive) return;
    _endReveal();
  }

  void _endReveal() {
    _revealPointer = null;
    _revealPanActive = false;
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

  chat_core.ChatTheme _chatThemeFor({required ThemeData theme}) {
    final cached = _chatThemeCache;
    if (cached != null && identical(cached.$1, theme)) return cached.$2;
    final derived = chat_core.ChatTheme.fromThemeData(theme);
    _chatThemeCache = (theme, derived);
    return derived;
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
