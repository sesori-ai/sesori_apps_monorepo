import "dart:async";

import "package:clock/clock.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../session_detail_presentation_scope.dart";

import "assistant_message_card.dart";
import "error_message_card.dart";
import "follow_detach_scrollable.dart";
import "forked_from_row.dart";
import "handoff_card.dart";
import "handoff_marker_row.dart";
import "jump_to_edge_pill.dart";
import "message_timestamp_reveal.dart";
import "queued_message_bubble.dart";
import "retry_error_message_card.dart";
import "scroll_follow_tracker.dart";
import "sent_bubble_landing.dart";
import "session_fork_flow.dart";
import "session_launch_submission_view.dart";
import "system_message_card.dart";
import "transcript_glide_activity.dart";
import "transcript_jump_notifier.dart";
import "transcript_laid_out_list_view.dart";
import "transcript_live_row.dart";
import "transcript_message_menu.dart";
import "transcript_motion.dart";
import "transcript_pinch_detector.dart";
import "transcript_prompt_slot.dart";
import "transcript_row_reporter.dart";
import "transcript_sticky_layout.dart";
import "transcript_sticky_prompt_overlay.dart";
import "turn_end_line.dart";
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

  /// When this surface sent the first message of the session it just created,
  /// kept after [launchHandoff] goes, as what replaces it still counts from then.
  required final DateTime? launchStartedAt,

  /// Null on a read-only surface, which shows the failure without actions.
  required final VoidCallback? onRetryFailedSend,
  required final VoidCallback? onRemoveFailedSend,

  /// Messages sent before the session existed that its launch has not
  /// delivered yet, shown after the ones already accepted.
  required final List<LaunchFollowUp> launchFollowUps,

  /// Whether each user turn renders as an invocation card or a bubble.
  required final PromptTurnShapes promptTurnShapes,

  /// Null on a read-only surface, which shows the follow-ups without actions.
  required final void Function({required String promptId})? onRetryLaunchFollowUp,
  required final void Function({required String promptId})? onRemoveLaunchFollowUp,

  /// Accepted sends the bridge has not listed yet — rendered as read-only
  /// queued bubbles so the prompt never blanks between its acceptance
  /// response and the bridge's queue event.
  final List<AwaitingBridgeSubmission> awaitingBridgeSubmissions = const [],
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

  /// How the transcript ends the turn a bridge stop cut off.
  required final InterruptedTurnView interruptedTurn,

  /// Sends the prompt that continues the interrupted turn, answering why it
  /// sent nothing; null on a surface that cannot send.
  required final Future<InterruptedTurnContinueRefusal?> Function()? onContinueInterruptedTurn,

  /// Requests the page of messages before the ones shown, or null when the
  /// start of the transcript is already loaded.
  required final Future<void> Function()? onLoadOlderMessages,

  /// The bridge's prompt index, or null until it arrives or when the bridge
  /// has none: it names the unloaded prompt to pin above the loaded messages.
  required final List<SessionPromptIndexEntry>? promptIndex,

  /// Loads every message from an unloaded prompt down to the loaded ones, for
  /// a tap on its pin.
  required final Future<LoadThroughOutcome> Function({required String messageId, required int seq}) onLoadThrough,
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

  /// Edit and resend on a user message, with why it cannot be edited, or null
  /// when it can, and the message's Fork from here, or null where it offers
  /// none. Null when the session offers no edit.
  required final void Function({
    required MessageWithParts message,
    required MessageEditRefusal? refusal,
    required VoidCallback? onFork,
  })?
  onEditMessage,

  /// "Fork from here" at [point]. [ownMessage] is the user message it was
  /// asked from, whose text and attachments go to the fork's composer, or
  /// null for an agent reply. Null when the session offers no fork.
  required final void Function({required ForkPoint point, required MessageWithParts? ownMessage})? onForkMessage,

  /// Where this session was forked from, shown above its oldest message once
  /// that is loaded, or null when it is not a fork.
  required final SessionForkOrigin? forkedFrom,

  /// Goes back to the session [forkedFrom] names.
  required final void Function({required String sessionId, required String? sessionTitle}) onOpenForkOrigin,

  /// The user message the composer is editing, which stands out, or null.
  required final String? editingMessageId,
  final String? retryErrorMessage,

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

  /// The prompt index as it stood, so the pin above the frozen messages never
  /// names a prompt sent after them.
  List<SessionPromptIndexEntry>? promptIndex,

  /// The frozen messages' card shapes, so a row being read never turns
  /// between a card and a bubble.
  Map<String, InvocationPromptTurnShape> messageShapes,

  /// The Interrupted line as it stood, so it neither arrives nor loses its
  /// Continue under the rows being read.
  InterruptedTurnView interruptedTurn,
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

