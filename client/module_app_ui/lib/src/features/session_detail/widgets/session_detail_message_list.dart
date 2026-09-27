import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

import "assistant_message_card.dart";
import "error_message_card.dart";
import "follow_detach_scrollable.dart";
import "jump_to_edge_pill.dart";
import "message_timestamp_reveal.dart";
import "queued_message_bubble.dart";
import "retry_error_message_card.dart";
import "scroll_follow_tracker.dart";
import "system_message_card.dart";
import "transcript_glide_activity.dart";
import "transcript_jump_notifier.dart";
import "transcript_laid_out_list_view.dart";
import "transcript_live_row.dart";
import "transcript_motion.dart";
import "transcript_pinch_detector.dart";
import "transcript_prompt_slot.dart";
import "transcript_row_reporter.dart";
import "transcript_sticky_layout.dart";
import "transcript_sticky_prompt_overlay.dart";
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

  /// The head of the local send queue; [queuedMessages] wait behind it.
  required final LocalSendPhase localSend,
  required final List<QueuedSessionSubmission> queuedMessages,

  /// The harness name a slow send names, or null until it is known.
  required final String? harnessName,

  /// The first message of a session this surface just created, shown as a
  /// sending bubble until the transcript holds its replacement.
  required final SessionLaunchHandoff? launchHandoff,

  /// Null on a read-only surface, which shows the failure without actions.
  required final VoidCallback? onRetryFailedSend,
  required final VoidCallback? onRemoveFailedSend,

  /// Accepted sends the bridge has not listed yet — rendered as read-only
  /// queued bubbles so the prompt never blanks between its acceptance
  /// response and the bridge's queue event.
  final List<QueuedSessionSubmission> awaitingBridgeSubmissions = const [],
  required final List<QueuedSessionPrompt> bridgeQueuedPrompts,
  required final Map<String, List<ComposerAttachment>> bridgePromptAttachments,
  final void Function(String promptId)? onCancelBridgeQueuedPrompt,
  required final Map<String, String> streamingText,
  required final List<Session> children,
  required final Map<String, SessionStatus> childStatuses,

  /// Whether the session works, by `hasActiveWork`. With no live step and
  /// no text streaming, a "Working…" row closes the transcript.
  required final bool isBusy,

  /// Whether the bridge reports the main agent mid-turn. Only while it is
  /// not does the sub-agent row take over from "Working…".
  required final bool mainAgentRunning,

  /// Requests the page of messages before the ones shown, or null when the
  /// start of the transcript is already loaded.
  required final Future<void> Function()? onLoadOlderMessages,
  required final ValueChanged<int>? onCancelQueuedMessage,
  required final bool isLoadingOlderMessages,

  /// Whether a refresh is replacing the transcript. One ending asks again for
  /// an older page the refresh dropped, when the transcript is still short.
  required final bool isRefreshing,

  /// Where the list writes, as it lays out, the prompt the reader is on: the
  /// one the pinned prompt names, else the next prompt below. Null with no
  /// prompt loaded. Only read, never listened to, since it changes mid-layout.
  required final ValueNotifier<String?> currentPromptId,

  /// Asks the list to move to a message, such as a prompt tapped on the
  /// Prompts screen.
  required final TranscriptJumpNotifier jumpNotifier,

  /// A pinch in on the transcript, with its focal point in global
  /// coordinates: opens the Prompts screen, grown from there.
  required final void Function({required Offset focalPoint}) onPinchIn,
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

  /// Side padding that centres the rows in a wide pane. It is scroll padding,
  /// so the wheel and the scrollbar still belong to the whole pane.
  final double horizontalInset = 0,
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
  bool isBusy,
  bool mainAgentRunning,
});

enum _TransientStage() {
  awaitingBridge,
  sending,
  failed,
  pending,
}

typedef _TransientSubmission = ({QueuedSessionSubmission submission, _TransientStage stage});

