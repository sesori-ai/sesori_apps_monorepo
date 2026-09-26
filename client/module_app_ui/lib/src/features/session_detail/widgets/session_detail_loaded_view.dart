import "dart:async";
import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "session_auto_continuation_notice.dart";
import "session_detail_message_list.dart";
import "session_detail_scaffold_sections.dart";

typedef SessionDetailBottomControlsBuilder = Widget Function({
  required BuildContext context,
  required String projectId,
  required String sessionId,
  required SessionDetailLoaded state,
});

/// The centred column widths of a pointer surface's session page.
///
/// The transcript reads wider than the composer below it: long-form text
/// benefits from a column that would make a text field and its pill row look
/// stretched.
class const SessionDetailColumnWidths({
  required final double transcript,
  required final double composer,
});

class SessionDetailLoadedView extends StatefulWidget {
  final String? projectId;
  final String sessionId;
  final SessionDetailLoaded state;
  final bool readOnly;
  final Widget? bottomControls;

  /// Caps the transcript and the bottom controls to centred columns of their
  /// own widths; null lets both span the pane.
  final SessionDetailColumnWidths? columnWidths;
  final VoidCallback onShowPendingQuestions;
  final VoidCallback onShowPendingPermissions;

  const new readOnly({
    super.key,
    required this.projectId,
    required this.sessionId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
    required this.bottomControls,
    required this.columnWidths,
  }) : readOnly = true;

  const new interactive({
    super.key,
    required this.projectId,
    required this.sessionId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
    required this.bottomControls,
    required this.columnWidths,
  }) : readOnly = false;

  @override
  State<SessionDetailLoadedView> createState() => _SessionDetailLoadedViewState();
}

class _SessionDetailLoadedViewState() extends State<SessionDetailLoadedView> {
  /// Measured height of the floating bottom controls overlaying the bottom of
  /// the chat — the needs-you cards, background-tasks bar and composer, or a
  /// read-only session's run details. Fed to the message list so the newest
  /// message rests just above them (and the "jump to latest" pill clears them)
  /// while older content scrolls up behind the composer's fade.
  ///
  /// A notifier rather than state: the composer's layout morphs animate its
  /// height frame-by-frame, and each measurement must re-inset only the
  /// message list — not rebuild the whole view including the very composer
  /// being measured.
  final ValueNotifier<double> _bottomControlsHeight = ValueNotifier<double>(0);

  @override
  void dispose() {
    _bottomControlsHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columnWidths = widget.columnWidths;
    if (columnWidths == null) return _buildContent(context: context, transcriptInset: 0, composerInset: 0);
    return LayoutBuilder(
      builder: (context, constraints) => _buildContent(
        context: context,
        transcriptInset: _centringInset(paneWidth: constraints.maxWidth, columnWidth: columnWidths.transcript),
        composerInset: _centringInset(paneWidth: constraints.maxWidth, columnWidth: columnWidths.composer),
      ),
    );
  }

  /// No inset once the pane is narrower than the column, so a narrow window
  /// degrades to the full-width layout instead of clipping.
  static double _centringInset({required double paneWidth, required double columnWidth}) =>
      math.max(0, (paneWidth - columnWidth) / 2);