/// A notifier that only says something happened.
class _Pulse() extends ChangeNotifier {
  void pulse() => notifyListeners();
}

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

  /// Around the agent's reply, and the working row that stands in for it.
  static const _kReplyPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

  /// Synthetic id for the launch's first message, the oldest transient row. A
  /// session has at most one, so it is never matched against echoes.
  static const _kLaunchRowId = "session-detail-launch-row";

  /// Synthetic id for a fork's "Forked from" line, the oldest row once the
  /// start of the transcript is loaded.
  static const _kForkedFromRowId = "session-detail-forked-from-row";
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

  /// How long a tapped unloaded prompt's load runs before its spinner shows,
  /// so a quick load never flashes one.
  static const _kPinLoadSpinnerDelay = Duration(milliseconds: 150);

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

  /// Rows that have eased all the way in, or were there when the list opened.
  /// Scrolling can drop one and build it again, and it only eases in again if it
  /// was dropped before it had opened.
  final Set<String> _easedInRowIds = {};

  /// How each built row last looked, so a row whose message is removed can
  /// fold away as it was.
  final Map<String, Widget> _builtRows = {};

  /// The rows of removed messages folding away where they were, as they last
  /// looked. Each leaves the list once it has folded.
  final Map<String, Widget> _leavingRows = {};

  /// The rows of the messages the last update removed, for the next build.
  Set<String> _removedRowIds = const {};

  /// How long removed rows keep their room for what replaces them. Another
  /// surface's edit reaches this one as its removals first and its prompt's
  /// echo and the Working row some frames later.
  static const _kFoldWait = Duration(milliseconds: 300);

  /// Leaving rows that keep their room, still shown, until rows join to take
  /// it or [_kFoldWait] ends. Folding as those rows grow, they move the rows
  /// above in one direction, where folding first would carry them down and
  /// the joining rows back up.
  final Set<String> _waitingRowIds = {};
  Timer? _foldWait;

  /// When a row last joined the list or the live row started showing.
  DateTime? _joinedAt;
  bool _liveRowShown = false;

  /// The row that replaced the launch bubble. It keeps the launch row's key, so
  /// the swap eases in place like a queued prompt turning into its message.
  String? _launchSlotRowId;

  /// The last build's rows by their place in order.
  Map<String, int> _rowIndexById = const {};

  /// The pending prompt row that woke an idle session: the working row sits
  /// right below it until it shows as a message, which the row follows anyway.
  String? _wakingPromptRowId;

  /// Whether no message has arrived since the session was last idle. A prompt
  /// that appears meanwhile still woke it, even when the session's busy status
  /// got here first, as it can for a prompt sent from another surface.
  bool _quietSinceIdle = false;

  /// The last build's newest message, to tell when one arrives.
  String? _newestMessageId;

  /// Whether an edit's accepted prompt shows the working row ahead of the
  /// busy status; see where the build sets it.
  bool _acceptedEditWorks = false;

  /// How long the working row stays away once streamed text ends with the
  /// session still busy. A harness can report idle some 50 ms after its reply's
  /// last part, and the row folding in and out again in between moves the
  /// rows above. A real gap before the next step outlasts this, and the next
  /// step's own row takes over sooner anyway.
  static const _kStreamEndGrace = Duration(milliseconds: 250);

  /// Whether the last build had streaming text.
  bool _streamed = false;

  /// Runs from a stream's end, while busy alone would bring back the working
  /// row, until [_kStreamEndGrace] ends or the session goes idle.
  Timer? _streamEndGrace;

  /// The last build's rendered user messages, prompts and steers alike, in
  /// order: the messages that can pin.
  Map<String, MessageWithParts> _userMessagesById = const {};

  /// The handoffs among the rows, from the last build.
  TranscriptHandoffs _handoffs = const TranscriptHandoffs(
    markers: {},
    foldedMessageIds: {},
    cards: {},
    queuedMarkers: {},
    queuedCards: {},
    stopping: false,
  );

  /// The attached user message bubbles, by message id.
  final _promptSlots = TranscriptPromptSlots();
  final GlobalKey _stickyKey = GlobalKey();

  /// The user messages the pins hold copies of: those that could pin next,
  /// which are the built ones and the one just above them.
  final ValueNotifier<List<String>> _stickyOpenerIds = ValueNotifier(const []);

  /// Fires each time the rows lay out, which every frame that scrolls them does.
  final _rowsLaidOut = _Pulse();

  /// What moves the rows' text while a selection in it stays the same: their
  /// layout, and the timestamp peek sliding them sideways. The selection
  /// highlight follows both.
  late final Listenable _rowsMoved = Listenable.merge([_rowsLaidOut, _revealController]);

  /// The built rows by id. Only built rows are here, so every scan stays
  /// bounded by the viewport and its cache extent.
  final Map<String, BuildContext> _rowContexts = {};

  /// The one row being held in place, until it settles or goes.
  _TurnAnchor? _anchor;

  /// Captured when a pinch's first pointer lands, before a trackpad pan-zoom
  /// start detaches the list, so a pinch leaves following alone.
  bool _pinchStartedFollowing = false;
  bool _pinchDetachSuppressed = false;

  /// Whether an open message's menu, not the reader, detached the list: it
  /// follows again once the menu closes, and offers no jump meanwhile.
  bool _heldByMenu = false;

  /// The last prompt index the list was given, kept while a refresh fetches
  /// it again so the unloaded prompt's pin stays put meanwhile.
  List<SessionPromptIndexEntry>? _promptIndex;

  /// The newest prompt this list saw the bridge hold, with when it was
  /// accepted. Its delivered message carries only the later delivery time, so
  /// the Working timer keeps this start instead of stepping back. A reopened
  /// list never saw it and counts from the delivery time.
  ({String promptId, int acceptedAt})? _lastHeldPrompt;

  /// When each prompt row on its way was sent, so that the row has one clock for
  /// its status line across its states and however often it is rebuilt. Kept here
  /// because scrolling away drops the row. Null for a prompt that was already
  /// waiting when the list opened: nothing just moved, so its line shows at once.
  final Map<String, DateTime?> _promptSentAt = {};

  /// The last build's unloaded prompt pinned above the rendered messages.
  SessionPromptIndexEntry? _unloadedPin;

  /// The rendered messages' turns, as the last build split them.
  TranscriptTurns _turns = const TranscriptTurns(turns: [], turnIndexByMessageId: {}, finalReplyIds: {});

  /// The Interrupted line the last build rendered, which the rows it builds
  /// read.
  InterruptedTurnView _interruptedTurn = const InterruptedTurnView.absent();

  /// The unloaded prompt a tap on its pin is loading, until that load ends.
  /// Its spinner keeps to this entry's side even once the pin itself clears.
  SessionPromptIndexEntry? _pinLoad;
  bool _showsPinLoadSpinner = false;
  Timer? _pinLoadSpinner;

  @override
  void initState() {
    super.initState();
    // The pin is in place on the first frame anyone reads, not on whichever later
    // layout happens to come along, which would pop it in over the text.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _layOutSticky();
    });
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
    _rowsLaidOut.dispose();
    _pinLoadSpinner?.cancel();
    _foldWait?.cancel();
    _streamEndGrace?.cancel();
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
    final oldestChanged = widget.messages.firstOrNull?.info.id != oldWidget.messages.firstOrNull?.info.id;
    // Apart from a refresh, which replaces the transcript, messages only leave
    // it when the harness removes them, as a rewind does. A refresh's messages
    // can be another row's re-keyed twin or paged-back history it drops, so
    // its rows go at once.
    final removedMessages = refreshEnded ? const <Message>[] : _removedMessages(oldWidget: oldWidget);
    _removedRowIds = {for (final info in removedMessages) _entryIdForMessage(info: info)};
    // An edit's removals leave an older message newest, which did not arrive:
    // the session stays quiet, so the edit's prompt wakes it above the
    // working row, where its echo lands.
    final newestMessageId = widget.messages.lastOrNull?.info.id;
    if (removedMessages.isNotEmpty && oldWidget.messages.any((message) => message.info.id == newestMessageId)) {
      _newestMessageId = newestMessageId;
    }
    if (refreshEnded || oldestChanged) {
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
    // While detached the snapshot keeps the list structure from shifting
    // under the reader; `_onFollowChanged` restores live inputs on reattach.
    //
    // Older history is the exception, whether an older page or a load up to
    // a tapped prompt brought it: the reader is detached precisely because
    // they scrolled back for it, and it is prepended *above* the viewport,
    // so rendering it cannot shift what is being read. Freezing it would
    // leave it loaded but invisible until the user returned to the newest
    // message. Removed messages are the other: their rows fold away, holding
    // the reader's rows where they are.
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
    if (frozen == null) return;
    final prepended = oldestChanged ? _prependedOlderMessages(frozen: frozen) : const <MessageWithParts>[];
    final delivered = _deliveredPromptMessages(frozen: frozen);
    final removedIds = {for (final info in removedMessages) info.id};
    final kept = [
      for (final message in frozen.messages)
        if (!removedIds.contains(message.info.id)) message,
    ];
    if (prepended.isEmpty && delivered.isEmpty && kept.length == frozen.messages.length) return;

    // Take *only* the newly prepended prefix and the prompts delivered into
    // rows already showing, less the removed messages. Taking the whole live
    // list would also pull in messages appended at the newest edge while
    // detached, which is exactly the reflow the freeze exists to prevent.
    // Everything else the snapshot holds — streaming text, children, statuses,
    // retry state — stays frozen.
    final merged = [...prepended, ...kept, ...delivered];
    setState(() {
      _snapshot = (
        messages: List<MessageWithParts>.unmodifiable(merged),
        streamingText: frozen.streamingText,
        children: frozen.children,
        childStatuses: frozen.childStatuses,
        retryErrorMessage: frozen.retryErrorMessage,
        isBusy: frozen.isBusy,
        mainAgentRunning: frozen.mainAgentRunning,
        promptIndex: frozen.promptIndex,
        messageShapes: {
          ...frozen.messageShapes,
          for (final MessageWithParts(:info) in [...prepended, ...delivered])
            info.id: ?widget.promptTurnShapes.messages[info.id],
        },
        interruptedTurn: frozen.interruptedTurn,
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

  /// Live messages for prompts the frozen transcript shows as pending rows. The
  /// bridge drops a prompt from its queue once delivered, so only the message
  /// can keep that row on screen.
  List<MessageWithParts> _deliveredPromptMessages({required _DetachedSnapshot frozen}) {
    final frozenIds = frozen.messages.map((message) => message.info.id).toSet();
    return [
      for (final message in widget.messages)
        if (message.info case MessageUser(:final id, promptId: final promptId?))
          if (message.hasRenderableUserContent &&
              !frozenIds.contains(id) &&
              _rowIndexById.containsKey("$_kPromptRowPrefix$promptId"))
            message,
    ];
  }

  /// The messages [oldWidget] showed that this update took away.
  List<Message> _removedMessages({required SessionDetailMessageList oldWidget}) {
    if (identical(oldWidget.messages, widget.messages)) return const [];
    final ids = {for (final message in widget.messages) message.info.id};
    return [
      for (final MessageWithParts(:info) in oldWidget.messages)
        if (!ids.contains(info.id)) info,
    ];
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
    promptIndex: widget.promptIndex ?? _promptIndex,
    messageShapes: widget.promptTurnShapes.messages,
    interruptedTurn: widget.interruptedTurn,
  );

  PromptTurnShape _messageShape({required String messageId}) => switch (_snapshot) {
    final frozen? => frozen.messageShapes[messageId] ?? const PromptTurnShape.bubble(),
    null => widget.promptTurnShapes.ofMessage(messageId: messageId),
  };

  void _onRowMount({required String rowId, required BuildContext context}) => _rowContexts[rowId] = context;

  void _onRowUnmount({required String rowId}) {
    _rowContexts.remove(rowId);
    _builtRows.remove(rowId);
    // Scrolled away before it had folded, it would not fold on coming back.
    if (_leavingRows.containsKey(rowId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onRowLeft(rowId: rowId));
    }
  }

  void _onRowLeft({required String rowId}) {
    if (mounted && _leavingRows.containsKey(rowId)) setState(() => _leavingRows.remove(rowId));
  }

  /// Holds rows that start leaving while following with nothing joining, see
  /// [_waitingRowIds], and lets every held row fold once rows join. Rows that
  /// joined in the last [transcriptMotionDuration] still grow, so rows leaving
  /// then fold at once.
  void _waitForReplacements({
    required Set<String> newlyLeaving,
    required bool rowsJoined,
    required bool following,
  }) {
    final now = clock.now();
    if (following && rowsJoined) _joinedAt = now;
    final joinedLately = switch (_joinedAt) {
      final joinedAt? => now.difference(joinedAt) < transcriptMotionDuration,
      null => false,
    };
    if (joinedLately) {
      _waitingRowIds.clear();
    } else if (following && newlyLeaving.isNotEmpty) {
      _waitingRowIds.addAll(newlyLeaving);
    }
    _waitingRowIds.retainAll(_leavingRows.keys);
    if (_waitingRowIds.isEmpty) {
      _foldWait?.cancel();
      _foldWait = null;
    } else {
      _foldWait ??= Timer(_kFoldWait, () {
        _foldWait = null;
        if (mounted) setState(_waitingRowIds.clear);
      });
    }
  }

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

  /// Holds message [messageId]'s row where a pinned message's tap lands it:
  /// on the pin line. A message that is gone moves nothing. Like any hold,
  /// this stops following. [landed] completes once the hold ends.
  void _jumpToMessage({required String messageId, required Completer<void> landed}) {
    final message = widget.messages.where((message) => message.info.id == messageId).firstOrNull;
    if (message == null) return landed.complete();
    // A message that arrived after the list froze is listed on the Prompts
    // screen too, so the list takes the live transcript in to reach it. The
    // hold below moves the reader straight to it, so the reflow goes unseen.
    if (_snapshot case final frozen? when !frozen.messages.any((message) => message.info.id == messageId)) {
      setState(() => _snapshot = _freezeLive());
    }
    _holdRow(
      rowId: _entryIdForMessage(info: message.info),
      top: _kPinnedRowTop,
      landed: landed,
    );
  }

  /// Glides back to user message [openerMessageId], landing it on the pin
  /// line, where its pin grows back into it. Under reduced motion it jumps
  /// there instead. Like any hold, this stops following.
  void _glideToPrompt({required String openerMessageId}) {
    final message = _userMessagesById[openerMessageId];
    if (message == null) return;
    final rowId = _entryIdForMessage(info: message.info);
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

  void _onPinTap({required String openerMessageId}) {
    if (_unloadedPin case final pin? when pin.messageId == openerMessageId) {
      // Another tap while it loads waits for that load.
      if (_pinLoad == null) unawaited(_openUnloadedPin(pin: pin));
      return;
    }
    _glideToPrompt(openerMessageId: openerMessageId);
  }

  /// Loads the transcript up to the unloaded prompt [pin] names, then glides
  /// back to it, as a tap on a loaded prompt's pin does. A slow load shows a
  /// spinner by the pin; one that fails says why.
  Future<void> _openUnloadedPin({required SessionPromptIndexEntry pin}) async {
    setState(() => _pinLoad = pin);
    _pinLoadSpinner = Timer(_kPinLoadSpinnerDelay, () => setState(() => _showsPinLoadSpinner = true));
    final outcome = await widget.onLoadThrough(messageId: pin.messageId, seq: pin.seq);
    if (!mounted) return;
    _pinLoadSpinner?.cancel();
    setState(() {
      _pinLoad = null;
      _showsPinLoadSpinner = false;
    });
    final loc = context.loc;
    final error = switch (outcome) {
      LoadThroughLoaded() => null,
      LoadThroughTargetMissing() => loc.transcriptPromptsGone,
      LoadThroughFailed() => loc.transcriptPromptsOpenFailed,
      LoadThroughSuperseded() => loc.transcriptPromptsRefreshed,
    };
    if (error != null) {
      return PregoPopupAlertPresenter.of(context)
          .show(title: error, variant: PregoPopupAlertsNotificationsVariant.error);
    }
    // The loaded prompt is a row once the list has built it.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) _glideToPrompt(openerMessageId: pin.messageId);
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

  /// Moves what follows the rows in the layout pass that moved them: the pins
  /// and the selection highlight.
  void _onRowsLaidOut() {
    _layOutSticky();
    _rowsLaidOut.pulse();
  }

  /// Places the pinned messages from where the user message bubbles are. Runs
  /// while the transcript lays out, once the rows have and once the pins
  /// have, so whichever lays out last places them with both current.
  void _layOutSticky() {
    // The pins lay out before the list when both have to, and a rebuild that
    // moved the rows has them out of place until the list does. Its pass, later
    // in this frame, places the pins.
    if (_rowContexts.values.any((rowContext) => _awaitsPlacing(rowContext: rowContext))) return;
    final openers = _stickyOpeners();
    final pinTop = widget.topInset + _kPinGap;
    // The message the pin names, else, before any has reached the pin line,
    // the next one below.
    final current = currentTranscriptStickyIndex(openers: openers, pinTop: pinTop);
    widget.currentPromptId.value = (current < 0 ? openers.firstOrNull : openers[current])?.id;
    final pins = _stickyKey.currentContext?.findRenderObject();
    // Until the pins have their size, their own layout places them.
    if (pins is! RenderTranscriptStickyPrompts || !pins.hasSize) return;
    final layout = layOutTranscriptStickyPrompts(
      openers: openers,
      previous: pins.stickyLayout,
      heights: pins.pinHeights,
      cutOpenerIds: pins.cutOpenerIds,
      pinTop: pinTop,
      viewportBottom: pins.size.height - TranscriptBottomInset.peek(context),
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
    // a prompt that could pin reaches the pin line, unless a far move outruns
    // them, when the last pin holds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _stickyOpenerIds.value = stickyOpenerIds;
    });
  }

  /// Whether the list has yet to place [rowContext]'s row. A row kept alive out
  /// of view has no place, and the list will not give it one.
  static bool _awaitsPlacing({required BuildContext rowContext}) {
    RenderObject? node = rowContext.findRenderObject();
    while (node != null) {
      if (node.parentData case SliverMultiBoxAdaptorParentData(:final layoutOffset, :final keptAlive)) {
        return layoutOffset == null && !keptAlive;
      }
      node = node.parent;
    }
    return false;
  }

  /// Every rendered user message in order, with where its bubble is. A built
  /// message's row is its bubble and the bubble's vertical margin; the row is
  /// read rather than the bubble because the rows are laid out by now, while
  /// a row's own content can still be waiting for its turn.
  List<TranscriptStickyOpener> _stickyOpeners() {
    // Only rows laid out at least once: a row just built above the others,
    // such as a prompt that loaded, is still above them, not below.
    int? firstBuiltRow;
    for (final MapEntry(key: rowId, value: rowContext) in _rowContexts.entries) {
      final index = _rowIndexById[rowId];
      final laidOut = switch (rowContext.findRenderObject()) {
        RenderBox(:final hasSize) => hasSize,
        _ => false,
      };
      if (index != null && laidOut && (firstBuiltRow == null || index < firstBuiltRow)) firstBuiltRow = index;
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
      // Above every rendered row, as the turn it opened runs into them.
      if (_unloadedPin case final pin?) (id: pin.messageId, place: const TranscriptStickyAbove()),
      for (final message in _userMessagesById.values)
        if (_entryIdForMessage(info: message.info) case final rowId)
          if (_rowIndexById[rowId] case final rowIndex?)
            (id: message.info.id, place: placeOf(rowId: rowId, rowIndex: rowIndex)),
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
      if (oldWidget.awaitingBridgeSubmissions[i] != widget.awaitingBridgeSubmissions[i]) return false;
    }
    return true;
  }

  bool _hasNewTransientSubmission({required SessionDetailMessageList oldWidget}) {
    final previousPromptIds = <String>{
      ?_localSendRow(localSend: oldWidget.localSend)?.submission.promptId,
      for (final submission in oldWidget.queuedMessages) submission.promptId,
      // A fast acceptance can move a send straight to the parked surface
      // between two builds; it is still the reader's new submission.
      for (final (:submission, since: _) in oldWidget.awaitingBridgeSubmissions) submission.promptId,
      // An accepted launch follow-up is parked under its promptId; it was
      // already on screen, not a new submission.
      for (final LaunchFollowUp(:submission) in oldWidget.launchFollowUps) submission.promptId,
    };
    return [
      ?_localSendRow(localSend: widget.localSend)?.submission,
      ...widget.queuedMessages,
      for (final (:submission, since: _) in widget.awaitingBridgeSubmissions) submission,
    ].any((submission) => !previousPromptIds.contains(submission.promptId));
  }

  /// The rows of sent prompts not yet shown as messages, in order.
  List<String> _pendingPromptRowIdsFor({
    required List<MessageWithParts> messages,
    required QueuedSessionSubmission? localSendSubmission,
    required List<QueuedSessionSubmission> queuedMessages,
    required List<QueuedSessionPrompt> bridgeQueuedPrompts,
    required List<AwaitingBridgeSubmission> awaitingBridgeSubmissions,
    required List<LaunchFollowUp> launchFollowUps,
  }) {
    final deliveredPromptIds = <String>{
      for (final message in messages)
        if (message.hasRenderableUserContent)
          if (message.info case MessageUser(promptId: final promptId?)) promptId,
    };
    final entries = <String>[
      for (final prompt in bridgeQueuedPrompts)
        if (!deliveredPromptIds.contains(prompt.id)) "$_kPromptRowPrefix${prompt.id}",
      for (final (:submission, since: _) in awaitingBridgeSubmissions)
        if (!deliveredPromptIds.contains(submission.promptId)) "$_kPromptRowPrefix${submission.promptId}",
      // Pressed before the session existed, so ahead of this screen's sends.
      for (final LaunchFollowUp(:submission) in launchFollowUps)
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

  /// The pending prompt that wakes the session, if any: one that appears while
  /// the session is idle or has shown nothing since, kept until it shows as a
  /// message or leaves. A prompt sent once the turn is under way is a steer and
  /// waits below the working row.
  String? _wakingPromptRowIdFor({
    required List<String> pendingPromptRowIds,
    required bool quietSinceIdle,
    required bool hasLaunchRow,
  }) {
    final waking = _wakingPromptRowId;
    if (waking != null && pendingPromptRowIds.contains(waking)) return waking;
    // A launch's first message wakes its session, above the working row.
    if (!quietSinceIdle || hasLaunchRow) return null;
    return pendingPromptRowIds.where((rowId) => !_rowIndexById.containsKey(rowId)).firstOrNull;
  }

  void _updatePromptSentAt({
    required List<String> pendingPromptRowIds,
    required Map<String, _TransientSubmission> transientSubmissions,
    required bool listOpening,
  }) {
    _promptSentAt.removeWhere((rowId, _) => !pendingPromptRowIds.contains(rowId));
    for (final followUp in widget.launchFollowUps) {
      if (followUp case QueuedLaunchFollowUp(:final since) || SendingLaunchFollowUp(:final since)) {
        _promptSentAt["$_kPromptRowPrefix${followUp.submission.promptId}"] = since;
      }
    }
    for (final (:submission, :since) in widget.awaitingBridgeSubmissions) {
      if (since != null) _promptSentAt["$_kPromptRowPrefix${submission.promptId}"] = since;
    }
    final now = clock.now();
    for (final rowId in pendingPromptRowIds) {
      final stage = transientSubmissions[rowId]?.stage;
      // A retry is a new send.
      if (stage == _TransientStage.failed) _promptSentAt.remove(rowId);
      if (stage == _TransientStage.failed || _promptSentAt.containsKey(rowId)) continue;
      final sendingHere = stage == _TransientStage.sending || stage == _TransientStage.awaitingBridge;
      _promptSentAt[rowId] = rowId == _launchSlotRowId || (listOpening && !sendingHere) ? widget.launchStartedAt : now;
    }
  }

  List<String> _rowIdsFor({
    required Iterable<String> messageRows,
    required List<String> pendingPromptRowIds,
    required String? wakingPromptRowId,
    required bool hasLaunchRow,
    required bool hasForkedFromRow,
  }) {
    // The prompt that woke the session is answered first, so its working row
    // follows it, as it will follow its message.
    final wakingEnd = wakingPromptRowId == null ? 0 : pendingPromptRowIds.indexOf(wakingPromptRowId) + 1;
    final entries = <String>[
      if (hasForkedFromRow) _kForkedFromRowId,
      ...messageRows,
      // Where the first message's echo lands, above the working row.
      if (hasLaunchRow) _kLaunchRowId,
      ...pendingPromptRowIds.take(wakingEnd),
      _kRetryErrorRowId,
      _kWorkingRowId,
      ...pendingPromptRowIds.skip(wakingEnd),
    ];
    final seenIds = <String>{};
    return [
      for (final entry in entries)
        if (seenIds.add(entry)) entry,
    ];
  }

  /// The rows of [current] that are new since [previous], less those that
  /// take the place of rows that left: between two rows both builds share, as
  /// many new rows as left there replace them, in order.
  static Set<String> _rowsArriving({required List<String> previous, required List<String> current}) {
    final currentIds = current.toSet();
    // The rows that left after each shared row, keyed null before the first.
    final leftAfter = <String?, int>{};
    String? shared;
    for (final rowId in previous) {
      if (currentIds.contains(rowId)) {
        shared = rowId;
      } else {
        leftAfter[shared] = (leftAfter[shared] ?? 0) + 1;
      }
    }
    final previousIds = previous.toSet();
    final arriving = <String>{};
    var leftHere = leftAfter[null] ?? 0;
    for (final rowId in current) {
      if (previousIds.contains(rowId)) {
        leftHere = leftAfter[rowId] ?? 0;
      } else if (leftHere > 0) {
        leftHere--;
      } else {
        arriving.add(rowId);
      }
    }
    return arriving;
  }

  /// [live] with each of the [leaving] rows where it was in [previous]: after
  /// the rows before it there, and before any row new since, so a prompt sent
  /// as an edit arrives below the rows its edit folds away.
  static List<String> _withLeavingRows({
    required List<String> live,
    required List<String> previous,
    required Set<String> leaving,
  }) {
    if (leaving.isEmpty) return live;
    final liveIds = live.toSet();
    final rows = <String>[];
    final placed = <String>{};
    var next = 0;
    for (final rowId in previous) {
      if (leaving.contains(rowId)) {
        if (placed.add(rowId)) rows.add(rowId);
      } else if (liveIds.contains(rowId) && !placed.contains(rowId)) {
        // The live rows up to and including this one.
        while (next < live.length) {
          final candidate = live[next++];
          if (placed.add(candidate)) rows.add(candidate);
          if (candidate == rowId) break;
        }
      }
    }
    for (final candidate in live.skip(next)) {
      if (placed.add(candidate)) rows.add(candidate);
    }
    return rows;
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
    final interruptedTurn = _interruptedTurn = snap?.interruptedTurn ?? widget.interruptedTurn;

    final indexById = _indexByIdFor(messages: messages);
    final transcript = const TranscriptBuilder().build(
      messages: messages,
      streamingText: streamingText,
      children: children,
      childStatuses: childStatuses,
    );
    final turns = _turns = const TranscriptTurnBuilder().build(
      messages: messages,
      hasOlderMessages: widget.onLoadOlderMessages != null,
      turnEndMessageIds: interruptedTurn.turnEndMessageIds,
    );
    _promptIndex = widget.promptIndex ?? _promptIndex;
    // An index that arrives while detached still pins above the frozen messages.
    final promptIndex = snap?.promptIndex ?? _promptIndex;
    final unloadedPin = _unloadedPin = const TranscriptPromptListBuilder().pinAbove(turns: turns, index: promptIndex);
    if (widget.bridgeQueuedPrompts.lastOrNull case final held?) {
      _lastHeldPrompt = (promptId: held.id, acceptedAt: held.createdAt);
    }
    final handoffs = _handoffs = const TranscriptHandoffBuilder().build(
      messages: messages,
      turns: turns,
      isBusy: isBusy,
      queuedPrompts: widget.bridgeQueuedPrompts,
    );
    // A send the bridge accepts while removed rows fold is an edit's, and its
    // turn is starting: its working row rises with its prompt and the fold,
    // not a beat later with the busy status, which would push the rows above
    // back up once the fold ended. Held until the prompt shows as a message.
    _acceptedEditWorks =
        widget.awaitingBridgeSubmissions.isNotEmpty &&
        (_acceptedEditWorks || _removedRowIds.isNotEmpty || _leavingRows.isNotEmpty);
    // A stream that ends while the session still works is often the turn's
    // last word, its idle a moment behind, so the working row does not come
    // back on busy alone until the grace ends. Whatever starts next shows its
    // own row meanwhile as usual.
    final streams = streamingText.isNotEmpty;
    if (!isBusy || _acceptedEditWorks) {
      _streamEndGrace?.cancel();
      _streamEndGrace = null;
    } else if (_streamed && !streams && !_liveRowShown) {
      _streamEndGrace?.cancel();
      _streamEndGrace = Timer(_kStreamEndGrace, () {
        _streamEndGrace = null;
        if (mounted) setState(() {});
      });
    }
    _streamed = streams;
    // A summary being written, or a stopped send still ending, shows its marker
    // in place of the working row.
    final activity = handoffs.showsWork || _streamEndGrace != null
        ? const TranscriptActivityIdle()
        : const TranscriptActivityBuilder().build(
            transcript: transcript,
            messages: messages,
            isBusy: isBusy || _acceptedEditWorks,
            mainAgentRunning: mainAgentRunning,
            retryErrorMessage: retryErrorMessage,
            streamingText: streamingText,
            children: children,
            childStatuses: childStatuses,
            // In the order their rows show.
            pendingPrompts: [
              for (final prompt in widget.bridgeQueuedPrompts) (promptId: prompt.id, acceptedAt: prompt.createdAt),
              for (final (:submission, since: _) in widget.awaitingBridgeSubmissions)
                (promptId: submission.promptId, acceptedAt: null),
              for (final followUp in widget.launchFollowUps)
                if (followUp case SendingLaunchFollowUp(:final submission) || AcceptedLaunchFollowUp(:final submission))
                  (promptId: submission.promptId, acceptedAt: null),
              if (localSendRow case (:final submission, stage: _TransientStage.sending))
                (promptId: submission.promptId, acceptedAt: null),
            ],
            lastHeldPrompt: _lastHeldPrompt,
          );
    final transientSubmissions = <String, _TransientSubmission>{
      for (final (:submission, since: _) in widget.awaitingBridgeSubmissions)
        "$_kPromptRowPrefix${submission.promptId}": (submission: submission, stage: _TransientStage.awaitingBridge),
      if (localSendRow case (:final submission, :final stage))
        "$_kPromptRowPrefix${submission.promptId}": (submission: submission, stage: stage),
      for (final submission in queuedMessages)
        "$_kPromptRowPrefix${submission.promptId}": (submission: submission, stage: _TransientStage.pending),
    };

    final pendingPromptRowIds = _pendingPromptRowIdsFor(
      messages: messages,
      localSendSubmission: localSendRow?.submission,
      queuedMessages: queuedMessages,
      bridgeQueuedPrompts: widget.bridgeQueuedPrompts,
      awaitingBridgeSubmissions: widget.awaitingBridgeSubmissions,
      launchFollowUps: widget.launchFollowUps,
    );
    final hasLaunchRow = widget.launchHandoff != null;
    // Live, like the prompt rows, even while the reader is detached.
    final newestMessageId = widget.messages.lastOrNull?.info.id;
    final quietSinceIdle = _quietSinceIdle =
        (!widget.isBusy && !widget.mainAgentRunning) || (_quietSinceIdle && newestMessageId == _newestMessageId);
    _newestMessageId = newestMessageId;
    final wakingPromptRowId = _wakingPromptRowId = _wakingPromptRowIdFor(
      pendingPromptRowIds: pendingPromptRowIds,
      quietSinceIdle: quietSinceIdle,
      hasLaunchRow: hasLaunchRow,
    );
    final liveRowIds = _rowIdsFor(
      messageRows: [
        for (final message in messages)
          if (message.hasRenderableUserContent && !handoffs.foldedMessageIds.contains(message.info.id))
            _entryIdForMessage(info: message.info),
      ],
      pendingPromptRowIds: pendingPromptRowIds,
      wakingPromptRowId: wakingPromptRowId,
      hasLaunchRow: hasLaunchRow,
      // Above the oldest message, so only once no older page is left.
      hasForkedFromRow: widget.forkedFrom != null && widget.onLoadOlderMessages == null,
    );
    final previousRowIndexById = _rowIndexById;
    final previousRowIds = previousRowIndexById.keys.toList();
    // A removed message's row folds away where it was, if the reader could
    // see it; one not built goes at once, as nobody sees it go. A row whose
    // message comes back stays.
    final liveRowIdSet = liveRowIds.toSet();
    _leavingRows.removeWhere((rowId, _) => liveRowIdSet.contains(rowId) || !previousRowIndexById.containsKey(rowId));
    final newlyLeaving = <String>{};
    if (!context.isReducedMotion) {
      for (final rowId in _removedRowIds) {
        if (_builtRows[rowId] case final row? when !liveRowIdSet.contains(rowId)) {
          _leavingRows[rowId] = row;
          newlyLeaving.add(rowId);
        }
      }
    }
    _removedRowIds = const {};
    final rowIds = _withLeavingRows(live: liveRowIds, previous: previousRowIds, leaving: _leavingRows.keys.toSet());
    _waitForReplacements(
      newlyLeaving: newlyLeaving,
      rowsJoined:
          (activity is! TranscriptActivityIdle && !_liveRowShown) ||
          rowIds.any((rowId) => !previousRowIndexById.containsKey(rowId)),
      following: snap == null,
    );
    _liveRowShown = activity is! TranscriptActivityIdle;
    final knownRowIds = _knownRowIds;
    if (knownRowIds != null && knownRowIds.contains(_kLaunchRowId) && !rowIds.contains(_kLaunchRowId)) {
      _launchSlotRowId = rowIds
          .where(
            (rowId) =>
                !knownRowIds.contains(rowId) && _isUserRow(rowId: rowId, messages: messages, indexById: indexById),
          )
          .firstOrNull;
    }
    _updatePromptSentAt(
      pendingPromptRowIds: pendingPromptRowIds,
      transientSubmissions: transientSubmissions,
      listOpening: previousRowIds.isEmpty,
    );
    _knownRowIds = rowIds.toSet();
    _easedInRowIds.retainAll(rowIds);
    if (previousRowIds.isEmpty) _easedInRowIds.addAll(rowIds);
    _rowIndexById = {for (final (index, rowId) in rowIds.indexed) rowId: index};
    _userMessagesById = {
      for (final message in messages)
        if (message.info is MessageUser &&
            message.hasRenderableUserContent &&
            !handoffs.markers.containsKey(message.info.id) &&
            !handoffs.cards.containsKey(message.info.id))
          message.info.id: message,
    };
    // Rows ease in, prompts as much as replies, so that the list rises for a
    // send instead of jumping. Not rows held still while scrolled away, nor those
    // found on returning from there, and a row that takes the place of one that
    // just left is that row re-keyed, as when a refresh swaps a live row for its
    // history twin. The row of a send on its way eases in whenever it is first
    // built, wherever the reader is: a glide back to the latest edge reaches it
    // some frames on, and at full height it would throw the list forward then.
    // The first rows of a list show at once, having nothing to move.
    final enteringRowIds = context.isReducedMotion || previousRowIds.isEmpty
        ? const <String>{}
        : {
            ...transientSubmissions.keys,
            if (knownRowIds != null && snap == null) ..._rowsArriving(previous: previousRowIds, current: rowIds),
          };
    // Coalesced post-frame pin-to-edge while following. The scheduler
    // collapses repeated calls within a frame and the jump is skipped
    // when `position.pixels` is already at the edge.
    _follow.scheduleJumpToEdge();

    return FollowDetachScrollable(
      tracker: _follow,
      detachedOverlayBuilder: _heldByMenu
          ? null
          : (ctx) => Builder(
              builder: (context) => JumpToEdgePill(
                tapTargetKey: _kJumpToLatestKey,
                label: loc.sessionDetailJumpToLatest,
                onTap: () => _follow.animateToEdge(),
                // Lift the pill clear of the floating composer overlaid below.
                bottomInset: TranscriptBottomInset.of(context),
              ),
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
        pinch: TranscriptPinchIn(
          onPointerDown: _onPinchPointerDown,
          onPinchStart: _onPinchStart,
          onPinchIn: widget.onPinchIn,
          onGestureEnd: _onPinchGestureEnd,
        ),
        child: NotificationListener<Notification>(
          onNotification: (notification) => switch (notification) {
            final TranscriptMessageMenuOpened menu => _onMessageMenuOpened(menu),
            _ => _onScrollNotification(notification),
          },
          // One selection across the messages, so a drag runs from one into
          // the next; each row keeps all but its messages' text out of it.
          // Around the peek, so a finger's horizontal drag peeks rather than
          // the selection's, which only a double-tap drag uses.
          child: PregoReadableSelectionArea(
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
                  PregoNestedSelectionHighlight(
                    moved: _rowsMoved,
                    child: TranscriptLaidOutListView(
                      key: _kListViewKey,
                      onLaidOut: _onRowsLaidOut,
                      detached: () => !_follow.following,
                      rowsLeaving: () => _leavingRows.isNotEmpty,
                      onCarriedToNewestEnd: _follow.reattach,
                      reverse: true,
                      controller: _follow.scrollController,
                      padding: EdgeInsetsDirectional.only(
                        start: widget.horizontalInset,
                        end: widget.horizontalInset,
                        top: 8 + widget.topInset,
                        // The list view adds the floating controls' height itself.
                        bottom: 8,
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
                        final leavingRow = _leavingRows[entryId];
                        final row = _builtRows[entryId] =
                            leavingRow ??
                            _buildRow(
                              entryId: entryId,
                              messages: messages,
                              indexById: indexById,
                              transientSubmissions: transientSubmissions,
                              transcript: transcript,
                              streamingText: streamingText,
                              retryErrorMessage: retryErrorMessage,
                              activity: activity,
                            );
                        return TranscriptRowReporter(
                          key: ValueKey(entryId == _launchSlotRowId ? _kLaunchRowId : entryId),
                          rowId: entryId,
                          onMount: _onRowMount,
                          onUnmount: _onRowUnmount,
                          child: PregoSelectionOnlyInNestedAreas(
                            child: SentBubbleArrival(
                              // Not the old rows a glide back to the latest edge builds on its way.
                              arriving: !previousRowIndexById.containsKey(entryId),
                              child: TranscriptPresence(
                                entering: enteringRowIds.contains(entryId) && !_easedInRowIds.contains(entryId),
                                exiting: leavingRow != null && !_waitingRowIds.contains(entryId),
                                onEntered: () => _easedInRowIds.add(entryId),
                                onExited: () => _onRowLeft(rowId: entryId),
                                child: row,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    // The copies' code blocks scroll sideways; the list must not
                    // read their scrolls as its own.
                    child: SelectionContainer.disabled(
                      // The pins select on their own, apart from the rows they copy.
                      child: NotificationListener<Notification>(
                        onNotification: (notification) =>
                            notification is ScrollNotification || notification is ScrollMetricsNotification,
                        child: ValueListenableBuilder(
                          valueListenable: _stickyOpenerIds,
                          builder: (context, openerIds, _) => TranscriptStickyPromptOverlay(
                            key: _stickyKey,
                            messages: [for (final openerId in openerIds) ?_userMessagesById[openerId]],
                            // The rows' own shapes, frozen with them while detached, so a pin never disagrees with its row.
                            promptTurnShapes: switch (snap) {
                              final frozen? => widget.promptTurnShapes.copyWith(messages: frozen.messageShapes),
                              null => widget.promptTurnShapes,
                            },
                            unloaded: unloadedPin,
                            horizontalInset: widget.horizontalInset,
                            onLayout: _layOutSticky,
                            onTap: _onPinTap,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Beside the pin, clear of its bubble, which keeps to the right, or
                  // of its card, which keeps to the left.
                  if (_pinLoad case final pinLoad?)
                    Positioned(
                      left: pinLoad.invocation == null ? widget.horizontalInset + UserMessageBubble.margin.left : null,
                      right: pinLoad.invocation == null
                          ? null
                          : widget.horizontalInset + UserMessageBubble.margin.right,
                      top: widget.topInset + _kPinGap + UserMessageBubble.padding,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _showsPinLoadSpinner ? 1 : 0,
                          duration: transcriptMotionDuration,
                          child: Semantics(
                            liveRegion: _showsPinLoadSpinner,
                            label: _showsPinLoadSpinner ? loc.transcriptPromptsLoading : null,
                            child: const SizedBox.square(dimension: 16, child: PregoActivityIndicator(color: null)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
    if ((entryId, widget.forkedFrom) case (_kForkedFromRowId, final origin?)) {
      return _revealable(
        createdAtMs: null,
        child: ForkedFromRow(origin: origin, onOpenOrigin: widget.onOpenForkOrigin),
      );
    }
    if (entryId == _kWorkingRowId) {
      return _revealable(
        createdAtMs: null,
        child: _workingRow(
          activity: activity,
          // Below the waking prompt, the next step follows its message and so
          // opens a card of its own.
          stepJoinsShownCard:
              _wakingPromptRowId == null && _stepJoinsShownCard(messages: messages, transcript: transcript),
        ),
      );
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
          deliveredMessageId: null,
          child: QueuedMessageBubble(
            body: null,
            displayText: submission.displayText,
            isCommand: submission is NewSessionCommandSubmissionSnapshot,
            shape: widget.promptTurnShapes.launch,
            attachmentCount: attachments.length,
            localAttachments: attachments,
            presentation: QueuedMessageBubblePresentation.sending(
              harnessName: PregoBrandLogo.displayNameFor(pluginId),
              sendingSince: startedAt,
              reservesLine: true,
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
          child: _handoffRow(message: message) ?? _deliveredPromptRow(message: message),
        );
      }
      final promptId = entryId.substring(_kPromptRowPrefix.length);
      final prompt = widget.bridgeQueuedPrompts.where((candidate) => candidate.id == promptId).firstOrNull;
      if (prompt != null) {
        // A handoff shows as it will once delivered, in the same row. The source's
        // marker offers no Cancel, as the source must be idle to hand off; the
        // target's card waits under the same status line a message would.
        if (_handoffs.queuedMarkers[prompt.id] case final marker?) {
          return _revealable(
            createdAtMs: prompt.createdAt,
            child: _endingInterruptedTurn(messageId: null, child: HandoffMarkerRow(marker: marker)),
          );
        }
        final card = _handoffs.queuedCards[prompt.id];
        final onCancel = widget.onCancelBridgeQueuedPrompt;
        return _revealable(
          createdAtMs: prompt.createdAt,
          child: _animatedPromptRow(
            deliveredMessageId: null,
            child: QueuedMessageBubble(
              body: card == null ? null : HandoffCard(card: card),
              displayText: _bridgePromptDisplayText(prompt),
              isCommand: prompt.command != null,
              shape: widget.promptTurnShapes.ofPrompt(promptId: prompt.id),
              attachmentCount: prompt.attachmentCount,
              localAttachments: widget.bridgePromptAttachments[prompt.id] ?? const [],
              presentation: switch (prompt.dispatchState) {
                QueuedPromptDispatchState.dispatched => QueuedMessageBubblePresentation.sending(
                  harnessName: widget.harnessName,
                  sendingSince: _promptSentAt[entryId],
                  // The launch's first message keeps the room its bubble had.
                  reservesLine: entryId == _launchSlotRowId,
                ),
                QueuedPromptDispatchState.queued || QueuedPromptDispatchState.unknown =>
                  onCancel == null
                      ? QueuedMessageBubblePresentation.pendingReadOnly(sentAt: _promptSentAt[entryId])
                      : QueuedMessageBubblePresentation.pending(
                          onCancel: () => onCancel(prompt.id),
                          sentAt: _promptSentAt[entryId],
                        ),
              },
            ),
          ),
        );
      }
    }
    final launchFollowUp = widget.launchFollowUps
        .where((followUp) => "$_kPromptRowPrefix${followUp.submission.promptId}" == entryId)
        .firstOrNull;
    if (launchFollowUp != null) {
      final submission = launchFollowUp.submission;
      return _revealable(
        createdAtMs: null,
        child: _animatedPromptRow(
          deliveredMessageId: null,
          child: QueuedMessageBubble(
            body: null,
            displayText: submission.displayText,
            isCommand: submission.isCommand,
            shape: widget.promptTurnShapes.ofPrompt(promptId: submission.promptId),
            attachmentCount: submission.attachments.length,
            localAttachments: submission.attachments,
            presentation: launchFollowUpPresentation(
              followUp: launchFollowUp,
              loc: context.loc,
              harnessName: widget.harnessName,
              onRetry: widget.onRetryLaunchFollowUp,
              onRemove: widget.onRemoveLaunchFollowUp,
            ),
          ),
        ),
      );
    }
    final transientSubmission = transientSubmissions[entryId];
    if (transientSubmission != null) {
      final submission = transientSubmission.submission;
      final onCancelQueuedMessage = widget.onCancelQueuedMessage;
      return _revealable(
        createdAtMs: null,
        child: _animatedPromptRow(
          deliveredMessageId: null,
          child: QueuedMessageBubble(
            body: null,
            displayText: submission.displayText,
            isCommand: submission.isCommand,
            shape: widget.promptTurnShapes.ofPrompt(promptId: submission.promptId),
            attachmentCount: submission.attachments.length,
            localAttachments: submission.attachments,
            presentation: switch (transientSubmission.stage) {
              _TransientStage.sending => QueuedMessageBubblePresentation.sending(
                harnessName: widget.harnessName,
                sendingSince: _promptSentAt[entryId],
                reservesLine: false,
              ),
              _TransientStage.failed => QueuedMessageBubblePresentation.failed(
                reason: switch (widget.localSend) {
                  LocalSendFailed(failure: RejectedPromptSend(:final reason)) => reason,
                  LocalSendFailed(failure: ModelUnavailablePromptSend()) =>
                    context.loc.sessionDetailSendFailedModelUnavailable,
                  LocalSendIdle() || LocalSendSending() || LocalSendFailed() => null,
                },
                onRetry: widget.onRetryFailedSend,
                onRemove: widget.onRemoveFailedSend,
              ),
              // Accepted but not yet listed, so nothing says it is queued.
              _TransientStage.awaitingBridge => QueuedMessageBubblePresentation.sending(
                harnessName: widget.harnessName,
                sendingSince: _promptSentAt[entryId],
                reservesLine: false,
              ),
              _TransientStage.pending when submission is UnavailableQueuedCommandSubmission =>
                QueuedMessageBubblePresentation.commandUnavailable(
                  onRemove: onCancelQueuedMessage == null
                      ? null
                      : () => _cancelQueuedSubmission(submission: submission),
                ),
              _TransientStage.pending =>
                onCancelQueuedMessage == null
                    ? QueuedMessageBubblePresentation.pendingReadOnly(sentAt: _promptSentAt[entryId])
                    : QueuedMessageBubblePresentation.pending(
                        onCancel: () => _cancelQueuedSubmission(submission: submission),
                        sentAt: _promptSentAt[entryId],
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
    final createdAtMs = message.info.time?.created;
    if (_handoffRow(message: message) case final handoff?) return _revealable(createdAtMs: createdAtMs, child: handoff);
    final card = switch (message.info) {
      // The launch bubble's echo keeps easing like the bubble it replaced.
      MessageUser() when entryId == _launchSlotRowId => _deliveredPromptRow(message: message),
      MessageUser(:final id) => _endingInterruptedTurn(
        messageId: id,
        child: _userMessage(message: message, outlineFade: null),
      ),
      MessageAssistant(sender: MessageSender.agent, :final id) => _agentRow(
        messageId: id,
        isError: false,
        blocks: transcript.blocksFor(messageId: id),
        streamingText: streamingText,
        createdAtMs: createdAtMs,
        end: null,
      ),
      MessageAssistant(:final id, :final sender) => _endingInterruptedTurn(
        messageId: id,
        child: SystemMessageCard(
          tagIcon: switch (sender) {
            MessageSender.sesori => TablerRegular.bell,
            MessageSender.agent || MessageSender.system || MessageSender.unknown => TablerRegular.robot,
          },
          tagLabel: switch (sender) {
            MessageSender.sesori => context.loc.sessionDetailSesoriAutomation,
            MessageSender.agent || MessageSender.system || MessageSender.unknown => context.loc.sessionDetailAutomation,
          },
          projectId: widget.projectId,
          blocks: transcript.blocksFor(messageId: id),
          streamingText: streamingText,
          createdAtMs: createdAtMs,
          // A notice about an agent's page reopens it; the page's lookup says
          // whether it is still there. The notice sits on the session the page
          // shows on, which the lookup accepts.
          onTap: switch (message.parts.whereType<MessagePartText>().map((p) => p.noticePageRequestId).nonNulls.firstOrNull) {
            final requestId? => () => unawaited(
              SessionDetailPresentationScope.read(
                context,
              ).openPage(context: context, requestId: requestId, sessionId: message.info.sessionID),
            ),
            _ => null,
          },
        ),
      ),
      final MessageError error => _agentRow(
        messageId: error.id,
        isError: true,
        blocks: transcript.blocksFor(messageId: error.id),
        streamingText: streamingText,
        createdAtMs: createdAtMs,
        // The Interrupted line ends the turn in place of its Stopped line.
        end: switch (_interruptedTurn) {
          InterruptedTurnShown(:final supersededStoppedIds) when supersededStoppedIds.contains(error.id) => null,
          InterruptedTurnShown() || InterruptedTurnAbsent() => error,
        },
      ),
    };
    return _revealable(createdAtMs: createdAtMs, child: card);
  }

  /// An agent reply's row: what it streamed, then, once the turn stopped or
  /// failed, the [end] row under it, and the Interrupted line when a bridge
  /// stop cut the turn off here. A reply keeps its row when its turn ends, so
  /// the end row grows in under it as the working row folds away.
  ///
  /// [end] is null for a reply, and for an error row whose Stopped line the
  /// Interrupted line replaces, which then shows only what it streamed.
  Widget _agentRow({
    required String messageId,
    required bool isError,
    required List<TranscriptBlock> blocks,
    required Map<String, String> streamingText,
    required int? createdAtMs,
    required MessageError? end,
  }) {
    final showsReply = blocks.isNotEmpty || !isError;
    return TranscriptPresenceColumn(
      children: [
        if (showsReply)
          SizedBox(
            key: const ValueKey("reply"),
            width: double.infinity,
            child: _agentReply(
              messageId: messageId,
              blocks: blocks,
              streamingText: streamingText,
              createdAtMs: createdAtMs,
            ),
          ),
        if (end != null)
          SizedBox(
            key: const ValueKey("end"),
            width: double.infinity,
            child: ErrorMessageCard(message: end, followsReply: showsReply),
          ),
        ?_interruptedLine(messageId: messageId, followsReply: showsReply && end == null),
      ],
    );
  }

  /// [child], the row of message [messageId], with the Interrupted line under
  /// it when a bridge stop cut the turn off after it. The row keeps one shape
  /// with or without the line, so it keeps its state when the line arrives.
  /// [messageId] is null for a prompt not delivered yet, which ends no turn.
  Widget _endingInterruptedTurn({required String? messageId, required Widget child}) => TranscriptPresenceColumn(
    children: [
      KeyedSubtree(key: const ValueKey("message"), child: child),
      ?_interruptedLine(messageId: messageId, followsReply: false),
    ],
  );

  /// The Interrupted line, when the turn a bridge stop cut off ends with
  /// message [messageId]. It offers Continue only while the turn can be picked
  /// up and this surface can send.
  Widget? _interruptedLine({required String? messageId, required bool followsReply}) {
    if (_interruptedTurn case InterruptedTurnShown(:final lineAfterMessageId, :final continueRefusal)
        when lineAfterMessageId == messageId) {
      final onContinue = widget.onContinueInterruptedTurn;
      final locked = continueRefusal?.locksContinue ?? false;
      return SizedBox(
        key: const ValueKey("interrupted"),
        width: double.infinity,
        child: InterruptedTurnLine(
          followsReply: followsReply,
          onContinue: onContinue == null || (continueRefusal != null && !locked)
              ? null
              : () => _continue(onContinue: onContinue),
          continueLocked: locked,
        ),
      );
    }
    return null;
  }

  /// Continues the interrupted turn, or says why it can't: an edit holds a
  /// locked Continue, and a tap on one folding away, or on a line frozen
  /// while the reader is detached, finds the turn already moved on. A reader
  /// who is detached is taken to the newest rows, which show where it went.
  Future<void> _continue({required Future<InterruptedTurnContinueRefusal?> Function() onContinue}) async {
    final refusal = await onContinue();
    if (refusal == null || !mounted) return;
    final loc = context.loc;
    PregoPopupAlertPresenter.of(context).show(
      title: switch (refusal) {
        InterruptedTurnContinueRefusal.editOpen => loc.sessionDetailContinueEditOpen,
        InterruptedTurnContinueRefusal.editSending => loc.sessionDetailEditSendingLock,
        InterruptedTurnContinueRefusal.sessionWorking => loc.sessionDetailContinueSessionWorking,
        InterruptedTurnContinueRefusal.promptPending => loc.sessionDetailContinuePromptPending,
        InterruptedTurnContinueRefusal.laterTurn ||
        InterruptedTurnContinueRefusal.noInterruptedTurn => loc.sessionDetailContinueAlreadyContinued,
      },
      variant: PregoPopupAlertsNotificationsVariant.warning,
      duration: PregoPopupAlertPresenter.defaultDuration,
    );
    if (!refusal.locksContinue && !_follow.following) await _follow.animateToEdge();
  }

  /// An agent reply's card, with its message menu.
  Widget _agentReply({
    required String messageId,
    required List<TranscriptBlock> blocks,
    required Map<String, String> streamingText,
    required int? createdAtMs,
  }) => TranscriptMessageMenu(
    spotlight: PregoMenuSpotlight.listRow,
    copyText: AssistantMessageCard.markdownOf(blocks: blocks, streamingText: streamingText),
    actions: [
      if ((widget.onForkMessage, _turns.replyForkPoint(messageId: messageId, working: widget.isBusy)) case (
        final onFork?,
        final point?,
      ))
        forkFromHereMenuItem(
          context: context,
          onTap: () => onFork(point: point, ownMessage: null),
        ),
    ],
    builder: (context, selectionArea) => AssistantMessageCard(
      projectId: widget.projectId,
      blocks: blocks,
      streamingText: streamingText,
      createdAtMs: createdAtMs,
      contentPadding: _kReplyPadding,
      selectionArea: selectionArea,
      showsLoneStep: false,
    ),
  );

  /// A user message's bubble, registered where it is so its pin can stand in
  /// for it.
  Widget _userMessage({required MessageWithParts message, required Duration? outlineFade}) {
    final onFork = switch ((
      widget.onForkMessage,
      _turns.userMessageForkPoint(messageId: message.info.id, working: widget.isBusy),
    )) {
      (final onFork?, final point?) => () => onFork(point: point, ownMessage: message),
      _ => null,
    };
    return TranscriptPromptSlot(
      openerId: message.info.id,
      registry: _promptSlots,
      child: UserMessageCard(
        message: message,
        shape: _messageShape(messageId: message.info.id),
        outlineFade: outlineFade,
        editing: widget.editingMessageId == message.info.id,
        onEdit: switch (widget.onEditMessage) {
          null => null,
          // The running turn offers no edit until it finishes, and the message
          // being edited none over the changes the composer holds.
          _ when widget.editingMessageId == message.info.id => null,
          _ when widget.isBusy && _turns.inNewestTurn(messageId: message.info.id) => null,
          final onEdit => () => onEdit(
            message: message,
            refusal: _turns.editRefusal(
              messageId: message.info.id,
              shape: _messageShape(messageId: message.info.id),
            ),
            onFork: onFork,
          ),
        },
        onFork: onFork,
      ),
    );
  }

  /// A handoff's marker or card in place of its prompt's bubble, or null for
  /// any other prompt. The card carries on from the queued card's row, so the
  /// status line it waited under sees out its fade.
  Widget? _handoffRow({required MessageWithParts message}) {
    final id = message.info.id;
    if (_handoffs.markers[id] case final marker?) {
      return _endingInterruptedTurn(
        messageId: id,
        child: HandoffMarkerRow(marker: marker),
      );
    }
    if (_handoffs.cards[id] case final card?) {
      return _animatedPromptRow(
        deliveredMessageId: id,
        child: QueuedMessageBubble(
          body: null,
          displayText: null,
          isCommand: false,
          shape: _messageShape(messageId: id),
          attachmentCount: 0,
          localAttachments: const [],
          presentation: QueuedMessageBubblePresentation.delivered(
            message: ({required outlineFade}) => HandoffCard(card: card),
          ),
        ),
      );
    }
    return null;
  }

  /// A delivered prompt's row. It carries on from the bubble that waited, the row's
  /// key keeping them one, so a line that showed sees out its fade, and a row built
  /// later has none to replay.
  Widget _deliveredPromptRow({required MessageWithParts message}) => _animatedPromptRow(
    deliveredMessageId: message.info.id,
    child: QueuedMessageBubble(
      body: null,
      displayText: null,
      isCommand: false,
      shape: _messageShape(messageId: message.info.id),
      attachmentCount: 0,
      localAttachments: const [],
      presentation: QueuedMessageBubblePresentation.delivered(
        message: ({required outlineFade}) => _userMessage(message: message, outlineFade: outlineFade),
      ),
    ),
  );

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
  ///
  /// Every state of the row keeps one shape, so the bubble that waited and its
  /// delivered message stay one element; [deliveredMessageId] is the delivered
  /// message, which may end an interrupted turn, or null before delivery.
  Widget _animatedPromptRow({required String? deliveredMessageId, required Widget child}) => _endingInterruptedTurn(
    messageId: deliveredMessageId,
    // No wrapper at all under reduced motion: a zero-duration AnimatedSize
    // re-dirties itself inside its own layout pass.
    child: context.isReducedMotion
        ? child
        : AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: AlignmentDirectional.topEnd,
            child: child,
          ),
  );

  /// The working row eases in when work starts or a step ends, and away when
  /// a step starts or work ends. The sub-agent row takes over, easing, while
  /// only sub-agents work.
  Widget _workingRow({required TranscriptActivity activity, required bool stepJoinsShownCard}) =>
      TranscriptPresenceColumn(
        children: [
          ?switch (activity) {
            TranscriptActivityWorking(:final sinceMs) => TranscriptWorkingRow(
              key: const ValueKey("session-detail-working"),
              sinceMs: sinceMs,
              // A step that opens a card of its own brings the card's padding.
              padding: stepJoinsShownCard ? _kReplyPadding.copyWith(top: 0, bottom: 0) : _kReplyPadding,
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

  /// Whether the next step lands in an agent reply card that already shows,
  /// and so already carries the reply padding: it joins the open group, or
  /// follows the newest message when that is a shown agent reply. Otherwise
  /// it opens a card of its own.
  static bool _stepJoinsShownCard({required List<MessageWithParts> messages, required Transcript transcript}) =>
      transcript.endsInOpenGroup ||
      switch (messages.lastOrNull?.info) {
        MessageAssistant(sender: MessageSender.agent, :final id) ||
        MessageError(:final id) => transcript.blocksFor(messageId: id).isNotEmpty,
        MessageUser() || MessageAssistant() || null => false,
      };

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

  /// Holds the transcript while a message's menu is open, as a detached list
  /// holds it: a reply streaming in at the newest edge would otherwise grow the
  /// spotlit message past its cut-out and carry it out from under the menu.
  bool _onMessageMenuOpened(TranscriptMessageMenuOpened notification) {
    if (!_follow.following) return true;
    _heldByMenu = true;
    _follow.detach();
    unawaited(
      notification.closed.then((_) {
        if (!mounted || !_heldByMenu) return;
        _heldByMenu = false;
        _follow.reattach();
      }),
    );
    return true;
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
