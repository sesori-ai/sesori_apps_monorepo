import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/agent_model_buttons.dart";
import "background_tasks_bar.dart";
import "prompt_input.dart";
import "session_detail_message_list.dart";
import "session_detail_scaffold_sections.dart";

class SessionDetailLoadedView extends StatelessWidget {
  final String? projectId;
  final SessionDetailLoaded state;
  final bool readOnly;
  final VoidCallback onShowPendingQuestions;
  final VoidCallback onShowPendingPermissions;
  final VoidCallback onOpenAgentPicker;
  final VoidCallback onOpenModelPicker;
  final VoidCallback onOpenVariantPicker;

  const SessionDetailLoadedView.readOnly({
    super.key,
    required this.projectId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
  }) : readOnly = true,
       onOpenAgentPicker = _noopCallback,
       onOpenModelPicker = _noopCallback,
       onOpenVariantPicker = _noopCallback;

  const SessionDetailLoadedView.editable({
    super.key,
    required this.projectId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
    required this.onOpenAgentPicker,
    required this.onOpenModelPicker,
    required this.onOpenVariantPicker,
  }) : readOnly = false;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final questionCount = state.pendingQuestions.fold<int>(0, (sum, q) => sum + q.questions.length);

    return Column(
      children: [
        if (state.isRefreshing) const LinearProgressIndicator(),
        if (state.pendingQuestions.isNotEmpty)
          SessionDetailPendingBanner(
            icon: Icons.help_outline,
            backgroundColor: context.zyra.colors.bgBrandPrimary,
            foregroundColor: context.zyra.colors.bgBrandPrimaryAlt,
            label: questionCount == 1 ? loc.questionBannerSingle : loc.questionBannerMultiple(questionCount),
            onTap: onShowPendingQuestions,
          ),
        if (state.pendingPermissions.isNotEmpty)
          SessionDetailPendingBanner(
            icon: Icons.shield_outlined,
            backgroundColor: context.zyra.colors.bgSuccessSecondary,
            foregroundColor: context.zyra.colors.fgSuccessPrimary,
            label: state.pendingPermissions.length == 1
                ? loc.permissionBannerSingle
                : loc.permissionBannerMultiple(state.pendingPermissions.length),
            onTap: onShowPendingPermissions,
          ),
        Expanded(
          child: state.messages.isEmpty && state.retryErrorMessage == null
              ? Center(child: Text(loc.sessionDetailEmpty))
              : SessionDetailMessageList(
                  projectId: projectId,
                  messages: state.messages,
                  streamingText: state.streamingText,
                  children: state.children,
                  childStatuses: state.childStatuses,
                  retryErrorMessage: state.retryErrorMessage,
                ),
        ),
        if (state.children.isNotEmpty && !readOnly)
          BackgroundTasksBar(
            projectId: projectId,
            children: state.children,
            childStatuses: state.childStatuses,
          ),
        if (!readOnly && state.queuedMessages.isNotEmpty)
          SessionDetailQueuedMessagesSection(messages: state.queuedMessages),
        if (!readOnly)
          PromptInput(
            isBusy: hasActiveWork(
              sessionStatus: state.sessionStatus,
              childStatuses: state.childStatuses,
            ),
            onSend: (text, command) => context.read<SessionDetailCubit>().sendMessage(
              text: text,
              command: command,
            ),
            onAbort: () => context.read<SessionDetailCubit>().abort(),
            header: null,
            composerHeader: AgentModelButtons(
              availableVariants: state.availableVariants,
              modelName: _resolveModelName(state),
              selectedAgent: state.selectedAgent,
              selectedAgentModel: state.selectedAgentModel,
              onAgentTap: onOpenAgentPicker,
              onModelTap: onOpenModelPicker,
              onVariantTap: onOpenVariantPicker,
            ),
            availableCommands: state.availableCommands,
            stagedCommand: state.stagedCommand,
            onCommandSelected: context.read<SessionDetailCubit>().stageCommand,
            onCommandCleared: context.read<SessionDetailCubit>().clearStagedCommand,
          ),
      ],
    );
  }

  String _resolveModelName(SessionDetailLoaded state) {
    final providerID = state.selectedAgentModel?.providerID;
    final modelID = state.selectedAgentModel?.modelID;
    const fallback = 'Model';
    if (providerID == null || modelID == null) return fallback;
    for (final provider in state.availableProviders) {
      if (provider.id == providerID) {
        final model = provider.models[modelID];
        if (model != null) return model.name;
      }
    }
    if (modelID.isNotEmpty) return modelID;
    return fallback;
  }
}

void _noopCallback() {}

bool hasActiveWork({
  required SessionStatus sessionStatus,
  required Map<String, SessionStatus> childStatuses,
}) {
  return sessionStatus is! SessionStatusIdle ||
      childStatuses.values.any((s) => s is SessionStatusBusy || s is SessionStatusRetry);
}
