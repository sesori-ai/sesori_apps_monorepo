import "dart:async";
import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "sent_bubble_landing.dart";
import "session_auto_continuation_notice.dart";
import "session_detail_message_list.dart";
import "session_detail_scaffold_sections.dart";
import "transcript_jump_notifier.dart";
import "transcript_laid_out_list_view.dart";
import "transcript_motion.dart";

typedef SessionDetailBottomControlsBuilder = Widget Function({
  required BuildContext context,
  required String projectId,
  required String sessionId,
  required SessionComposerSource source,
});

/// What the session composer is built from.
sealed class const SessionComposerSource();

/// The loaded session.
final class const LoadedSessionComposerSource({required final SessionDetailLoaded state}) extends SessionComposerSource;

/// The composer the session's launch handed over, while the first load runs:
/// it shows the options the launch committed and holds what was unsent.
final class const LaunchSessionComposerSource({
  required final SessionLaunchComposer composer,
  required final CommandInfo? stagedCommand,
}) extends SessionComposerSource;

/// The widths of the two centred columns a pointer surface reads a session in.
/// They are separate design constants rather than one number: body text carries
/// a longer measure comfortably, while a text field and its pill row look
/// stretched well before it does. Both are always known together, so the pair
/// travels as one value.
final class const SessionDetailColumnWidths({
  /// Caps the transcript's reading column.
  required final double transcript,

  /// Caps the floating bottom controls — the needs-you cards, the composer and
  /// its pills.
  required final double composer,
});

/// The pending-request sheet open over the session. Its card steps aside while
/// the sheet rises, so the transcript has already settled when the sheet
/// closes.
enum OpenRequestSheet() {
  question,
  permission,
}

class SessionDetailLoadedView extends StatelessWidget {
  final String? projectId;
  final String sessionId;
  final SessionDetailLoaded state;
  final bool readOnly;
  final Widget? bottomControls;

  /// Centres the transcript and the bottom controls in their own columns; null
  /// lets both span the pane, as the phone does.
  final SessionDetailColumnWidths? columnWidths;
  final VoidCallback onShowPendingQuestions;
  final VoidCallback onShowPendingPermissions;

  /// The request sheet open over this page, if any.
  final OpenRequestSheet? openRequestSheet;

  /// Forwarded to the transcript: see [SessionDetailMessageList.currentPromptId],
  /// [SessionDetailMessageList.jumpNotifier] and [SessionDetailMessageList.onPinchIn].
  final ValueNotifier<String?> currentPromptId;
  final TranscriptJumpNotifier jumpNotifier;
  final void Function({required Offset focalPoint}) onPinchIn;

  const new readOnly({
    super.key,
    required this.projectId,
    required this.sessionId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
    required this.openRequestSheet,
    required this.bottomControls,
    required this.columnWidths,
    required this.currentPromptId,
    required this.jumpNotifier,
    required this.onPinchIn,
  }) : readOnly = true;

  const new interactive({
    super.key,
    required this.projectId,
    required this.sessionId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
    required this.openRequestSheet,
    required this.bottomControls,
    required this.columnWidths,
    required this.currentPromptId,
    required this.jumpNotifier,
    required this.onPinchIn,
  }) : readOnly = false;

