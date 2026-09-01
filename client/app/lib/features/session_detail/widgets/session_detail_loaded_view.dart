import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/di/injection.dart";
import "../../../core/widgets/agent_model_buttons.dart";
import "../../../core/widgets/composer_surface_style.dart";
import "background_tasks_bar.dart";
import "prompt_input.dart";
import "session_detail_message_list.dart";
import "session_detail_scaffold_sections.dart";

class SessionDetailLoadedView extends StatefulWidget {
  final String? projectId;
  final String sessionId;
  final SessionDetailLoaded state;
  final bool readOnly;
  final VoidCallback onShowPendingQuestions;
  final VoidCallback onShowPendingPermissions;

  const new readOnly({
    super.key,
    required this.projectId,
    required this.sessionId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
  }) : readOnly = true;

  const new editable({
    super.key,
    required this.projectId,
    required this.sessionId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
  }) : readOnly = false;

  @override
  State<SessionDetailLoadedView> createState() => _SessionDetailLoadedViewState();
}

class _SessionDetailLoadedViewState() extends State<SessionDetailLoadedView> {
  /// Measured height of the floating bottom controls overlaying the bottom of
  /// the chat — the background-tasks bar and composer. Fed to the message list
  /// so the newest message rests just above them (and the
  /// "jump to latest" pill clears them) while older content scrolls up behind
  /// the composer's fade. Read-only variants stay at 0.
  ///
  /// A notifier rather than state: the composer's layout morphs animate its
  /// height frame-by-frame, and each measurement must re-inset only the
  /// message list — not rebuild the whole view including the very composer
  /// being measured.
  final ValueNotifier<double> _bottomControlsHeight = ValueNotifier<double>(0);
  late final ValueNotifier<PregoComposerSurfaceStyle> _composerSurfaceStyle;

  @override
  void initState() {
    super.initState();
    _composerSurfaceStyle = ValueNotifier(
      resolveInitialComposerSurfaceStyle(
        inputMode: context.read<ChatInputModeCubit>().state,
        draft: context.read<SessionDetailCubit>().composerDraft,
        stagedCommand: widget.state.stagedCommand,
      ),
    );
  }

