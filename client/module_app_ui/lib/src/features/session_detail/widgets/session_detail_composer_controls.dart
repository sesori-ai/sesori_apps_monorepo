import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../composer_presentation_scope.dart";
import "../session_detail_presentation_scope.dart";
import "agent_model_buttons.dart";
import "background_tasks_bar.dart";
import "composer_surface_style.dart";
import "prompt_input.dart";
import "session_abort_scope_dialog.dart";
import "session_approval_chip.dart";
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
  required final SessionComposerSource source,
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
        stagedCommand: switch (widget.source) {
          LoadedSessionComposerSource(:final state) => state.stagedCommand,
          LaunchSessionComposerSource(:final stagedCommand) => stagedCommand,
        },
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
    final cubit = context.read<SessionDetailCubit>();
    return switch (widget.source) {
      LoadedSessionComposerSource(:final state) => _buildLoaded(context: context, state: state),
      // The launch's options stay read-only until the load, as they were
      // while the session was being created: the cubit refuses to change them.
      LaunchSessionComposerSource(:final composer, :final stagedCommand) => _buildComposer(
        context: context,
        // The launch's first message is already in the transcript.
        hasMessages: true,
        attachmentsSupported: composer.supportsPromptAttachments,
        isBusy: false,
        initialAttachments: cubit.launchAttachments,
        onInitialAttachmentsConsumed: cubit.acknowledgeLaunchAttachments,
        autofocus: composer.hadFocus,
        initialSelection: composer.unsent?.selection,
        // D9: the options are committed at Send.
        optionsReadOnly: true,
        agents: composer.agents,
        selectedAgent: composer.agent,
        providers: composer.providers,
        selectedAgentModel: composer.agentModel,
        availableVariants: composer.availableVariants,
        fastModeControl: composer.fastModeControl,
        statusChips: ({required surfaceStyle, required pointer}) => const [],
        composerTrailing: null,
        availableCommands: composer.commands,
        stagedCommand: stagedCommand,
      ),
    };
  }

  Widget _buildLoaded({required BuildContext context, required SessionDetailLoaded state}) => _buildComposer(
    context: context,
    // Queued messages count: the user has already "sent" something, so the
    // composer should rest as a follow-up field even before the first message
    // lands in the list.
    hasMessages:
        state.hasRenderableMessages ||
        state.launchHandoff != null ||
        state.localSend is! LocalSendIdle ||
        state.queuedMessages.isNotEmpty ||
        state.awaitingBridgeSubmissions.isNotEmpty ||
        state.bridgeQueuedPrompts.isNotEmpty,
    attachmentsSupported: state.supportsPromptAttachments,
    isBusy: hasActiveWork(sessionStatus: state.sessionStatus, childStatuses: state.childStatuses),
    initialAttachments: const [],
    onInitialAttachmentsConsumed: () {},
    autofocus: false,
    initialSelection: null,
    optionsReadOnly: false,
    agents: state.availableAgents,
    selectedAgent: state.selectedAgent,
    providers: state.availableProviders,
    selectedAgentModel: state.selectedAgentModel,
    availableVariants: state.availableVariants,
    fastModeControl: state.fastModeControl,
    statusChips: ({required surfaceStyle, required pointer}) =>
        _statusChips(state: state, surfaceStyle: surfaceStyle, pointer: pointer),
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
  );

  Widget _buildComposer({
    required BuildContext context,
    required bool hasMessages,
    required bool? attachmentsSupported,
    required bool isBusy,
    required List<ComposerAttachment> initialAttachments,
    required VoidCallback onInitialAttachmentsConsumed,
    required bool autofocus,
    required ({int start, int end})? initialSelection,
    required bool optionsReadOnly,
    required List<AgentInfo> agents,
    required String? selectedAgent,
    required List<ProviderInfo> providers,
    required AgentModel? selectedAgentModel,
    required List<SessionVariant> availableVariants,
    required FastModeControl fastModeControl,
    required List<Widget> Function({required PregoComposerSurfaceStyle surfaceStyle, required bool pointer})
    statusChips,
    required Widget? composerTrailing,
    required List<CommandInfo> availableCommands,
    required CommandInfo? stagedCommand,
  }) {
    final composerCapabilities = ComposerPresentationScope.of(context);
    final pointer = composerCapabilities.presentation == ComposerPresentation.pointer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PromptInput(
            draftIdentity: widget.sessionId,
            restorationKey: null,
            initialDraft: context.read<SessionDetailCubit>().composerDraft,
            initialSelection: initialSelection,
            initialAttachments: initialAttachments,
            onInitialAttachmentsConsumed: onInitialAttachmentsConsumed,
            onAttachmentsChanged: null,
            onSelectionChanged: null,
            onBusyChanged: null,
            autofocus: autofocus,
            hasMessages: hasMessages,
            attachmentsSupported: attachmentsSupported,
            isBusy: isBusy,
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
                agents: agents,
                selectedAgent: selectedAgent,
                onAgentSelected: context.read<SessionDetailCubit>().selectAgent,
                providers: providers,
                selectedAgentModel: selectedAgentModel,
                onModelSelected: context.read<SessionDetailCubit>().selectModel,
                availableVariants: availableVariants,
                onVariantSelected: context.read<SessionDetailCubit>().selectVariant,
                fastModeControl: fastModeControl,
                decideFastModeToggle: context.read<SessionDetailCubit>().fastModeToggleDecision,
                onFastModeChanged: context.read<SessionDetailCubit>().setFastMode,
                compact: pointer,
                readOnly: optionsReadOnly,
                trailing: statusChips(surfaceStyle: surfaceStyle, pointer: pointer),
              ),
            ),
            composerTrailing: composerTrailing,
            availableCommands: availableCommands,
            stagedCommand: stagedCommand,
            onCommandSelected: context.read<SessionDetailCubit>().stageCommand,
            onCommandCleared: context.read<SessionDetailCubit>().clearStagedCommand,
          ),
        ),
      ],
    );
  }

  /// Quiet session states beside the pickers: the session's approval mode, and
  /// auto-continuation while it is enabled but not due.
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
      // Touch status chips stay glyphs so the shared-width pickers keep their labels.
      ?switch (state.approvalControl) {
        SessionApprovalHidden() => null,
        SessionApprovalBridgeWideYolo() => YoloChip(
          surfaceStyle: surfaceStyle,
          showLabel: pointer,
          onOpenSettings: () => SessionDetailPresentationScope.read(context).openBridgeSettings(),
        ),
        final SessionApprovalPerSession control => SessionApprovalChip(
          surfaceStyle: surfaceStyle,
          control: control,
          showLabel: pointer,
          updating: state.isUpdatingApproval,
          onSelect: (mode) => unawaited(context.read<SessionDetailCubit>().setApprovalMode(mode: mode)),
        ),
      },
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
