import "dart:async";

import "package:flutter/gestures.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "assistant_message_card.dart";
import "error_message_card.dart";
import "follow_detach_scrollable.dart";
import "jump_to_edge_pill.dart";
import "message_timestamp_reveal.dart";
import "queued_message_bubble.dart";
import "retry_error_message_card.dart";
import "scroll_follow_tracker.dart";
import "user_message_card.dart";

/// Chat-style message list for the session detail screen.
///
/// The reversed list keeps newest content at scroll offset zero. While following,
/// [ScrollFollowTracker] pins it there. While detached, rendered inputs are
/// snapshotted so live changes cannot move the viewport.
class const SessionDetailMessageList({
  super.key,
  required final String? projectId,
  required final List<MessageWithParts> messages,
  required final QueuedSessionSubmission? sendingSubmission,
  required final List<QueuedSessionSubmission> queuedMessages,

  /// Accepted sends the bridge has not listed yet — rendered as read-only
  /// queued bubbles so the prompt never blanks between its acceptance
  /// response and the bridge's queue event.
  final List<QueuedSessionSubmission> awaitingBridgeSubmissions = const [],
  required final List<QueuedSessionPrompt> bridgeQueuedPrompts,
  final void Function(String promptId)? onCancelBridgeQueuedPrompt,
  required final Map<String, String> streamingText,
  required final List<Session> children,
  required final Map<String, SessionStatus> childStatuses,

  /// Requests the page of messages before the ones shown, or null when the
  /// start of the transcript is already loaded.
  required final Future<void> Function()? onLoadOlderMessages,
  required final ValueChanged<int>? onCancelQueuedMessage,
  required final bool isLoadingOlderMessages,
  final String? retryErrorMessage,

  /// Height of the floating composer overlaying the list's bottom edge. Used
  /// both as extra bottom scroll padding — so the newest message rests clear of
  /// the composer while older content scrolls up behind its fade — and to lift
  /// the "jump to latest" pill above the composer. Zero in the read-only
  /// variant, which renders no composer.
  final double bottomInset = 0,

  /// Top inset (status bar + nav bar height) the list scrolls behind. Added as
  /// extra top scroll padding so the oldest message rests clear of the
  /// transparent bar at full scroll, while content in between scrolls up behind
  /// it and dissolves into the bar's fade.
  final double topInset = 0,
}) extends StatefulWidget {
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

typedef _TransientSubmission = ({QueuedSessionSubmission submission, bool isSending, bool awaitingBridge});

class _SessionDetailMessageListState() extends State<SessionDetailMessageList> with SingleTickerProviderStateMixin {
  static const _kListViewKey = Key("session-detail-message-list-view");
  static const _kJumpToLatestKey = Key("session-detail-jump-to-latest");

  /// Width of the per-message timestamp gutter revealed by the horizontal
  /// "peek" gesture, and the distance rows slide left at full reveal.
  /// Wide enough for a dated label this year (e.g. "Jun 14, 9:41 AM");
  /// rarer/longer labels ellipsize in [MessageTimestampReveal].
  static const double _kMaxReveal = 108;

  /// Disallowed-direction or vertical-dominant travel that releases the
  /// pending timestamp gesture. Kept below `kTouchSlop` so small vertical and
  /// rightward-first drags remain available to the transcript.
  static const double _kRevealPendingRejectionSlop = 8;

  static const Set<PointerDeviceKind> _kRevealPointerDevices = {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };

  /// Synthetic id for the shimmering retry-error row pinned at the newest
  /// edge. Domain message ids come from the assistant backend and cannot
  /// collide with this.
  static const _kRetryErrorRowId = "session-detail-retry-error-row";
  static const _kPromptRowPrefix = "session-detail-prompt-";

  /// Distance from the oldest edge at which the next older page starts
  /// loading — about one phone viewport, so scrolling back through history
  /// has its page ready instead of stopping dead at the edge.
  static const double _kOlderPagePrefetchExtent = 600;

  late final ScrollFollowTracker _follow;

  /// Shared 0..1 progress for the horizontal timestamp-reveal "peek".
  /// Set directly while the user drags; springs back to 0 on release.
  /// Every visible row's [MessageTimestampReveal] listens to it, so one
  /// drag moves the whole transcript in lockstep.
  late final AnimationController _revealController;

  /// Captured on horizontal-drag down, before the outer trackpad listener can
  /// detach. Once the horizontal recognizer wins, suppression restores this
  /// state and keeps the timestamp peek from disturbing follow mode.
  bool _revealStartedFollowing = false;

  bool _revealDragActive = false;
  bool _revealDetachSuppressed = false;

  /// Snapshot taken at the moment of detach. `null` means "not frozen
  /// — use live `widget.*` props".
  _DetachedSnapshot? _snapshot;
  bool _loadOlderCallbackInFlight = false;

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
  }

  @override
  void dispose() {
    _follow.removeListener(_onFollowChanged);
    _follow.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SessionDetailMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final olderPageRequestCompleted = oldWidget.isLoadingOlderMessages && !widget.isLoadingOlderMessages;
    // While detached the snapshot keeps the list structure from shifting
    // under the reader; `_onFollowChanged` restores live inputs on reattach.
    //
    // Older pages are the exception: the reader is detached precisely
    // because they scrolled back for them, and they are prepended *above*
    // the viewport, so rendering them cannot shift what is being read.
    // Freezing them would leave the page loaded but invisible until the
    // user returned to the newest message.
    if (_follow.following) return;
    final frozen = _snapshot;
    final transientSubmissionsChanged = !_transientSubmissionsMatch(oldWidget: oldWidget);
    if (frozen != null && transientSubmissionsChanged) {
      if (_hasNewTransientSubmission(oldWidget: oldWidget)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _follow.following) return;
          unawaited(_follow.animateToEdge());
        });
      }
    }
    if (!olderPageRequestCompleted) return;
    if (frozen == null) return;
    final prepended = _prependedOlderMessages(frozen: frozen);
    if (prepended.isEmpty) return;

    // Take *only* the newly prepended prefix. Taking the whole live list would
    // also pull in messages appended at the newest edge while detached, which
    // is exactly the reflow the freeze exists to prevent. Everything else the
    // snapshot holds — streaming text, children, statuses, retry state — stays
    // frozen.
    final merged = [...prepended, ...frozen.messages];
    setState(() {
      _snapshot = (
        messages: List<MessageWithParts>.unmodifiable(merged),
        streamingText: frozen.streamingText,
        children: frozen.children,
        childStatuses: frozen.childStatuses,
        retryErrorMessage: frozen.retryErrorMessage,
      );
    });
    // The prepended rows render against the frozen `streamingText` and
    // `childStatuses`, which have no entries for them. That is correct rather
    // than a gap: those maps describe live activity at the newest edge, and
    // history old enough to be paged back to has finished streaming and has
    // no running child work.
    //
  }

  /// History prepended above the frozen transcript, in order. Empty when this
  /// update only touched the newest edge.
  List<MessageWithParts> _prependedOlderMessages({required _DetachedSnapshot frozen}) {
    final frozenOldestId = frozen.messages.firstOrNull?.info.id;
    if (frozenOldestId == null) return const [];
    final boundary = widget.messages.indexWhere((message) => message.info.id == frozenOldestId);
    if (boundary <= 0) return const [];
    final frozenIds = frozen.messages.map((message) => message.info.id).toSet();
    final prepended = widget.messages.sublist(0, boundary);
    if (prepended.any((message) => frozenIds.contains(message.info.id))) return const [];
    return prepended;
  }

  void _onFollowChanged() {
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
          retryErrorMessage: widget.retryErrorMessage,
        );
      }
    });
  }

  bool _transientSubmissionsMatch({required SessionDetailMessageList oldWidget}) {
    if (!identical(oldWidget.sendingSubmission, widget.sendingSubmission)) return false;
    if (oldWidget.queuedMessages.length != widget.queuedMessages.length) return false;
    for (var i = 0; i < widget.queuedMessages.length; i++) {
      if (!identical(oldWidget.queuedMessages[i], widget.queuedMessages[i])) return false;
    }
    if (oldWidget.bridgeQueuedPrompts.length != widget.bridgeQueuedPrompts.length) return false;
    for (var i = 0; i < widget.bridgeQueuedPrompts.length; i++) {
      if (oldWidget.bridgeQueuedPrompts[i] != widget.bridgeQueuedPrompts[i]) return false;
    }
    if (oldWidget.awaitingBridgeSubmissions.length != widget.awaitingBridgeSubmissions.length) return false;
    for (var i = 0; i < widget.awaitingBridgeSubmissions.length; i++) {
      if (!identical(oldWidget.awaitingBridgeSubmissions[i], widget.awaitingBridgeSubmissions[i])) return false;
    }
    return true;
  }

  bool _hasNewTransientSubmission({required SessionDetailMessageList oldWidget}) {
    final previous = <QueuedSessionSubmission>{
      ?oldWidget.sendingSubmission,
      ...oldWidget.queuedMessages,
      // A fast acceptance can move a send straight to the parked surface
      // between two builds; it is still the reader's new submission.
      ...oldWidget.awaitingBridgeSubmissions,
    };
    return [
      ?widget.sendingSubmission,
      ...widget.queuedMessages,
      ...widget.awaitingBridgeSubmissions,
    ].any((submission) => !previous.contains(submission));
  }

  List<String> _rowIdsFor({
    required List<MessageWithParts> messages,
    required QueuedSessionSubmission? sendingSubmission,
    required List<QueuedSessionSubmission> queuedMessages,
    required List<QueuedSessionPrompt> bridgeQueuedPrompts,
    required List<QueuedSessionSubmission> awaitingBridgeSubmissions,
    required bool hasRetryError,
  }) {
    final deliveredPromptIds = <String>{
      for (final message in messages)
        if (message.hasRenderableUserContent)
          if (message.info case MessageUser(promptId: final promptId?)) promptId,
    };
    final entries = <String>[
      for (final message in messages)
        if (message.hasRenderableUserContent) _entryIdForMessage(info: message.info),
      if (hasRetryError) _kRetryErrorRowId,
      for (final prompt in bridgeQueuedPrompts)
        if (!deliveredPromptIds.contains(prompt.id)) "$_kPromptRowPrefix${prompt.id}",
      for (final submission in awaitingBridgeSubmissions)
        if (!deliveredPromptIds.contains(submission.promptId)) "$_kPromptRowPrefix${submission.promptId}",
      if (sendingSubmission != null && !deliveredPromptIds.contains(sendingSubmission.promptId))
        "$_kPromptRowPrefix${sendingSubmission.promptId}",
      for (final submission in queuedMessages)
        if (!deliveredPromptIds.contains(submission.promptId)) "$_kPromptRowPrefix${submission.promptId}",
    ];
    final seenIds = <String>{};
    return [
      for (final entry in entries)
        if (seenIds.add(entry)) entry,
    ];
  }

  String _entryIdForMessage({required Message info}) => switch (info) {
    MessageUser(promptId: final promptId?) => "$_kPromptRowPrefix$promptId",
    MessageUser() || MessageAssistant() || MessageError() => info.id,
  };

  static String? _bridgePromptDisplayText(QueuedSessionPrompt prompt) {
    final command = prompt.command;
    final text = prompt.text;
    if (command == null) return text;
    return text == null ? "/$command" : "/$command $text";
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final snap = _snapshot;
    final messages = snap?.messages ?? widget.messages;
    final sendingSubmission = widget.sendingSubmission;
    final queuedMessages = widget.queuedMessages;
    final streamingText = snap?.streamingText ?? widget.streamingText;
    final children = snap?.children ?? widget.children;
    final childStatuses = snap?.childStatuses ?? widget.childStatuses;
    final retryErrorMessage = snap?.retryErrorMessage ?? widget.retryErrorMessage;

    final indexById = _indexByIdFor(messages: messages);
    final transientSubmissions = <String, _TransientSubmission>{
      for (final submission in widget.awaitingBridgeSubmissions)
        "$_kPromptRowPrefix${submission.promptId}": (submission: submission, isSending: false, awaitingBridge: true),
      if (sendingSubmission != null)
        "$_kPromptRowPrefix${sendingSubmission.promptId}": (
          submission: sendingSubmission,
          isSending: true,
          awaitingBridge: false,
        ),
      for (final submission in queuedMessages)
        "$_kPromptRowPrefix${submission.promptId}": (submission: submission, isSending: false, awaitingBridge: false),
    };

    final rowIds = _rowIdsFor(
      messages: messages,
      sendingSubmission: sendingSubmission,
      queuedMessages: queuedMessages,
      bridgeQueuedPrompts: widget.bridgeQueuedPrompts,
      awaitingBridgeSubmissions: widget.awaitingBridgeSubmissions,
      hasRetryError: retryErrorMessage != null,
    );
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
      // Horizontal "peek" gesture: slide the transcript left to reveal each
      // message's timestamp on the right. This participates in the gesture
      // arena so a nested horizontal scrollable, such as a fenced code block,
      // wins exclusively. Early cross-axis rejection preserves the list's
      // eager small-vertical-drag detach behavior.
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
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: PregoHorizontalDragGestureDetector(
          behavior: HitTestBehavior.translucent,
          supportedDevices: _kRevealPointerDevices,
          onHorizontalDragDown: _onRevealDragDown,
          onHorizontalDragStart: _onRevealDragStart,
          onHorizontalDragUpdate: _onRevealDragUpdate,
          onHorizontalDragEnd: _onRevealDragEnd,
          onHorizontalDragCancel: _onRevealDragCancel,
          pendingRejectionSlop: _kRevealPendingRejectionSlop,
          direction: PregoHorizontalDragDirection.left,
          dragStartBehavior: DragStartBehavior.down,
          child: ListView.builder(
            key: _kListViewKey,
            reverse: true,
            controller: _follow.scrollController,
            padding: EdgeInsetsDirectional.only(top: 8 + widget.topInset, bottom: 8 + widget.bottomInset),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: rowIds.length,
            findChildIndexCallback: (key) {
              if (key case ValueKey<String>(value: final rowId)) {
                final domainIndex = rowIds.indexOf(rowId);
                return domainIndex < 0 ? null : rowIds.length - domainIndex - 1;
              }
              return null;
            },
            itemBuilder: (context, index) {
              final entryId = rowIds[rowIds.length - index - 1];
              return KeyedSubtree(
                key: ValueKey(entryId),
                child: _buildRow(
                  entryId: entryId,
                  messages: messages,
                  indexById: indexById,
                  transientSubmissions: transientSubmissions,
                  streamingText: streamingText,
                  children: children,
                  childStatuses: childStatuses,
                  retryErrorMessage: retryErrorMessage,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required String entryId,
    required List<MessageWithParts> messages,
    required Map<String, int> indexById,
    required Map<String, _TransientSubmission> transientSubmissions,
    required Map<String, String> streamingText,
    required List<Session> children,
    required Map<String, SessionStatus> childStatuses,
    required String? retryErrorMessage,
  }) {
    if (entryId == _kRetryErrorRowId) {
      if (retryErrorMessage == null) return const SizedBox.shrink();
      // Synthetic row: no timestamp, but it still slides with the rest.
      return _revealable(createdAtMs: null, child: RetryErrorMessageCard(message: retryErrorMessage));
    }
    if (entryId.startsWith(_kPromptRowPrefix)) {
      // One row serves the prompt's whole lifecycle. Resolve the most settled
      // state first: the delivered message, else the bridge-queued entry, else
      // the locally staged submission. A mid-handoff frame (entry updated
      // before the next widget rebuild, or vice versa) then renders the
      // previous state instead of collapsing to an empty box.
      final index = indexById[entryId];
      if (index != null && index < messages.length && messages[index].hasRenderableUserContent) {
        final message = messages[index];
        return _revealable(
          createdAtMs: message.info.time?.created,
          child: _animatedPromptRow(child: UserMessageCard(message: message)),
        );
      }
      final promptId = entryId.substring(_kPromptRowPrefix.length);
      final prompt = widget.bridgeQueuedPrompts.where((candidate) => candidate.id == promptId).firstOrNull;
      if (prompt != null) {
        final onCancel = widget.onCancelBridgeQueuedPrompt;
        return _revealable(
          createdAtMs: prompt.createdAt,
          child: _animatedPromptRow(
            child: QueuedMessageBubble(
              key: ValueKey(entryId),
              displayText: _bridgePromptDisplayText(prompt),
              isCommand: prompt.command != null,
              attachmentCount: prompt.attachmentCount,
              presentation: onCancel == null
                  ? const QueuedMessageBubblePresentation.pendingReadOnly()
                  : QueuedMessageBubblePresentation.pending(onCancel: () => onCancel(prompt.id)),
            ),
          ),
        );
      }
    }
    final transientSubmission = transientSubmissions[entryId];
    if (transientSubmission != null) {
      final submission = transientSubmission.submission;
      final onCancelQueuedMessage = widget.onCancelQueuedMessage;
      return _revealable(
        createdAtMs: null,
        child: _animatedPromptRow(
          child: QueuedMessageBubble(
            key: ValueKey(entryId),
            displayText: submission.displayText,
            isCommand: submission.isCommand,
            attachmentCount: submission.attachments.length,
            presentation: transientSubmission.isSending
                ? const QueuedMessageBubblePresentation.sending()
                : transientSubmission.awaitingBridge || onCancelQueuedMessage == null
                ? const QueuedMessageBubblePresentation.pendingReadOnly()
                : QueuedMessageBubblePresentation.pending(
                    onCancel: () => _cancelQueuedSubmission(submission: submission),
                  ),
          ),
        ),
      );
    }
    final index = indexById[entryId];
    if (index == null || index >= messages.length) return const SizedBox.shrink();
    final message = messages[index];
    if (!message.hasRenderableUserContent) {
      return const SizedBox.shrink();
    }
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

  void _cancelQueuedSubmission({required QueuedSessionSubmission submission}) {
    final onCancelQueuedMessage = widget.onCancelQueuedMessage;
    if (onCancelQueuedMessage == null) return;
    final index = widget.queuedMessages.indexWhere((candidate) => identical(candidate, submission));
    if (index < 0) return;
    onCancelQueuedMessage(index);
  }

  /// Eases a prompt row's height as it moves between its sending, queued,
  /// and sent renderings, whose status rows differ in height — without this
  /// each hop snaps and reads as a flash in the bottom-pinned list.
  Widget _animatedPromptRow({required Widget child}) {
    // No wrapper at all under reduced motion: a zero-duration AnimatedSize
    // re-dirties itself inside its own layout pass.
    if (context.isReducedMotion) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      alignment: AlignmentDirectional.topEnd,
      child: child,
    );
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

  void _onRevealDragDown(DragDownDetails details) {
    _revealStartedFollowing = _follow.following;
  }

  void _onRevealDragStart(DragStartDetails details) {
    _revealDragActive = true;
    _revealController.stop();
    if (_revealStartedFollowing) {
      _follow.suppressDetach();
      _revealDetachSuppressed = true;
    }
  }

  void _onRevealDragUpdate(DragUpdateDetails details) {
    final next = (_revealController.value - (details.primaryDelta ?? 0) / _kMaxReveal).clamp(0.0, 1.0);
    _revealController.value = next;
  }

  void _onRevealDragEnd(DragEndDetails details) => _endReveal();

  void _onRevealDragCancel() {
    if (!_revealDragActive) {
      scheduleMicrotask(() {
        if (mounted && !_revealDragActive) _revealStartedFollowing = false;
      });
      return;
    }
    _endReveal();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final loadOlderMessages = widget.onLoadOlderMessages;
    // Prefetch on scroll updates nearing the oldest edge, so paging back
    // through history feels continuous. The scroll-end check is the fallback
    // for a transcript too short to scroll: clamping physics emits no update
    // at zero extent, only the end notification.
    final nearingOldestEdge = switch (notification) {
      ScrollUpdateNotification(:final metrics) => metrics.extentAfter < _kOlderPagePrefetchExtent,
      ScrollEndNotification(:final metrics) => metrics.extentAfter == 0,
      _ => false,
    };
    if (nearingOldestEdge &&
        notification.metrics.axis == Axis.vertical &&
        !_loadOlderCallbackInFlight &&
        !widget.isLoadingOlderMessages &&
        loadOlderMessages != null) {
      _loadOlderCallbackInFlight = true;
      unawaited(_loadOlderMessages(loadOlderMessages));
    }
    return _onNestedScrollNotification(notification);
  }

  Future<void> _loadOlderMessages(Future<void> Function() loadOlderMessages) async {
    try {
      await loadOlderMessages();
    } catch (error, stackTrace) {
      loge("Failed to load older session messages", error, stackTrace);
    } finally {
      if (mounted) _loadOlderCallbackInFlight = false;
    }
  }

  bool _onNestedScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollStartNotification ||
        notification.metrics.axis != Axis.horizontal ||
        !_revealStartedFollowing ||
        _revealDragActive) {
      return false;
    }

    // A nested horizontal scrollable won after trackpad pan-start detached the
    // transcript. Restore the follow state captured by drag-down; vertical
    // scroll notifications deliberately leave that detach intact.
    _follow.suppressDetach();
    _follow.releaseDetachSuppression();
    _revealStartedFollowing = false;
    return false;
  }

  void _endReveal() {
    _revealDragActive = false;
    _revealStartedFollowing = false;
    if (_revealDetachSuppressed) {
      _revealDetachSuppressed = false;
      _follow.releaseDetachSuppression();
    }
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
      for (var i = 0; i < messages.length; i++)
        if (messages[i].info case MessageUser(promptId: final promptId?)) "$_kPromptRowPrefix$promptId": i,
    };
  }

  int _signatureOf({required List<MessageWithParts> messages}) {
    // Hash every id so the cache invalidates on any structural change —
    // including a middle insert/delete/replace that preserves length and the
    // first/last ids. A user message's promptId is part of the map's keys
    // (the stable prompt row resolves through it), so it participates too:
    // a live upsert that stamps promptId onto an existing id must rebuild.
    // Cheap for chat-sized transcripts and bounded by maxLines at the render
    // layer.
    return Object.hashAll(
      messages.map(
        (m) => switch (m.info) {
          MessageUser(:final id, :final promptId) => Object.hash(id, promptId),
          MessageAssistant(:final id) || MessageError(:final id) => id,
        },
      ),
    );
  }
}
