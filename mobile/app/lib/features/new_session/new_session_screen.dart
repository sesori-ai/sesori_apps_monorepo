import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/agent_model_buttons.dart";
import "../../core/widgets/agent_picker_sheet.dart";
import "../../core/widgets/model_picker_sheet.dart";
import "../../core/widgets/variant_picker_sheet.dart";
import "../session_detail/widgets/prompt_input.dart";

class NewSessionScreen extends StatelessWidget {
  final String projectId;

  const NewSessionScreen({
    super.key,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewSessionCubit(
        sessionService: getIt<SessionService>(),
        projectId: projectId,
      ),
      child: _NewSessionBody(projectId: projectId),
    );
  }
}

class _NewSessionBody extends StatefulWidget {
  final String projectId;

  const _NewSessionBody({required this.projectId});

  @override
  State<_NewSessionBody> createState() => _NewSessionBodyState();
}

class _NewSessionBodyState extends State<_NewSessionBody> {
  bool _dedicatedWorktree = true;

  void _dismissScreen() {
    context.pop();
  }

  void _openAgentPicker(AgentModelData data) {
    final cubit = context.read<NewSessionCubit>();
    AgentPickerSheet.show(
      context,
      agents: data.agents,
      selectedAgent: data.agent ?? "",
      onAgentChanged: cubit.selectAgent,
    );
  }

  void _openModelPicker(AgentModelData data) {
    final cubit = context.read<NewSessionCubit>();
    final agentModel = data.agentModel;
    ModelPickerSheet.show(
      context,
      providers: data.providers,
      selectedProviderID: agentModel?.providerID ?? "",
      selectedModelID: agentModel?.modelID ?? "",
      onModelChanged: cubit.selectModel,
    );
  }

  void _openVariantPicker(AgentModelData data) {
    VariantPickerSheet.show(
      context,
      selectedVariant: data.selectedVariant,
      availableVariants: data.availableVariants,
      onVariantChanged: context.read<NewSessionCubit>().selectVariant,
    );
  }

  Widget? _buildErrorBanner(NewSessionState state) {
    return switch (state) {
      NewSessionError(:final message) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
      NewSessionIdle() => null,
      NewSessionSending() => null,
      NewSessionCreated() => null,
    };
  }

  Widget? _buildComposerHeader(NewSessionState state) {
    final data = state.agentModelData;
    final selectedAgent = data?.agent;
    if (data == null || data.agents.isEmpty || selectedAgent == null) return null;

    final modelName = _resolveModelName(data);
    return AgentModelButtons(
      availableVariants: data.availableVariants,
      modelName: modelName,
      selectedAgent: selectedAgent,
      selectedVariant: data.selectedVariant,
      onAgentTap: () => _openAgentPicker(data),
      onModelTap: () => _openModelPicker(data),
      onVariantTap: () => _openVariantPicker(data),
    );
  }

  String _resolveModelName(AgentModelData data) {
    final providerID = data.agentModel?.providerID;
    final modelID = data.agentModel?.modelID;
    final loc = context.loc;
    if (providerID == null || modelID == null) return loc.sessionDetailPickerModel;
    for (final provider in data.providers) {
      if (provider.id == providerID) {
        final model = provider.models[modelID];
        if (model != null) return model.name;
      }
    }
    if (modelID.isNotEmpty) return modelID;
    return loc.sessionDetailPickerModel;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NewSessionCubit>().state;
    final loc = context.loc;

    return BlocListener<NewSessionCubit, NewSessionState>(
      listenWhen: (_, current) => current is NewSessionCreated,
      listener: (context, state) {
        if (state case NewSessionCreated(:final session)) {
          _dismissScreen();
          context.pushRoute(
            AppRoute.sessionDetail(
              projectId: widget.projectId,
              sessionId: session.id,
              sessionTitle: session.title ?? "",
              readOnly: false,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(loc.sessionListNewSession)),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: Text(loc.newSessionDedicatedWorktree),
                      subtitle: Text(
                        loc.newSessionDedicatedWorktreeDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _dedicatedWorktree,
                      onChanged: (value) => setState(() => _dedicatedWorktree = value),
                    ),
                  ],
                ),
              ),
            ),
            PromptInput(
              isBusy: state is NewSessionSending,
              onSend: (String text, String? command) {
                context.read<NewSessionCubit>().createSession(
                  text: text,
                  command: command,
                  dedicatedWorktree: _dedicatedWorktree,
                );
              },
              onAbort: _dismissScreen,
              header: _buildErrorBanner(state),
              composerHeader: _buildComposerHeader(state),
              availableCommands: state.agentModelData?.commands ?? const [],
              stagedCommand: state.agentModelData?.stagedCommand,
              onCommandSelected: context.read<NewSessionCubit>().stageCommand,
              onCommandCleared: context.read<NewSessionCubit>().clearStagedCommand,
            ),
          ],
        ),
      ),
    );
  }
}