/// A row held [top] px below the top edge. Compared by identity, so a newer
/// anchor stops the steps of the one it replaced. [landed], when set, completes
/// once the hold ends, however it ends.
final class _TurnAnchor({
  required final String rowId,
  required final double top,
  required final Completer<void>? landed,
});

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
  /// collide with this. Like the working row it stays in the list, empty
  /// without a retry, so the card eases in and out.
  static const _kRetryErrorRowId = "session-detail-retry-error-row";

  /// Synthetic id for the live row that closes the transcript while the
  /// session works. The row stays in the list, empty while idle, so it eases
  /// in and out as work starts and ends.
  static const _kWorkingRowId = "session-detail-working-row";

  /// Synthetic id for the launch's first message, the oldest transient row. A
  /// session has at most one, so it is never matched against echoes.
  static const _kLaunchRowId = "session-detail-launch-row";
  static const _kPromptRowPrefix = "session-detail-prompt-";

  /// Distance from the oldest edge at which the next older page starts
  /// loading — about one phone viewport, so scrolling back through history
  /// has its page ready instead of stopping dead at the edge.
  static const double _kOlderPagePrefetchExtent = 600;

  /// How far below the top edge a pinned prompt's bubble rests.
  static const double _kPinGap = 6;

  /// Where a prompt's row rests once its pin glides back to it: with its
  /// bubble on the pin line, so the pin hands over to it unseen.
  static const double _kPinnedRowTop = _kPinGap - PregoSpacing.xs;

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

  /// Set when the oldest edge needed a check while a page was on its way, so
  /// the check runs once that load settles.
  bool _checkOldestEdgeAfterLoad = false;

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

  /// The rows of the last build, so a row that joins at the newest edge while
  /// following eases in. Null until the first build and after reattaching, so
  /// the rows already there, or caught up at once, do not animate.
  Set<String>? _knownRowIds;

  /// The row that replaced the launch bubble. It keeps the bubble's key, so
  /// the swap eases in place like a queued prompt turning into its message.
  String? _launchSlotRowId;

  /// The last build's rows by their place in order.
  Map<String, int> _rowIndexById = const {};
  TranscriptTurns _turns = const TranscriptTurns(turns: [], turnIndexByMessageId: {});

  /// The attached opener bubbles of prompt turns, by opener id.
  final _promptSlots = TranscriptPromptSlots();
  final GlobalKey _stickyKey = GlobalKey();

  /// The prompts the pinned prompts hold copies of: those that could pin
  /// next, which are the built ones and the one just above them.
  final ValueNotifier<List<String>> _stickyOpenerIds = ValueNotifier(const []);

  /// The built rows by id. Only built rows are here, so every scan stays
  /// bounded by the viewport and its cache extent.
  final Map<String, BuildContext> _rowContexts = {};

  /// The one row being held in place, until it settles or goes.
  _TurnAnchor? _anchor;

  /// Captured when a pinch's first pointer lands, before a trackpad pan-zoom
  /// start detaches the list, so a pinch leaves following alone.
  bool _pinchStartedFollowing = false;
  bool _pinchDetachSuppressed = false;

  @override
  void initState() {
    super.initState();
    _follow = ScrollFollowTracker(edge: ScrollFollowEdge.min);
    _follow.addListener(_onFollowChanged);
    widget.jumpNotifier.addListener(_onJumpRequested);
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _follow.removeListener(_onFollowChanged);
    _follow.dispose();
    widget.jumpNotifier.removeListener(_onJumpRequested);
    _revealController.dispose();
    _stickyOpenerIds.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SessionDetailMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A page that leaves the transcript shorter than the viewport moves no
    // scroll extent, so no metrics notification follows it. Check the oldest
    // edge once the page is laid out, to keep paging until the viewport fills.
    // A refresh drops or discards an older page asked for meanwhile, and can
    // land on the same oldest message, so its end checks too. A failed page
    // keeps the oldest message, so a failing bridge is not asked again until
    // the list scrolls, its layout changes or a refresh ends.
    final refreshEnded = oldWidget.isRefreshing && !widget.isRefreshing;
    if (refreshEnded || widget.messages.firstOrNull?.info.id != oldWidget.messages.firstOrNull?.info.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // A discarded page can still be on its way; check once it settles.
        if (_loadOlderCallbackInFlight) {
          _checkOldestEdgeAfterLoad = true;
        } else {
          _checkOldestEdge();
        }
      });
    }
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
        isBusy: frozen.isBusy,
        mainAgentRunning: frozen.mainAgentRunning,
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
        _knownRowIds = null;
      } else {
        _snapshot ??= _freezeLive();
      }
    });
  }

  _DetachedSnapshot _freezeLive() => (
    messages: List<MessageWithParts>.unmodifiable(widget.messages),
    streamingText: Map<String, String>.unmodifiable(widget.streamingText),
    children: List<Session>.unmodifiable(widget.children),
    childStatuses: Map<String, SessionStatus>.unmodifiable(widget.childStatuses),
    retryErrorMessage: widget.retryErrorMessage,
    isBusy: widget.isBusy,
    mainAgentRunning: widget.mainAgentRunning,
  );

  void _onRowMount({required String rowId, required BuildContext context}) => _rowContexts[rowId] = context;

  void _onRowUnmount({required String rowId}) => _rowContexts.remove(rowId);

  /// Where row [rowId] sits in the list's box, or null while it is not built.
  /// During the list's layout a row can be built but not yet laid out, or on
  /// its way out; it is not built until every box up to the list has a size.
  ({double top, double bottom})? _spanOf({required String rowId}) {
    final list = context.findRenderObject();
    final row = _rowContexts[rowId]?.findRenderObject();
    if (list is! RenderBox || row is! RenderBox) return null;
    RenderObject? node = row;
    while (node != list) {
      if (node == null || (node is RenderBox && !node.hasSize)) return null;
      node = node.parent;
    }
    final top = row.localToGlobal(Offset.zero, ancestor: list).dy;
    return (top: top, bottom: top + row.size.height);
  }

  /// Moves row [rowId] to rest [top] px below the top edge, from the next frame.
  void _holdRow({required String rowId, required double top, required Completer<void>? landed}) {
    final anchor = _anchor = _TurnAnchor(rowId: rowId, top: top, landed: landed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _stepAnchor(anchor: anchor, first: true));
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// One step toward [anchor], once a frame has laid out the rows it
  /// measures, so at most one jump a frame. A built row jumps into place and
  /// is checked again, as lazy extents are estimates. An unbuilt row is
  /// searched for from the built rows. The anchor ends once its row settles
  /// or the list can move no closer, when the row goes, or when the list
  /// follows the latest edge again.
  void _stepAnchor({required _TurnAnchor anchor, required bool first}) {
    if (!_advanceAnchor(anchor: anchor, first: first)) anchor.landed?.complete();
  }

  /// One step of [_stepAnchor]; whether another step follows.
  bool _advanceAnchor({required _TurnAnchor anchor, required bool first}) {
    if (!mounted || !identical(anchor, _anchor)) return false;
    _anchor = null;
    final list = context.findRenderObject();
    final target = _rowIndexById[anchor.rowId];
    if (list is! RenderBox || target == null || (_follow.following && !first)) return false;
    final double delta;
    if (_spanOf(rowId: anchor.rowId) case final span?) {
      delta = widget.topInset + anchor.top - span.top;
    } else {
      // Move the built row nearest the target just out of the viewport on the
      // far side. The rows toward the target then fill the viewport in order
      // from that row, so no jump passes over it.
      final built = [
        for (final rowId in _rowContexts.keys)
          if (_rowIndexById[rowId] case final index?) (rowId: rowId, index: index),
      ];
      if (built.isEmpty) return false;
      final nearest = built.reduce((a, b) => (a.index - target).abs() <= (b.index - target).abs() ? a : b);
      final span = _spanOf(rowId: nearest.rowId);
      if (span == null) return false;
      // Older rows sit above.
      delta = target < nearest.index ? list.size.height - span.top : -span.bottom;
    }
    final position = _follow.scrollController.position;
    final pixels = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((pixels - position.pixels).abs() <= 0.5) return false;
    _anchor = anchor;
    // A held turn stops following, even where the jump ends within the latest
    // edge's tolerance and the tracker would follow again, so later output
    // never pulls the reader away from it.
    position.jumpTo(pixels);
    _follow.detach();
    WidgetsBinding.instance.addPostFrameCallback((_) => _stepAnchor(anchor: anchor, first: false));
    return true;
  }

  void _onJumpRequested() {
    if (widget.jumpNotifier.take() case final jump?) _jumpToMessage(messageId: jump.messageId, landed: jump.landed);
  }

  /// Holds message [messageId]'s row where a pinned prompt's tap lands a
  /// prompt: an opener on the pin line, any other message just below the
  /// prompt pinned over it. A message that is gone
  /// moves nothing. Like any hold, this stops following. [landed] completes
  /// once the hold ends.
  void _jumpToMessage({required String messageId, required Completer<void> landed}) {
    final message = widget.messages.where((message) => message.info.id == messageId).firstOrNull;
    if (message == null) return landed.complete();
    // A message that arrived after the list froze is listed on the Prompts
    // screen too, so the list takes the live transcript in to reach it. The
    // hold below moves the reader straight to it, so the reflow goes unseen.
    // Its turn is not built yet, so a prompt taken in this way rests just below
    // the pin, where a follow-up would.
    if (_snapshot case final frozen? when !frozen.messages.any((message) => message.info.id == messageId)) {
      setState(() => _snapshot = _freezeLive());
    }
    final pins = _stickyKey.currentContext?.findRenderObject();
    final top = _turns.promptTurnFor(openerMessageId: messageId) == null && pins is RenderTranscriptStickyPrompts
        ? _kPinnedRowTop + pins.compactHeight + transcriptStickyGap
        : _kPinnedRowTop;
    _holdRow(
      rowId: _entryIdForMessage(info: message.info),
      top: top,
      landed: landed,
    );
  }

  /// Glides back to the prompt of turn [openerMessageId], landing it on the
  /// pin line, where its pin grows back into it. Under reduced motion it jumps
  /// there instead. Like any hold, this stops following.
  void _glideToPrompt({required String openerMessageId}) {
    final turn = _turns.promptTurnFor(openerMessageId: openerMessageId);
    if (turn == null) return;
    final rowId = _entryIdForMessage(info: turn.opener.info);
    final position = _follow.scrollController.position;
    if (context.isReducedMotion || position is! ScrollPositionWithSingleContext) {
      return _holdRow(rowId: rowId, top: _kPinnedRowTop, landed: null);
    }
    _anchor = null;
    _follow.detach();
    position.beginActivity(
      TranscriptGlideActivity(
        position: position,
        target: () => _glideTarget(rowId: rowId),
      ),
    );
  }

  /// The offset that rests row [rowId] where a glide lands it. An unbuilt row
  /// is estimated from the built rows above it, at their mean height. Null
  /// once the row is gone, or below the built rows, where no pin leads.
  double? _glideTarget({required String rowId}) {
    final pixels = _follow.scrollController.position.pixels;
    final restTop = widget.topInset + _kPinnedRowTop;
    if (_spanOf(rowId: rowId) case final span?) return pixels + restTop - span.top;
    final target = _rowIndexById[rowId];
    if (target == null) return null;
    ({int index, double top})? first;
    var builtHeight = 0.0;
    var builtCount = 0;
    for (final builtRowId in _rowContexts.keys) {
      final index = _rowIndexById[builtRowId];
      final span = _spanOf(rowId: builtRowId);
      if (index == null || span == null) continue;
      builtHeight += span.bottom - span.top;
      builtCount++;
      if (first == null || index < first.index) first = (index: index, top: span.top);
    }
    if (first == null || target > first.index) return null;
    return pixels + restTop - (first.top - (first.index - target) * builtHeight / builtCount);
  }

  /// Places the pinned prompts from where the opener bubbles are. Runs while
  /// the transcript lays out, once the rows have and once the pins have, so
  /// whichever lays out last places them with both current.
  void _layOutSticky() {
    final openers = _stickyOpeners();
    final pinTop = widget.topInset + _kPinGap;
    // The prompt the pin names, else, before any has reached the pin line, the
    // next one below.
    final current = currentTranscriptStickyIndex(openers: openers, pinTop: pinTop);
    widget.currentPromptId.value = (current < 0 ? openers.firstOrNull : openers[current])?.id;
    final pins = _stickyKey.currentContext?.findRenderObject();
    if (pins is! RenderTranscriptStickyPrompts) return;
    final layout = layOutTranscriptStickyPrompts(
      openers: openers,
      fullHeights: pins.fullHeights,
      compactHeight: pins.compactHeight,
      pinTop: pinTop,
    );
    pins.stickyLayout = layout;
    _promptSlots.hideOnly(openerIds: layout.hiddenOpenerIds);
    final stickyOpenerIds = [
      for (final (index, opener) in openers.indexed)
        if (opener.place is TranscriptStickyBuilt ||
            opener.place is TranscriptStickyAbove &&
                openers.elementAtOrNull(index + 1)?.place is! TranscriptStickyAbove)
          opener.id,
    ];
    if (listEquals(stickyOpenerIds, _stickyOpenerIds.value)) return;
    // Layout cannot rebuild; the copies join from the next frame, well before
    // a prompt that could pin reaches the pin line.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _stickyOpenerIds.value = stickyOpenerIds;
    });
  }

  /// Every prompt turn's opener in order, with where its bubble is. A built
  /// opener's row is its bubble and the bubble's vertical margin; the row is
  /// read rather than the bubble because the rows are laid out by now, while
  /// a row's own content can still be waiting for its turn.
  List<TranscriptStickyOpener> _stickyOpeners() {
    int? firstBuiltRow;
    for (final rowId in _rowContexts.keys) {
      final index = _rowIndexById[rowId];
      if (index != null && (firstBuiltRow == null || index < firstBuiltRow)) firstBuiltRow = index;
    }
    TranscriptStickyPlace placeOf({required String rowId, required int rowIndex}) {
      if (_spanOf(rowId: rowId) case final span?) {
        const margin = UserMessageBubble.margin;
        return TranscriptStickyBuilt(top: span.top + margin.top, bottom: span.bottom - margin.bottom);
      }
      return firstBuiltRow != null && rowIndex < firstBuiltRow
          ? const TranscriptStickyAbove()
          : const TranscriptStickyBelow();
    }

    return [
      for (final turn in _turns.turns)
        if (turn case TranscriptPromptTurn(:final opener))
          if (_entryIdForMessage(info: opener.info) case final rowId)
            if (_rowIndexById[rowId] case final rowIndex?)
              (id: opener.info.id, place: placeOf(rowId: rowId, rowIndex: rowIndex)),
    ];
  }

  void _onPinchPointerDown() => _pinchStartedFollowing = _follow.following;

  /// Keeps a list that followed when the pinch began following while it
  /// pinches, undoing a trackpad pan-zoom start's detach.
  void _onPinchStart() {
    if (!_pinchStartedFollowing || _pinchDetachSuppressed) return;
    _pinchDetachSuppressed = true;
    _follow.suppressDetach();
  }

  void _onPinchGestureEnd() {
    _pinchStartedFollowing = false;
    _releasePinchDetachSuppression();
  }

  void _releasePinchDetachSuppression() {
    if (!_pinchDetachSuppressed) return;
    _pinchDetachSuppressed = false;
    _follow.releaseDetachSuppression();
  }

  bool _transientSubmissionsMatch({required SessionDetailMessageList oldWidget}) {
    if (oldWidget.localSend != widget.localSend) return false;
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
    final previousPromptIds = <String>{
      ?_localSendRow(localSend: oldWidget.localSend)?.submission.promptId,
      for (final submission in oldWidget.queuedMessages) submission.promptId,
      // A fast acceptance can move a send straight to the parked surface
      // between two builds; it is still the reader's new submission.
      for (final submission in oldWidget.awaitingBridgeSubmissions) submission.promptId,
    };
    return [
      ?_localSendRow(localSend: widget.localSend)?.submission,
      ...widget.queuedMessages,
      ...widget.awaitingBridgeSubmissions,
    ].any((submission) => !previousPromptIds.contains(submission.promptId));
  }

  List<String> _rowIdsFor({
    required List<MessageWithParts> messages,
    required Iterable<String> messageRows,
    required QueuedSessionSubmission? localSendSubmission,
    required List<QueuedSessionSubmission> queuedMessages,
    required List<QueuedSessionPrompt> bridgeQueuedPrompts,
    required List<QueuedSessionSubmission> awaitingBridgeSubmissions,
    required bool hasLaunchRow,
  }) {
    final deliveredPromptIds = <String>{
      for (final message in messages)
        if (message.hasRenderableUserContent)
          if (message.info case MessageUser(promptId: final promptId?)) promptId,
    };
    final entries = <String>[
      ...messageRows,
      // Where the first message's echo lands, above the working row.
      if (hasLaunchRow) _kLaunchRowId,
      _kRetryErrorRowId,
      _kWorkingRowId,
      for (final prompt in bridgeQueuedPrompts)
        if (!deliveredPromptIds.contains(prompt.id)) "$_kPromptRowPrefix${prompt.id}",
      for (final submission in awaitingBridgeSubmissions)
        if (!deliveredPromptIds.contains(submission.promptId)) "$_kPromptRowPrefix${submission.promptId}",
      if (localSendSubmission != null && !deliveredPromptIds.contains(localSendSubmission.promptId))
        "$_kPromptRowPrefix${localSendSubmission.promptId}",
      for (final submission in queuedMessages)
        if (!deliveredPromptIds.contains(submission.promptId)) "$_kPromptRowPrefix${submission.promptId}",
    ];
    final seenIds = <String>{};
    return [
      for (final entry in entries)
        if (seenIds.add(entry)) entry,
    ];
  }

  static _TransientSubmission? _localSendRow({required LocalSendPhase localSend}) => switch (localSend) {
    LocalSendIdle() => null,
    LocalSendSending(:final submission) => (submission: submission, stage: _TransientStage.sending),
    LocalSendFailed(:final submission) => (submission: submission, stage: _TransientStage.failed),
  };

  String _entryIdForMessage({required Message info}) => switch (info) {
    MessageUser(promptId: final promptId?) => "$_kPromptRowPrefix$promptId",
    MessageUser() || MessageAssistant() || MessageError() => info.id,
  };

  /// Whether [rowId] shows the user's side: a prompt or a user message.
  static bool _isUserRow({
    required String rowId,
    required List<MessageWithParts> messages,
    required Map<String, int> indexById,
  }) {
    if (rowId.startsWith(_kPromptRowPrefix)) return true;
    final index = indexById[rowId];
    return index != null && index < messages.length && messages[index].info is MessageUser;
  }

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
    final localSendRow = _localSendRow(localSend: widget.localSend);
    final queuedMessages = widget.queuedMessages;
    final streamingText = snap?.streamingText ?? widget.streamingText;
    final children = snap?.children ?? widget.children;
    final childStatuses = snap?.childStatuses ?? widget.childStatuses;
    final retryErrorMessage = snap?.retryErrorMessage ?? widget.retryErrorMessage;
    final isBusy = snap?.isBusy ?? widget.isBusy;
    final mainAgentRunning = snap?.mainAgentRunning ?? widget.mainAgentRunning;

    final indexById = _indexByIdFor(messages: messages);
    final transcript = const TranscriptBuilder().build(
      messages: messages,
      streamingText: streamingText,
      children: children,
      childStatuses: childStatuses,
    );
    final turns = const TranscriptTurnBuilder().build(
      messages: messages,
      hasOlderMessages: widget.onLoadOlderMessages != null,
    );
    final activity = const TranscriptActivityBuilder().build(
      transcript: transcript,
      turns: turns,
      messages: messages,
      isBusy: isBusy,
      mainAgentRunning: mainAgentRunning,
      retryErrorMessage: retryErrorMessage,
      hasStreamingText: streamingText.isNotEmpty,
      children: children,
      childStatuses: childStatuses,
    );
    final transientSubmissions = <String, _TransientSubmission>{
      for (final submission in widget.awaitingBridgeSubmissions)
        "$_kPromptRowPrefix${submission.promptId}": (submission: submission, stage: _TransientStage.awaitingBridge),
      if (localSendRow case (:final submission, :final stage))
        "$_kPromptRowPrefix${submission.promptId}": (submission: submission, stage: stage),
      for (final submission in queuedMessages)
        "$_kPromptRowPrefix${submission.promptId}": (submission: submission, stage: _TransientStage.pending),
    };

    final rowIds = _rowIdsFor(
      messages: messages,
      messageRows: [
        for (final message in messages)
          if (message.hasRenderableUserContent) _entryIdForMessage(info: message.info),
      ],
      localSendSubmission: localSendRow?.submission,
      queuedMessages: queuedMessages,
      bridgeQueuedPrompts: widget.bridgeQueuedPrompts,
      awaitingBridgeSubmissions: widget.awaitingBridgeSubmissions,
      hasLaunchRow: widget.launchHandoff != null,
    );
    final knownRowIds = _knownRowIds;
    if (knownRowIds != null && knownRowIds.contains(_kLaunchRowId) && !rowIds.contains(_kLaunchRowId)) {
      _launchSlotRowId = rowIds
          .where(
            (rowId) =>
                !knownRowIds.contains(rowId) && _isUserRow(rowId: rowId, messages: messages, indexById: indexById),
          )
          .firstOrNull;
    }
    _knownRowIds = rowIds.toSet();
    _rowIndexById = {for (final (index, rowId) in rowIds.indexed) rowId: index};
    _turns = turns;
    // Rows held still while scrolled away never animate, and a prompt shows
    // at once: only the agent's side of the transcript eases in.
    final enteringRowIds = knownRowIds == null || snap != null || context.isReducedMotion
        ? const <String>{}
        : {
            for (final rowId in rowIds)
              if (!knownRowIds.contains(rowId) && !_isUserRow(rowId: rowId, messages: messages, indexById: indexById))
                rowId,
          };
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
      child: TranscriptPinchDetector(
        onPointerDown: _onPinchPointerDown,
        onPinchStart: _onPinchStart,
        onPinchIn: widget.onPinchIn,
        onGestureEnd: _onPinchGestureEnd,
        child: NotificationListener<Notification>(
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
            child: Stack(
              children: [
                TranscriptLaidOutListView(
                  key: _kListViewKey,
                  onLaidOut: _layOutSticky,
                  reverse: true,
                  controller: _follow.scrollController,
                  padding: EdgeInsetsDirectional.only(
                    start: widget.horizontalInset,
                    end: widget.horizontalInset,
                    top: 8 + widget.topInset,
                    bottom: 8 + widget.bottomInset,
                  ),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: rowIds.length,
                  findChildIndexCallback: (key) {
                    if (key case ValueKey<String>(value: final keyValue)) {
                      final rowId = keyValue == _kLaunchRowId ? _launchSlotRowId ?? keyValue : keyValue;
                      final domainIndex = rowIds.indexOf(rowId);
                      return domainIndex < 0 ? null : rowIds.length - domainIndex - 1;
                    }
                    return null;
                  },
                  itemBuilder: (context, index) {
                    final entryId = rowIds[rowIds.length - index - 1];
                    return TranscriptRowReporter(
                      key: ValueKey(entryId == _launchSlotRowId ? _kLaunchRowId : entryId),
                      rowId: entryId,
                      onMount: _onRowMount,
                      onUnmount: _onRowUnmount,
                      child: TranscriptPresence(
                        entering: enteringRowIds.contains(entryId),
                        exiting: false,
                        onExited: null,
                        child: _buildRow(
                          entryId: entryId,
                          messages: messages,
                          indexById: indexById,
                          transientSubmissions: transientSubmissions,
                          transcript: transcript,
                          streamingText: streamingText,
                          retryErrorMessage: retryErrorMessage,
                          activity: activity,
                        ),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  // The copies' code blocks scroll sideways; the list must not
                  // read their scrolls as its own.
                  child: NotificationListener<Notification>(
                    onNotification: (notification) =>
                        notification is ScrollNotification || notification is ScrollMetricsNotification,
                    child: ValueListenableBuilder(
                      valueListenable: _stickyOpenerIds,
                      builder: (context, openerIds, _) => TranscriptStickyPromptOverlay(
                        key: _stickyKey,
                        turns: [for (final openerId in openerIds) ?turns.promptTurnFor(openerMessageId: openerId)],
                        horizontalInset: widget.horizontalInset,
                        onLayout: _layOutSticky,
                        onTap: _glideToPrompt,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    required Transcript transcript,
    required Map<String, String> streamingText,
    required String? retryErrorMessage,
    required TranscriptActivity activity,
  }) {
    if (entryId == _kRetryErrorRowId) {
      // Synthetic row: no timestamp, but it still slides with the rest.
      return _revealable(
        createdAtMs: null,
        child: TranscriptPresenceColumn(
          children: [
            if (retryErrorMessage != null)
              RetryErrorMessageCard(key: const ValueKey("session-detail-retry-error"), message: retryErrorMessage),
          ],
        ),
      );
    }
    if (entryId == _kWorkingRowId) {
      return _revealable(createdAtMs: null, child: _workingRow(activity: activity));
    }
    if (widget.launchHandoff
        case SessionLaunchHandoff(
          :final submission,
          :final pluginId,
          :final startedAt,
        )
        when entryId == _kLaunchRowId) {
      final attachments = switch (submission) {
        NewSessionTextSubmissionSnapshot(:final attachments) => attachments,
        NewSessionCommandSubmissionSnapshot() => const <ComposerAttachment>[],
      };
      return _revealable(
        createdAtMs: null,
        child: _animatedPromptRow(
          child: QueuedMessageBubble(
            key: const ValueKey(_kLaunchRowId),
            displayText: submission.displayText,
            isCommand: submission is NewSessionCommandSubmissionSnapshot,
            attachmentCount: attachments.length,
            localAttachments: attachments,
            presentation: QueuedMessageBubblePresentation.sending(
              harnessName: PregoBrandLogo.displayNameFor(pluginId),
              sendingSince: startedAt,
            ),
          ),
        ),
      );
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
          child: _animatedPromptRow(child: _userMessage(message: message)),
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
              localAttachments: widget.bridgePromptAttachments[prompt.id] ?? const [],
              presentation: switch (prompt.dispatchState) {
                QueuedPromptDispatchState.dispatched => QueuedMessageBubblePresentation.sending(
                  harnessName: widget.harnessName,
                  sendingSince: null,
                ),
                QueuedPromptDispatchState.queued || QueuedPromptDispatchState.unknown =>
                  onCancel == null
                      ? const QueuedMessageBubblePresentation.pendingReadOnly()
                      : QueuedMessageBubblePresentation.pending(onCancel: () => onCancel(prompt.id)),
              },
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
            localAttachments: submission.attachments,
            presentation: switch (transientSubmission.stage) {
              _TransientStage.sending => QueuedMessageBubblePresentation.sending(
                harnessName: widget.harnessName,
                sendingSince: null,
              ),
              _TransientStage.failed => QueuedMessageBubblePresentation.failed(
                onRetry: widget.onRetryFailedSend,
                onRemove: widget.onRemoveFailedSend,
              ),
              _TransientStage.awaitingBridge => const QueuedMessageBubblePresentation.pendingReadOnly(),
              _TransientStage.pending when submission is UnavailableQueuedCommandSubmission =>
                QueuedMessageBubblePresentation.commandUnavailable(
                  onRemove: onCancelQueuedMessage == null
                      ? null
                      : () => _cancelQueuedSubmission(submission: submission),
                ),
              _TransientStage.pending =>
                onCancelQueuedMessage == null
                    ? const QueuedMessageBubblePresentation.pendingReadOnly()
                    : QueuedMessageBubblePresentation.pending(
                        onCancel: () => _cancelQueuedSubmission(submission: submission),
                      ),
            },
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
      // The launch bubble's echo keeps easing like the bubble it replaced.
      MessageUser() when entryId == _launchSlotRowId => _animatedPromptRow(child: _userMessage(message: message)),
      MessageUser() => _userMessage(message: message),
      MessageAssistant(sender: MessageSender.agent, :final id) => AssistantMessageCard(
        projectId: widget.projectId,
        blocks: transcript.blocksFor(messageId: id),
        streamingText: streamingText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      MessageAssistant(:final id) => SystemMessageCard(
        projectId: widget.projectId,
        blocks: transcript.blocksFor(messageId: id),
        streamingText: streamingText,
      ),
      final MessageError messageError => ErrorMessageCard(message: messageError),
    };
    return _revealable(createdAtMs: message.info.time?.created, child: card);
  }

  /// A user message's bubble; a prompt turn's opener registers where it is,
  /// so its pin can stand in for it.
  Widget _userMessage({required MessageWithParts message}) {
    final card = UserMessageCard(message: message);
    if (_turns.promptTurnFor(openerMessageId: message.info.id) == null) return card;
    return TranscriptPromptSlot(openerId: message.info.id, registry: _promptSlots, child: card);
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

  /// The working row eases in when work starts or a step ends, and away when
  /// a step starts or work ends. The sub-agent row takes over, easing, while
  /// only sub-agents work.
  Widget _workingRow({required TranscriptActivity activity}) => TranscriptPresenceColumn(
    children: [
      ?switch (activity) {
        TranscriptActivityWorking(:final sinceMs) => TranscriptWorkingRow(
          key: const ValueKey("session-detail-working"),
          sinceMs: sinceMs,
        ),
        TranscriptActivitySubAgents(:final count, :final sinceMs) => TranscriptSubAgentsRow(
          key: const ValueKey("session-detail-sub-agents"),
          count: count,
          sinceMs: sinceMs,
        ),
        TranscriptActivityIdle() => null,
      },
    ],
  );

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

  bool _onScrollNotification(Notification notification) {
    // Nearing the oldest edge prefetches the older page, so paging back through
    // history feels continuous. Scroll updates report it while scrolling; the
    // metrics notification reports it after a layout without a scroll, such as
    // the first page or a taller window, so a transcript shorter than
    // the viewport pages on its own. The scroll-end check is the fallback for
    // a transcript too short to scroll: clamping physics moves nothing at zero
    // extent, so only the end notification reports the attempt. A nested
    // scrollable's notifications (depth above 0) do not count.
    final nearingOldestEdge = switch (notification) {
      ScrollUpdateNotification(depth: 0, :final metrics) ||
      ScrollMetricsNotification(depth: 0, :final metrics) => metrics.extentAfter < _kOlderPagePrefetchExtent,
      ScrollEndNotification(depth: 0, :final metrics) => metrics.extentAfter == 0,
      _ => false,
    };
    if (nearingOldestEdge) _requestOlderPage();
    return notification is ScrollNotification && _onNestedScrollNotification(notification);
  }

  void _checkOldestEdge() {
    final position = _follow.scrollController.position;
    if (position.hasContentDimensions && position.extentAfter < _kOlderPagePrefetchExtent) _requestOlderPage();
  }

  /// Asks for the page before the oldest message, unless the start of the
  /// transcript is loaded or a page is already on its way.
  void _requestOlderPage() {
    final loadOlderMessages = widget.onLoadOlderMessages;
    if (loadOlderMessages == null || _loadOlderCallbackInFlight || widget.isLoadingOlderMessages) return;
    _loadOlderCallbackInFlight = true;
    unawaited(_loadOlderMessages(loadOlderMessages));
  }

  Future<void> _loadOlderMessages(Future<void> Function() loadOlderMessages) async {
    try {
      await loadOlderMessages();
    } catch (error, stackTrace) {
      loge("Failed to load older session messages", error, stackTrace);
    } finally {
      if (mounted) {
        _loadOlderCallbackInFlight = false;
        if (_checkOldestEdgeAfterLoad) {
          _checkOldestEdgeAfterLoad = false;
          _checkOldestEdge();
        }
      }
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