  @override
  Widget build(BuildContext context) {
    final columnWidths = this.columnWidths;
    if (columnWidths == null) return _buildContent(context: context, transcriptInset: 0, composerInset: 0);
    return LayoutBuilder(
      builder: (context, constraints) => _buildContent(
        context: context,
        transcriptInset: math.max(0, (constraints.maxWidth - columnWidths.transcript) / 2),
        composerInset: math.max(0, (constraints.maxWidth - columnWidths.composer) / 2),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required double transcriptInset,
    required double composerInset,
  }) {
    final loc = context.loc;
    final showEmptyState =
        !_isBusy(state: state) &&
        !state.hasRenderableMessages &&
        state.retryErrorMessage == null &&
        state.olderMessagesCursor == null &&
        !state.isLoadingOlderMessages &&
        state.localSend is LocalSendIdle &&
        state.queuedMessages.isEmpty &&
        state.awaitingBridgeSubmissions.isEmpty &&
        state.launchFollowUps.isEmpty &&
        state.bridgeQueuedPrompts.isEmpty &&
        state.launchHandoff == null;
    final questionCount = state.pendingQuestions.fold<int>(0, (sum, q) => sum + q.questions.length);
    final hasTypedRequest = state.pendingQuestions.any((q) => q.interactionKind != QuestionInteractionKind.question);
    // An archived session's requests can never be answered.
    final canAnswer = !readOnly && !state.isArchived && state.interaction.canInteract;
    final showsQuestionCard = canAnswer && openRequestSheet != OpenRequestSheet.question;
    final needsYou = [
      if (state.pendingQuestions.firstOrNull?.questions.firstOrNull case final question? when showsQuestionCard)
        SessionDetailNeedsYouCard(
          key: const ValueKey("needs-you-question"),
          icon: TablerRegular.help,
          label: hasTypedRequest
              ? (state.pendingQuestions.length == 1
                    ? loc.pendingRequestBannerSingle
                    : loc.pendingRequestBannerMultiple(state.pendingQuestions.length))
              : (questionCount == 1 ? loc.questionBannerSingle : loc.questionBannerMultiple(questionCount)),
          request: _firstLine(question.question),
          action: hasTypedRequest ? loc.needsYouReview : loc.needsYouAnswer,
          leads: true,
          onPressed: onShowPendingQuestions,
        ),
      if (state.pendingPermissions.firstOrNull case final permission?
          when canAnswer && openRequestSheet != OpenRequestSheet.permission)
        SessionDetailNeedsYouCard(
          key: const ValueKey("needs-you-permission"),
          icon: TablerRegular.shield,
          label: state.pendingPermissions.length == 1
              ? loc.permissionBannerSingle
              : loc.permissionBannerMultiple(state.pendingPermissions.length),
          request: _firstLine(permission.description),
          action: loc.needsYouReview,
          leads: !showsQuestionCard || state.pendingQuestions.firstOrNull?.questions.firstOrNull == null,
          onPressed: onShowPendingPermissions,
        ),
    ];
    final hasBottomControls = needsYou.isNotEmpty || bottomControls != null;

    // The scaffold lets this view fill the full height behind the transparent
    // bar (reserveBarSpace: false), so the message list scrolls behind it like
    // every other screen. The chat's content inset — and the pinned refresh
    // indicator and archived notice — come from PregoTopBarInsetBuilder so
    // they clear the bar at rest and ride the top-nav connection banner's height
    // animation frame-by-frame.
    //
    // Built once per state, so the controls growing or folding moves the
    // transcript through its inset alone, without rebuilding its rows.
    final content = Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: showEmptyState
                  ? Center(child: Text(loc.sessionDetailEmpty))
                  : PregoTopBarInsetBuilder(
                      builder: (context, topInset, _) => _TranscriptHeldWhileRequestSettles(
                        state: state,
                        builder: (state) => _buildTranscript(
                          context: context,
                          state: state,
                          topInset: topInset,
                          transcriptInset: transcriptInset,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        // The refresh indicator and archived notice pin just below the
        // transparent bar, floating over the chat that scrolls behind them —
        // rather than pushing the chat down out of the behind-bar region. The
        // cluster itself is inset-independent, so it rides through as `child`
        // and only the Positioned offset follows the banner animation.
        PregoTopBarInsetBuilder(
          builder: (context, topInset, child) => Positioned(
            top: topInset,
            left: 0,
            right: 0,
            child: child ?? const SizedBox.shrink(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isRefreshing) const LinearProgressIndicator(),
              // Archiving is permanent, so this session is audit-only: say so
              // where the composer used to be.
              if (state.isArchived) const SessionDetailArchivedNotice(),
              // The harness can no longer restore this session; its stored
              // history stays readable beneath this floating layer, which
              // fades rather than moving the transcript.
              AnimatedSwitcher(
                duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: switch (state.cannotContinueMessage) {
                  final message? => SessionDetailCannotContinueNotice(message: message),
                  null => const SizedBox.shrink(),
                },
              ),
            ],
          ),
        ),
      ],
    );
    return PregoFloatingBottomControlsLayout(
      contentBuilder: (context, bottomControlsHeight) =>
          TranscriptBottomInset(inset: bottomControlsHeight, child: content),
      // Floating bottom controls: the needs-you cards docked above the
      // background-tasks bar and composer. Queued submissions are regular
      // rows in the transcript above them. Every control's halo paints in
      // one layer beneath them all, fading the transcript passing under it.
      controls: hasBottomControls
          ? Padding(
              padding: EdgeInsets.symmetric(horizontal: composerInset),
              child: PregoPageHaloLayer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Each card grows into its room and folds away as it last
                    // looked, so the transcript above glides rather than snaps.
                    // A card folds away while its sheet rises, so nothing moves
                    // when the sheet closes.
                    TranscriptPresenceColumn(risesFromBottom: true, children: needsYou),
                    if (!readOnly && !state.isArchived)
                      SessionAutoContinuationNotice(
                        view: state.session.autoContinuation,
                        updating: state.isUpdatingAutoContinuation,
                        canInteract: state.interaction.canInteract,
                        onEnabledChanged: (enabled) =>
                            unawaited(context.read<SessionDetailCubit>().setAutoContinuation(enabled: enabled)),
                      ),
                    if (bottomControls case final controls?)
                      SentBubbleRowReach(reach: composerInset - transcriptInset, child: controls),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTranscript({
    required BuildContext context,
    required SessionDetailLoaded state,
    required double topInset,
    required double transcriptInset,
  }) {
    // A lost response may already have reached the bridge, so only an
    // authoritative rejection can be removed.
    final canRemoveFailedSend =
        !readOnly &&
        switch (state.localSend) {
          LocalSendFailed(:final failure) => failure.provesNotRun,
          LocalSendIdle() || LocalSendSending() => false,
        };
    return SessionDetailMessageList(
      projectId: projectId,
      messages: state.messages,
      localSend: state.localSend,
      queuedMessages: state.queuedMessages,
      harnessName: state.interaction.harnessDisplayName,
      launchHandoff: state.launchHandoff,
      launchStartedAt: context.read<SessionDetailCubit>().launchStartedAt,
      onRetryFailedSend: readOnly || !state.interaction.canInteract
          ? null
          : context.read<SessionDetailCubit>().retryFailedSend,
      onRemoveFailedSend: canRemoveFailedSend ? context.read<SessionDetailCubit>().removeFailedSend : null,
      launchFollowUps: state.launchFollowUps,
      promptTurnShapes: state.promptTurnShapes,
      onRetryLaunchFollowUp: readOnly || !state.interaction.canInteract
          ? null
          : context.read<SessionDetailCubit>().retryLaunchFollowUp,
      onRemoveLaunchFollowUp: readOnly ? null : context.read<SessionDetailCubit>().removeLaunchFollowUp,
      bridgeQueuedPrompts: state.bridgeQueuedPrompts,
      bridgePromptAttachments: state.bridgePromptAttachments,
      awaitingBridgeSubmissions: state.awaitingBridgeSubmissions,
      onCancelBridgeQueuedPrompt: readOnly || !state.interaction.canInteract
          ? null
          : (promptId) => unawaited(
              context.read<SessionDetailCubit>().cancelBridgeQueuedPrompt(promptId: promptId),
            ),
      isLoadingOlderMessages: state.isLoadingOlderMessages,
      isRefreshing: state.isRefreshing,
      currentPromptId: currentPromptId,
      jumpNotifier: jumpNotifier,
      onPinchIn: onPinchIn,
      streamingText: state.streamingText,
      children: state.children,
      childStatuses: state.childStatuses,
      isBusy: _isBusy(state: state),
      mainAgentRunning: state.mainAgentRunning,
      // Null once the start of the transcript is loaded,
      // so the list stops asking for more.
      onLoadOlderMessages: state.olderMessagesCursor == null
          ? null
          : context.read<SessionDetailCubit>().loadOlderMessages,
      promptIndex: state.promptIndex,
      onLoadThrough: context.read<SessionDetailCubit>().loadMessagesThrough,
      onCancelQueuedMessage: readOnly ? null : context.read<SessionDetailCubit>().cancelQueuedMessage,
      retryErrorMessage: state.retryErrorMessage,
      // Pad the oldest-message edge clear of the bar it scrolls
      // behind; the list pads the newest-message edge clear of
      // the floating bottom controls by the TranscriptBottomInset
      // above it. Content in between scrolls up behind the bar's
      // fade and the composer's fade.
      topInset: topInset,
      horizontalInset: transcriptInset,
    );
  }
}

/// A session waiting on the user is not working; its card says so.
bool _isBusy({required SessionDetailLoaded state}) =>
    hasActiveWork(sessionStatus: state.sessionStatus, childStatuses: state.childStatuses) &&
    state.pendingQuestions.isEmpty &&
    state.pendingPermissions.isEmpty;

/// Builds the transcript from [state], except that for the moment after a
/// pending request goes away it keeps showing what it showed. That moment is
/// the request's card folding away, or its sheet leaving, so the transcript's
/// own changes, such as an interrupted turn folding its steps, follow that
/// motion instead of stacking onto it. Then everything that arrived applies.
class const _TranscriptHeldWhileRequestSettles({
  required final SessionDetailLoaded state,
  required final Widget Function(SessionDetailLoaded state) builder,
}) extends StatefulWidget {
  @override
  State<_TranscriptHeldWhileRequestSettles> createState() => _TranscriptHeldWhileRequestSettlesState();
}

class _TranscriptHeldWhileRequestSettlesState() extends State<_TranscriptHeldWhileRequestSettles> {
  late SessionDetailLoaded _shown = widget.state;
  Timer? _settling;

  static int _requestCount(SessionDetailLoaded state) =>
      state.pendingQuestions.length + state.pendingPermissions.length;

  @override
  void didUpdateWidget(_TranscriptHeldWhileRequestSettles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_requestCount(widget.state) < _requestCount(oldWidget.state) && !context.isReducedMotion) {
      _settling?.cancel();
      // A card folds and a bottom sheet leaves in this time.
      _settling = Timer(transcriptMotionDuration, () => setState(() => _shown = widget.state));
    }
    if (!(_settling?.isActive ?? false)) _shown = widget.state;
  }

  @override
  void dispose() {
    _settling?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_shown);
}

String _firstLine(String text) => text.trim().split("\n").first;

bool hasActiveWork({
  required SessionStatus sessionStatus,
  required Map<String, SessionStatus> childStatuses,
}) {
  return sessionStatus is! SessionStatusIdle || childStatuses.values.any((status) => isChildRunning(status: status));
}