  @override
  void dispose() {
    _bottomControlsHeight.dispose();
    _composerSurfaceStyle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = widget.state;
    final editableSessionId = widget.readOnly ? null : widget.sessionId;
    final hasBottomControls = editableSessionId != null;
    final showEmptyState =
        !state.hasRenderableMessages &&
        state.retryErrorMessage == null &&
        state.olderMessagesCursor == null &&
        !state.isLoadingOlderMessages &&
        state.sendingSubmission == null &&
        state.queuedMessages.isEmpty &&
        state.awaitingBridgeSubmissions.isEmpty &&
        state.bridgeQueuedPrompts.isEmpty;
    final questionCount = state.pendingQuestions.fold<int>(0, (sum, q) => sum + q.questions.length);

    // The scaffold lets this view fill the full height behind the transparent
    // bar (reserveBarSpace: false), so the message list scrolls behind it like
    // every other screen. The chat's content inset — and the pinned refresh
    // indicator / banners — come from PregoTopBarInsetBuilder so they clear
    // the bar at rest and ride the top-nav connection banner's height
    // animation frame-by-frame.
    final content = Stack(
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
                          sendingSubmission: state.sendingSubmission,
                          queuedMessages: state.queuedMessages,
                          bridgeQueuedPrompts: state.bridgeQueuedPrompts,
                          awaitingBridgeSubmissions: state.awaitingBridgeSubmissions,
                          onCancelBridgeQueuedPrompt: widget.readOnly
                              ? null
                              : (promptId) => unawaited(
                                  context.read<SessionDetailCubit>().cancelBridgeQueuedPrompt(promptId: promptId),
                                ),
                          isLoadingOlderMessages: state.isLoadingOlderMessages,
                          streamingText: state.streamingText,
                          children: state.children,
                          childStatuses: state.childStatuses,
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
                        ),
                      ),
                    ),
            ),
          ],
        ),
        // The refresh indicator and pending banners pin just below the
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
              // where the composer used to be, and drop the pending banners —
              // an archived session's requests can never be answered.
              if (state.isArchived) const SessionDetailArchivedNotice(),
              if (!state.isArchived && state.pendingQuestions.isNotEmpty)
                SessionDetailPendingBanner(
                  icon: Icons.help_outline,
                  backgroundColor: context.prego.colors.bgBrandPrimary,
                  foregroundColor: context.prego.colors.textBrandPrimary,
                  label: questionCount == 1 ? loc.questionBannerSingle : loc.questionBannerMultiple(questionCount),
                  onTap: widget.onShowPendingQuestions,
                ),
              if (!state.isArchived && state.pendingPermissions.isNotEmpty)
                SessionDetailPendingBanner(
                  icon: Icons.shield_outlined,
                  backgroundColor: context.prego.colors.bgSuccessPrimary,
                  foregroundColor: context.prego.colors.textSuccessPrimary,
                  label: state.pendingPermissions.length == 1
                      ? loc.permissionBannerSingle
                      : loc.permissionBannerMultiple(state.pendingPermissions.length),
                  onTap: widget.onShowPendingPermissions,
                ),
            ],
          ),
        ),
        // Floating bottom controls — the background-tasks bar and composer.
        // Queued submissions are regular rows in the transcript above them.
        if (hasBottomControls)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: PregoSizeObserver(
              onSizeChanged: (size) {
                if (!mounted) return;
                _bottomControlsHeight.value = size.height;
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.children.isNotEmpty)
                    ValueListenableBuilder<PregoComposerSurfaceStyle>(
                      valueListenable: _composerSurfaceStyle,
                      builder: (context, surfaceStyle, _) => BackgroundTasksBar(
                        surfaceStyle: surfaceStyle,
                        projectId: widget.projectId,
                        children: state.children,
                        childStatuses: state.childStatuses,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PromptInput(
                      draftIdentity: editableSessionId,
                      restorationKey: null,
                      initialDraft: context.read<SessionDetailCubit>().composerDraft,
                      initialAttachments: const [],
                      onInitialAttachmentsConsumed: () {},
                      // Queued messages count: the user has already "sent"
                      // something, so the composer should rest as a follow-up
                      // field even before the first message lands in the list.
                      hasMessages:
                          state.hasRenderableMessages ||
                          state.sendingSubmission != null ||
                          state.queuedMessages.isNotEmpty ||
                          state.awaitingBridgeSubmissions.isNotEmpty ||
                          state.bridgeQueuedPrompts.isNotEmpty,
                      attachmentsSupported: state.supportsPromptAttachments,
                      isBusy: hasActiveWork(
                        sessionStatus: state.sessionStatus,
                        childStatuses: state.childStatuses,
                      ),
                      onSend: ({required draft, required command, required attachments}) =>
                          context.read<SessionDetailCubit>().sendMessage(
                            text: draft.text,
                            command: command,
                            inputMode: command == null ? draft.inputMode : ComposerInputMode.typed,
                            attachments: attachments,
                          ),
                      onVoiceTranscriptionCompleted: context
                          .read<SessionDetailCubit>()
                          .reportVoiceTranscriptionCompleted,
                      onDraftChanged: (draft) => context.read<SessionDetailCubit>().saveComposerDraft(
                        draft: draft,
                      ),
                      onDraftCleared: context.read<SessionDetailCubit>().clearComposerDraft,
                      onAbort: () => context.read<SessionDetailCubit>().abort(),
                      surfaceStyleController: _composerSurfaceStyle,
                      header: null,
                      composerHeader: ValueListenableBuilder<PregoComposerSurfaceStyle>(
                        valueListenable: _composerSurfaceStyle,
                        builder: (context, surfaceStyle, _) => AgentModelButtons(
                          surfaceStyle: surfaceStyle,
                          agents: state.availableAgents,
                          selectedAgent: state.selectedAgent,
                          onAgentSelected: context.read<SessionDetailCubit>().selectAgent,
                          providers: state.availableProviders,
                          selectedAgentModel: state.selectedAgentModel,
                          onModelSelected: context.read<SessionDetailCubit>().selectModel,
                          availableVariants: state.availableVariants,
                          onVariantSelected: context.read<SessionDetailCubit>().selectVariant,
                        ),
                      ),
                      availableCommands: state.availableCommands,
                      stagedCommand: state.stagedCommand,
                      onCommandSelected: context.read<SessionDetailCubit>().stageCommand,
                      onCommandCleared: context.read<SessionDetailCubit>().clearStagedCommand,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (widget.readOnly) return content;
    return BlocProvider(
      create: (_) {
        final service = getIt<VoiceTranscriptionService>();
        return VoiceInputCubit(
          service: service,
          session: service.createSession(projectId: widget.projectId),
        );
      },
      child: content,
    );
  }
}

bool hasActiveWork({
  required SessionStatus sessionStatus,
  required Map<String, SessionStatus> childStatuses,
}) {
  return sessionStatus is! SessionStatusIdle ||
      childStatuses.values.any((s) => s is SessionStatusBusy || s is SessionStatusRetry);
}