  Widget _buildContent({
    required BuildContext context,
    required double transcriptInset,
    required double composerInset,
  }) {
    final loc = context.loc;
    final state = widget.state;
    // A session waiting on the user is not working; its card says so.
    final isBusy =
        hasActiveWork(sessionStatus: state.sessionStatus, childStatuses: state.childStatuses) &&
        state.pendingQuestions.isEmpty &&
        state.pendingPermissions.isEmpty;
    final showEmptyState =
        !isBusy &&
        !state.hasRenderableMessages &&
        state.retryErrorMessage == null &&
        state.olderMessagesCursor == null &&
        !state.isLoadingOlderMessages &&
        state.localSend is LocalSendIdle &&
        state.queuedMessages.isEmpty &&
        state.awaitingBridgeSubmissions.isEmpty &&
        state.bridgeQueuedPrompts.isEmpty;
    // A lost response may already have reached the bridge, so only an
    // authoritative rejection can be removed.
    final canRemoveFailedSend =
        !widget.readOnly &&
        switch (state.localSend) {
          LocalSendFailed(:final failure) => failure == PromptSendFailure.rejected,
          LocalSendIdle() || LocalSendSending() => false,
        };
    final questionCount = state.pendingQuestions.fold<int>(0, (sum, q) => sum + q.questions.length);
    // An archived session's requests can never be answered.
    final canAnswer = !widget.readOnly && !state.isArchived && state.interaction.canInteract;
    final needsYou = [
      if (state.pendingQuestions.firstOrNull?.questions.firstOrNull case final question? when canAnswer)
        SessionDetailNeedsYouCard(
          icon: TablerRegular.help,
          label: questionCount == 1 ? loc.questionBannerSingle : loc.questionBannerMultiple(questionCount),
          request: _firstLine(question.question),
          action: loc.needsYouAnswer,
          onPressed: widget.onShowPendingQuestions,
        ),
      if (state.pendingPermissions.firstOrNull case final permission? when canAnswer)
        SessionDetailNeedsYouCard(
          icon: TablerRegular.shield,
          label: state.pendingPermissions.length == 1
              ? loc.permissionBannerSingle
              : loc.permissionBannerMultiple(state.pendingPermissions.length),
          request: _firstLine(permission.description),
          action: loc.needsYouReview,
          onPressed: widget.onShowPendingPermissions,
        ),
    ];
    final hasBottomControls = needsYou.isNotEmpty || widget.bottomControls != null;

    // The scaffold lets this view fill the full height behind the transparent
    // bar (reserveBarSpace: false), so the message list scrolls behind it like
    // every other screen. The chat's content inset — and the pinned refresh
    // indicator and archived notice — come from PregoTopBarInsetBuilder so
    // they clear the bar at rest and ride the top-nav connection banner's height
    // animation frame-by-frame.
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: showEmptyState
                  ? Center(child: Text(loc.sessionDetailEmpty))
                  : PregoTopBarInsetBuilder(
                      builder: (context, topInset, _) => ValueListenableBuilder<double>(
                        valueListenable: _bottomControlsHeight,
                        builder: (context, bottomControlsHeight, _) => SessionDetailMessageList(
                          projectId: widget.projectId,
                          messages: state.messages,
                          localSend: state.localSend,
                          queuedMessages: state.queuedMessages,
                          harnessName: state.interaction.harnessDisplayName,
                          onRetryFailedSend: widget.readOnly || !state.interaction.canInteract
                              ? null
                              : context.read<SessionDetailCubit>().retryFailedSend,
                          onRemoveFailedSend: canRemoveFailedSend
                              ? context.read<SessionDetailCubit>().removeFailedSend
                              : null,
                          bridgeQueuedPrompts: state.bridgeQueuedPrompts,
                          bridgePromptAttachments: state.bridgePromptAttachments,
                          awaitingBridgeSubmissions: state.awaitingBridgeSubmissions,
                          onCancelBridgeQueuedPrompt: widget.readOnly || !state.interaction.canInteract
                              ? null
                              : (promptId) => unawaited(
                                  context.read<SessionDetailCubit>().cancelBridgeQueuedPrompt(promptId: promptId),
                                ),
                          isLoadingOlderMessages: state.isLoadingOlderMessages,
                          isRefreshing: state.isRefreshing,
                          transcriptFolded: state.transcriptFolded,
                          onTranscriptFoldedChanged: context.read<SessionDetailCubit>().setTranscriptFolded,
                          streamingText: state.streamingText,
                          children: state.children,
                          childStatuses: state.childStatuses,
                          isBusy: isBusy,
                          // Null once the start of the transcript is loaded,
                          // so the list stops asking for more.
                          onLoadOlderMessages: state.olderMessagesCursor == null
                              ? null
                              : context.read<SessionDetailCubit>().loadOlderMessages,
                          onCancelQueuedMessage: widget.readOnly
                              ? null
                              : context.read<SessionDetailCubit>().cancelQueuedMessage,
                          retryErrorMessage: state.retryErrorMessage,
                          // Pad the oldest-message edge clear of the bar it scrolls
                          // behind, and the newest-message edge clear of the floating
                          // bottom controls overlaid below (background-tasks bar and
                          // composer); content in between scrolls
                          // up behind the bar's fade and the composer's fade.
                          topInset: topInset,
                          bottomInset: hasBottomControls ? bottomControlsHeight : 0,
                          horizontalInset: transcriptInset,
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
            ],
          ),
        ),
        // Floating bottom controls: the needs-you cards docked above the
        // background-tasks bar and composer. Queued submissions are regular
        // rows in the transcript above them.
        if (hasBottomControls)
          Positioned(
            bottom: 0,
            left: composerInset,
            right: composerInset,
            child: PregoSizeObserver(
              onSizeChanged: (size) {
                if (!mounted) return;
                _bottomControlsHeight.value = size.height;
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...needsYou,
                  if (!widget.readOnly && !state.isArchived)
                    SessionAutoContinuationNotice(
                      view: state.session.autoContinuation,
                      updating: state.isUpdatingAutoContinuation,
                      canInteract: state.interaction.canInteract,
                      onEnabledChanged: (enabled) =>
                          unawaited(context.read<SessionDetailCubit>().setAutoContinuation(enabled: enabled)),
                    ),
                  ?widget.bottomControls,
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _firstLine(String text) => text.trim().split("\n").first;

bool hasActiveWork({
  required SessionStatus sessionStatus,
  required Map<String, SessionStatus> childStatuses,
}) {
  return sessionStatus is! SessionStatusIdle ||
      childStatuses.values.any((s) => s is SessionStatusBusy || s is SessionStatusRetry);
}
