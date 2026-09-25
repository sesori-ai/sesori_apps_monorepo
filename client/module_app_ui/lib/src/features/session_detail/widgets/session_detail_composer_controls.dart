import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../composer_presentation_scope.dart";
import "../session_detail_presentation_scope.dart";
import "agent_model_buttons.dart";
import "background_tasks_bar.dart";
import "composer_surface_style.dart";
import "prompt_input.dart";
import "session_abort_scope_dialog.dart";
import "session_auto_continuation_chip.dart";
import "session_auto_continuation_notice.dart";
import "session_detail_loaded_view.dart";
import "yolo_chip.dart";

/// Shared session composer controls injected below the transcript view.
///
/// Product shells provide platform and voice capabilities through
/// [ComposerPresentationScope].
class const SessionDetailComposerControls({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final SessionDetailLoaded state,
}) extends StatefulWidget {
  @override
  State<SessionDetailComposerControls> createState() => _SessionDetailComposerControlsState();
}

class _SessionDetailComposerControlsState() extends State<SessionDetailComposerControls> {
  late final ValueNotifier<PregoComposerSurfaceStyle> _composerSurfaceStyle;

  @override
  void initState() {
    super.initState();
    _composerSurfaceStyle = ValueNotifier(
      resolveInitialComposerSurfaceStyle(
        inputMode: ComposerPresentationScope.read(context).inputMode,
        draft: context.read<SessionDetailCubit>().composerDraft,
        stagedCommand: widget.state.stagedCommand,
      ),
    );
  }

  @override
  void dispose() {
    _composerSurfaceStyle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final composerCapabilities = ComposerPresentationScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PromptInput(
            draftIdentity: widget.sessionId,
            restorationKey: null,
            initialDraft: context.read<SessionDetailCubit>().composerDraft,
            initialAttachments: const [],
            onInitialAttachmentsConsumed: () {},
            // Queued messages count: the user has already "sent"
            // something, so the composer should rest as a follow-up field
            // even before the first message lands in the list.
            hasMessages:
                state.hasRenderableMessages ||
                state.localSend is! LocalSendIdle ||
                state.queuedMessages.isNotEmpty ||
                state.awaitingBridgeSubmissions.isNotEmpty ||
                state.bridgeQueuedPrompts.isNotEmpty,
            attachmentsSupported: state.supportsPromptAttachments,
            isBusy: hasActiveWork(
              sessionStatus: state.sessionStatus,
              childStatuses: state.childStatuses,
            ),
            canSend: true,
            onSend: ({required draft, required command, required attachments}) =>
                context.read<SessionDetailCubit>().sendMessage(
                  text: draft.text,
                  command: command,
                  inputMode: command == null ? draft.inputMode : ComposerInputMode.typed,
                  attachments: attachments,
                ),
            onVoiceTranscriptionCompleted: composerCapabilities.voiceSupport.isSupported
                ? context.read<SessionDetailCubit>().reportVoiceTranscriptionCompleted
                : null,
            onDraftChanged: (draft) => context.read<SessionDetailCubit>().saveComposerDraft(draft: draft),
            onDraftCleared: context.read<SessionDetailCubit>().clearComposerDraft,
            onAbort: () => stopSessionWithScope(
              context: context,
              cubit: context.read<SessionDetailCubit>(),
            ),
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
                fastModeControl: state.fastModeControl,
                decideFastModeToggle: context.read<SessionDetailCubit>().fastModeToggleDecision,
                onFastModeChanged: context.read<SessionDetailCubit>().setFastMode,
                compact: composerCapabilities.presentation == ComposerPresentation.pointer,
                trailing: _statusChips(
                  state: state,
                  surfaceStyle: surfaceStyle,
                  pointer: composerCapabilities.presentation == ComposerPresentation.pointer,
                ),
              ),
            ),
            composerTrailing: state.children.isEmpty
                ? null
                : ValueListenableBuilder<PregoComposerSurfaceStyle>(
                    valueListenable: _composerSurfaceStyle,
                    builder: (context, surfaceStyle, _) => BackgroundTasksBar(
                      surfaceStyle: surfaceStyle,
                      projectId: widget.projectId,
                      children: state.children,
                      childStatuses: state.childStatuses,
                    ),
                  ),
            availableCommands: state.availableCommands,
            stagedCommand: state.stagedCommand,
            onCommandSelected: context.read<SessionDetailCubit>().stageCommand,
            onCommandCleared: context.read<SessionDetailCubit>().clearStagedCommand,
          ),
        ),
      ],
    );
  }

  /// Quiet session states beside the pickers: YOLO while the bridge approves
  /// everything, and auto-continuation while it is enabled but not due.
  List<Widget> _statusChips({
    required SessionDetailLoaded state,
    required PregoComposerSurfaceStyle surfaceStyle,
    required bool pointer,
  }) {
    final view = state.session.autoContinuation;
    // Enabled with nothing due: the chip stands in for the hidden card.
    final continuation = view != null && view.enabled && !sessionAutoContinuationNoticeVisible(view: view)
        ? view
        : null;
    return [
      if (state.yoloEnabled)
        YoloChip(
          surfaceStyle: surfaceStyle,
          // Touch status chips stay glyphs so the shared-width pickers keep their labels.
          showLabel: pointer,
          onOpenSettings: () => SessionDetailPresentationScope.read(context).openBridgeSettings(),
        ),
      if (continuation != null)
        SessionAutoContinuationChip(
          surfaceStyle: surfaceStyle,
          view: continuation,
          showLabel: pointer,
          updating: state.isUpdatingAutoContinuation,
          onDisable: () => unawaited(context.read<SessionDetailCubit>().setAutoContinuation(enabled: false)),
        ),
    ];
  }
}
