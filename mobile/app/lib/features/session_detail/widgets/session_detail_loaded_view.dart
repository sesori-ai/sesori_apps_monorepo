import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

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
  final VoidCallback onOpenEffortPicker;

  const SessionDetailLoadedView.readOnly({
    super.key,
    required this.projectId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
  }) : readOnly = true,
       onOpenAgentPicker = _noopCallback,
       onOpenModelPicker = _noopCallback,
       onOpenEffortPicker = _noopCallback;

  const SessionDetailLoadedView.editable({
    super.key,
    required this.projectId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
    required this.onOpenAgentPicker,
    required this.onOpenModelPicker,
    required this.onOpenEffortPicker,
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
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            label: questionCount == 1 ? loc.questionBannerSingle : loc.questionBannerMultiple(questionCount),
            onTap: onShowPendingQuestions,
          ),
        if (state.pendingPermissions.isNotEmpty)
          SessionDetailPendingBanner(
            icon: Icons.shield_outlined,
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
            label: state.pendingPermissions.length == 1
                ? loc.permissionBannerSingle
                : loc.permissionBannerMultiple(state.pendingPermissions.length),
            onTap: onShowPendingPermissions,
          ),
        Expanded(
          child: state.messages.isEmpty
              ? Center(child: Text(loc.sessionDetailEmpty))
              : SessionDetailMessageList(
                  projectId: projectId,
                  messages: state.messages,
                  streamingText: state.streamingText,
                  children: state.children,
                  childStatuses: state.childStatuses,
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
              providers: state.availableProviders,
              selectedAgent: state.selectedAgent,
              selectedProviderID: state.selectedProviderID,
              selectedModelID: state.selectedModelID,
              selectedEffort: state.selectedEffort,
              onAgentTap: onOpenAgentPicker,
              onModelTap: onOpenModelPicker,
              onEffortTap: onOpenEffortPicker,
            ),
            availableCommands: state.availableCommands,
            stagedCommand: state.stagedCommand,
            onCommandSelected: context.read<SessionDetailCubit>().stageCommand,
            onCommandCleared: context.read<SessionDetailCubit>().clearStagedCommand,
          ),
      ],
    );
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
