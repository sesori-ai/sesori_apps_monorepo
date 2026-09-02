import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../composer_presentation_scope.dart";
import "agent_model_buttons.dart";
import "background_tasks_bar.dart";
import "composer_surface_style.dart";
import "prompt_input.dart";
import "session_detail_loaded_view.dart";

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
            onVoiceTranscriptionCompleted: composerCapabilities.voiceSupport == ComposerVoiceSupport.supported
                ? context.read<SessionDetailCubit>().reportVoiceTranscriptionCompleted
                : null,
            onDraftChanged: (draft) => context.read<SessionDetailCubit>().saveComposerDraft(draft: draft),
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
    );
  }
}
